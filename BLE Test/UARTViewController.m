//
//  UARTViewController.m
//  Bluefruit Connect
//
//  Created by Adafruit Industries on 2/5/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import <dispatch/dispatch.h>
#import <QuartzCore/QuartzCore.h>
#import "UARTViewController.h"
#import "NSString+hex.h"
#import "NSData+hex.h"

#define kKeyboardAnimationDuration 0.3f

@interface UARTViewController(){
    
    dispatch_queue_t backgroundQueueA;
    dispatch_queue_t backgroundQueueB;
    double           lastScroll;
    double           scrollIntvl;
    UIFont           *consoleFont;
    NSString         *unkownCharString;
    
}

@end

@implementation UARTViewController


- (id)initWithDelegate:(id<UARTViewControllerDelegate>)aDelegate{
    
    //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
    
    NSString *nibName;
    
    if (IS_IPHONE_4){
        nibName = @"UARTViewController_iPhone";
    }
    else if (IS_IPHONE_5){
        nibName = @"UARTViewController_iPhone568px";
    }
    else{
        nibName = @"UARTViewController_iPad";
    }
    
    self = [super initWithNibName:nibName bundle:[NSBundle mainBundle]];
    
    if (self){
        self.delegate = aDelegate;
        self.title = @"UART";
        self.helpViewController.title = @"UART Help";
        backgroundQueueA = dispatch_queue_create("com.adafruit.bluefruitconnect.bgqueuea", NULL);
        backgroundQueueB = dispatch_queue_create("com.adafruit.bluefruitconnect.bgqueueb", NULL);
        lastScroll = 0.0;
        scrollIntvl = 0.25;
    }
    
    return self;
    
}


- (id)initWithNibName:(NSString*)nibNameOrNil bundle:(NSBundle*)nibBundleOrNil{
    
    //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
    
    NSString *nibName;
    
    if (IS_IPHONE_4){
        nibName = @"UARTViewController_iPhone";
    }
    else if (IS_IPHONE_5){
        nibName = @"UARTViewController_iPhone568px";
    }
    else{
        nibName = @"UARTViewController_iPad";
    }
    
    self = [super initWithNibName:nibName bundle:[NSBundle mainBundle]];
    
    if (self) {
        // Custom initialization
    }
    
    return self;
}


#pragma mark - View Lifecycle


- (void)viewDidLoad{
    
    [super viewDidLoad];
    
    //initialization
    self.helpViewController.delegate = self.delegate;
    
    //define unknown char
    unkownCharString = [NSString stringWithFormat:@"%C", (unichar)0xFFFD];   //diamond question mark
    
    //round corners on console
    self.consoleView.clipsToBounds = YES;
    self.consoleView.layer.cornerRadius = 4.0;
    
    //retrieve console font
    consoleFont = [self.consoleView font];
    
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
    
    [self clearConsole:nil];
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


#pragma mark Data format & display


- (void)updateConsoleWithIncomingData:(NSData*)newData {
    
    
    
    //Write new received data to the console text view
    
    //convert data to string & replace characters we can't display
    int dataLength = (int)newData.length;
    uint8_t data[dataLength];
    
    [newData getBytes:&data length:dataLength];
    
    for (int i = 0; i<dataLength; i++) {
        
        if ((data[i] <= 0x1f) || (data[i] >= 0x80)) {    //null characters
            if ((data[i] != 0x9) && //0x9 == TAB
                (data[i] != 0xa) && //0xA == NL
                (data[i] != 0xd)) { //0xD == CR
                data[i] = 0xA9;
            }
        }
    }
    
    NSString *newString = [[NSString alloc]initWithBytes:&data
                                                  length:dataLength
                                                encoding:NSUTF8StringEncoding];
    
    
    //Update ASCII text on background thread A
    dispatch_async(backgroundQueueA, ^(void) {
        NSString *appendString = @"\n"; //each message appears on new line
        NSAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@", newString, appendString] //line breaks in ACII mode
                                                                                attributes: @{NSForegroundColorAttributeName : [UIColor redColor],
                                                                                              NSFontAttributeName : consoleFont
                                                                                              }];
        NSMutableAttributedString *newASCIIText = [[NSMutableAttributedString alloc] initWithAttributedString:_consoleAsciiText];
        [newASCIIText appendAttributedString:attrString];
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [self updateConsoleAscii:newASCIIText];
        });
    });
    
    
    //Update Hex text on background thread B
    dispatch_async(backgroundQueueB, ^(void) {
        NSString *newHexString = [newData hexRepresentationWithSpaces:YES];
        NSAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", newHexString]      //no line breaks in Hex mode
                                                                                attributes: @{
                                                                                              NSForegroundColorAttributeName : [UIColor redColor],
                                                                                              NSFontAttributeName : consoleFont
                                                                                              }];
        NSMutableAttributedString *newHexText = [[NSMutableAttributedString alloc] initWithAttributedString:_consoleHexText];
        [newHexText appendAttributedString:attrString];
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [self updateConsoleHex:newHexText];
        });
    });
    
}


