//
//  NSData+hex.h
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 2/14/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (hex)

-(NSString*)hexRepresentationWithSpaces:(BOOL)spaces;

@end
