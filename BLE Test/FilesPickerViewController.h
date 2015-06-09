//
//  FilesPickerViewController.h
//  BluefruitUpdater
//
//  Created by Antonio García on 22/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import <UIKit/UIKit.h>

@protocol FilesPickerViewControllerDelegate <NSObject>

- (void)onFilesPickerCancel;
- (void)onFilesPickerStartUpdateWithHexFile:(NSURL *)hexFileUrl iniFileUrl:(NSURL *)initFileUrl;

@end

@interface FilesPickerViewController : UIViewController

@property id<FilesPickerViewControllerDelegate> delegate;


@end
