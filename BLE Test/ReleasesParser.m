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
            
            //
            // Firmwares
            //
            id firmwareParentNode = [boardDictionary objectForKey:@"firmware"];

            // Read firmware releases
            {
                id firmwareNodes = [firmwareParentNode objectForKey:@"firmwarerelease"];
                if (firmwareNodes) {
                    if ([firmwareNodes isKindOfClass:[NSArray class]])
                    {
                        for (NSDictionary *firmwareNode in firmwareNodes)
                        {
                            FirmwareInfo *releaseInfo = [self parseFirmwareNode:firmwareNode boardName:boardName isBeta:NO];
                            [boardInfo.firmwareReleases addObject:releaseInfo];
                        }
                    }
                    else        // Special case for only 1 firmwarerelease
                    {
                        FirmwareInfo *releaseInfo = [self parseFirmwareNode:firmwareNodes boardName:boardName isBeta:NO];
                        [boardInfo.firmwareReleases addObject:releaseInfo];
                        
                    }
                }
            }
            
            // Read beta firmware releases
            const BOOL showBetaReleases = [[NSUserDefaults standardUserDefaults] boolForKey:@"betareleases_preference"];
            if (showBetaReleases)
            {
                id firmwareNodes = [firmwareParentNode objectForKey:@"firmwarebeta"];
                if (firmwareNodes) {
                    if ([firmwareNodes isKindOfClass:[NSArray class]])
                    {
                        for (NSDictionary *firmwareNode in firmwareNodes)
                        {
                            FirmwareInfo *releaseInfo = [self parseFirmwareNode:firmwareNode boardName:boardName isBeta:YES];
                            [boardInfo.firmwareReleases addObject:releaseInfo];
                        }
                    }
                    else        // Special case for only 1 firmwarerelease
                    {
                        FirmwareInfo *releaseInfo = [self parseFirmwareNode:firmwareNodes boardName:boardName isBeta:YES];
                        [boardInfo.firmwareReleases addObject:releaseInfo];
                        
                    }
                }
            }
            
            // Sort based on version (descending)
            [boardInfo.firmwareReleases sortUsingComparator:^NSComparisonResult(FirmwareInfo *obj1, FirmwareInfo *obj2) {
                return -[obj1.version compare:obj2.version options:NSNumericSearch];
            }];


            //
            // Booloaders
            //
            id bootloaderParentNode = [boardDictionary objectForKey:@"bootloader"];

            // Read bootloader releases
            {
                id bootloaderNodes = [bootloaderParentNode objectForKey:@"bootloaderrelease"];
                if (bootloaderNodes) {
                    if ([bootloaderNodes isKindOfClass:[NSArray class]])
                    {
                        for (NSDictionary *bootloaderNode in bootloaderNodes)
                        {
                            BootloaderInfo *bootloaderInfo = [self parseBootloaderNode:bootloaderNode boardName:boardName isBeta:NO];
                            [boardInfo.bootloaderReleases addObject:bootloaderInfo];
                        }
                    }
                    else        // Special case for only 1 bootloaderrelease
                    {
                        BootloaderInfo *bootloaderInfo = [self parseBootloaderNode:bootloaderNodes boardName:boardName isBeta:NO];
                        [boardInfo.bootloaderReleases addObject:bootloaderInfo];
                    }
                }
            }
            
            // Read bootloader releases
            if (showBetaReleases)
            {
                id bootloaderNodes = [bootloaderParentNode objectForKey:@"bootloaderbeta"];
                if (bootloaderNodes) {
                    if ([bootloaderNodes isKindOfClass:[NSArray class]])
                    {
                        for (NSDictionary *bootloaderNode in bootloaderNodes)
                        {
                            BootloaderInfo *bootloaderInfo = [self parseBootloaderNode:bootloaderNode boardName:boardName isBeta:YES];
                            [boardInfo.bootloaderReleases addObject:bootloaderInfo];
                        }
                    }
                    else        // Special case for only 1 bootloaderrelease
                    {
                        BootloaderInfo *bootloaderInfo = [self parseBootloaderNode:bootloaderNodes boardName:boardName isBeta:YES];
                        [boardInfo.bootloaderReleases addObject:bootloaderInfo];
                    }
                }
            }

            // Sort based on version (descending)
            [boardInfo.bootloaderReleases sortUsingComparator:^NSComparisonResult(BootloaderInfo *obj1, BootloaderInfo *obj2) {
                return -[obj1.version compare:obj2.version options:NSNumericSearch];
            }];

        }
    
        
    }@catch(NSException *e) {
        DLog(@"Error parsing releases.xml");
    }
    
    
    return boardsReleases;
}

+ (FirmwareInfo *)parseFirmwareNode:(NSDictionary *)firmwareReleaseNode boardName:(NSString *)boardName isBeta:(BOOL)isBeta
{
    FirmwareInfo *releaseInfo = [FirmwareInfo new];
    releaseInfo.fileType = APPLICATION;
    releaseInfo.version =[firmwareReleaseNode objectForKey:@"_version"];
    releaseInfo.hexFileUrl =[firmwareReleaseNode objectForKey:@"_hexfile"];
    releaseInfo.iniFileUrl =[firmwareReleaseNode objectForKey:@"_initfile"];
    releaseInfo.minBootloaderVersion = [firmwareReleaseNode objectForKey:@"_minbootloader"];
    releaseInfo.boardName = boardName;
    releaseInfo.isBeta = isBeta;

    return releaseInfo;
}

+ (BootloaderInfo *)parseBootloaderNode:(NSDictionary *)bootloaderNode boardName:(NSString *)boardName isBeta:(BOOL)isBeta
{
    BootloaderInfo *bootloaderInfo = [BootloaderInfo new];
    bootloaderInfo.fileType = BOOTLOADER;
    bootloaderInfo.version = [bootloaderNode objectForKey:@"_version"];
    bootloaderInfo.hexFileUrl =[bootloaderNode objectForKey:@"_hexfile"];
    bootloaderInfo.iniFileUrl =[bootloaderNode objectForKey:@"_initfile"];
    bootloaderInfo.boardName = boardName;
    bootloaderInfo.isBeta = isBeta;

    return bootloaderInfo;
}

@end

