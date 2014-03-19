//
//  BLEAppDelegate.h
//  Adafruit Bluefruit LE Connect
//
//  Copyright (c) 2013 Adafruit Industries. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BLEMainViewController;

@interface BLEAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) BLEMainViewController *mainViewController;

@end
