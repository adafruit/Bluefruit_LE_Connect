//
//  UARTViewController.m
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 2/5/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import "UARTViewController.h"
#import "NSString+hex.h"
#import "NSData+hex.h"

#define kKeyboardAnimationDuration 0.3f

@implementation UARTViewController


- (id)initWithDelegate:(id<UARTViewControllerDelegate>)aDelegate{
    
    NSString *nibName = IS_IPAD ? @"UARTViewController_iPad" : @"UARTViewController_iPhone";
    
    self = [super initWithNibName:nibName bundle:[NSBundle mainBundle]];
    
    if (self){
        self.delegate = aDelegate;
        self.title = @"UART";
        self.helpViewController.title = @"UART Help";
    }
    
    return self;
    
}


- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil{
    
    NSString *nibName = IS_IPAD ? @"UARTViewController_iPad" : @"UARTViewController_iPhone";
    
    self = [super initWithNibName:nibName bundle:[NSBundle mainBundle]];
    
    if (self) {
        // Custom initialization
    }
    
    return self;
}


#pragma mark - View Lifecycle


- (void)viewDidLoad{
    
    [super viewDidLoad];
    
    self.helpViewController.delegate = self.delegate;
    
    //round corners on console
    self.consoleView.clipsToBounds = YES;
    self.consoleView.layer.cornerRadius = 4.0;
    
    //register for keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:self.view.window];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:self.view.window];
    
    //register for textfield notifications
    //    UITextFieldTextDidChangeNotification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textFieldDidChange:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:self.view.window];
}


- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)viewDidUnload{
    
    [self setConsoleView:nil];
    [self setInputField:nil];
    [self setSendButton:nil];
    [self setConsoleModeControl:nil];
    
    //unregister for keyboard notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
    
    [super viewDidUnload];
    
}


- (void)updateConsoleWithIncomingData:(NSData*)newData {
    
    //RX - message received from Bluefruit
    
    //convert data to string & replace ocurances of "(null)"
    NSString *newString = [NSString stringWithUTF8String:[newData bytes]];
//    unichar ns = 0xDB;
//    NSString *nullSymbol = [NSString stringWithFormat:@"%C", 0x2588];   //block
    NSString *nullSymbol = [NSString stringWithFormat:@"%C", (unichar)0x25a0];   //black square
    
//    newString = [newString stringByReplacingOccurrencesOfString:@"(null)" withString:nullSymbol];
    
    if (newString == nil) {
        newString = nullSymbol;
    }
    
    
    //check for null character
    
    UIColor *color = [UIColor redColor];
    NSString *appendString = @"\n"; //each message appears on new line
    
    
    //Update ASCII text
    UIFont * consoleFont = [self.consoleView font];
    NSAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@", newString, appendString] //line breaks in ACII mode
                                                                            attributes: @{NSForegroundColorAttributeName : color,
                                                                                          NSFontAttributeName : consoleFont
                                                                                          }];
    NSMutableAttributedString *newASCIIText = [[NSMutableAttributedString alloc] initWithAttributedString:_consoleAsciiText];
    [newASCIIText appendAttributedString:attrString];
    _consoleAsciiText = newASCIIText;
    
    
    //Update Hex text
    NSString *newHexString = [newData hexRepresentationWithSpaces:YES];
    attrString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", newHexString]      //no line breaks in Hex mode
                                                        attributes: @{
                                                                      NSForegroundColorAttributeName : color,
                                                                      NSFontAttributeName : consoleFont
                                                                      }];
    NSMutableAttributedString *newHexText = [[NSMutableAttributedString alloc] initWithAttributedString:_consoleHexText];
    [newHexText appendAttributedString:attrString];
    _consoleHexText = newHexText;
    
    //write string to console based on mode selection
    switch (_consoleModeControl.selectedSegmentIndex) {
        case 0:
            //ASCII
            _consoleView.attributedText = _consoleAsciiText;
            break;
        case 1:
            //Hex
            _consoleView.attributedText = _consoleHexText;
            break;
        default:
            _consoleView.attributedText = _consoleAsciiText;
            break;
    }
    
    //scroll output to bottom
    [_consoleView scrollRangeToVisible:NSMakeRange([_consoleView.text length], 0)];
    [_consoleView setScrollEnabled:NO];
    [_consoleView setScrollEnabled:YES];
    
    [self updateConsoleButtons];
    
}


