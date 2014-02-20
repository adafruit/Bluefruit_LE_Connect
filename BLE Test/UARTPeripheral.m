//
//  UARTPeripheral.m
//  nRF UART
//
//  Created by Ole Morten on 1/12/13.
//  Copyright (c) 2013 Nordic Semiconductor. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "UARTPeripheral.h"

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


+ (CBUUID *) uartServiceUUID{
    
    return [CBUUID UUIDWithString:@"6e400001-b5a3-f393-e0a9-e50e24dcca9e"];
}


+ (CBUUID *) txCharacteristicUUID{
    
    return [CBUUID UUIDWithString:@"6e400002-b5a3-f393-e0a9-e50e24dcca9e"];
}


+ (CBUUID *) rxCharacteristicUUID{
    
    return [CBUUID UUIDWithString:@"6e400003-b5a3-f393-e0a9-e50e24dcca9e"];
}


+ (CBUUID *) deviceInformationServiceUUID{
    
    return [CBUUID UUIDWithString:@"180A"];
}


+ (CBUUID *) hardwareRevisionStringUUID{
    
    return [CBUUID UUIDWithString:@"2A27"];
}


- (UARTPeripheral*)initWithPeripheral:(CBPeripheral*)peripheral delegate:(id<UARTPeripheralDelegate>) delegate{
    
    if (self = [super init])
    {
        _peripheral = peripheral;
        _peripheral.delegate = self;
        _delegate = delegate;
    }
    return self;
}


- (void) didConnect{
    
    [_peripheral discoverServices:@[self.class.uartServiceUUID, self.class.deviceInformationServiceUUID]];
    NSLog(@"Did start service discovery.");
}


- (void) didDisconnect{
    
}


- (void) writeString:(NSString*)string{
    
    NSData *data = [NSData dataWithBytes:string.UTF8String length:string.length];
    
    [self writeRawData:data];
}


- (void) writeRawData:(NSData*)data{
    
//    NSLog(@"writeRawData:");
    
    if ((self.txCharacteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) != 0)
    {
        [self.peripheral writeValue:data forCharacteristic:self.txCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
    else if ((self.txCharacteristic.properties & CBCharacteristicPropertyWrite) != 0)
    {
        [self.peripheral writeValue:data forCharacteristic:self.txCharacteristic type:CBCharacteristicWriteWithResponse];
    }
    else
    {
        NSLog(@"No write property on TX characteristic, %d.", self.txCharacteristic.properties);
    }
    
}


- (void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError*)error{
    
    if (error)
    {
        NSLog(@"Error discovering services: %@", error);
        
        [_delegate uartDidEncounterError:@"Error discovering services"];
        
        return;
    }
    
    for (CBService *s in [peripheral services])
    {
        if ([s.UUID isEqual:self.class.uartServiceUUID])
        {
            NSLog(@"Found correct service");
            self.uartService = s;
            
            [self.peripheral discoverCharacteristics:@[self.class.txCharacteristicUUID, self.class.rxCharacteristicUUID] forService:self.uartService];
        }
        else if ([s.UUID isEqual:self.class.deviceInformationServiceUUID])
        {
            [self.peripheral discoverCharacteristics:@[self.class.hardwareRevisionStringUUID] forService:s];
        }
    }
}


- (void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    
    if (error)
    {
        NSLog(@"Error discovering characteristics: %@", error);
        
        [_delegate uartDidEncounterError:@"Error discovering characteristics"];
        
        return;
    }
    
    for (CBCharacteristic *c in [service characteristics])
    {
        if ([c.UUID isEqual:self.class.rxCharacteristicUUID])
        {
            NSLog(@"Found RX characteristic");
            self.rxCharacteristic = c;
            
            [self.peripheral setNotifyValue:YES forCharacteristic:self.rxCharacteristic];
        }
        else if ([c.UUID isEqual:self.class.txCharacteristicUUID])
        {
            NSLog(@"Found TX characteristic");
            self.txCharacteristic = c;
        }
        else if ([c.UUID isEqual:self.class.hardwareRevisionStringUUID])
        {
            NSLog(@"Found Hardware Revision String characteristic");
            [self.peripheral readValueForCharacteristic:c];
            
            //HW characteristic is last to be discovered, notify delegate we're all set
            [_delegate uartDidConnect];
        }
    }
}


- (void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    
    if (error)
    {
        NSLog(@"Error receiving notification for characteristic %@: %@", characteristic, error);
        
        [_delegate uartDidEncounterError:@"Error receiving notification for characteristic"];
        
        return;
    }
    
    NSLog(@"Received data on a characteristic.");
    
    if (characteristic == self.rxCharacteristic)
    {
        [self.delegate didReceiveData:[characteristic value]];
    }
    else if ([characteristic.UUID isEqual:self.class.hardwareRevisionStringUUID])
    {
        NSString *hwRevision = @"";
        const uint8_t *bytes = characteristic.value.bytes;
        for (int i = 0; i < characteristic.value.length; i++)
        {
//            NSLog(@"%x", bytes[i]);
            hwRevision = [hwRevision stringByAppendingFormat:@"0x%02x, ", bytes[i]];
        }
        
        [self.delegate didReadHardwareRevisionString:[hwRevision substringToIndex:hwRevision.length-2]];
    }
}


@end
