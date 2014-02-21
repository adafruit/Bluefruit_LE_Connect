//
//  UARTPeripheral.m
//  nRF UART
//
//  Created by Ole Morten on 1/12/13.
//  Copyright (c) 2013 Nordic Semiconductor. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "UARTPeripheral.h"
#import "CBUUID+StringExtraction.h"

@interface UARTPeripheral ()
@property CBService *uartService;
@property CBCharacteristic *rxCharacteristic;
@property CBCharacteristic *txCharacteristic;

@end

@implementation UARTPeripheral
@synthesize peripheral = _peripheral;
@synthesize delegate = _delegate;

@synthesize uartService = _uartService;
@synthesize rxCharacteristic = _rxCharacteristic;
@synthesize txCharacteristic = _txCharacteristic;


#pragma mark - UUID Retrieval


+ (CBUUID*)uartServiceUUID{
    
    return [CBUUID UUIDWithString:@"6e400001-b5a3-f393-e0a9-e50e24dcca9e"];
}


+ (CBUUID*)txCharacteristicUUID{
    
    return [CBUUID UUIDWithString:@"6e400002-b5a3-f393-e0a9-e50e24dcca9e"];
}


+ (CBUUID*)rxCharacteristicUUID{
    
    return [CBUUID UUIDWithString:@"6e400003-b5a3-f393-e0a9-e50e24dcca9e"];
}


+ (CBUUID*)deviceInformationServiceUUID{
    
    return [CBUUID UUIDWithString:@"180A"];
}


+ (CBUUID*)hardwareRevisionStringUUID{
    
    return [CBUUID UUIDWithString:@"2A27"];
}


#pragma mark - Utility methods


- (UARTPeripheral*)initWithPeripheral:(CBPeripheral*)peripheral delegate:(id<UARTPeripheralDelegate>) delegate{
    
    if (self = [super init]){
        self.peripheral = peripheral;
        self.peripheral.delegate = self;
        self.delegate = delegate;
    }
    return self;
}


- (void)didConnect{
    
    if(_peripheral.services){
        printf("Skipping service discovery for %s\r\n", [_peripheral.name UTF8String]);
        [self peripheral:_peripheral didDiscoverServices:nil]; //already discovered services, DO NOT re-discover. Just pass along the peripheral.
        return;
    }
    
    printf("Starting service discovery for %s\r\n", [_peripheral.name UTF8String]);
    
    [_peripheral discoverServices:@[self.class.uartServiceUUID, self.class.deviceInformationServiceUUID]];
    
}


- (void)didDisconnect{
    
}


- (void)writeString:(NSString*)string{
    
    NSData *data = [NSData dataWithBytes:string.UTF8String length:string.length];
    
    [self writeRawData:data];
}


