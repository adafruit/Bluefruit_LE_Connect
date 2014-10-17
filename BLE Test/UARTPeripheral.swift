//
//  UARTPeripheral.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/12/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import CoreBluetooth

@objc protocol UARTPeripheralDelegate: Any {
    
    func didReceiveData(newData:NSData)
    func didReadSoftwareRevisionString(string:NSString)
    func uartDidEncounterError(error:NSString)
    
}

class UARTPeripheral: NSObject, CBPeripheralDelegate {
    
    var currentPeripheral:CBPeripheral!
    var delegate:UARTPeripheralDelegate!
    var uartService:CBService?
    var rxCharacteristic:CBCharacteristic?
    var txCharacteristic:CBCharacteristic?
    
    
    //MARK: UUID Retrieval
    
    class func uartServiceUUID()->CBUUID{
    
        return CBUUID.UUIDWithString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
        
    }
    
    
    class func txCharacteristicUUID()->CBUUID{
    
        return CBUUID.UUIDWithString("6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    }
    
    
    class func rxCharacteristicUUID()->CBUUID{
    
        return CBUUID.UUIDWithString("6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    }
    
    
    class func deviceInformationServiceUUID()->CBUUID{
    
        return CBUUID.UUIDWithString("180A")
    }
    
    
    class func hardwareRevisionStringUUID()->CBUUID{
    
        return CBUUID.UUIDWithString("2A27")
    }
    
    
    class func manufacturerNameStringUUID()->CBUUID{    //    Manufacturer Name String	0x2A29
        
        return CBUUID.UUIDWithString("2A29")
    }
    
    
    class func modelNumberStringUUID()->CBUUID{         //    Model Number String		0x2A24
        
        return CBUUID.UUIDWithString("2A24")
    }
    
    
    class func firmwareRevisionStringUUID()->CBUUID{    //    Firmware Revision String	0x2A26
        
        return CBUUID.UUIDWithString("2A26")
    }
    
    
    class func softwareRevisionStringUUID()->CBUUID{    //    Software Revision String  0x2A28
        
        return CBUUID.UUIDWithString("2A28")
    }
    
    
    //MARK: Utility methods
    
    init(peripheral:CBPeripheral, delegate:UARTPeripheralDelegate){
        
        super.init()
        
        self.currentPeripheral = peripheral
        self.currentPeripheral.delegate = self
        self.delegate = delegate
    
    }
    
    
    func didConnect() {
    
    //Respond to peripheral connection
    
        if currentPeripheral.services != nil{
            println("Skipping service discovery for \(currentPeripheral.name.utf8)")
            peripheral(currentPeripheral, didDiscoverServices: nil)  //already discovered services, DO NOT re-discover. Just pass along the peripheral.
            return
        }
    
        println("Starting service discovery for \(currentPeripheral.name.utf8)")

        currentPeripheral.discoverServices([UARTPeripheral.uartServiceUUID(), UARTPeripheral.deviceInformationServiceUUID()])
//        currentPeripheral.discoverServices(nil)
    
    }
    
    
    func didDisconnect() {
    
    //Respond to peripheral disconnection
    
    }
    
    
    func writeString(string:NSString){
    
    //Send string to peripheral
    
        let data = NSData(bytes: string.UTF8String, length: string.length)
        
        writeRawData(data)
    }
    
    
    func writeRawData(data:NSData) {
    
    //Send data to peripheral
        
        if (txCharacteristic == nil){
            println("WARNING: Unable to write data without txcharacteristic!")
            return
        }
    
        if (txCharacteristic!.properties.toRaw() & CBCharacteristicProperties.WriteWithoutResponse.toRaw()) != 0 {
            
            currentPeripheral.writeValue(data, forCharacteristic: self.txCharacteristic, type: CBCharacteristicWriteType.WithoutResponse)
        }
        
        else if ((txCharacteristic!.properties.toRaw() & CBCharacteristicProperties.Write.toRaw()) != 0){
            currentPeripheral.writeValue(data, forCharacteristic: txCharacteristic, type: CBCharacteristicWriteType.WithResponse)
        }
            
        else{
            println("No write property on TX characteristic, \(txCharacteristic!.properties)")
        }
    
    }
    
    
    func UUIDsAreEqual(firstID:CBUUID, _ secondID:CBUUID)->Bool {
        
        if firstID.representativeString() == secondID.representativeString() {
            return true
        }
            
        else {
            return false
        }
        
    }
    
    
    func setupPeripheralForUse(peripheral:CBPeripheral) {
        
        println("Set up peripheral for use")
        
        let services = peripheral.services as [CBService]
        
        for s in services {
            
            let characteristics = s.characteristics as [CBCharacteristic]
            
            for c in characteristics {
                
                if UUIDsAreEqual(c.UUID, UARTPeripheral.rxCharacteristicUUID()) {
                    
                    println("Found RX characteristic")
                    rxCharacteristic = c
                    peripheral.setNotifyValue(true, forCharacteristic: rxCharacteristic)
                    
                }
                    
                else if UUIDsAreEqual(c.UUID, UARTPeripheral.txCharacteristicUUID()) {
                    
                    println("Found TX characteristic")
                    txCharacteristic = c
                }
                    
                else if UUIDsAreEqual(c.UUID, UARTPeripheral.hardwareRevisionStringUUID()) {
                    
                    println("Found Hardware Revision String characteristic")
                    peripheral.readValueForCharacteristic(c)  //Once hardware revision string is read connection will be complete …
                    
                }
                
            }
            
        }
        
    }
    
    
    //MARK: CBPeripheral Delegate methods
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        
        //Respond to finding a new service on peripheral
        
        if error != nil {
            
            handleError("Error discovering services")
            
            return
        }
        
        println("Did Discover Services")
        
        
        let services = peripheral.services as [CBService]
        
        for s in services {
            
            if (s.characteristics != nil){
                
                self.peripheral(peripheral, didDiscoverCharacteristicsForService: s, error: nil)    // If characteristics have already been discovered, do not check again
                
            }
                
            else if UUIDsAreEqual(s.UUID, UARTPeripheral.uartServiceUUID()) {
                
                println("Found Service: UART")
                
                uartService = s
//                peripheral.discoverCharacteristics([UARTPeripheral.txCharacteristicUUID(), UARTPeripheral.rxCharacteristicUUID()], forService: uartService)
                peripheral.discoverCharacteristics(nil, forService: uartService)
                
            }
                
            else if UUIDsAreEqual(s.UUID, UARTPeripheral.deviceInformationServiceUUID()){
                
                println("Found Service: Device Information")
                
                peripheral.discoverCharacteristics(nil, forService: s)
            }
        }
        
    }
    
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        
        //Respond to finding a new characteristic on service
        
        if error != nil {
            handleError("Error discovering characteristics")
            
            return
        }
        
        println("Service \(service.description) has \(service.characteristics.count) characteristics")
        
//                if service.UUID == UARTPeripheral.deviceInformationServiceUUID() && service.characteristics.count == 0 {    //MARK: Hack for no HW Revision
//                    println("Device Information Service contains no characteristics, skipping HW Rev")
//                    delegate.didReadHardwareRevisionString("NONE")  //No HW Rev, connect anyway
//                }
        
        for c in (service.characteristics as [CBCharacteristic]) {
            
            switch c.UUID {
            case UARTPeripheral.rxCharacteristicUUID():         //"6e400003-b5a3-f393-e0a9-e50e24dcca9e"
                println("Found Characteristic: RX")
                rxCharacteristic = c
                currentPeripheral.setNotifyValue(true, forCharacteristic: rxCharacteristic)
                break
            case UARTPeripheral.txCharacteristicUUID():         //"6e400002-b5a3-f393-e0a9-e50e24dcca9e"
                println("Found Characteristic: TX")
                txCharacteristic = c
                break
            case UARTPeripheral.hardwareRevisionStringUUID():   //"2A27"
                println("Found Characteristic: Hardware Revision")
                currentPeripheral.readValueForCharacteristic(c)
                break
            case UARTPeripheral.manufacturerNameStringUUID():
                println("Found Characteristic: Manufacturer Name")
                currentPeripheral.readValueForCharacteristic(c)
                break
            case UARTPeripheral.modelNumberStringUUID():
                println("Found Characteristic: Model Number")
                currentPeripheral.readValueForCharacteristic(c)
                break
            case UARTPeripheral.firmwareRevisionStringUUID():
                println("Found Characteristic: Firmware Revision")
                currentPeripheral.readValueForCharacteristic(c)
                break
            case UARTPeripheral.softwareRevisionStringUUID():
                println("Found Characteristic: Software Revision")
                currentPeripheral.readValueForCharacteristic(c)
                break
            default:
                println("Found Characteristic: Unknown")
                break
            }
            
        }
        
    }
    
    
    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        
        //Respond to value change on peripheral
        
        if error != nil {
            handleError("Error receiving notification for characteristic\(characteristic.description.utf8): \(error.description.utf8)")
            return
        }
        
        if (characteristic == self.rxCharacteristic){
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.delegate.didReceiveData(characteristic.value)
            })
            
        }
            
        else if UUIDsAreEqual(characteristic.UUID, UARTPeripheral.softwareRevisionStringUUID()) {
            
            var swRevision = NSString(string: "")
            let bytes:UnsafePointer<Void> = characteristic.value.bytes
            //    const uint8_t *bytes = characteristic.value.bytes;
            
            for i in 0...characteristic.value.length {  //TODO: Check
                
                swRevision = NSString(format: "0x%x", UInt8(bytes[i]) ) //TODO: Check
            }
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.delegate.didReadSoftwareRevisionString(swRevision)
            })
        }
        
        
    }
    
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverIncludedServicesForService service: CBService!, error: NSError!) {
        
        //Respond to finding a new characteristic on service
        
        if error != nil {
            handleError("Error discovering included service characteristics")
            return
        }
        
        println("Included service: \(service.description) has \(service.includedServices.count) included services")
        
//        if service.characteristics.count == 0 {
//            currentPeripheral.discoverIncludedServices(nil, forService: service)
//        }
        
        for s in (service.includedServices as [CBService]) {
            
            println("   included service: \(s.description)")
        }
        
    }
    
    
    func handleError(errorString:String) {
        
        println(errorString)
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.delegate.uartDidEncounterError(errorString)
        })
        
    }
    
    
}