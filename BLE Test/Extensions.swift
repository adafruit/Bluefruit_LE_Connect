//
//  Extensions.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/14/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import CoreBluetooth


extension NSData {
    
    func hexRepresentationWithSpaces(spaces:Bool) ->NSString {
        
        var byteArray = [UInt8](count: self.length, repeatedValue: 0x0)
        // The Test Data is moved into the 8bit Array.
        self.getBytes(&byteArray, length:self.length)
//        self.debugDescription
        
        var hexBits = "" as String
        for value in byteArray {
            let newHex = NSString(format:"0x%2X", value) as String
            hexBits += newHex.stringByReplacingOccurrencesOfString(" ", withString: "0", options: NSStringCompareOptions.CaseInsensitiveSearch)
            if spaces {
                hexBits += " "
            }
        }
        return hexBits
    }
    
}


extension NSString {
    
    func toHexSpaceSeparated() ->NSString {
        
        let len = UInt(self.length)
        var charArray = [unichar](count: self.length, repeatedValue: 0x0)
        
//        let chars = UnsafeMutablePointer<unichar>(malloc(len * UInt(sizeofValue(unichar))))
        
        self.getCharacters(&charArray)
        
        var hexString = NSMutableString()
        var charString:NSString
        
        for i in 0...(len-1) {
            charString = NSString(format: "0x%x", charArray[Int(i)])
            
            if (charString.length == 1){
                charString = "0".stringByAppendingString(charString)
            }
            
            hexString.appendString(charString.stringByAppendingString(" "))
        }
        
//        free(chars)
        
        return hexString
    }
    
}


extension CBUUID {
    
    func representativeString() ->NSString{
        
        let data = self.data
        var byteArray = [UInt8](count: data.length, repeatedValue: 0x0)
        data.getBytes(&byteArray, length:data.length)
        
        let outputString = NSMutableString(capacity: 16)
        
        for value in byteArray {
            
            switch (value){
//            case 3:
//            case 5:
//            case 7:
            case 9:
                outputString.appendFormat("%02x-", value)
                break
            default:
                outputString.appendFormat("%02x", value)
            }
            
        }
        
        return outputString
    }
    
}