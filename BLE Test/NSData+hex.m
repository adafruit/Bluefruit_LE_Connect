//
//  NSData+hex.m
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 2/14/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import "NSData+hex.h"

@implementation NSData (hex)


- (NSString*)hexRepresentationWithSpaces:(BOOL)spaces{
    
    const unsigned char* bytes = (const unsigned char*)[self bytes];
    NSUInteger nbBytes = [self length];
    
    //If spaces is true, insert a space every this many input bytes (twice this many output characters).
    static const NSUInteger spaceEveryThisManyBytes = 4UL;
    
    NSUInteger strLen = 2*nbBytes + (spaces ? nbBytes/spaceEveryThisManyBytes : 0);
    
    NSMutableString* hex = [[NSMutableString alloc] initWithCapacity:strLen];
    for(NSUInteger i=0; i<nbBytes; ) {
        [hex appendFormat:@"0x%x", bytes[i]];
        //We need to increment here so that the every-n-bytes computations are right.
        ++i;
        
        if (spaces) {
            [hex appendString:@" "];
        }
    }
    
    return hex;
}


@end
