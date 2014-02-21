//
//  UARTPeripheral.h
//  nRF UART
//
//  Created by Ole Morten on 1/12/13.
//  Copyright (c) 2013 Nordic Semiconductor. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol UARTPeripheralDelegate

- (void) uartDidConnect;
- (void) didReceiveData:(NSData*)newData;

@optional

- (void) didReadHardwareRevisionString:(NSString*) string;
- (void) uartDidEncounterError:(NSString*) error;

@end


@interface UARTPeripheral : NSObject <CBPeripheralDelegate>

@property CBPeripheral *peripheral;
@property id<UARTPeripheralDelegate> delegate;

+ (CBUUID*)uartServiceUUID;
- (UARTPeripheral*)initWithPeripheral:(CBPeripheral*)peripheral delegate:(id<UARTPeripheralDelegate>) delegate;
- (void) writeString:(NSString*) string;
- (void) writeRawData:(NSData*)data;
- (void) didConnect;
- (void) didDisconnect;

@end
