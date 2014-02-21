//
//  PinIOViewController.h
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 2/3/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PinCell.h"
#import "HelpViewController.h"

@protocol PinIOViewControllerDelegate <NSObject, HelpViewControllerDelegate>

- (void)sendData:(NSData*)newData;

@end

@interface PinIOViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, PinCellDelegate>

@property (weak, nonatomic) id<PinIOViewControllerDelegate>              delegate;
@property (strong, nonatomic) IBOutlet UITableView                       *pinTable;
@property (strong, nonatomic) IBOutlet UILabel                           *headerLabel;
@property (strong, nonatomic) IBOutlet PinCell                           *digitalPinCell;
@property (strong, nonatomic) IBOutlet HelpViewController                *helpViewController;
@property (strong, nonatomic) IBOutlet UITextView                        *debugConsole;

- (id)initWithDelegate:(id<PinIOViewControllerDelegate>)aDelegate;
- (void)didConnect;
- (void)digitalControlChanged:(UISegmentedControl*)sender;
- (void)cellButtonTapped:(UIButton*)sender;
- (void)modeControlChanged:(UISegmentedControl*)sender;
- (IBAction)toggleDebugConsole:(id)sender;
- (void)receiveData:(NSData*)newData;

@end
