//
//  BLEPeripheral.swift
//  Adafruit Bluefruit LE Connect
//
//  Represents a connected peripheral
//
//  Created by Collin Cunningham on 10/29/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BLEPeripheralDelegate: Any {
    
    var connectionMode:ConnectionMode { get }
    func didReceiveData(newData:NSData)
    func connectionFinalized()
    func uartDidEncounterError(error:NSString)
    
}

class BLEPeripheral: NSObject, CBPeripheralDelegate {
    
    var currentPeripheral:CBPeripheral!
    var delegate:BLEPeripheralDelegate!
    var uartService:CBService?
    var rxCharacteristic:CBCharacteristic?
    var txCharacteristic:CBCharacteristic?
    var knownServices:[CBService] = []
    
    //MARK: Utility methods
    
    init(peripheral:CBPeripheral, delegate:BLEPeripheralDelegate){
        
        super.init()
        
        self.currentPeripheral = peripheral
        self.currentPeripheral.delegate = self
        self.delegate = delegate
    }
    
    
    func didConnect(withMode:ConnectionMode) {
        
        //Respond to peripheral connection
        
        //Already discovered services
        if currentPeripheral.services != nil{
            printLog(self, funcName: "didConnect", logString: "Skipping service discovery")
            peripheral(currentPeripheral, didDiscoverServices: nil)  //already discovered services, DO NOT re-discover. Just pass along the peripheral.
            return
        }
        
        printLog(self, funcName: "didConnect", logString: "Starting service discovery")
        
        switch withMode.rawValue {
        case ConnectionMode.UART.rawValue,
             ConnectionMode.PinIO.rawValue,
             ConnectionMode.Controller.rawValue,
            ConnectionMode.DFU.rawValue:
            currentPeripheral.discoverServices([uartServiceUUID(), dfuServiceUUID(), deviceInformationServiceUUID()])       // Discover dfu and dis (needed to check if update is available)
        case ConnectionMode.Info.rawValue:
            currentPeripheral.discoverServices(nil)
            break
        default:
            printLog(self, funcName: "didConnect", logString: "non-matching mode")
            break
        }
        
        //        currentPeripheral.discoverServices([BLEPeripheral.uartServiceUUID(), BLEPeripheral.deviceInformationServiceUUID()])
        //        currentPeripheral.discoverServices(nil)
        
    }
    
    
    func writeString(string:NSString){
        
        //Send string to peripheral
        
        let data = NSData(bytes: string.UTF8String, length: string.length)
        
        writeRawData(data)
    }
    
    
    func writeRawData(data:NSData) {
        
        //Send data to peripheral
        
        if (txCharacteristic == nil){
            printLog(self, funcName: "writeRawData", logString: "Unable to write data without txcharacteristic")
            return
        }
        
        var writeType:CBCharacteristicWriteType
        
        if (txCharacteristic!.properties.rawValue & CBCharacteristicProperties.WriteWithoutResponse.rawValue) != 0 {
            
            writeType = CBCharacteristicWriteType.WithoutResponse
            
        }
            
        else if ((txCharacteristic!.properties.rawValue & CBCharacteristicProperties.Write.rawValue) != 0){
            
            writeType = CBCharacteristicWriteType.WithResponse
        }
            
        else{
            printLog(self, funcName: "writeRawData", logString: "Unable to write data without characteristic write property")
            return
        }
        
        //TODO: Test packetization
        
        //send data in lengths of <= 20 bytes
        let dataLength = data.length
        let limit = 20
        
        //Below limit, send as-is
        if dataLength <= limit {
            currentPeripheral.writeValue(data, forCharacteristic: txCharacteristic!, type: writeType)
        }
            
            //Above limit, send in lengths <= 20 bytes
        else {
            
            var len = limit
            var loc = 0
            var idx = 0 //for debug
            
            while loc < dataLength {
                
                let rmdr = dataLength - loc
                if rmdr <= len {
                    len = rmdr
                }
                
                let range = NSMakeRange(loc, len)
                var newBytes = [UInt8](count: len, repeatedValue: 0)
                data.getBytes(&newBytes, range: range)
                let newData = NSData(bytes: newBytes, length: len)
                //                    println("\(self.classForCoder.description()) writeRawData : packet_\(idx) : \(newData.hexRepresentationWithSpaces(true))")
                self.currentPeripheral.writeValue(newData, forCharacteristic: self.txCharacteristic!, type: writeType)
                
                loc += len
                idx += 1
            }
        }
        
    }
    
    
    //MARK: CBPeripheral Delegate methods
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        //Respond to finding a new service on peripheral
        