- (void)updateConsoleWithOutgoingString:(NSString*)newString{
    
    //TX - message to send to Bluefruit
    
    UIColor *color = [UIColor blueColor];
    NSString *appendString = @"\n"; //each message appears on new line
    
    
    //Update ASCII text
    UIFont * consoleFont = [self.consoleView font];
    NSAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@", newString, appendString] //line breaks in ACII mode
                                                                            attributes: @{NSForegroundColorAttributeName : color,
                                                                                          NSFontAttributeName : consoleFont
                                                                                          }];
    NSMutableAttributedString *newASCIIText = [[NSMutableAttributedString alloc] initWithAttributedString:_consoleAsciiText];
    [newASCIIText appendAttributedString:attrString];
    _consoleAsciiText = newASCIIText;
    
    
    //Update Hex text
    NSString *newHexString = [NSString stringToHexSpaceSeparated:newString];
    attrString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", newHexString]      //no line breaks in Hex mode
                                                        attributes: @{
                                                                      NSForegroundColorAttributeName : color,
                                                                      NSFontAttributeName : consoleFont
                                                                      }];
    NSMutableAttributedString *newHexText = [[NSMutableAttributedString alloc] initWithAttributedString:_consoleHexText];
    [newHexText appendAttributedString:attrString];
    _consoleHexText = newHexText;
    
    //write string to console based on mode selection
    switch (_consoleModeControl.selectedSegmentIndex) {
        case 0:
            //ASCII
            _consoleView.attributedText = _consoleAsciiText;
            break;
        case 1:
            //Hex
            _consoleView.attributedText = _consoleHexText;
            break;
        default:
            _consoleView.attributedText = _consoleAsciiText;
            break;
    }
    
    //scroll output to bottom
    [_consoleView scrollRangeToVisible:NSMakeRange([_consoleView.text length], 0)];
    [_consoleView setScrollEnabled:NO];
    [_consoleView setScrollEnabled:YES];
    
    [self updateConsoleButtons];
}


- (void)updateConsoleButtons{
    
    //disable console buttons if console has no text
    BOOL enabled = ([self.consoleView.text compare:@""] == NSOrderedSame) ? NO : YES;
    
    [_consoleCopyButton setEnabled:enabled];
    [_consoleClearButton setEnabled:enabled];
    
}


- (void)resetUI{
    
    //clear console & update buttons
    [self clearConsole:nil];
    
    //dismiss keyboard
    [_inputField resignFirstResponder];
    
}


- (IBAction)clearConsole:(id)sender{
    
    [self.consoleView setText:@""];
    
    _consoleAsciiText = [[NSAttributedString alloc]init];
    _consoleHexText = [[NSAttributedString alloc]init];
    
    [self updateConsoleButtons];
}


- (IBAction)copyConsole:(id)sender{
    
    //copy console text to clipboard w formatting
//    [self.consoleView select:self];
//    self.consoleView.selectedRange = NSMakeRange(0, [self.consoleView.text length]);
//    [[UIApplication sharedApplication] sendAction:@selector(copy:) to:nil from:self forEvent:nil];
//    [self.consoleView resignFirstResponder];
    
    //copy console text to clipboard w/o formatting
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.consoleView.text;
    
    
    //notify user via alert pop-up
//    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:nil
//                                                   message:@"Console text copied to clipboard"
//                                                  delegate:nil
//                                         cancelButtonTitle:@"OK"
//                                         otherButtonTitles:nil];
//    [alert show];
    
    
    //notify user via color animation of text view
    UIColor *iosCyan = [UIColor colorWithRed:(32.0/255.0)
                                       green:(149.0/255.0)
                                        blue:(251.0/255.0)
                                       alpha:1.0];
    [_consoleView setBackgroundColor:iosCyan];
    
    [UIView animateWithDuration:0.45
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.consoleView.backgroundColor = [UIColor whiteColor];
                     }
                     completion:^(BOOL finished) {
                         
                     }
     ];
    
}


