//
//  Constants.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/1/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

//System Variables
let CURRENT_DEVICE = UIDevice.currentDevice()
let INTERFACE_IS_PAD:Bool = (CURRENT_DEVICE.userInterfaceIdiom == UIUserInterfaceIdiom.Pad)
let INTERFACE_IS_PHONE:Bool = (CURRENT_DEVICE.userInterfaceIdiom == UIUserInterfaceIdiom.Phone)

let IS_IPAD:Bool = INTERFACE_IS_PAD
let IS_IPHONE:Bool = INTERFACE_IS_PHONE
let MAIN_SCREEN = UIScreen.mainScreen()
let IS_IPHONE_5:Bool = MAIN_SCREEN.bounds.size.height == 568.0
let IS_IPHONE_4:Bool = MAIN_SCREEN.bounds.size.height == 480.0
let IS_RETINA:Bool = MAIN_SCREEN.respondsToSelector("scale") && (MAIN_SCREEN.scale == 2.0)
let IOS_VERSION_FLOAT:Float = (CURRENT_DEVICE.systemVersion as NSString).floatValue
let LOGGING = false
let PREF_UART_SHOULD_ECHO_LOCAL = "UartEchoLocal"
let cellSelectionColor = UIColor(red: 100.0/255.0, green: 182.0/255.0, blue: 255.0/255.0, alpha: 1.0)


func animateCellSelection(cell:UITableViewCell) {
    
    //fade cell background blue to white
    cell.backgroundColor = cellSelectionColor
    UIView.animateWithDuration(0.25, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: { () -> Void in
        cell.backgroundColor = UIColor.whiteColor()
        }) { (done:Bool) -> Void in
    }
}


func delay(delay:Double, closure:()->()) {
    
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure
    )
}


//MARK: User prefs

func uartShouldEchoLocal() ->Bool {
    
    // Pref was not set
    if NSUserDefaults.standardUserDefaults().valueForKey(PREF_UART_SHOULD_ECHO_LOCAL) == nil {
        uartShouldEchoLocalSet(false)
        return false
    }
        
    // Pref was set
    else {
        return NSUserDefaults.standardUserDefaults().boolForKey(PREF_UART_SHOULD_ECHO_LOCAL)
    }
    
}


func uartShouldEchoLocalSet(shouldEcho:Bool) {
    
    NSUserDefaults.standardUserDefaults().setBool(shouldEcho, forKey: PREF_UART_SHOULD_ECHO_LOCAL)
    
}


//MARK: UUID Retrieval

func uartServiceUUID()->CBUUID{
    
    return CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    
}


func txCharacteristicUUID()->CBUUID{
    
    return CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
}


func rxCharacteristicUUID()->CBUUID{
    
    return CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
}


func deviceInformationServiceUUID()->CBUUID{
    
    return CBUUID(string: "180A")
}


func hardwareRevisionStringUUID()->CBUUID{
    
    return CBUUID(string: "2A27")
}


func manufacturerNameStringUUID()->CBUUID{    //    Manufacturer Name String	0x2A29
    
    return CBUUID(string: "2A29")
}


func modelNumberStringUUID()->CBUUID{         //    Model Number String		0x2A24
    
    return CBUUID(string: "2A24")
}


func firmwareRevisionStringUUID()->CBUUID{    //    Firmware Revision String	0x2A26
    
    return CBUUID(string: "2A26")
}


func softwareRevisionStringUUID()->CBUUID{    //    Software Revision String  0x2A28
    
    return CBUUID(string: "2A28")
}


func serialNumberStringUUID()->CBUUID{    //    Software Revision String  0x2A28
    
    return CBUUID(string: "2A25")
}


func dfuServiceUUID()->CBUUID{    //    Software Revision String  0x2A28
    
    return CBUUID(string: "00001530-1212-efde-1523-785feabcd123")
}


let knownUUIDs:[CBUUID] =  [
    uartServiceUUID(),
    txCharacteristicUUID(),
    rxCharacteristicUUID(),
    deviceInformationServiceUUID(),
    hardwareRevisionStringUUID(),
    manufacturerNameStringUUID(),
    modelNumberStringUUID(),
    firmwareRevisionStringUUID(),
    softwareRevisionStringUUID(),
    serialNumberStringUUID(),
    dfuServiceUUID(),
    CBUUID(string: CBUUIDCharacteristicAggregateFormatString),
    CBUUID(string: CBUUIDCharacteristicExtendedPropertiesString),
    CBUUID(string: CBUUIDCharacteristicFormatString),
    CBUUID(string: CBUUIDCharacteristicUserDescriptionString),
    CBUUID(string: CBUUIDClientCharacteristicConfigurationString),
    CBUUID(string: CBUUIDServerCharacteristicConfigurationString)
]



let knownUUIDNames:[String] =  [
    "UART",
    "TXD",
    "RXD",
    "Device Information",
    "Hardware Revision",
    "Manufacturer Name",
    "Model Number",
    "Firmware Revision",
    "Software Revision",
    "Serial Number",
    "DFU Service",
    "Characteristic Aggregate Format",
    "Characteristic Extended Properties",
    "Characteristic Format",
    "Characteristic User Description",
    "Client Characteristic Configuration",
    "Server Characteristic Configuration",
]


func UUIDsAreEqual(firstID:CBUUID, secondID:CBUUID)->Bool {
    
    if firstID.representativeString() == secondID.representativeString() {
        return true
    }
        
    else {
        return false
    }
    
}

