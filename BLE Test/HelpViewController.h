//
//  HelpViewController.h
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 2/10/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HelpViewController;

@protocol HelpViewControllerDelegate

- (void)helpViewControllerDidFinish:(HelpViewController*)controller;

@end

@interface HelpViewController : UIViewController

@property (weak, nonatomic)IBOutlet id <HelpViewControllerDelegate> delegate;
@property (strong, nonatomic) IBOutlet UILabel                      *versionLabel;
@property (strong, nonatomic) IBOutlet UITextView                   *textView;

- (IBAction)done:(id)sender;

@end