- (IBAction)sendMessage:(id)sender{
    
    //disable send button
    [_sendButton setEnabled:NO];
    
    if ([_inputField.text compare:@""] == NSOrderedSame) {
        return;
    }
    
    //send inputField's string via UART
    NSString *newString = _inputField.text;
    NSData *data = [NSData dataWithBytes:newString.UTF8String length:newString.length];
    [_delegate sendData:data];
    
    //clear input field's text
    [_inputField setText:@""];
    
    //reflect sent message in console
    [self updateConsoleWithOutgoingString:newString];
    
}


- (void)receiveData:(NSData*)newData{
    
    //convert data to string
//    NSString *string = [NSString stringWithUTF8String:[newData bytes]];
    
    [self updateConsoleWithIncomingData:newData];
    
}


- (void)keyboardWillHide:(NSNotification*)n{
    
    NSDictionary* userInfo = [n userInfo];
    
    // get the size of the keyboard
    CGSize keyboardSize = [[userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    //calculate new position for input view
    CGRect newRect = CGRectMake(_inputView.frame.origin.x, _inputView.frame.origin.y + keyboardSize.height, _inputView.frame.size.width, _inputView.frame.size.height);
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    // The kKeyboardAnimationDuration I am using is 0.3
    [UIView setAnimationDuration:kKeyboardAnimationDuration];
    [self.inputView setFrame:newRect];
    [UIView commitAnimations];
    
    _keyboardIsShown = NO;
}


- (void)keyboardWillShow:(NSNotification*)n{
    
    if (_keyboardIsShown) {
        return;
    }
    
    NSDictionary* userInfo = [n userInfo];
    
    // get the size of the keyboard
    CGSize keyboardSize = [[userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    //calculate new position for input view
    
    CGRect newRect;
    if (IS_IPAD) {
        
        //iPad Landscape
        if (UIInterfaceOrientationIsLandscape([self interfaceOrientation])) {
            newRect = CGRectMake(_inputView.frame.origin.x, _inputView.frame.origin.y - keyboardSize.width, _inputView.frame.size.width, _inputView.frame.size.height);
        }
        
        //iPad Portrait
        else{
            newRect = CGRectMake(_inputView.frame.origin.x, _inputView.frame.origin.y - keyboardSize.height, _inputView.frame.size.width, _inputView.frame.size.height);
        }
    }
    
    //iPhone
    else{
    
        newRect = CGRectMake(_inputView.frame.origin.x, _inputView.frame.origin.y - keyboardSize.height, _inputView.frame.size.width, _inputView.frame.size.height);
    }
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:0.25f];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [self.inputView setFrame:newRect];
    [UIView commitAnimations];
    
    _keyboardIsShown = YES;
}


- (void)textFieldDidChange:(NSNotification*)n{
    
    //check for empty input field & disable send button appropriately
    if ([_inputField.text compare:@""] == NSOrderedSame) {
        _sendButton.enabled = NO;
    }
    
    else{
        _sendButton.enabled = YES;
    }
    
}


#pragma mark - Text Field delegate methods


- (BOOL)textFieldShouldReturn:(UITextField*)textField{
    
    [self sendMessage:nil];
    
    [_inputField resignFirstResponder];
    
    return YES;
}


- (IBAction)consoleModeControlDidChange:(UISegmentedControl*)sender{
    
    switch (sender.selectedSegmentIndex) {
        case 0:
            _consoleView.attributedText = _consoleAsciiText;
            break;
        case 1:
            _consoleView.attributedText = _consoleHexText;
            break;
        default:
            _consoleView.attributedText = _consoleAsciiText;
            break;
    }
    
}


- (void)didConnect{
    
    //respond to connection
    [self resetUI];
}


@end
