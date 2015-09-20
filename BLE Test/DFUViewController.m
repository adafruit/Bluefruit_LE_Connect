//
//  DFUViewController.m
//  BluefruitUpdater
//
//  Created by Antonio García on 15/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import "DFUViewController.h"
//#import "BleManager.h"
#import "DFUOperations.h"
#import "LogHelper.h"
#import "FirmwareUpdater.h"
#import "UpdateDialogViewController.h"
#import "UserFilesTableViewCell.h"
#import "FilesPickerViewController.h"
#import "Adafruit_Bluefruit_LE_Connect-Swift.h"

@interface DFUViewController () <UITableViewDataSource, UITableViewDelegate, FirmwareUpdaterDelegate, UpdateDialogViewControllerDelegate, UserFilesTableViewCellDelegate, FilesPickerViewControllerDelegate
//    BleManagerDelegate
    >

{
    // UI
    __weak IBOutlet UITableView *baseTableView;
    __weak IBOutlet UIView *waitView;

    // Data
    BoardInfo *boardRelease;
    DeviceInfoData *deviceInfoData;
    FirmwareUpdater *firmwareUpdater;
    UpdateDialogViewController *updateDialogViewController;
    
    BOOL firmwareUpdaterRunning;
}
@end

@implementation DFUViewController

static const NSInteger kSection_ConnectedPeripheral = 0;
static const NSInteger kSection_FirmwareReleases = 1;
static const NSInteger kSection_BootloaderReleases = 2;


- (void)viewDidLoad {
    [super viewDidLoad];

    // UI
    self.title = @"Firmware Updater";
    [baseTableView setBackgroundColor:[UIColor clearColor]];
    waitView.hidden = NO;
    
    if (_peripheral)
    {
        firmwareUpdater = [FirmwareUpdater new];
        firmwareUpdaterRunning = YES;
        [firmwareUpdater connectAndCheckUpdatesForPeripheral:_peripheral delegate:self];

    }
    else
    {
        [self peripheralUnexpectedDisconnect];
    }
    
    //refresh updates for DFU
    //[FirmwareUpdater refreshSoftwareUpdatesDatabase];
    
    [baseTableView registerNib:[UINib nibWithNibName:@"UserFilesTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"UserFilesCell"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
//    [BleManager sharedInstance].delegate = self;
    [[BLEMainViewController sharedInstance] setDelegate:self];
    
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"UpdateDialogViewController"])
    {
        updateDialogViewController = segue.destinationViewController;
        updateDialogViewController.delegate = self;
    }
}

#pragma mark -
- (void)peripheralUnexpectedDisconnect
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Peripheral disconnected. Go back to previous viewcontroller
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:@"Peripheral disconnected" preferredStyle:UIAlertControllerStyleAlert];
        __weak DFUViewController *weakSelf = self;
        UIAlertAction *okAction = [UIAlertAction  actionWithTitle:@"Ok"  style:UIAlertActionStyleDefault  handler:^(UIAlertAction *action) {
            DFUViewController *strongSelf = weakSelf;
            [strongSelf.navigationController popViewControllerAnimated:YES];
        }];
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    });
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case kSection_ConnectedPeripheral:
            return @"Connected Peripheral";
        case kSection_FirmwareReleases:
            return @"Firmware Releases";
        case kSection_BootloaderReleases:
            return @"Bootloader Releases";
            
        default:
            return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case kSection_ConnectedPeripheral:
            return 1;
            
        case kSection_FirmwareReleases: {
            NSInteger numRows = 1;      // at least a custom firmware button
            if (boardRelease && boardRelease.firmwareReleases) {
                NSArray *firmwareReleases = boardRelease.firmwareReleases;
                numRows += (firmwareReleases?firmwareReleases.count:0);
            }
            return numRows;
        }
        case kSection_BootloaderReleases:
            return 0;
            
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    const NSInteger section = indexPath.section;
    const NSInteger row = indexPath.row;
    
    UITableViewCell *cell;
    if (section == kSection_ConnectedPeripheral) {
        static NSString *kCellIdentifier = @"PeripheralCell";
        cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCellIdentifier];
        }

        cell.textLabel.text = _peripheral.name;
        cell.detailTextLabel.text = deviceInfoData.softwareRevision?[NSString stringWithFormat:@"Firmware: %@", deviceInfoData.softwareRevision]:nil;

        cell.backgroundColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:1];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

    }
    else if (section == kSection_FirmwareReleases)
    {
        if (row == [self tableView:tableView numberOfRowsInSection:section] -1)     // If is the last row (UserFiles)
        {
            static NSString *kCellIdentifier = @"UserFilesCell";
            UserFilesTableViewCell *userFilesCell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier forIndexPath:indexPath];
            if (userFilesCell == nil) {
                userFilesCell = [[UserFilesTableViewCell alloc]init];
                
            }
            userFilesCell.delegate = self;
            cell = userFilesCell;
        }
        else
        {
            static NSString *kCellIdentifier = @"FirmwareCell";
            cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCellIdentifier];
            }
            
            NSArray *firmwareReleases = boardRelease.firmwareReleases;
            FirmwareInfo *firmwareInfo = [firmwareReleases objectAtIndex:row];
            
            cell.textLabel.text = [NSString stringWithFormat:firmwareInfo.isBeta?@"Beta Version %@":@"Version %@", firmwareInfo.version];
            cell.detailTextLabel.text = firmwareInfo.boardName;
        }
    }
    else {
        static NSString *kCellIdentifier = @"BootloaderCell";
        cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCellIdentifier];
        }
    }
    
   
    return cell;
}


