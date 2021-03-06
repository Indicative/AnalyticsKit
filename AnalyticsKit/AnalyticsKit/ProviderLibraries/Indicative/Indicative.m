//
//  Indicative.m
//  Indicative

//  Standalone client for Indicative's REST API.  Events are queued up in an NSMutableArray, and a scheduled timer job periodically sends us those events in a background thread.
//
//  Created by Indicative on 08-01-13.
//  Copyright (c) 2013 Indicative. All rights reserved.
//

#import "Indicative.h"
#import "IndicativeEvent.h"

#define INDICATIVE_VERSION @"0.0.4"
#define INDICATIVE_ENDPOINT @"https://api.indicative.com/service/event/batch"
#define INDICATIVE_TIMEOUT_SECONDS 30
#define SEND_EVENTS_INTERVAL_SECONDS 60
#define INDICATIVE_BATCH_SIZE 100
#define INDICATIVE_DEBUG false

static Indicative* mIndicative = nil;

@interface Indicative ()

@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *uniqueKey;
@property (nonatomic, retain) NSMutableArray *unsentEvents;
@property (nonatomic, copy) NSDictionary *deviceProperties;

@property (nonatomic, retain) NSTimer *sendEventTimer;

@end

@implementation Indicative

/**
 * Instantiates and returns the static Indicative instance.
 *
 * @returns the static Indicative instance
 */
+(Indicative*)get {
    if(nil == mIndicative) {
        mIndicative = [[Indicative alloc] init];
    }
    
    return mIndicative;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/**
 * Schedules the timer to periodically send Events to the Indicative API endpoint.
 */
-(void)startSendEventsTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if(self.sendEventTimer && self.sendEventTimer.isValid) {
            return;
        }
        
        SEL mySel = @selector(sendEvents:);
        
        NSMethodSignature* mySignature = [[self class] instanceMethodSignatureForSelector:mySel];
        NSInvocation* nsInv = [NSInvocation invocationWithMethodSignature:mySignature];
        
        [nsInv setTarget:self];
        [nsInv setSelector:mySel];
        
        self.sendEventTimer = [NSTimer scheduledTimerWithTimeInterval:SEND_EVENTS_INTERVAL_SECONDS
                                                           invocation:nsInv
                                                              repeats:YES];
        
        if(INDICATIVE_DEBUG) {
            NSLog(@"[Indicative] Started background timer");
        }
        
    });
}

-(void)stopSendEventsTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.sendEventTimer) {
            [self.sendEventTimer invalidate];
            if(INDICATIVE_DEBUG) {
                NSLog(@"[Indicative] Stopped background timer");
            }
        }
        
        self.sendEventTimer = nil;
    });
}

/**
 * Instantiates the static Indicative instance and initializes it with the project's API key.
 *
 * @param apiKey    the Project's API Key
 *
 * @returns         the static Indicative instance
 */
