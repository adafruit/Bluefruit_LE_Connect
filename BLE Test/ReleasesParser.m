//
//  ReleasesParser.m
//  BluefruitUpdater
//
//  Created by Antonio García on 16/04/15.
//  Copyright (C) 2015 Adafruit Industries (www.adafruit.com)
//

#import "ReleasesParser.h"
#import "LogHelper.h"
#import "XMLDictionary.h"
#import "Utility.h"

#pragma mark - BoardInfo
@implementation BoardInfo
-(id)init {
    if ( self = [super init] ) {
        _firmwareReleases = [NSMutableArray array];
        _bootloaderReleases = [NSMutableArray array];
    }
    return self;
}

@end

#pragma mark - BasicVersionInfo
@implementation BasicVersionInfo
@end

#pragma mark - FirmwareInfo
@implementation FirmwareInfo
@end

#pragma mark - BootloaderInfo
@implementation BootloaderInfo
@end


#pragma mark - ReleasesParser
@interface ReleasesParser () <NSXMLParserDelegate>
{
}
@end

@implementation ReleasesParser

+ (NSDictionary *)parse:(NSData *)data
{
    NSMutableDictionary *boardsReleases =  [NSMutableDictionary dictionary];
    
    @try
    {
        XMLDictionaryParser *xmlDicionary = [[XMLDictionaryParser alloc] init];
        NSDictionary *releasesDictionary = [xmlDicionary dictionaryWithData:data];
        
        NSArray *boardsArray = [[releasesDictionary objectForKey:@"boards"] objectForKey:@"board"];

        for (NSDictionary *boardDictionary in boardsArray) {
            NSString *boardName = [boardDictionary objectForKey:@"_name"];
            
            BoardInfo *boardInfo = [BoardInfo new];
            [boardsReleases setObject:boardInfo forKey:boardName];
            
            // Read firmware releases
            id firmwareNodes = [[boardDictionary objectForKey:@"firmware"] objectForKey:@"firmwarerelease"];
            if ([firmwareNodes isKindOfClass:[NSArray class]])
            {
                for (NSDictionary *firmwareNode in firmwareNodes)
                {
                    FirmwareInfo *releaseInfo = [self parseFirmwareNode:firmwareNode boardName:boardName];
                    [boardInfo.firmwareReleases addObject:releaseInfo];
                }
            }
            else        // Special case for only 1 firmwarerelease
            {
                FirmwareInfo *releaseInfo = [self parseFirmwareNode:firmwareNodes boardName:boardName];
                [boardInfo.firmwareReleases addObject:releaseInfo];
                
            }
            
            // Read bootloader releases
            id bootloaderNodes = [[boardDictionary objectForKey:@"bootloader"] objectForKey:@"bootloaderrelease"];
            if ([bootloaderNodes isKindOfClass:[NSArray class]])
            {
                for (NSDictionary *bootloaderNode in bootloaderNodes)
                {
                    BootloaderInfo *bootloaderInfo = [self parseBootloaderNode:bootloaderNode boardName:boardName];
                    [boardInfo.bootloaderReleases addObject:bootloaderInfo];
                }
            }
            else        // Special case for only 1 bootloaderrelease
            {
                BootloaderInfo *bootloaderInfo = [self parseBootloaderNode:bootloaderNodes boardName:boardName];
                [boardInfo.bootloaderReleases addObject:bootloaderInfo];
                
            }

        }
        
    }@catch(NSException *e) {
        DLog(@"Error parsing releases.xml");
    }
    
    
    return boardsReleases;
}

+ (FirmwareInfo *)parseFirmwareNode:(NSDictionary *)firmwareNode boardName:(NSString *)boardName
{
    FirmwareInfo *releaseInfo = [FirmwareInfo new];
    releaseInfo.fileType = APPLICATION;
    releaseInfo.version =[firmwareNode objectForKey:@"_version"];
    releaseInfo.hexFileUrl =[firmwareNode objectForKey:@"_hexfile"];
    releaseInfo.iniFileUrl =[firmwareNode objectForKey:@"_initfile"];
    releaseInfo.minBootloaderVersion = [firmwareNode objectForKey:@"_minbootloader"];
    releaseInfo.boardName = boardName;

    return releaseInfo;
}

+ (BootloaderInfo *)parseBootloaderNode:(NSDictionary *)bootloaderNode boardName:(NSString *)boardName
{
    BootloaderInfo *bootloaderInfo = [BootloaderInfo new];
    bootloaderInfo.fileType = BOOTLOADER;
    bootloaderInfo.version = [bootloaderNode objectForKey:@"_version"];
    bootloaderInfo.hexFileUrl =[bootloaderNode objectForKey:@"_hexfile"];
    bootloaderInfo.iniFileUrl =[bootloaderNode objectForKey:@"_initfile"];
    bootloaderInfo.boardName = boardName;

    return bootloaderInfo;
}

@end

