//
//  FirmwareUpdater.m
//  BluefruitUpdater
//
//  Created by Antonio García on 17/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import "FirmwareUpdater.h"
#import "ReleasesParser.h"
#import "LogHelper.h"
//#import "BleManager.h"
#import "Adafruit_Bluefruit_LE_Connect-Swift.h"

#pragma mark - DeviceInfoData
@implementation DeviceInfoData

static NSString* const kManufacturer = @"Adafruit Industries";
static NSString* const kDefaultBootloaderVersion = @"0.0";

- (NSString *)defaultBootloaderVersion
{
    return kDefaultBootloaderVersion;
}

- (NSString *)bootloaderVersion
{
    NSString *result = kDefaultBootloaderVersion;
    if (_firmwareRevision) {
        NSInteger index = [_firmwareRevision rangeOfString:@", "].location;
        if (index != NSNotFound)
        {
            NSString *bootloaderVersion = [_firmwareRevision substringFromIndex:index+2];
            result = bootloaderVersion;
        }
    }
    return result;
}

- (BOOL)hasDefaultBootloaderVersion
{
    return [[self bootloaderVersion] isEqualToString:kDefaultBootloaderVersion];
}

@end

#pragma mark - FirmwareUpdater
@interface FirmwareUpdater ()
{
    __weak id<CBPeripheralDelegate> previousPeripheralDelegate;
}

@property (weak) id<FirmwareUpdaterDelegate> delegate;

@end

@implementation FirmwareUpdater

//  Config
static NSString *kDefaultUpdateServerUrl = @"https://raw.githubusercontent.com/adafruit/Adafruit_BluefruitLE_Firmware/master/releases.xml";
static NSString *kReleasesXml = @"updatemanager_releasesxml";

// Constants
static  NSString* const kNordicDeviceFirmwareUpdateService = @"00001530-1212-EFDE-1523-785FEABCD123";
static  NSString* const kDeviceInformationService = @"180A";
static  NSString* const kModelNumberCharacteristic = @"00002A24-0000-1000-8000-00805F9B34FB";
static  NSString* const kManufacturerNameCharacteristic = @"00002A29-0000-1000-8000-00805F9B34FB";
static  NSString* const kSoftwareRevisionCharacteristic = @"00002A28-0000-1000-8000-00805F9B34FB";
static  NSString* const kFirmwareRevisionCharacteristic = @"00002A26-0000-1000-8000-00805F9B34FB";

- (NSDictionary *)releases
{
    NSDictionary *boardsInfoDictionary = nil;
    
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:kReleasesXml];
    if (data)
    {
        // Parse data
        boardsInfoDictionary = [ReleasesParser parse:data];
    }

    return boardsInfoDictionary;
}

+ (void)refreshSoftwareUpdatesDatabase
{
    @synchronized(self) {
        // Download data
        NSURL *dataUrl = [NSURL URLWithString:kDefaultUpdateServerUrl];
        [FirmwareUpdater downloadDataFromURL:dataUrl withCompletionHandler:^(NSData *data) {
            // Save to user defaults
            NSString* newStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            DLog(@"%@", newStr);
            [[NSUserDefaults standardUserDefaults] setObject:data forKey:kReleasesXml];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }];
    }
}


+ (void)downloadDataFromURL:(NSURL *)url withCompletionHandler:(void (^)(NSData *))completionHandler 
{
    if ([url.scheme isEqualToString:@"file"])        // Check if url is local and just open the file
    {
        NSData *data = [NSData dataWithContentsOfURL:url];
        completionHandler(data);
    }
    else
    {
        // If the url is not local, download the file
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
        
        NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error != nil) {
                // If any error occurs then just display its description on the console.
                DLog(@"%@", [error description]);
            }
            else{
                NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
                if (statusCode != 200) {
                    DLog(@"Download file HTTP status code = %ld", (long)statusCode);
                }
                
                // Call the completion handler with the returned data on the main thread.
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    completionHandler(data);
                }];
            }
        }];
        
        [task resume];
    }
}

#pragma mark  Peripheral Management
- (void)checkUpdatesForPeripheral:(CBPeripheral *)peripheral delegate:(id<FirmwareUpdaterDelegate>) delegate
{
    _delegate = delegate;
    previousPeripheralDelegate = peripheral.delegate;
    peripheral.delegate = self;

    // The peripheral is already connected, so got to didDiscoverServices
    [self peripheral:peripheral didDiscoverServices:nil];
}


