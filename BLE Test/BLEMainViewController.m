//
//  BLEMainViewController.m
//  BLE Test
//
//  Created by Collin Cunningham on 2/1/13.
//  Copyright (c) 2013 Adafruit Industries. All rights reserved.
//

#import "BLEMainViewController.h"
#import "utils.h"
#import <QuartzCore/QuartzCore.h>
#import "NSString+hex.h"
#import "NSData+hex.h"

#define CONNECTING_TEXT @"Connecting…"
#define DISCONNECTING_TEXT @"Disconnecting…"
#define DISCONNECT_TEXT @"Disconnect"
#define CONNECT_TEXT @"Connect"


@interface BLEMainViewController ()<UIAlertViewDelegate>{
    
    CBCentralManager    *cm;
    UIAlertView         *currentAlertView;
    UARTPeripheral      *currentPeripheral;
    UIBarButtonItem     *infoBarButton;
    
}

@end


@implementation BLEMainViewController


#pragma mark - View Lifecycle


- (void)viewDidLoad{
    [super viewDidLoad];
    
    [self.view setAutoresizesSubviews:YES];
    
    [self addChildViewController:self.navController];
    
    [self.view addSubview:self.navController.view];
	
    //disable navcontroller's swiping feature
    self.navController.interactivePopGestureRecognizer.enabled = NO;
    
    cm = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    _connectionMode = ConnectionModeNone;
    _connectionStatus = ConnectionStatusDisconnected;
    currentAlertView = nil;
    
    
    //create add'l controllers
//    self.pinIoViewController = [[PinIOViewController alloc]initWithDelegate:self];
//    self.uartViewController = [[UARTViewController alloc]initWithDelegate:self];
    
    
    //add info bar button to mode controllers
    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject: _infoButton];
    UIButton *buttonCopy = [NSKeyedUnarchiver unarchiveObjectWithData: archivedData];
    [buttonCopy addTarget:self action:@selector(showInfo:) forControlEvents:UIControlEventTouchUpInside];
    infoBarButton = [[UIBarButtonItem alloc]initWithCustomView:buttonCopy];
//    self.pinIoViewController.navigationItem.rightBarButtonItem = infobb;
    
//    buttonCopy = [NSKeyedUnarchiver unarchiveObjectWithData: archivedData];
//    [buttonCopy addTarget:self action:@selector(showInfo:) forControlEvents:UIControlEventTouchUpInside];
//    infobb = [[UIBarButtonItem alloc]initWithCustomView:buttonCopy];
//    self.uartViewController.navigationItem.rightBarButtonItem = infobb;
    
}


- (void)viewWillAppear:(BOOL)animated{
    
    [self.view setNeedsLayout];
    
}


- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)viewDidUnload{
    
    [super viewDidUnload];
}


#pragma mark - Root UI


