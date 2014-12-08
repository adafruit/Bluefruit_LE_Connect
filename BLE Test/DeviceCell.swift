//
//  DeviceCell.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/19/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import UIKit

class DeviceCell: UITableViewCell {
    
    var nameLabel:UILabel!
    var toggleButton:UIButton!
    var rssiLabel:UILabel!
    var uartCapableLabel:UILabel!
    var signalImageView:UIImageView!
    var signalImages:[UIImage]!
    private var lastSigIndex = -1
    private var lastSigUpdate:Double = NSDate.timeIntervalSinceReferenceDate()
    private let updateIntvl = 3.0
    var connectButton:UIButton!
    var isOpen:Bool = false

    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Initialization code
        
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    
    func updateSignalImage(RSSI:NSNumber) {
        
        // Only update every few seconds
        let now = NSDate.timeIntervalSinceReferenceDate()
        if lastSigIndex != -1 && (now - lastSigUpdate) < updateIntvl {
            return
        }
        
        let rssiInt = RSSI.integerValue
        var rssiString = RSSI.stringValue
        var index = 0
        
        if rssiInt == 127 {     // value of 127 reserved for RSSI not available
            index = 0
            rssiString = "N/A"
        }
        else if rssiInt <= -84 {
            index = 0
        }
        else if rssiInt <= -72 {
            index = 1
        }
        else if rssiInt <= -60 {
            index = 2
        }
        else if rssiInt <= -48 {
            index = 3
        }
        else {
            index = 4
        }
     
        if index != lastSigIndex {
            rssiLabel.text = rssiString
            signalImageView.image = signalImages[index]
            lastSigIndex = index
            lastSigUpdate = now
        }
        
    }
    
}
