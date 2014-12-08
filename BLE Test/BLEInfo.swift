//
//  BLEInfo.swift
//  Adafruit Bluefruit LE Connect
//
//  Data for display in Info mode/list
//
//  Created by Collin Cunningham on 10/28/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation


public struct BLEDescriptor {
    
    var title:String!
    var UUID:NSUUID!
    
}


public struct BLECharacteristic {
    
    var title:String!
    var UUID:NSUUID!
    var descriptors:[BLEDescriptor]
    
}


public struct BLEService {
    
    var title:String!
    var UUID:NSUUID!
    var characteristics:[BLECharacteristic]
    
}