- (void)updateConsoleAscii:(NSAttributedString*)text{
    
    _consoleAsciiText = text;
    
    if (_consoleModeControl.selectedSegmentIndex == ASCII) {
        [self updateConsole];
    }
    
}


- (void)updateConsoleHex:(NSAttributedString*)text{
    
    _consoleHexText = text;
    
    if (_consoleModeControl.selectedSegmentIndex == HEX) {
        [self updateConsole];
    }
    
}


- (void)updateConsole{
    
    //write string to console based on mode selection
    switch (_consoleModeControl.selectedSegmentIndex) {
        case ASCII:
            //ASCII
            _consoleView.attributedText = _consoleAsciiText;
            break;
        case HEX:
            //Hex
            _consoleView.attributedText = _consoleHexText;
            break;
        default:
            _consoleView.attributedText = _consoleAsciiText;
            break;
    }
    
    //scroll output to bottom
    double time = CACurrentMediaTime();
    if ((time - lastScroll) > scrollIntvl) {
        [self scrollConsoleToBottom];
        lastScroll = time;
    }

//    [self scrollConsoleToBottom];
    
}


-(void)scrollConsoleToBottom {
    
    CGRect caretRect = [_consoleView caretRectForPosition:_consoleView.endOfDocument];
    [_consoleView scrollRectToVisible:caretRect animated:NO];
    
    
//    [_consoleView scrollRangeToVisible:NSMakeRange([_consoleView.text length], 0)];
//    [_consoleView setScrollEnabled:NO];
//    [_consoleView setScrollEnabled:YES];
    
//    [self updateConsoleButtons];
    
}


- (void)updateConsoleWithOutgoingString:(NSString*)newString{
    
    //Write new sent data to the console text view
    
    UIColor *color = [UIColor blueColor];
    NSString *appendString = @"\n"; //each message appears on new line
    
    
    //Update ASCII text
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
    
    //Disable console buttons if console has no text
    
    BOOL enabled = ([self.consoleView.text compare:@""] == NSOrderedSame) ? NO : YES;
    
    [_consoleCopyButton setEnabled:enabled];
    [_consoleClearButton setEnabled:enabled];
    
}


- (void)resetUI{
    
    //Clear console & update buttons
    [self clearConsole:nil];
    
    //Dismiss keyboard
    [_inputField resignFirstResponder];
    
}


- (IBAction)clearConsole:(id)sender{
    
    [self.consoleView setText:@""];
    
    _consoleAsciiText = [[NSAttributedString alloc]init];
    _consoleHexText = [[NSAttributedString alloc]init];
    
    [self updateConsoleButtons];
}


- (IBAction)copyConsole:(id)sender{
    
    //Copy console text to clipboard w/o formatting
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.consoleView.text;
    
    //Notify user via color animation of text view
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
    
    //Respond to keyboard's Done button being tapped …
    
    //Disable send button
    [_sendButton setEnabled:NO];
    
    //check for empty field
    if ([_inputField.text compare:@""] == NSOrderedSame) {
        return;
    }
    
    //Send inputField's string via UART
    NSString *newString = _inputField.text;
    NSData *data = [NSData dataWithBytes:newString.UTF8String length:newString.length];
    [_delegate sendData:data];
    
    //Clear input field's text
    [_inputField setText:@""];
    
    //Reflect sent message in console
    [self updateConsoleWithOutgoingString:newString];
    
}


- (void)receiveData:(NSData*)newData{
    
    //Receive data from device if we're finished loading
    if (self.isViewLoaded && self.view.window) {
        [self updateConsoleWithIncomingData:newData];
    }
    
}


#pragma mark - Keyboard


- (void)keyboardWillHide:(NSNotification*)n{
    
    //Lower input view when keyboard hides
    
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
    
    //Raise input view when keyboard shows
    
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
    
    //Check for empty input field & disable send button appropriately
    if ([_inputField.text compare:@""] == NSOrderedSame) {
        _sendButton.enabled = NO;
    }
    
    else{
        _sendButton.enabled = YES;
    }
    
}


#pragma mark - Text Field delegate methods


- (BOOL)textFieldShouldReturn:(UITextField*)textField{
    
    //Keyboard's Done button was tapped
    
    [self sendMessage:nil];
    
    [_inputField resignFirstResponder];
    
    return YES;
}


- (IBAction)consoleModeControlDidChange:(UISegmentedControl*)sender{
    
    //Respond to console's ASCII/Hex control value changed
    
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
    
    //Respond to connection
    
    [self resetUI];
    
}


@end
