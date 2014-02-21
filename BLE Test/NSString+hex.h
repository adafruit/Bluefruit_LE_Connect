//
//  NSString+hex.h
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 1/24/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (hex)

+ (NSString*) stringFromHex:(NSString*)str;
+ (NSString*) stringToHex:(NSString*)str;
+ (NSString*) stringToHexSpaceSeparated:(NSString*)str;

@end