- (void)helpViewControllerDidFinish:(HelpViewController*)controller{
    
    if (IS_IPHONE) {
        
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
    else {
        [self.helpPopoverController dismissPopoverAnimated:YES];
    }
}


- (HelpViewController*)currentHelpViewController{
    
    //Determine which help view to show based on the current view shown
    
    HelpViewController *hvc;
    
    if ([_navController.topViewController isKindOfClass:[PinIOViewController class]])
        hvc = _pinIoViewController.helpViewController;
    
    else if ([_navController.topViewController isKindOfClass:[UARTViewController class]])
        hvc = _uartViewController.helpViewController;
    
    else
        hvc = self.helpViewController;
    
    return hvc;
}


- (IBAction)showInfo:(id)sender{
    
    // Show info view on iPhone via flip transition
    if (IS_IPHONE) {
        
        [self presentViewController:[self currentHelpViewController] animated:YES completion:nil];
    }
    
    //iPad
    else if (IS_IPAD) {
        
        //close popover it is being shown
        if (_helpPopoverController != nil && [self.helpPopoverController isPopoverVisible]) {
            [self.helpPopoverController dismissPopoverAnimated:YES];
            self.helpPopoverController = nil;
        }
        
        //show popover if it isn't shown
        else {
            self.helpPopoverController = [[UIPopoverController alloc]initWithContentViewController:[self currentHelpViewController]];
            self.helpPopoverController.backgroundColor = [UIColor darkGrayColor];
            
            CGRect aFrame = [[[_navController.navigationBar.items lastObject] rightBarButtonItem] customView].frame;
            [self.helpPopoverController presentPopoverFromRect:aFrame
                                                        inView:[[[_navController.navigationBar.items lastObject] rightBarButtonItem] customView].superview
                                                        permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        }
    }
}


- (IBAction)buttonTapped:(UIButton*)sender{
    
    if (currentAlertView != nil && currentAlertView.isVisible) {
        NSLog(@"ALERT VIEW ALREADY SHOWN");
        return;
    }
    
    if ([sender isEqual:self.pinIoButton]) {    //Pin I/O
        NSLog(@"Starting Pin I/O Mode …");
        _connectionMode = ConnectionModePinIO;
        
    }
    else if ([sender isEqual:self.uartButton]){ //UART
        NSLog(@"Starting UART Mode …");
        _connectionMode = ConnectionModeUART;
    }
    else return;
    
    _connectionStatus = ConnectionStatusScanning;
    
    [self enableConnectionButtons:NO];
    
    [self scanForPeripherals];
    
    currentAlertView = [[UIAlertView alloc]initWithTitle:@"Scanning …"
                                          message:nil
                                         delegate:self
                                cancelButtonTitle:@"Cancel"
                                otherButtonTitles:nil];
    
    [currentAlertView show];
    
}


- (void)scanForPeripherals{
    
    //skip scanning if UART is already connected
    NSArray *connectedPeripherals = [cm retrieveConnectedPeripheralsWithServices:@[UARTPeripheral.uartServiceUUID]];
    if ([connectedPeripherals count] > 0) {
        //connect to first peripheral in array
        [self connectPeripheral:[connectedPeripherals objectAtIndex:0]];
    }
    
    else{
        
        [cm scanForPeripheralsWithServices:@[UARTPeripheral.uartServiceUUID]
                                   options:@{CBCentralManagerScanOptionAllowDuplicatesKey: [NSNumber numberWithBool:NO]}];
    }
    
}


- (void)connectPeripheral:(CBPeripheral*)peripheral{
    
    //Clear off any pending connections
    [cm cancelPeripheralConnection:peripheral];
    
    //Connect
    currentPeripheral = [[UARTPeripheral alloc] initWithPeripheral:peripheral delegate:self];
    [cm connectPeripheral:peripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey: [NSNumber numberWithBool:YES]}];
    
}


- (void)disconnect{
    
    _connectionStatus = ConnectionStatusDisconnected;
    _connectionMode = ConnectionModeNone;
    
    [cm cancelPeripheralConnection:currentPeripheral.peripheral];
    
}


- (void)enableConnectionButtons:(BOOL)enabled{
    
    _uartButton.enabled = enabled;
    _pinIoButton.enabled = enabled;
}


- (void)enableConnectionButtons{
    
    [self enableConnectionButtons:YES];
}


#pragma mark UIAlertView delegate methods


- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    //the only button in our alert views is cancel
    
//    NSLog(@"STOP SCAN");
    
    if (_connectionStatus == ConnectionStatusConnected) {
        [self disconnect];
    }
    else if (_connectionStatus == ConnectionStatusScanning){
        [cm stopScan];
    }
    
    _connectionStatus = ConnectionStatusDisconnected;
    _connectionMode = ConnectionModeNone;
    
    currentAlertView = nil;
    
    [self enableConnectionButtons:YES];
    
    //alert dismisses automatically @ return
    
}


#pragma mark Navigation Controller delegate methods


- (void)navigationController:(UINavigationController*)navigationController willShowViewController:(UIViewController*)viewController animated:(BOOL)animated{
    
//    NSLog(@"navigationController willShowViewController");
    
    //disconnect when returning to main view
    if (_connectionStatus == ConnectionStatusConnected && [viewController isEqual:_menuViewController]) {
        [self disconnect];
        
        //dismiss UART keyboard
        [_uartViewController.inputField resignFirstResponder];
    }
    
}


#pragma mark CBCentralManagerDelegate


- (void) centralManagerDidUpdateState:(CBCentralManager*)central{
    
    if (central.state == CBCentralManagerStatePoweredOn){
        
        //respond to powered on
    }
    
    else if (central.state == CBCentralManagerStatePoweredOff){
        
        //respond to powered off
    }
    
}


- (void) centralManager:(CBCentralManager*)central didDiscoverPeripheral:(CBPeripheral*)peripheral advertisementData:(NSDictionary*)advertisementData RSSI:(NSNumber*)RSSI{
    
    NSLog(@"Did discover peripheral %@", peripheral.name);
    
    [cm stopScan];
    
    [self connectPeripheral:peripheral];
}


- (void) centralManager:(CBCentralManager*)central didConnectPeripheral:(CBPeripheral*)peripheral{
    
    if ([currentPeripheral.peripheral isEqual:peripheral]){
        
        if(peripheral.services){
            NSLog(@"Did connect to existing peripheral %@", peripheral.name);
            [currentPeripheral peripheral:peripheral didDiscoverServices:nil]; //already discovered services, DO NOT re-discover. Just pass along the peripheral.
        }
        
        else{
            NSLog(@"Did connect peripheral %@", peripheral.name);
            [currentPeripheral didConnect];
        }
    }
}


