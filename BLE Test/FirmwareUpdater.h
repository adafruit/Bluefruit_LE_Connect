//
//  FirmwareUpdater.h
//  BluefruitUpdater
//
//  Created by Antonio García on 17/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import <Foundation/Foundation.h>
@import CoreBluetooth;
#import "ReleasesParser.h"

#pragma mark - DeviceInfoData
@interface DeviceInfoData : NSObject
@property NSString *manufacturer;
@property NSString *modelNumber;
@property NSString *firmwareRevision;
@property NSString *softwareRevision;
- (NSString *)bootloaderVersion;
- (NSString *)defaultBootloaderVersion;
- (BOOL)hasDefaultBootloaderVersion;
@end


#pragma mark - FirmwareUpdater
@protocol FirmwareUpdaterDelegate <NSObject>
- (void)onFirmwareUpdatesAvailable:(BOOL)isUpdateAvailable latestRelease:(FirmwareInfo *)latestRelease deviceInfoData:(DeviceInfoData *)deviceInfoData allReleases:(NSDictionary *)allReleases;
- (void)dfuServiceNotFound;
@end

@interface FirmwareUpdater : NSObject  <CBPeripheralDelegate>

@property DeviceInfoData *deviceInfoData;

// Releases database
+ (void)refreshSoftwareUpdatesDatabase;

// Download helper
+ (void)downloadDataFromURL:(NSURL *)url withCompletionHandler:(void (^)(NSData *))completionHandler;

// Check updates
- (void)checkUpdatesForPeripheral:(CBPeripheral *)peripheral delegate:(id<FirmwareUpdaterDelegate>) delegate;
- (void)connectAndCheckUpdatesForPeripheral:(CBPeripheral *)peripheral delegate:(id<FirmwareUpdaterDelegate>) delegate;
@end
