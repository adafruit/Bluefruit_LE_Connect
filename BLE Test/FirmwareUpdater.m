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
#import "BluetoothLE_Test-Swift.h"

#pragma mark - DeviceInfoData
@implementation DeviceInfoData

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
@interface FirmwareUpdater () <CBPeripheralDelegate>
@property (weak) id<FirmwareUpdaterDelegate> delegate;
@end

@implementation FirmwareUpdater

//  Config
static NSString *kDefaultUpdateServerUrl = @"https://raw.githubusercontent.com/adafruit/Adafruit_BluefruitLE_Firmware/master/releases.xml";

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
    
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"updatemanager_releasesxml"];
    if (data)
    {
        // Parse data
        boardsInfoDictionary = [ReleasesParser parse:data];
    }

    return boardsInfoDictionary;
}

+ (void)refreshSoftwareUpdatesDatabase
{
    // Download data
    NSURL *dataUrl = [NSURL URLWithString:kDefaultUpdateServerUrl];
    [FirmwareUpdater downloadDataFromURL:dataUrl withCompletionHandler:^(NSData *data) {
        // Save to user defaults
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"updatemanager_releasesxml"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
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
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
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
        [self.delegate dfuServiceNotFound];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    // Read the characteristics discovered
    for (CBCharacteristic *characteristic in service.characteristics) {
        DLog(@"Discovered characteristic %@", characteristic);
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
    
    [self onDeviceInfoUpdated];
}

- (void)onDeviceInfoUpdated
{ 
    if (_deviceInfoData.manufacturer && _deviceInfoData.modelNumber && _deviceInfoData.softwareRevision && _deviceInfoData.firmwareRevision) {
        DLog(@"Device Info Data received");
        [_delegate onFirmwareUpdatesAvailable:NO latestRelease:nil deviceInfoData:_deviceInfoData allReleases:[self releases]];
    }
    
}


@end
