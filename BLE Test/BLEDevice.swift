//
//  BLEDevice.swift
//  Adafruit Bluefruit LE Connect
//  
//  Used to represent an unconnected peripheral in scanning/discovery list
//
//  Created by Collin Cunningham on 10/17/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//


import Foundation
import CoreBluetooth

class BLEDevice {
    
    var peripheral: CBPeripheral!
    var isUART:Bool = false
//    var isDFU:Bool = false
    private var advertisementData: [NSObject : AnyObject]
    var RSSI:NSNumber {
        didSet {
            self.deviceCell?.updateSignalImage(RSSI)
        }
    }
    private let nilString = "nil"
    var connectableBool:Bool {
        let num = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber
        if num != nil {
            return num!.boolValue
        }
        else {
            return false
        }
    }
    var name:String = ""
    
    var deviceCell:DeviceCell? {
        didSet {
            deviceCell?.nameLabel.text = self.name
            deviceCell?.connectButton.hidden = !(self.connectableBool)
            deviceCell?.updateSignalImage(RSSI)
            deviceCell?.uartCapableLabel.hidden = !self.isUART
        }
    }
    
    var localName:String {
        var nameString = advertisementData[CBAdvertisementDataLocalNameKey] as? NSString
            if nameString == nil {
                nameString = nilString
            }
        return nameString! as String
    }
    
    var manufacturerData:String {
        let newData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? NSData
            if newData == nil {
                return nilString
            }
            let dataString = newData?.hexRepresentation()
            
            return dataString!
    }
    
    var serviceData:String {
        let dict = advertisementData[CBAdvertisementDataServiceDataKey] as? NSDictionary
            if dict == nil {
                return nilString
            }
            else {
                return dict!.description
            }
    }
    
    var serviceUUIDs:[String] {
        let svcIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? NSArray
            if svcIDs == nil {
                return [nilString]
            }
        return self.stringsFromUUIDs(svcIDs!)
    }
    
    var overflowServiceUUIDs:[String] {
        let ovfIDs = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? NSArray
            
            if ovfIDs == nil {
                return [nilString]
            }
        return self.stringsFromUUIDs(ovfIDs!)
    }
    
    var txPowerLevel:String {
        let txNum = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
            if txNum == nil {
                return nilString
            }
        return txNum!.stringValue
    }
    
    var isConnectable:String {
        let num = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber
            if num == nil {
                return nilString
            }
            let verdict = num!.boolValue
        
        //Enable connect button according to connectable value
        if self.deviceCell?.connectButton != nil {
            deviceCell?.connectButton.enabled = verdict
        }
            
            return verdict.description
    }
    
    var solicitedServiceUUIDs:[String] {
        let ssIDs = advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? NSArray
            
            if ssIDs == nil {
                return [nilString]
            }
            
            return self.stringsFromUUIDs(ssIDs!)
    }
    
    var RSSString:String {
        return RSSI.stringValue
    }
    
    var identifier:NSUUID? {
        if self.peripheral == nil {
            printLog(self, funcName: "identifier", logString: "attempting to retrieve peripheral ID before peripheral set")
            return nil
        }
        else {
            return self.peripheral.identifier
        }
    }
    
    var UUIDString:String {
        let str = self.identifier?.UUIDString
        if str != nil {
            return str!
        }
        else {
            return nilString
        }
    }
    
    var advertisementArray:[[String]] = []
    

    init(peripheral:CBPeripheral!, advertisementData:[NSObject : AnyObject]!, RSSI:NSNumber!) {
        
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.RSSI = RSSI
        
        var array:[[String]] = []
        var entry:[String] = ["Local Name", self.localName]
        if entry[1] != nilString {
            array.append(entry)
        }
        
//        entry = ["UUID", UUIDString]
//        if entry[1] != nilString { array.append(entry) }
        
        entry = ["Manufacturer Data", manufacturerData]
        if entry[1] != nilString { array.append(entry) }
        entry = ["Service Data", serviceData]
        if entry[1] != nilString { array.append(entry) }
        var completServiceUUIDs:[String] = serviceUUIDs
        if overflowServiceUUIDs[0] != nilString { completServiceUUIDs += overflowServiceUUIDs }
        entry = ["Service UUIDs"] + completServiceUUIDs
        if entry[1] != nilString { array.append(entry) }
        entry = ["TX Power Level", txPowerLevel]
        if entry[1] != nilString { array.append(entry) }
        entry = ["Connectable", isConnectable]
        if entry[1] != nilString { array.append(entry) }
        entry = ["Solicited Service UUIDs"] + solicitedServiceUUIDs
        if entry[1] != nilString { array.append(entry) }
        
        advertisementArray = array
        
        var nameString = peripheral.name
        
        
        //FOR SCREENSHOTS v
//        if nameString == "Apple TV" {
//            var rand:String = "\(random())"
//            rand = rand.stringByPaddingToLength(2, withString: " ", startingAtIndex: 0)
//            nameString = "UP_\(rand)"
//        }
//        else if nameString == "UART" {
//            var rand:String = "\(random())"
//            rand = rand.stringByPaddingToLength(1, withString: " ", startingAtIndex: 2)
//            nameString = nameString + "-\(rand)"
//        }
        //FOR SCREENSHOTS ^
        
        
        
        if nameString == nil || nameString == "" {
            nameString = "N/A"
        }
        self.name = nameString!
        
        //Check for UART & DFU services
        for id in completServiceUUIDs {
            if uartServiceUUID().equalsString(id, caseSensitive: false, omitDashes: true) {
                isUART = true
            }
//            else if dfuServiceUUID().equalsString(id, caseSensitive: false, omitDashes: true) {
//                isDFU = true
//            }
        }
        
    }
    
    
    func stringsFromUUIDs(idArray:NSArray)->[String] {
        
        var idStringArray = [String](count: idArray.count, repeatedValue: "")
        
        idArray.enumerateObjectsUsingBlock({ (obj:AnyObject!, idx:Int, stop:UnsafeMutablePointer<ObjCBool>) -> Void in
            let objUUID = obj as? CBUUID
            let idStr = objUUID!.UUIDString
            idStringArray[idx] = idStr
        })
        return idStringArray
        
    }
    
    
    func printAdData(){
        
        if LOGGING {
            print("- - - -")
            for a in advertisementArray {
                print(a)
            }
            print("- - - -")
        }
        
    }
    
    
}