        if error != nil {
            
//            handleError("\(self.classForCoder.description()) didDiscoverServices : Error discovering services")
            printLog(self, funcName: "didDiscoverServices", logString: "\(error.debugDescription)")
            
            return
        }
        
        //        println("\(self.classForCoder.description()) didDiscoverServices")
        
        
        let services = peripheral.services as [CBService]!
        
        for s in services {
            
            // Service characteristics already discovered
            if (s.characteristics != nil){
                self.peripheral(peripheral, didDiscoverCharacteristicsForService: s, error: nil)    // If characteristics have already been discovered, do not check again
            }
                
            //UART, Pin I/O, or Controller mode
            else if delegate.connectionMode == ConnectionMode.UART ||
                    delegate.connectionMode == ConnectionMode.PinIO ||
                    delegate.connectionMode == ConnectionMode.Controller ||
                    delegate.connectionMode == ConnectionMode.DFU {
                if UUIDsAreEqual(s.UUID, secondID: uartServiceUUID()) {
                    uartService = s
                    peripheral.discoverCharacteristics([txCharacteristicUUID(), rxCharacteristicUUID()], forService: uartService!)
                }
            }
                
            // Info mode
            else if delegate.connectionMode == ConnectionMode.Info {
                knownServices.append(s)
                peripheral.discoverCharacteristics(nil, forService: s)
            }
            
            //DFU / Firmware Updater mode
            else if delegate.connectionMode == ConnectionMode.DFU {
                knownServices.append(s)
                peripheral.discoverCharacteristics(nil, forService: s)
            }
            
        }
        
        printLog(self, funcName: "didDiscoverServices", logString: "all top-level services discovered")
        
    }
    
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        //Respond to finding a new characteristic on service
        
        if error != nil {
//            handleError("Error discovering characteristics")
            printLog(self, funcName: "didDiscoverCharacteristicsForService", logString: "\(error.debugDescription)")
            
            return
        }
        
        printLog(self, funcName: "didDiscoverCharacteristicsForService", logString: "\(service.description) with \(service.characteristics!.count) characteristics")
        
        // UART mode
        if  delegate.connectionMode == ConnectionMode.UART ||
            delegate.connectionMode == ConnectionMode.PinIO ||
            delegate.connectionMode == ConnectionMode.Controller ||
            delegate.connectionMode == ConnectionMode.DFU {
            
            for c in (service.characteristics as [CBCharacteristic]!) {
                
                switch c.UUID {
                case rxCharacteristicUUID():         //"6e400003-b5a3-f393-e0a9-e50e24dcca9e"
                    printLog(self, funcName: "didDiscoverCharacteristicsForService", logString: "\(service.description) : RX")
                    rxCharacteristic = c
                    currentPeripheral.setNotifyValue(true, forCharacteristic: rxCharacteristic!)
                    break
                case txCharacteristicUUID():         //"6e400002-b5a3-f393-e0a9-e50e24dcca9e"
                    printLog(self, funcName: "didDiscoverCharacteristicsForService", logString: "\(service.description) : TX")
                    txCharacteristic = c
                    break
                default:
//                    printLog(self, "didDiscoverCharacteristicsForService", "Found Characteristic: Unknown")
                    break
                }
                
            }
            
            if rxCharacteristic != nil && txCharacteristic != nil {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.delegate.connectionFinalized()
                })
            }
        }
        
        // Info mode
        else if delegate.connectionMode == ConnectionMode.Info {
            
            for c in (service.characteristics as [CBCharacteristic]!) {
                
                //Read readable characteristic values
                if (c.properties.rawValue & CBCharacteristicProperties.Read.rawValue) != 0 {
                    peripheral.readValueForCharacteristic(c)
                }
                
                peripheral.discoverDescriptorsForCharacteristic(c)
                
            }
            
        }
        
    }
    
    
    func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        if error != nil {
//            handleError("Error discovering descriptors \(error.debugDescription)")
            printLog(self, funcName: "didDiscoverDescriptorsForCharacteristic", logString: "\(error.debugDescription)")
//            return
        }
        
        else {
            if characteristic.descriptors?.count != 0 {
                for d in characteristic.descriptors! {
                    let desc = d as CBDescriptor!
                    printLog(self, funcName: "didDiscoverDescriptorsForCharacteristic", logString: "\(desc.description)")
                    
//                    currentPeripheral.readValueForDescriptor(desc)
                }
            }

        }
        
        
        //Check if all characteristics were discovered
        var allCharacteristics:[CBCharacteristic] = []
        for s in knownServices {
            for c in s.characteristics! {
                allCharacteristics.append(c as CBCharacteristic!)
            }
        }
        for idx in 0...(allCharacteristics.count-1) {
            if allCharacteristics[idx] === characteristic {
//                println("found characteristic index \(idx)")
                if (idx + 1) == allCharacteristics.count {
//                    println("found last characteristic")
                    if delegate.connectionMode == ConnectionMode.Info {
                        delegate.connectionFinalized()
                    }
                }
            }
        }

        
    }
    
    
