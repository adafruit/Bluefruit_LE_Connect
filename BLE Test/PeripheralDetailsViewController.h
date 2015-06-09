//
//  PeripheralDetailsViewController.h
//  BluefruitUpdater
//
//  Created by Antonio García on 15/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import <UIKit/UIKit.h>
@import CoreBluetooth;

@interface PeripheralDetailsViewController : UIViewController

@property CBPeripheral* peripheral;

@end
