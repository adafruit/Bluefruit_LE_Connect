//
//  Constants.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/1/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit

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

let LOGGING = true

func delay(delay:Double, closure:()->()) {
    
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure
    )
}