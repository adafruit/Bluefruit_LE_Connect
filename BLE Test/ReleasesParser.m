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
            id firmwareNodes = [boardDictionary objectForKey:@"firmware"];  //check for multiple firmware entries
            NSArray *firmwareNodesArray;
            if ([firmwareNodes isKindOfClass:[NSArray class]]) {
//                DLog(@"MULTIPLE FIRMWARE ENTRIES");
                firmwareNodesArray = (NSArray*)firmwareNodes;
            }
            else {
//                DLog(@"SINGLE FIRMWARE ENTRY");
                firmwareNodesArray = [NSArray arrayWithObject:firmwareNodes];
            }
            
            for (NSDictionary *firmwareNode in firmwareNodesArray) {
                
                id firmwareReleaseNodes = [firmwareNode objectForKey:@"firmwarerelease"];    //parsing error on last?
                if ([firmwareReleaseNodes isKindOfClass:[NSArray class]])
                {
                    for (NSDictionary *firmwareReleaseNode in firmwareReleaseNodes)
                    {
                        FirmwareInfo *releaseInfo = [self parseFirmwareReleaseNode:firmwareReleaseNode boardName:boardName];
                        [boardInfo.firmwareReleases addObject:releaseInfo];
                    }
                }
                else        // Special case for only 1 firmwarerelease
                {
                    FirmwareInfo *releaseInfo = [self parseFirmwareReleaseNode:firmwareReleaseNodes boardName:boardName];
                    [boardInfo.firmwareReleases addObject:releaseInfo];
                    
                }
                
            }
            
            // Read bootloader releases
            id bootloaderNodes = [boardDictionary objectForKey:@"bootloader"];  //check for multiple bootloader entries
            NSArray *bootloaderNodesArray;
            if ([bootloaderNodes isKindOfClass:[NSArray class]]) {
//                DLog(@"MULTIPLE BOOTLOADER ENTRIES");
                bootloaderNodesArray = (NSArray*)bootloaderNodes;
            }
            else {
//                DLog(@"SINGLE BOOTLOADER ENTRY");
                bootloaderNodesArray = [NSArray arrayWithObject:bootloaderNodes];
            }
            
            for (NSDictionary * bootloaderNode in bootloaderNodesArray) {
                id bootloaderReleaseNodes = [bootloaderNode objectForKey:@"bootloaderrelease"];
                if ([bootloaderReleaseNodes isKindOfClass:[NSArray class]])
                {
//                DLog(@"Read bootloaderInfo");
                    for (NSDictionary *bootloaderNode in bootloaderReleaseNodes)
                    {
                        BootloaderInfo *bootloaderInfo = [self parseBootloaderNode:bootloaderNode boardName:boardName];
                        [boardInfo.bootloaderReleases addObject:bootloaderInfo];
                    }
                }
                else        // Special case for only 1 bootloaderrelease
                {
//                DLog(@"Read bootloaderInfo single");
                    BootloaderInfo *bootloaderInfo = [self parseBootloaderNode:bootloaderReleaseNodes boardName:boardName];
                    [boardInfo.bootloaderReleases addObject:bootloaderInfo];
                    
                }
            }

        }
        
    }@catch(NSException *e) {
        DLog(@"Error parsing releases.xml");
    }
    
    
    return boardsReleases;
}

+ (FirmwareInfo *)parseFirmwareReleaseNode:(NSDictionary *)firmwareReleaseNode boardName:(NSString *)boardName
{
    FirmwareInfo *releaseInfo = [FirmwareInfo new];
    releaseInfo.fileType = APPLICATION;
    releaseInfo.version =[firmwareReleaseNode objectForKey:@"_version"];
    releaseInfo.hexFileUrl =[firmwareReleaseNode objectForKey:@"_hexfile"];
    releaseInfo.iniFileUrl =[firmwareReleaseNode objectForKey:@"_initfile"];
    releaseInfo.minBootloaderVersion = [firmwareReleaseNode objectForKey:@"_minbootloader"];
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

