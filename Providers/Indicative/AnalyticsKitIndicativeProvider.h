//
//  AnalyticsKitIndicativeProvider.h
//  AnalyticsKit
//
//  Created by Chris Fei on 8/29/14.
//  Copyright (c) 2014 Two Bit Labs. All rights reserved.
//

#import "AnalyticsKit.h"

@interface AnalyticsKitIndicativeProvider : NSObject <AnalyticsKitProvider>

-(id<AnalyticsKitProvider>)initWithAPIKey:(NSString *)apiKey;

@end