+(Indicative*)launch:(NSString*)apiKey {
    if(INDICATIVE_DEBUG) {
        NSLog(@"[Indicative] Initializing...");
        if(apiKey) {
            NSLog(@"[Indicative] Using API Key: %@", apiKey);
        } else {
            NSLog(@"[Indicative] Tried to initialize with a null API Key!");
        }
    }
    
    Indicative *indicative = [Indicative get];
    indicative.apiKey = apiKey;
    
    [self restoreSavedData];
    
    if(!indicative.uniqueKey) {
        indicative.uniqueKey = [Indicative generateUniqueKey];
        [self persistData];
    }
    
    indicative.deviceProperties = [Indicative generateDeviceProps];
    
    indicative.unsentEvents = [NSMutableArray arrayWithCapacity:INDICATIVE_BATCH_SIZE];
    
    [indicative startSendEventsTimer];
    
    [[NSNotificationCenter defaultCenter] addObserver:indicative
                                             selector:@selector(onBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:indicative
                                             selector:@selector(startSendEventsTimer)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:indicative
                                             selector:@selector(stopSendEventsTimer)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    return indicative;
}

+(Indicative*)identifyUser:(NSString*)uniqueKey {
    Indicative *indicative = [Indicative get];
    indicative.uniqueKey = uniqueKey;
    
    [self persistData];
    
    return indicative;
}

+(NSString*)uniqueKey {
    return [Indicative get].uniqueKey;
}

+(NSString*)generateUniqueKey {
    if(NSClassFromString(@"UIDevice")) {
        return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    } else {
        return [[NSUUID UUID] UUIDString];
    }
}

+(void)persistData {
    [[NSUserDefaults standardUserDefaults] setObject:[Indicative uniqueKey] forKey:@"indicativeUniqueKey"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if(INDICATIVE_DEBUG) {
        NSLog(@"Saved Indicative unique key: %@, %@", [Indicative uniqueKey], [[NSUserDefaults standardUserDefaults] objectForKey:@"indicativeUniqueKey"]);
    }
}

+(void)restoreSavedData {
    NSString *uniqueKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"indicativeUniqueKey"];
    if(uniqueKey) {
        [Indicative get].uniqueKey = uniqueKey;
        if(INDICATIVE_DEBUG) {
            NSLog(@"Restored Indicative unique key: %@", [Indicative uniqueKey]);
        }
    }
}

+(NSDictionary*)deviceProperties {
    return [Indicative get].deviceProperties;
}

+(void)record:(NSString*)eventName {
    [Indicative record:eventName withProperties:nil];
}

+(void)record:(NSString*)eventName withProperties:(NSDictionary*)properties {
    NSMutableDictionary *propertiesToSend = [NSMutableDictionary dictionaryWithDictionary:[Indicative deviceProperties]];
    [propertiesToSend addEntriesFromDictionary:properties];
    
    IndicativeEvent *event = [IndicativeEvent createEvent:eventName
                                             withUniqueId:[Indicative uniqueKey]
                                           withProperties:propertiesToSend];
    
    [Indicative recordEvent:event];
}

/**
 * Adds the Event object to an NSMutableArray.
 *
 * @param event    the Event to be recorded
 */
+(void)recordEvent:(IndicativeEvent*)event {
    @synchronized(self){
        if(INDICATIVE_DEBUG) {
            NSLog(@"[Indicative] Recording indicative event %@", event.eventName);
        }
        [[self get].unsentEvents addObject:event];
    }
}

+(NSDictionary *)generateDeviceProps {
    NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
    UIDevice *device = [UIDevice currentDevice];
    
    NSString *appVersion = [bundleInfo objectForKey:@"CFBundleVersion"];
    NSString *appBuild = [bundleInfo objectForKey:@"CFBundleShortVersionString"];
    NSString *osName = [device systemName];
    NSString *osVersion = [device systemVersion];
    NSString *deviceModel = [device model];
    
    return @{
             @"App Version": appVersion,
             @"App Build": appBuild,
             @"Device OS": osName,
             @"Device OS Version": osVersion,
             @"Device Model": deviceModel
             };
}

-(void)onBackground {
    UIDevice *device = [UIDevice currentDevice];
    if(device.isMultitaskingSupported) {
        
        UIApplication *application = [UIApplication sharedApplication];
        
        __block UIBackgroundTaskIdentifier backgroundTask;
        
        void (^doneWithTask)() = ^void() {
            if(backgroundTask != UIBackgroundTaskInvalid) {
                [application endBackgroundTask:backgroundTask];
                backgroundTask = UIBackgroundTaskInvalid;
            }
        };
        
        backgroundTask = [application beginBackgroundTaskWithExpirationHandler:^() {
            NSLog(@"POST to Indicative was canceled!");
            doneWithTask();
        }];
        
        [self sendEvents:doneWithTask];
    }
}

/**
 * Sends any events in the NSMutableArray to the Indicative API endpoint. If sent successfully, or if a non-retriable error code is received, the event is removed from the NSMutableArray.
 */
-(void) sendEvents:(void(^)())callback {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(queue, ^() {
        NSInteger totalSent = 0;
        
        while(self.unsentEvents.count > 0) {
            
            @try {
                
                NSInteger numInBatch = self.unsentEvents.count > INDICATIVE_BATCH_SIZE ? INDICATIVE_BATCH_SIZE : self.unsentEvents.count;
                
                NSRange range = NSMakeRange(0, numInBatch);
                NSArray *batch = [self.unsentEvents subarrayWithRange:range];
                
                NSDictionary *postData = [IndicativeEvent buildJSONDocument:self.apiKey withEvents:batch];
                
                NSInteger statusCode = [self postRequest:postData];
                
                if(INDICATIVE_DEBUG) {
                    NSLog(@"Received status code: %d", statusCode);
                }
                
                if(statusCode == 0 || statusCode >= 400) {
                    NSLog(@"Error while sending events to Indicative: HTTP %d", statusCode);
                    break;
                }
                
                [self.unsentEvents removeObjectsInRange:range];
                
                totalSent += batch.count;
                
                if(INDICATIVE_DEBUG) {
                    NSLog(@"Sent batch of %d events", batch.count);
                }
            }
            @catch (NSException* ex) {
                NSLog(@"Error while preparing events to send to Indicative: %@", ex);
                break;
            }
        }
        
        if(INDICATIVE_DEBUG && totalSent > 0) {
            NSLog(@"Done sending events. Sent %d total", totalSent);
        }
        
        if(callback) {
            callback();
        }
    });
}

/**
 * Posts the Event to the Indicative API endpoint.
 *
 * @param jsonPayload   an NSDictionary representing the event
 *
 * @returns             the response's status code
 */
-(NSInteger)postRequest:(NSDictionary*)jsonPayload {
	// create a request
	NSURL* url = [NSURL URLWithString:INDICATIVE_ENDPOINT];
	NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:url];
    
	// !! Set this timeout and handle timeout errors.
	[req setTimeoutInterval:INDICATIVE_TIMEOUT_SECONDS];
	
	[req setHTTPMethod:@"POST"];
    
    NSError* jsonError = nil;
    NSData* postData = [NSJSONSerialization dataWithJSONObject:jsonPayload options:0 error:&jsonError];
    
    [req setHTTPBody:postData];
    [req setValue:@"iOS" forHTTPHeaderField: @"Indicative-Client"];
    [req setValue:@"application/json" forHTTPHeaderField: @"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"%d", postData.length] forHTTPHeaderField:@"Content-Length"];
    
	NSHTTPURLResponse* resp = nil;
    NSInteger statusCode = 0;
    NSError* error = nil;
    
	NSData* nsData = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&error];
    
    NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)resp;
    statusCode = urlResponse.statusCode;
    if(INDICATIVE_DEBUG){
        if (!error) {
            NSLog(@"Status Code from Indicative: %li %@", (long)urlResponse.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:urlResponse.statusCode]);
            NSLog(@"Response Body from Indicative: %@", [[NSString alloc] initWithData:nsData encoding:NSUTF8StringEncoding]);
        } else {
            NSLog(@"An error occured with your request to Indicative, Status Code: %i", urlResponse.statusCode);
            NSLog(@"Indicative Response Error Description: %@", [error localizedDescription]);
            NSLog(@"Indicative Response Body: %@", [[NSString alloc] initWithData:nsData encoding:NSUTF8StringEncoding]);
        }
    }
    
    return statusCode;
}

@end
