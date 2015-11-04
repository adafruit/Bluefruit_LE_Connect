//
//  BLESensorButton.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 2/3/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

class BLESensorButton: UIButton {

//    override init() {
//        dimmed = false
//        super.init()
//        self.customizeButton()
//    }
    
    override init(frame: CGRect) {
        dimmed = false
        super.init(frame: frame)
        self.customizeButton()
    }

    required init(coder aDecoder: NSCoder) {
        dimmed = false
        super.init(coder: aDecoder)!
        self.customizeButton()
    }
    
    
    let offColor = bleBlueColor
    let onColor = UIColor.whiteColor()
    
    var dimmed: Bool {    // Highlighted is used as an interactive disabled state
        willSet(newValue) {
            if newValue == false {
                self.layer.borderColor = bleBlueColor.CGColor
                self.setTitleColor(offColor, forState: UIControlState.Normal)
                self.setTitleColor(onColor, forState: UIControlState.Selected)
            }
            else {
                self.layer.borderColor = UIColor.lightGrayColor().CGColor
                self.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Normal)
                self.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Selected)
            }
        }
    }
    
    
    func customizeButton(){
        
        self.titleLabel?.font = UIFont.systemFontOfSize(14.0)
        self.setTitle("OFF", forState: UIControlState.Normal)
        self.setTitle("ON", forState: UIControlState.Selected)
        self.setTitleColor(offColor, forState: UIControlState.Normal)
        self.setTitleColor(onColor, forState: UIControlState.Selected)
        self.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Highlighted)
        self.backgroundColor = UIColor.whiteColor()
        self.setBackgroundImage(UIImage(named: "ble_blue_1px.png"), forState: UIControlState.Selected)
        self.layer.cornerRadius = 8.0
        self.clipsToBounds = true
        self.layer.borderColor = offColor.CGColor
        self.layer.borderWidth = 1.0
        
    }

}
