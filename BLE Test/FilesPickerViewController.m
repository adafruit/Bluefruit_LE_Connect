//
//  FilesPickerViewController.m
//  BluefruitUpdater
//
//  Created by Antonio García on 22/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import "FilesPickerViewController.h"
#import "LogHelper.h"

@interface FilesPickerViewController () <UIDocumentMenuDelegate, UIDocumentPickerDelegate>
{
    // UI
    __weak IBOutlet UIView *dialogView;
    __weak IBOutlet UIView *leftButtonView;
    __weak IBOutlet UIView *rightButtonView;
    __weak IBOutlet UIView *cancelView;
    __weak IBOutlet UILabel *hexFileUrlLabel;
    __weak IBOutlet UILabel *iniFileUrlLabel;
    
    // Data
    BOOL isPickingHexFile;
    NSURL *hexFileUrl;
    NSURL *iniFileUrl;
}
@end

@implementation FilesPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // UI
    dialogView.layer.cornerRadius = 4;
    dialogView.layer.masksToBounds = YES;
    cancelView.transform = CGAffineTransformMakeTranslation(-1, 0);
    
    leftButtonView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    leftButtonView.layer.borderWidth = 1;
    
    rightButtonView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    rightButtonView.layer.borderWidth = 1;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onClickFileChoose:(UIButton *)sender {
    NSInteger tag = sender.tag;
    isPickingHexFile = tag == 0;
    
     UIDocumentMenuViewController *importMenu = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[@"public.data", @"public.content"]  inMode:UIDocumentPickerModeImport];
     importMenu.delegate = self;
     [self presentViewController:importMenu animated:YES completion:nil];
}

- (IBAction)onClickStartUpdate:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        if (_delegate)
        {
            [_delegate onFilesPickerStartUpdateWithHexFile:hexFileUrl iniFileUrl:iniFileUrl];
        }
    }];
}


- (IBAction)onClickCancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        if (_delegate)
        {
            [_delegate onFilesPickerCancel];
        }
    }];
}

- (void)updateFileNames
{
    hexFileUrlLabel.text = hexFileUrl?[hexFileUrl lastPathComponent ]:@"<No file selected>";
    iniFileUrlLabel.text = iniFileUrl?[iniFileUrl lastPathComponent ]:@"<No file selected>";
}

#pragma mark - UIDocumentMenuDelegate

- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker
{
    documentPicker.delegate = self;
    [self presentViewController:documentPicker animated:YES completion:nil];
}

- (void)documentMenuWasCancelled:(UIDocumentMenuViewController *)documentMenu
{
    
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
    DLog(@"picked: %@", url.absoluteString);
    
    if (isPickingHexFile) {
        hexFileUrl = url;
    }
    else {
        iniFileUrl = url;
    }
    
    [self updateFileNames];
}



- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    
}

@end
