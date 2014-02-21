//
//  CBUUID+StringExtraction.m
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 2/21/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import "CBUUID+StringExtraction.h"


@implementation CBUUID (StringExtraction)


- (NSString *)representativeString;{
    
    NSData *data = [self data];
    
    NSUInteger bytesToConvert = [data length];
    const unsigned char *uuidBytes = [data bytes];
    NSMutableString *outputString = [NSMutableString stringWithCapacity:16];
    
    for (NSUInteger currentByteIndex = 0; currentByteIndex < bytesToConvert; currentByteIndex++)
    {
        switch (currentByteIndex)
        {
            case 3:
            case 5:
            case 7:
            case 9:[outputString appendFormat:@"%02x-", uuidBytes[currentByteIndex]]; break;
            default:[outputString appendFormat:@"%02x", uuidBytes[currentByteIndex]];
        }
        
    }
    
    return outputString;
}



@end
