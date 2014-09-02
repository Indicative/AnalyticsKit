//
//  AnalyticsKitIndicativeProvider.m
//  AnalyticsKit
//
//  Created by Chris Fei on 8/29/14.
//  Copyright (c) 2014 Two Bit Labs. All rights reserved.
//

#import "AnalyticsKitIndicativeProvider.h"
#import "Indicative.h"

@implementation AnalyticsKitIndicativeProvider

-(id<AnalyticsKitProvider>)initWithAPIKey:(NSString *)apiKey {
    self = [super init];
    if (self) {
        [Indicative launch:apiKey];
    }
    return self;
}

-(void)applicationWillEnterForeground {}
-(void)applicationDidEnterBackground {}
-(void)applicationWillTerminate {}

-(void)uncaughtException:(NSException *)exception {
    NSDictionary *properties = @{
                                 @"ename" : [exception name],
                                 @"reason" : [exception reason],
                                 @"userInfo" : [exception userInfo]
                                 };
    
    [Indicative record:@"Uncaught Exception" withProperties:properties];
}

-(void)logScreen:(NSString *)screenName {
    [Indicative record:[@"Screen - " stringByAppendingString:screenName]];
}

-(void)logEvent:(NSString *)event {
    [Indicative record:event];
}

-(void)logEvent:(NSString *)event withProperties:(NSDictionary *)dict {
    [Indicative record:event withProperties:dict];
}

-(void)logEvent:(NSString *)event withProperty:(NSString *)key andValue:(NSString *)value {
    NSDictionary *properties = [NSDictionary dictionaryWithObject:value forKey:key];
    [Indicative record:event withProperties:properties];
}

- (void)logEvent:(NSString *)eventName timed:(BOOL)timed{
    [self logEvent:eventName];
}

- (void)logEvent:(NSString *)eventName withProperties:(NSDictionary *)dict timed:(BOOL)timed{
    [self logEvent:eventName withProperties:dict];
}

-(void)endTimedEvent:(NSString *)eventName withProperties:(NSDictionary *)dict{}

-(void)logError:(NSString *)name message:(NSString *)message exception:(NSException *)exception {
    
    NSDictionary *properties = @{
                                 @"name" : name,
                                 @"message" : message,
                                 @"ename" : [exception name],
                                 @"reason" : [exception reason],
                                 @"userInfo" : [exception userInfo]
                                 };
    
    [Indicative record:@"Exception" withProperties:properties];
}

-(void)logError:(NSString *)name message:(NSString *)message error:(NSError *)error {
    
    NSDictionary *properties = @{@"name" : name,
                                 @"message" : message,
                                 @"description" : [error localizedDescription],
                                 @"code" :[ NSString stringWithFormat:@"%ld", (long)[error code]],
                                 @"domain" : [error domain],
                                 @"userInfo" : [[error userInfo] description]
                                 };
    
    [Indicative record:@"Error" withProperties:properties];
}

@end
