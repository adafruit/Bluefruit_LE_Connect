//
//  UpdateDialogViewController.h
//  BluefruitUpdater
//
//  Created by Antonio García on 18/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import <UIKit/UIKit.h>
@import CoreBluetooth;

@class FirmwareInfo;
@class DeviceInfoData;

@protocol UpdateDialogViewControllerDelegate <NSObject>
- (void)onUpdateDialogCancel;
- (void)onUpdateDialogSuccess;
- (void)onUpdateDialogError:(NSString *)errorMessage;
@end

@interface UpdateDialogViewController : UIViewController

@property (weak) id<UpdateDialogViewControllerDelegate> delegate;
/*
@property CBPeripheral* peripheral;
@property FirmwareInfo *firmwareInfo;
@property DeviceInfoData *deviceInfoData;
*/

- (void)setPeripheral:(CBPeripheral *)peripheral hexUrl:(NSURL *)hexUrl iniUrl:(NSURL *)iniUrl deviceInfoData:(DeviceInfoData *)deviceInfoData;
@end
