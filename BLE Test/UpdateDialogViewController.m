//
//  UpdateDialogViewController.m
//  BluefruitUpdater
//
//  Created by Antonio García on 18/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import "UpdateDialogViewController.h"
#import "DFUOperations.h"
//#import "BleManager.h"
#import "FirmwareUpdater.h"
#import "LogHelper.h"
#import "Adafruit_Bluefruit_LE_Connect-Swift.h"

@interface UpdateDialogViewController () <DFUOperationsDelegate>
{
    // UI
    __weak IBOutlet UILabel *titleLabel;
    __weak IBOutlet UILabel *progressLabel;
    __weak IBOutlet UIProgressView *progressView;
    __weak IBOutlet UIView *dialogView;
    
    // Parameters
    CBPeripheral* peripheral;
    NSURL *hexUrl;
    NSURL *iniUrl;
    DeviceInfoData *deviceInfoData;
    
    // DFU data
    DFUOperations *dfuOperations;
    BOOL isConnected;
    BOOL isDFUVersionExits;
    BOOL isTransferring;
    BOOL isDFUCancelled;
    BOOL isDfuStarted;
    NSInteger dfuVersion;
}
@end

@implementation UpdateDialogViewController

static NSString *const kApplicationHexFilename = @"application.hex";
static NSString *const kApplicationIniFilename = @"application.bin";        // don't change extensions. dfuOperations will look for these specific extensions

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Init
    dfuOperations = [[DFUOperations alloc] initWithDelegate:self];

    // UI
    dialogView.layer.cornerRadius = 4;
    
    // Download files
    [self setTitleText:@"Downloading hex file"];
    __weak UpdateDialogViewController *weakSelf = self;
    [FirmwareUpdater downloadDataFromURL:hexUrl withCompletionHandler:^(NSData * data) {
        UpdateDialogViewController *strongSelf = weakSelf;
        [strongSelf downloadedFirmwareData:data];
    }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setPeripheral:(CBPeripheral *)aPeripheral hexUrl:(NSURL *)aHexUrl iniUrl:(NSURL *)aIniUrl deviceInfoData:(DeviceInfoData *)aDeviceInfoData
{
    peripheral = aPeripheral;
    hexUrl = aHexUrl;
    iniUrl = aIniUrl;
    deviceInfoData = aDeviceInfoData;
}

- (void)setTitleText:(NSString *)text
{
    titleLabel.text = text;
}

- (void)setProgress:(CGFloat)progress
{
    progressView.progress = progress;
    progressLabel.text = [NSString stringWithFormat:@"%.0f%%", progress*100];
}

- (IBAction)onClickCancel:(id)sender {
    // Cancel current operation
    [dfuOperations cancelDFU];
    
    // Dismiss
    [self dismissViewControllerAnimated:YES completion:^{
        if (_delegate) {
            [_delegate onUpdateDialogCancel];
        }
    }];
}

- (void)downloadedFirmwareData:(NSData *)data{
    // Single hex file needed
    if (data)
    {
        NSString *bootloaderVersion = [deviceInfoData bootloaderVersion];
        const BOOL useHexOnly = [bootloaderVersion isEqualToString:deviceInfoData.defaultBootloaderVersion];
        
        if (useHexOnly)
        {
            NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:kApplicationHexFilename]];
            [data writeToURL:fileURL atomically:YES];
            
            [self startDFUOperation];
        }
        else
        {
            [self setTitleText:@"Downloading init file"];
            __weak UpdateDialogViewController *weakSelf = self;
            [FirmwareUpdater downloadDataFromURL:iniUrl withCompletionHandler:^(NSData * iniData) {
                UpdateDialogViewController *strongSelf = weakSelf;
                [strongSelf downloadedFirmwareHexData:data iniData:iniData];
            }];
        }
    }
    else
    {
        [self showSoftwareDownloadError];
    }
}

- (void)downloadedFirmwareHexData:(NSData *)hexData iniData:(NSData *)iniData {
    //  hex + dat file needed
    if (hexData && iniData)
    {
        NSURL *hexFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:kApplicationHexFilename]];
        [hexData writeToURL:hexFileURL atomically:YES];
        NSURL *iniFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:kApplicationIniFilename]];
        [iniData writeToURL:iniFileURL atomically:YES];
        
        [self startDFUOperation];
    }
    else
    {
        [self showSoftwareDownloadError];
    }
}

- (void)showSoftwareDownloadError
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:@"Software download error" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction  actionWithTitle:@"Ok"  style:UIAlertActionStyleDefault  handler:nil];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)startDFUOperation
{
    isDfuStarted= NO;
    isDFUCancelled = NO;
    [self setTitleText:@"DFU Init"];
    
    // Setup dfu Operations (continues on onReadDFUVersion)
    // Files should be ready at NSTemporaryDirectory/application.hex (and application.dat if needed)
//    CBCentralManager *centralManager = [BleManager sharedInstance].centralManager;
    CBCentralManager *centralManager = [BLEMainViewController sharedInstance].centralManager;
    [dfuOperations setCentralManager:centralManager];
    [dfuOperations connectDevice:peripheral];
}


