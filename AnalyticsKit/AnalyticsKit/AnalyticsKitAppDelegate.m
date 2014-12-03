//
//  AnalyticsKitAppDelegate.m
//  AnalyticsKit
//
//  Created by Christopher Pickslay on 10/23/13.
//  Copyright (c) 2013 Two Bit Labs. All rights reserved.
//

#import "AnalyticsKitAppDelegate.h"
#import "AnalyticsKit.h"
#import "AnalyticsKitDebugProvider.h"
#import "AnalyticsKitIndicativeProvider.h"

@implementation AnalyticsKitAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    AnalyticsKitDebugProvider *debug = [AnalyticsKitDebugProvider new];
    AnalyticsKitIndicativeProvider *indicative = [[AnalyticsKitIndicativeProvider alloc] initWithAPIKey:@"API_KEY_HERE"];
    
    [AnalyticsKit initializeLoggers:@[debug, indicative]];
    [AnalyticsKit logEvent:@"App started"];
    return YES;
}
							
- (void)applicationWillEnterForeground:(UIApplication *)application {
    [AnalyticsKit applicationWillEnterForeground];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [AnalyticsKit applicationDidEnterBackground];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [AnalyticsKit applicationWillTerminate];
}


@end
