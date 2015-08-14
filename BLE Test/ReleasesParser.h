//
//  ReleasesParser.h
//  BluefruitUpdater
//
//  Created by Antonio García on 16/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import <Foundation/Foundation.h>

#pragma mark - BoardInfo
@interface BoardInfo : NSObject
@property NSMutableArray *firmwareReleases;
@property NSMutableArray *bootloaderReleases;
@end

#pragma mark - BasicVersionInfo
@interface BasicVersionInfo : NSObject
@property NSInteger fileType;
@property NSString *version;
@property NSString *hexFileUrl;
@property NSString *iniFileUrl;
@property NSString *boardName;
@property BOOL isBeta;
@end

#pragma mark - FirmwareInfo
@interface FirmwareInfo : BasicVersionInfo
@property NSString *minBootloaderVersion;
@end

#pragma mark - BootloaderInfo
@interface BootloaderInfo : BasicVersionInfo
@end


#pragma mark - ReleasesParser
@interface ReleasesParser : NSObject

+ (NSDictionary *)parse:(NSData *)data;

@end
