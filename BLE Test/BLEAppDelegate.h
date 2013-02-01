//
//  BLEAppDelegate.h
//  BLE Test
//
//  Created by Collin Cunningham on 2/1/13.
//  Copyright (c) 2013 Adafruit Industries. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BLEMainViewController;

@interface BLEAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) BLEMainViewController *mainViewController;

@end
