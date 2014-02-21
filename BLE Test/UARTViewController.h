//
//  UARTViewController.h
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 2/5/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HelpViewController.h"

@protocol UARTViewControllerDelegate <NSObject, HelpViewControllerDelegate>

- (void)sendData:(NSData*)newData;

@end


@interface UARTViewController : UIViewController <UITextFieldDelegate>

typedef enum {
    LOGGING,
    RX,
    TX,
} ConsoleDataType;

typedef enum {
    ASCII = 0,
    HEX,
} ConsoleMode;

@property (weak, nonatomic) id<UARTViewControllerDelegate>      delegate;
@property (strong, nonatomic) IBOutlet HelpViewController       *helpViewController;
@property (strong, nonatomic) IBOutlet UITextView               *consoleView;
@property (strong, nonatomic) IBOutlet UIView                   *inputView;
@property (strong, nonatomic) IBOutlet UITextField              *inputField;
@property (strong, nonatomic) IBOutlet UIButton                 *sendButton;
@property (strong, nonatomic) IBOutlet UIButton                 *consoleCopyButton;
@property (strong, nonatomic) IBOutlet UIButton                 *consoleClearButton;
@property (strong, nonatomic) IBOutlet UISegmentedControl       *consoleModeControl;
@property (nonatomic, assign) BOOL                              keyboardIsShown;
@property (strong, nonatomic) NSAttributedString                *consoleAsciiText;
@property (strong, nonatomic) NSAttributedString                *consoleHexText;

- (id)initWithDelegate:(id<UARTViewControllerDelegate>)aDelegate;
- (IBAction)clearConsole:(id)sender;
- (IBAction)copyConsole:(id)sender;
- (IBAction)sendMessage:(id)sender;
- (void)receiveData:(NSData*)newData;
- (IBAction)consoleModeControlDidChange:(UISegmentedControl*)sender;
- (void)didConnect;
- (void)resetUI;

@end
