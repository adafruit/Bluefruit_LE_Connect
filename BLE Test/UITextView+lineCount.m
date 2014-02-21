//
//  UITextView+lineCount.m
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 2/21/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import "UITextView+lineCount.h"

@implementation UITextView (lineCount)


- (int)lineCount{
    
    return self.contentSize.height/self.font.lineHeight;
    
}


@end
