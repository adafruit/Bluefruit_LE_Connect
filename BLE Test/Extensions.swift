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
    
    
    func hexRepresentation()->String {
        
        let dataLength:Int = self.length
        let string = NSMutableString(capacity: dataLength*2)
        let dataBytes:UnsafePointer<Void> = self.bytes
        for idx in 0..<dataLength {
            string.appendFormat("%02x", [UInt(dataBytes[idx])] )
        }
        
        return string as String
    }
    
    
    func stringRepresentation()->String {
        
        //Write new received data to the console text view
        
        //convert data to string & replace characters we can't display
        let dataLength:Int = self.length
        var data = [UInt8](count: dataLength, repeatedValue: 0)
        
        self.getBytes(&data, length: dataLength)
        
        for index in 0..<dataLength {
            if (data[index] <= 0x1f) || (data[index] >= 0x80) { //null characters
                if (data[index] != 0x9)       //0x9 == TAB
                    && (data[index] != 0xa)   //0xA == NL
                    && (data[index] != 0xd) { //0xD == CR
                        data[index] = 0xA9
                }
                
            }
        }
        
        let newString = NSString(bytes: &data, length: dataLength, encoding: NSUTF8StringEncoding)
        
        return newString! as String
        
    }
    
}


extension NSString {
    
    func toHexSpaceSeparated() ->NSString {
        
        let len = UInt(self.length)
        var charArray = [unichar](count: self.length, repeatedValue: 0x0)
        
        //        let chars = UnsafeMutablePointer<unichar>(malloc(len * UInt(sizeofValue(unichar))))
        
        self.getCharacters(&charArray)
        
        let hexString = NSMutableString()
        var charString:NSString
        
        for i in 0..<len {
            charString = NSString(format: "0x%02X", charArray[Int(i)])
            
            if (charString.length == 1){
                charString = "0".stringByAppendingString(charString as String)
            }
            
            hexString.appendString(charString.stringByAppendingString(" "))
        }
        
        
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
            case 9:
                outputString.appendFormat("%02x-", value)
                break
            default:
                outputString.appendFormat("%02x", value)
            }
            
        }
        
        return outputString
    }
    
    
    func equalsString(toString:String, caseSensitive:Bool, omitDashes:Bool)->Bool {
        
        var aString = toString
        var verdict = false
        var options = NSStringCompareOptions.CaseInsensitiveSearch
        
        if omitDashes == true {
            aString = toString.stringByReplacingOccurrencesOfString("-", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
        }
        
        if caseSensitive == true {
            options = NSStringCompareOptions.LiteralSearch
        }
        
//        println("\(self.representativeString()) ?= \(aString)")
        
        verdict = aString.compare(self.representativeString() as String, options: options, range: nil, locale: NSLocale.currentLocale()) == NSComparisonResult.OrderedSame
        
        return verdict
        
    }
    
}


func printLog(obj:AnyObject, funcName:String, logString:String?) {
    
    if LOGGING != true {
        return
    }
    
    if logString != nil {
        print("\(obj.classForCoder!.description()) \(funcName) : \(logString!)")
    }
    else {
        print("\(obj.classForCoder!.description()) \(funcName)")
    }
    
}


func binaryforByte(value: UInt8) -> String {
    
    var str = String(value, radix: 2)
    let len = str.characters.count
    if len < 8 {
        var addzeroes = 8 - len
        while addzeroes > 0 {
            str = "0" + str
            addzeroes -= 1
        }
    }
    
    return str
}



extension UIImage
{
    func tintWithColor(color:UIColor)->UIImage {
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()
        
        // flip the image
        CGContextScaleCTM(context, 1.0, -1.0)
        CGContextTranslateCTM(context, 0.0, -self.size.height)
        
        // multiply blend mode
        CGContextSetBlendMode(context, CGBlendMode.Multiply)
        
        let rect = CGRectMake(0, 0, self.size.width, self.size.height)
        CGContextClipToMask(context, rect, self.CGImage)
        color.setFill()
        CGContextFillRect(context, rect)
        
        // create uiimage
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
        
    }
}