//    func peripheral(peripheral: CBPeripheral!, didUpdateValueForDescriptor descriptor: CBDescriptor!, error: NSError!) {
//        
//        if error != nil {
////            handleError("Error reading descriptor value \(error.debugDescription)")
//            printLog(self, "didUpdateValueForDescriptor", "\(error.debugDescription)")
////            return
//        }
//        
//        else {
//            println("descriptor value = \(descriptor.value)")
//            println("descriptor description = \(descriptor.description)")
//        }
//        
//    }
    
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        //Respond to value change on peripheral
        
        if error != nil {
//            handleError("Error updating value for characteristic\(characteristic.description.utf8) \(error.description.utf8)")
            printLog(self, funcName: "didUpdateValueForCharacteristic", logString: "\(error.debugDescription)")
            return
        }
        
        //UART mode
        if delegate.connectionMode == ConnectionMode.UART || delegate.connectionMode == ConnectionMode.PinIO || delegate.connectionMode == ConnectionMode.Controller {
            
            if (characteristic == self.rxCharacteristic){
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.delegate.didReceiveData(characteristic.value!)
                })
                
            }
                //TODO: Finalize for info mode
            else if UUIDsAreEqual(characteristic.UUID, secondID: softwareRevisionStringUUID()) {
                
//                var swRevision = NSString(string: "")
//                let bytes:UnsafePointer<Void> = characteristic.value!.bytes
//                for i in 0...characteristic.value!.length {
//                    
//                    swRevision = NSString(format: "0x%x", UInt8(bytes[i]) )
//                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.delegate.connectionFinalized()
                })
            }
            
        }
        
        
    }
    
    
    func peripheral(peripheral: CBPeripheral, didDiscoverIncludedServicesForService service: CBService, error: NSError?) {
        
        //Respond to finding a new characteristic on service
        
        if error != nil {
            printLog(self, funcName: "didDiscoverIncludedServicesForService", logString: "\(error.debugDescription)")
            return
        }
        
        printLog(self, funcName: "didDiscoverIncludedServicesForService", logString: "service: \(service.description) has \(service.includedServices?.count) included services")
        
        //        if service.characteristics.count == 0 {
        //            currentPeripheral.discoverIncludedServices(nil, forService: service)
        //        }
        
        for s in (service.includedServices as [CBService]!) {
            
            printLog(self, funcName: "didDiscoverIncludedServicesForService", logString: "\(s.description)")
        }
        
    }
    
    
    func handleError(errorString:String) {
        
        printLog(self, funcName: "Error", logString: "\(errorString)")
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.delegate.uartDidEncounterError(errorString)
        })
        
    }
    
    
}