#pragma mark - DFUOperationsDelegate

-(void)onDeviceConnected:(CBPeripheral *)peripheral
{
    DLog(@"DFUOperationsDelegate - onDeviceConnected");
    isConnected = YES;
    isDFUVersionExits = NO;
    dfuVersion = -1;
}

-(void)onDeviceConnectedWithVersion:(CBPeripheral *)peripheral
{
    DLog(@"DFUOperationsDelegate - onDeviceConnectedWithVersion");
    isConnected = YES;
    isDFUVersionExits = YES;
    dfuVersion = -1;
}

-(void)onDeviceDisconnected:(CBPeripheral *)aPeripheral
{
    dispatch_async(dispatch_get_main_queue(), ^{
        DLog(@"DFUOperationsDelegate - onDeviceDisconnected");
        if (dfuVersion != 1) {
            isTransferring = NO;
            isConnected = NO;
            
            if (dfuVersion == 0)
            {
                [self onError:@"The legacy bootloader on this device is not compatible with this application"];
            }
            else
            {
                [self onError:@"Update error"];
            }
        }
        else {
            double delayInSeconds = 3.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [dfuOperations connectDevice:aPeripheral];
            });
        }
    });
}

-(void)onReadDFUVersion:(int)version
{
    dispatch_async(dispatch_get_main_queue(), ^{
        DLog(@"DFUOperationsDelegate - onReadDFUVersion: %ld", (long)version);
        dfuVersion = version;
        if (dfuVersion == 1) {
            [self setTitleText:@"DFU set bootloader mode"];
            [dfuOperations setAppToBootloaderMode];
        }
        else if (dfuVersion > 1 && !isDFUCancelled && !isDfuStarted)
        {
            // Ready to start
            isDfuStarted = YES;
            NSString *bootloaderVersion = [deviceInfoData bootloaderVersion];
            BOOL useHexOnly = [bootloaderVersion isEqualToString:deviceInfoData.defaultBootloaderVersion];
            
            [self setTitleText:@"Updating"];
            if (useHexOnly)
            {
                NSURL *fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:kApplicationHexFilename]];
                [dfuOperations performDFUOnFile:fileURL firmwareType:APPLICATION];
            }
            else {
                NSURL *hexFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:kApplicationHexFilename]];
                NSURL *iniFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:kApplicationIniFilename]];
                [dfuOperations performDFUOnFileWithMetaData:hexFileURL firmwareMetaDataURL:iniFileURL firmwareType:APPLICATION];
            }
        }
    });
    /*
     else if (dfuVersion == -100 && !isDFUCancelled && !isDfuStarted)
     {
     // Legacy bootloader not supported
     [self onError:@"The legacy bootloader on this device is not compatible with this application"];
     [dfuOperations cancelDFU];
     }
     */
    
}

-(void)onDFUStarted
{
    DLog(@"DFUOperationsDelegate - onDFUStarted");
    isTransferring = YES;
}

-(void)onDFUCancelled
{
    DLog(@"DFUOperationsDelegate - onDFUCancelled");
    // Disconnected while updating
    isDFUCancelled = YES;
    [self onError:@"Update cancelled"];
}

-(void)onSoftDeviceUploadStarted
{
    DLog(@"DFUOperationsDelegate - onSoftDeviceUploadStarted");
    
}

-(void)onBootloaderUploadStarted
{
    DLog(@"DFUOperationsDelegate - onBootloaderUploadStarted");
    
}

-(void)onSoftDeviceUploadCompleted
{
    DLog(@"DFUOperationsDelegate - onSoftDeviceUploadCompleted");
    
}

-(void)onBootloaderUploadCompleted
{
    DLog(@"DFUOperationsDelegate - onBootloaderUploadCompleted");
    
}

-(void)onTransferPercentage:(int)percentage
{
    DLog(@"DFUOperationsDelegate - onTransferPercentage: %ld", (long)percentage);
    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
        [self setProgress:percentage/100.f];
    }];
}

-(void)onSuccessfulFileTranferred
{
    DLog(@"DFUOperationsDelegate - onSuccessfulFileTranferred");
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
        [self dismissViewControllerAnimated:YES completion:^{
            if (_delegate) {
                [_delegate onUpdateDialogSuccess];
            }
        }];
    }];
}

-(void)onError:(NSString *)errorMessage
{
    DLog(@"DFUOperationsDelegate - onError: %@", errorMessage);
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
        [self dismissViewControllerAnimated:YES completion:^{
            if (_delegate) {
                [_delegate onUpdateDialogError:errorMessage];
            }
        }];
    }];
}
@end
