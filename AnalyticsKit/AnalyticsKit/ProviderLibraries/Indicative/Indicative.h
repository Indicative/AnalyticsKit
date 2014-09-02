//
//  Indicative.h
//  Indicative
//
//  Created by Indicative on 08-01-13.
//  Copyright (c) 2013 Indicative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IndicativeEvent.h"

@interface Indicative : NSObject

+(Indicative*)launch:(NSString*)apiKey;
+(Indicative*)identifyUser:(NSString*)uniqueKey;

+(void)record:(NSString*)eventName;
+(void)record:(NSString*)eventName withProperties:(NSDictionary*)properties;
+(void)recordEvent:(IndicativeEvent*)event;

@end