- (void) centralManager:(CBCentralManager*)central didDisconnectPeripheral:(CBPeripheral*)peripheral error:(NSError*)error{
    
    NSLog(@"Did disconnect peripheral %@", peripheral.name);
    
    //respond to disconnected
    [self peripheralDidDisconnect];
    
    if ([currentPeripheral.peripheral isEqual:peripheral])
    {
        [currentPeripheral didDisconnect];
    }
}


#pragma mark UARTPeripheralDelegate


- (void)didReadHardwareRevisionString:(NSString*)string{
    
    //respond to hardware revision string read
    
    NSLog(@"HW Revision: %@", string);
    
    //Bail if we aren't in the process of connecting
    if (currentAlertView == nil) return;
    
    _connectionStatus = ConnectionStatusConnected;
    
    //Pin I/O mode
    if (_connectionMode == ConnectionModePinIO) {
        self.pinIoViewController = [[PinIOViewController alloc]initWithDelegate:self];
        _pinIoViewController.navigationItem.rightBarButtonItem = infoBarButton;
        [_pinIoViewController didConnect];
    }
    //UART mode
    else if (_connectionMode == ConnectionModeUART){
        self.uartViewController = [[UARTViewController alloc]initWithDelegate:self];
        _uartViewController.navigationItem.rightBarButtonItem = infoBarButton;
        [_uartViewController didConnect];
        
    }
    
    //Dismiss Alert view & update main view
    [currentAlertView dismissWithClickedButtonIndex:-1 animated:NO];
    
    //Push appropriate viewcontroller onto the navcontroller
    UIViewController *vc = nil;
    
    if (_connectionMode == ConnectionModePinIO)
        vc = _pinIoViewController;
    
    else if (_connectionMode == ConnectionModeUART)
        vc = _uartViewController;
    
    if (vc != nil){
        [_navController pushViewController:vc animated:YES];
    }
    
    else
        NSLog(@"CONNECTED WITH NO CONNECTION MODE SET!");
    
    currentAlertView = nil;
    
    
}


- (void)uartDidConnect{
    
    
    
}


- (void)uartDidEncounterError:(NSString*)error{
    
    //Dismiss "scanning …" alert view if shown
    if (currentAlertView != nil) {
        [currentAlertView dismissWithClickedButtonIndex:0 animated:NO];
    }
    
    //Display error alert
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Error"
                                                   message:error
                                                  delegate:nil
                                         cancelButtonTitle:@"OK"
                                         otherButtonTitles:nil];
    
    [alert show];
    
}


- (void)didReceiveData:(NSData*)newData{

    //Debug
    NSString *hexString = [newData hexRepresentationWithSpaces:YES];
    NSLog(@"Received: %@", hexString);
    
    if (_connectionStatus == ConnectionStatusConnected || _connectionStatus == ConnectionStatusScanning) {
        //UART
        if (_connectionMode == ConnectionModeUART) {
            //send data to UART Controller
            [_uartViewController receiveData:newData];
        }
        
        //Pin I/O
        else if (_connectionMode == ConnectionModePinIO){
            //send data to PIN IO Controller
            [_pinIoViewController receiveData:newData];
        }
    }
}


- (void)peripheralDidDisconnect{
    
    //if we were in the process of scanning/connecting, dismiss alert
    if (currentAlertView != nil) {
        [self uartDidEncounterError:@"Peripheral disconnected"];
    }
    
    //if status was connected, then disconnect was unexpected by the user, show alert
    UIViewController *topVC = [_navController topViewController];
    if ((_connectionStatus == ConnectionStatusConnected) &&
        ([topVC isMemberOfClass:[PinIOViewController class]] ||
        [topVC isMemberOfClass:[UARTViewController class]])) {
        
        //return to main view
        [_navController popToRootViewControllerAnimated:YES];
        
        //display disconnect alert
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Disconnected"
                                                       message:@"BLE peripheral has disconnected"
                                                      delegate:nil
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles: nil];
        
        [alert show];
    }
    
    _connectionStatus = ConnectionStatusDisconnected;
    _connectionMode = ConnectionModeNone;
    
    //dereference mode controllers
    self.pinIoViewController = nil;
    self.uartViewController = nil;
    
    //make reconnection available after short delay
    [self performSelector:@selector(enableConnectionButtons) withObject:nil afterDelay:1.0f];
    
}


- (void)alertBluetoothPowerOff{
    
    NSString *title     = @"Bluetooth Power";
    NSString *message   = @"You must turn on Bluetooth in Settings in order to connect to a device";
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
}


- (void)alertFailedConnection{
    
    NSString *title     = @"Unable to connect";
    NSString *message   = @"Please check power & wiring,\nthen reset your Arduino";
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
    
}


#pragma mark UartViewControllerDelegate / PinIOViewControllerDelegate


- (void)sendData:(NSData*)newData{
    
    NSString *hexString = [newData hexRepresentationWithSpaces:YES];
    NSLog(@"Sending: %@", hexString);
    
    [currentPeripheral writeRawData:newData];
    
}


@end

