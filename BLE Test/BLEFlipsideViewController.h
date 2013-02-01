//
//  BLEFlipsideViewController.h
//  BLE Test
//
//  Created by Collin Cunningham on 2/1/13.
//  Copyright (c) 2013 Adafruit Industries. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BLEFlipsideViewController;

@protocol BLEFlipsideViewControllerDelegate
- (void)flipsideViewControllerDidFinish:(BLEFlipsideViewController *)controller;
@end

@interface BLEFlipsideViewController : UIViewController

@property (weak, nonatomic) id <BLEFlipsideViewControllerDelegate> delegate;

- (IBAction)done:(id)sender;

@end