- (void)writeRawData:(NSData*)data{
    
//    NSLog(@"writeRawData:");
    
    if ((self.txCharacteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) != 0){
        
        [self.peripheral writeValue:data forCharacteristic:self.txCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
    else if ((self.txCharacteristic.properties & CBCharacteristicPropertyWrite) != 0){
        [self.peripheral writeValue:data forCharacteristic:self.txCharacteristic type:CBCharacteristicWriteWithResponse];
    }
    else{
        NSLog(@"No write property on TX characteristic, %d.", self.txCharacteristic.properties);
    }
    
}


- (BOOL)compareID:(CBUUID*)firstID toID:(CBUUID*)secondID{
    
    if ([[firstID representativeString] compare:[secondID representativeString]] == NSOrderedSame) {
        return YES;
    }
    
    else
        return NO;
    
}


- (void)setupPeripheralForUse:(CBPeripheral*)peripheral{
    
    printf("Set up peripheral for use");
    
    for (CBService *s in peripheral.services) {
        
        for (CBCharacteristic *c in [s characteristics]){
            
            if ([self compareID:c.UUID toID:self.class.rxCharacteristicUUID]){
                
                printf("Found RX characteristic\r\n");
                self.rxCharacteristic = c;
                
                [self.peripheral setNotifyValue:YES forCharacteristic:self.rxCharacteristic];
            }
            
            else if ([self compareID:c.UUID toID:self.class.txCharacteristicUUID]){
                
                printf("Found TX characteristic\r\n");
                self.txCharacteristic = c;
            }
            
            else if ([self compareID:c.UUID toID:self.class.hardwareRevisionStringUUID]){
                
                printf("Found Hardware Revision String characteristic\r\n");
                [self.peripheral readValueForCharacteristic:c];
                
                //HW characteristic is last to be discovered, notify delegate we're all set
                [_delegate uartDidConnect];
                
            }
            
        }

    }
    
}


#pragma mark - CBPeripheral Delegate methods


- (void)peripheral:(CBPeripheral*)peripheral didDiscoverServices:(NSError*)error{
    
    printf("Did Discover Services\r\n");
    
    if (!error) {
        
        for (CBService *s in [peripheral services]){
            
            if (s.characteristics){
                [self peripheral:peripheral didDiscoverCharacteristicsForService:s error:nil]; //already discovered characteristic before, DO NOT do it again
            }
            
            else if ([self compareID:s.UUID toID:self.class.uartServiceUUID]){
                
                printf("Found correct service\r\n");
                
                self.uartService = s;
                
                [self.peripheral discoverCharacteristics:@[self.class.txCharacteristicUUID, self.class.rxCharacteristicUUID] forService:self.uartService];
            }
            
            else if ([self compareID:s.UUID toID:self.class.deviceInformationServiceUUID]){
                
                [self.peripheral discoverCharacteristics:@[self.class.hardwareRevisionStringUUID] forService:s];
            }
        }
    }
    
    else{
        
        printf("Error discovering services\r\n");
        
        [_delegate uartDidEncounterError:@"Error discovering services"];
        
        return;
    }
    
}


- (void)peripheral:(CBPeripheral*)peripheral didDiscoverCharacteristicsForService:(CBService*)service error:(NSError*)error{
    
//    NSLog(@"Did Discover Characteristics");
    
    if (!error){
        
        CBService *s = [peripheral.services objectAtIndex:(peripheral.services.count - 1)];
        if([self compareID:service.UUID toID:s.UUID]){
            
            //last service discovered
            printf("Found all characteristics\r\n");
            
            [self setupPeripheralForUse:peripheral];
            
        }
        
    }
    
    else{
        
        printf("Error discovering characteristics: %s\r\n", [error.description UTF8String]);
        
        [_delegate uartDidEncounterError:@"Error discovering characteristics"];
        
        return;
    }
    
}


- (void)peripheral:(CBPeripheral*)peripheral didUpdateValueForCharacteristic:(CBCharacteristic*)characteristic error:(NSError*)error{
    
//    NSLog(@"Received data on a characteristic.");
    

    if (!error){
        if (characteristic == self.rxCharacteristic){
            
            [self.delegate didReceiveData:[characteristic value]];
        }
        
        else if ([self compareID:characteristic.UUID toID:self.class.hardwareRevisionStringUUID]){
            
            NSString *hwRevision = @"";
            const uint8_t *bytes = characteristic.value.bytes;
            for (int i = 0; i < characteristic.value.length; i++){
                
                hwRevision = [hwRevision stringByAppendingFormat:@"0x%x, ", bytes[i]];
            }
            
            [self.delegate didReadHardwareRevisionString:[hwRevision substringToIndex:hwRevision.length-2]];
        }
    }
    
    else{
        
        printf("Error receiving notification for characteristic %s: %s\r\n", [characteristic.description UTF8String], [error.description UTF8String]);
        
        [_delegate uartDidEncounterError:@"Error receiving notification for characteristic"];
        
        return;
    }
    
}


@end