#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    const NSInteger section = indexPath.section;
    const NSInteger row = indexPath.row;
    
    if (section == kSection_FirmwareReleases &&  row != [self tableView:tableView numberOfRowsInSection:section] -1)     // If is not the last row (UserFiles)
    {
        NSArray *firmwareReleases = boardRelease.firmwareReleases;
        FirmwareInfo *firmwareInfo = [firmwareReleases objectAtIndex:row];
        [self confirmDfuUpdateWithFirmware:firmwareInfo];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


#pragma mark - BleManagerDelegate

- (void)onDeviceConnectionChange:(CBPeripheral *)peripheral
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([peripheral isEqual:_peripheral] && peripheral.state != CBPeripheralStateConnected && firmwareUpdaterRunning)
        {
            DLog(@"Peripheral disconnected");
            [self peripheralUnexpectedDisconnect];
        }
    });
}

#pragma mark - FirmwareUpdaterDelegate
- (void)onFirmwareUpdatesAvailable:(BOOL)isUpdateAvailable latestRelease:(FirmwareInfo *)latestRelease deviceInfoData:(DeviceInfoData *)aDeviceInfoData allReleases:(NSDictionary *)allReleases
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        DLog(@"onFirmwareUpdatesAvailable");
        firmwareUpdaterRunning = NO;
        deviceInfoData = aDeviceInfoData;
        if (allReleases)
        {
            boardRelease = [allReleases objectForKey:deviceInfoData.modelNumber];
        }
        
        //    [[BleManager sharedInstance] disconnectCurrentConnectedPeripheral];
        [[BLEMainViewController sharedInstance] disconnect];
        
        waitView.hidden = YES;
        [baseTableView reloadData];
        
        // Check if this bootloader version is compatible with the nordic dfu library
        if ([deviceInfoData hasDefaultBootloaderVersion]) {
            [self onUpdateDialogError:@"The legacy bootloader on this device is not compatible with this application" exitOnDismissal:YES];
        }
        
    });
}

- (void) dfuServiceNotFound
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:@"No DFU Service found on device" preferredStyle:UIAlertControllerStyleAlert];
    __weak DFUViewController *weakSelf = self;
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"Ok"  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        DFUViewController *strongSelf = weakSelf;
        [strongSelf.navigationController popViewControllerAnimated:YES];
    }];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
    
}

