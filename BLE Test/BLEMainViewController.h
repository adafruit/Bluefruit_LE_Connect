//
//  BLEMainViewController.h
//  BLE Test
//
//  Created by Collin Cunningham on 2/1/13.
//  Copyright (c) 2013 Adafruit Industries. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "UARTPeripheral.h"
#import "HelpViewController.h"
#import "PinIOViewController.h"
#import "UARTViewController.h"


@interface BLEMainViewController : UIViewController <UINavigationControllerDelegate, HelpViewControllerDelegate, CBCentralManagerDelegate, UARTPeripheralDelegate, UARTViewControllerDelegate, PinIOViewControllerDelegate>

typedef enum {
    ConnectionModeNone  = 0,
    ConnectionModePinIO,
    ConnectionModeUART,
} ConnectionMode;

typedef enum {
    ConnectionStatusDisconnected = 0,
    ConnectionStatusScanning,
    ConnectionStatusConnected,
} ConnectionStatus;

@property (nonatomic, assign) ConnectionMode                    connectionMode;
@property (nonatomic, assign) ConnectionStatus                  connectionStatus;
@property (strong, nonatomic) UIPopoverController               *helpPopoverController;
@property (strong, nonatomic) IBOutlet PinIOViewController      *pinIoViewController;
@property (strong, nonatomic) IBOutlet UARTViewController       *uartViewController;
@property (strong, nonatomic) IBOutlet UIButton                 *pinIoButton;
@property (strong, nonatomic) IBOutlet UIButton                 *uartButton;
@property (strong, nonatomic) IBOutlet UIButton                 *infoButton;
@property (strong, nonatomic) IBOutlet UINavigationController   *navController;
@property (strong, nonatomic) IBOutlet UIViewController         *menuViewController;
@property (strong, nonatomic) IBOutlet HelpViewController       *helpViewController;
@property (strong, nonatomic) IBOutlet UIView                   *helpView;

- (IBAction)showInfo:(id)sender;
- (IBAction)buttonTapped:(UIButton*)sender;
- (void)helpViewControllerDidFinish:(HelpViewController*)controller;

@end

//@protocol PinIoViewControllerDelegate <NSObject>
//
//@end
//
//@interface PinIoViewController : UIViewController
//
//@property (strong, nonatomic) BLEMainViewController             *mainController;
//
//@end
//
//
//