- (void)connectAndCheckUpdatesForPeripheral:(CBPeripheral *)peripheral delegate:(id<FirmwareUpdaterDelegate>) delegate
{
    _delegate = delegate;
    [self connectToPeripheral:peripheral];
}

- (void)connectToPeripheral:(CBPeripheral *)peripheral {
    
    peripheral.delegate = self;
//    CBUUID *dfuServiceUUID = [CBUUID UUIDWithString:kNordicDeviceFirmwareUpdateService];
//    CBUUID *disServiceUUID = [CBUUID UUIDWithString:kDeviceInformationService];
    
//    BleManager *bleManager = [BleManager sharedInstance];
//    [bleManager connectToPeripheral:peripheral servicesToDiscover:@[dfuServiceUUID, disServiceUUID]];
    
    BLEMainViewController *blemvc = [BLEMainViewController sharedInstance];
    [blemvc connectPeripheralForDFU:peripheral];
    
}

- (void)hasConnectedPeripheralDFUService
{
}


#pragma mark  CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {

    // Retrieve services
    CBUUID *dfuServiceUUID = [CBUUID UUIDWithString:kNordicDeviceFirmwareUpdateService];
    CBUUID *disServiceUUID = [CBUUID UUIDWithString:kDeviceInformationService];
    CBService *dfuService = nil;
    CBService *disService = nil;

    for (CBService *service in peripheral.services) {
        DLog(@"Discovered service %@", service);
        //NSString *serviceUUID = service.UUID.UUIDString;
        if ([service.UUID isEqual:dfuServiceUUID]) {
            dfuService = service;
        }
        else if ([service.UUID isEqual:disServiceUUID]) {
            disService = service;
        }
    }

    // If we have the services that we need, retrieve characteristics
    if (dfuService && disService) {
        _deviceInfoData = [DeviceInfoData new];
        CBUUID *manufacturerCharacteristicUUID = [CBUUID UUIDWithString:kManufacturerNameCharacteristic];
        CBUUID *modelNumberCharacteristicUUID = [CBUUID UUIDWithString:kModelNumberCharacteristic];
        CBUUID *softwareRevisionCharacteristicUUID = [CBUUID UUIDWithString:kSoftwareRevisionCharacteristic];
        CBUUID *firmwareRevisionCharacteristicUUID = [CBUUID UUIDWithString:kFirmwareRevisionCharacteristic];

        [peripheral discoverCharacteristics:@[manufacturerCharacteristicUUID, modelNumberCharacteristicUUID, softwareRevisionCharacteristicUUID, firmwareRevisionCharacteristicUUID] forService:disService];
        //[peripheral discoverCharacteristics:nil forService:disService];
    }
    else
    {
        DLog(@"Peripheral has no dfu or dis service available");
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate dfuServiceNotFound];
        });
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    // Read the characteristics discovered
    for (CBCharacteristic *characteristic in service.characteristics) {
      //  DLog(@"Discovered characteristic %@", characteristic);
        [peripheral readValueForCharacteristic:characteristic];
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    CBUUID *manufacturerCharacteristicUUID = [CBUUID UUIDWithString:kManufacturerNameCharacteristic];
    CBUUID *modelNumberCharacteristicUUID = [CBUUID UUIDWithString:kModelNumberCharacteristic];
    CBUUID *softwareRevisionCharacteristicUUID = [CBUUID UUIDWithString:kSoftwareRevisionCharacteristic];
    CBUUID *firmwareRevisionCharacteristicUUID = [CBUUID UUIDWithString:kFirmwareRevisionCharacteristic];
    
    NSData *data = characteristic.value;
    //NSString *characteristicUUID = characteristic.UUID.UUIDString;
    
    if ([characteristic.UUID isEqual:manufacturerCharacteristicUUID]) {
        _deviceInfoData.manufacturer = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    else if ([characteristic.UUID isEqual:modelNumberCharacteristicUUID]) {
        _deviceInfoData.modelNumber = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    else if ([characteristic.UUID isEqual:softwareRevisionCharacteristicUUID]) {
        _deviceInfoData.softwareRevision = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    else if ([characteristic.UUID isEqual:firmwareRevisionCharacteristicUUID]) {
        _deviceInfoData.firmwareRevision = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    
    DLog(@"didUpdateValueForCharacteristic %@", characteristic);
    [self onDeviceInfoUpdatedForPeripheral:peripheral];
}

- (void)onDeviceInfoUpdatedForPeripheral:(CBPeripheral *)peripheral
{ 
    if (_deviceInfoData.manufacturer && _deviceInfoData.modelNumber && _deviceInfoData.softwareRevision && _deviceInfoData.firmwareRevision) {
        DLog(@"Device Info Data received");

        
        if (_delegate == nil) {
            DLog(@"Error: onDeviceInfoUpdatedForPeripheral with no delegate");
        }

        NSString *versionToIgnore = [[NSUserDefaults standardUserDefaults] stringForKey:@"softwareUpdateIgnoredVersion"];

        
        BOOL isFirmwareUpdateAvailable = NO;
    
        NSDictionary *allReleases = [self releases];
        FirmwareInfo *latestRelease = nil;
        
        if (![_deviceInfoData hasDefaultBootloaderVersion]) {       // Special check because Nordic dfu library for iOS dont work with the default booloader version
            BOOL isManufacturerCorrect = [kManufacturer caseInsensitiveCompare:_deviceInfoData.manufacturer] == NSOrderedSame;
            if (isManufacturerCorrect) {
                BoardInfo *boardInfo = [allReleases objectForKey:_deviceInfoData.modelNumber];
                if (boardInfo) {
                    NSArray *modelReleases = boardInfo.firmwareReleases;
                    if (modelReleases && modelReleases.count > 0) {
                        // Get the latest release (discard all beta releases)
                        int selectedRelease = 0;
                        do {
                            latestRelease = [modelReleases objectAtIndex:selectedRelease];
                            selectedRelease++;
                        } while(latestRelease.isBeta && selectedRelease<modelReleases.count);
                        
                        if (!latestRelease.isBeta)
                        {
                            // Check if the bootloader is compatible with this version
                            if (_deviceInfoData.bootloaderVersion && [_deviceInfoData.bootloaderVersion compare:latestRelease.minBootloaderVersion options:NSNumericSearch] != NSOrderedAscending) {
                                // Check if the user chose to ignore this version
                                if ([latestRelease.version compare:versionToIgnore options:NSNumericSearch] != NSOrderedSame) {
                                    
                                    const BOOL isNewerVersion = [latestRelease.version compare:_deviceInfoData.softwareRevision options:NSNumericSearch] == NSOrderedDescending;
                                    const BOOL showUpdateOnlyForNewerVersions = YES;            // only for debug purposes (should be YES for release)
                                    
                                    isFirmwareUpdateAvailable = isNewerVersion || !showUpdateOnlyForNewerVersions;
                                    
#ifdef DEBUG
                                    if (isNewerVersion) {
                                        DLog(@"Updates: New version found. Ask the user to install: %@", latestRelease.version);
                                    }
                                    else {
                                        DLog(@"Updates: Device has already latest version: %@", _deviceInfoData.softwareRevision);
                                        
                                        if (isFirmwareUpdateAvailable) {
                                            DLog(@"Updates: user asked to show old versions too");
                                        }
                                    }
#endif
                                }
                                else {
                                    DLog(@"Updates: User ignored version: %@. Skipping...", versionToIgnore);
                                }
                            }
                            else {
                                DLog(@"Updates: No non-beta firmware releases found for model: %@", versionToIgnore);
                                
                            }
                        }
                        else {
                            DLog(@"Updates: Bootloader version %@ below minimum needed: %@", _deviceInfoData.bootloaderVersion, latestRelease.minBootloaderVersion);
                        }
                    }
                    else {
                        DLog(@"Updates: No firmware releases found for model: %@", _deviceInfoData.modelNumber);
                    }
                }
                else {
                    DLog(@"Updates: No releases found for model:  %@", _deviceInfoData.modelNumber);
                }
            }
            else {
                DLog(@"Updates: No updates for unknown manufacturer %@", _deviceInfoData.manufacturer);
            }
        }else {
            DLog(@"The legacy bootloader on this device is not compatible with this application");
        }

        
        peripheral.delegate = previousPeripheralDelegate;
        [_delegate onFirmwareUpdatesAvailable:isFirmwareUpdateAvailable latestRelease:latestRelease deviceInfoData:_deviceInfoData allReleases:allReleases];
    }
}


@end