#pragma mark - Dfu Update
- (void)confirmDfuUpdateWithFirmware:(FirmwareInfo *)firmwareInfo
{
//    BOOL areRequerimentsMet = YES;
     // Check that the minimum bootloader version requirement is met
    NSComparisonResult compareBootloader = [deviceInfoData.bootloaderVersion caseInsensitiveCompare:firmwareInfo.minBootloaderVersion];
    if (compareBootloader == NSOrderedDescending || compareBootloader == NSOrderedSame) {
        NSString *message = [NSString stringWithFormat:@"Download and install firmware version %@",  firmwareInfo.version];

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction  actionWithTitle:@"Ok"  style:UIAlertActionStyleDefault  handler:^(UIAlertAction *action) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^ {
                [self startDfuUpdateWithFirmware:firmwareInfo];
            }];
        }];
        UIAlertAction *cancelAction = [UIAlertAction  actionWithTitle:@"Cancel"  style:UIAlertActionStyleDefault  handler:nil];
        [alertController addAction:okAction];
        [alertController addAction:cancelAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
    else {
//        areRequerimentsMet = NO;
        
        NSString *alertText = [NSString stringWithFormat:@"This firmware update is not compatible with your bootloader. You need to update your bootloader to version %@ before installing this firmware release", firmwareInfo.minBootloaderVersion];
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:alertText preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction  actionWithTitle:@"Ok"  style:UIAlertActionStyleDefault  handler:nil];
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}
                                   
- (void)startDfuUpdateWithFirmware:(FirmwareInfo *)firmwareInfo
{
    // Start update
//    UpdateDialogViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"UpdateDialogViewController"];
    UpdateDialogViewController *viewController = [[UpdateDialogViewController alloc]init];
    [viewController setPeripheral:_peripheral hexUrl:[NSURL URLWithString:firmwareInfo.hexFileUrl] iniUrl:[NSURL URLWithString:firmwareInfo.iniFileUrl] deviceInfoData:deviceInfoData];
    viewController.delegate = self;
    [self presentCoverVertical:viewController];
}

#pragma mark - UpdateDialogViewControllerDelegate
- (void)onUpdateDialogSuccess
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:@"Update completed successfully" preferredStyle:UIAlertControllerStyleAlert];
    __weak DFUViewController *weakSelf = self;
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"Ok"  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        DFUViewController *strongSelf = weakSelf;
        [strongSelf.navigationController popViewControllerAnimated:YES];
    }];
    [alertController addAction:okAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)onUpdateDialogCancel
{
}

- (void)onUpdateDialogError:(NSString *)errorMessage exitOnDismissal:(BOOL)exit
{
    if (self.presentedViewController == nil) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
        __weak DFUViewController *weakSelf = self;
        UIAlertAction *okAction;
        if (exit) {
            okAction = [UIAlertAction  actionWithTitle:@"Ok" style:UIAlertActionStyleDefault  handler:^(UIAlertAction *action) {
                DFUViewController *strongSelf = weakSelf;
                [strongSelf.navigationController popViewControllerAnimated:YES];
            }];
        }
        else {
            okAction = [UIAlertAction  actionWithTitle:@"Ok" style:UIAlertActionStyleDefault  handler:nil];
        }
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)onUpdateDialogError:(NSString *)errorMessage
{
    [self onUpdateDialogError:errorMessage exitOnDismissal:NO];
}

#pragma mark - UserFilesTableViewCellDelegate
- (void)onUserFilesClick:(NSInteger)tag
{
    
//    FilesPickerViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"FilesPickerViewController"];
    FilesPickerViewController *viewController = [[FilesPickerViewController alloc]init];
    viewController.delegate = self;
    [self presentCoverVertical:viewController];
    
}

#pragma mark - FilesPickerViewControllerDelegate

- (void)onFilesPickerStartUpdateWithHexFile:(NSURL *)hexFileUrl iniFileUrl:(NSURL *)initFileUrl
{
    if (hexFileUrl)
    {
        // Launch update
//        UpdateDialogViewController *viewController = [self.storyboard instantiateViewControllerWithIdentifier:@"UpdateDialogViewController"];
        UpdateDialogViewController *viewController = [[UpdateDialogViewController alloc]init];
        viewController.delegate = self;
        [viewController setPeripheral:_peripheral hexUrl:hexFileUrl iniUrl:initFileUrl deviceInfoData:deviceInfoData];
        [self presentCoverVertical:viewController];

    }
    else
    {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:@"At least an Hex file should be selected" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction  actionWithTitle:@"Ok"  style:UIAlertActionStyleDefault  handler:nil];
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)onFilesPickerCancel
{
    
}

- (void)presentCoverVertical:(UIViewController*)viewController {
    
    viewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    viewController.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    [self presentViewController:viewController animated:YES completion:nil];
    
}


@end
