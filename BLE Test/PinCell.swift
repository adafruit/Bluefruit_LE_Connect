//
//  PinCell.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/10/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit

@objc protocol PinCellDelegate {
    
    func cellModeUpdated(sender: AnyObject)
    
}

enum PinState:Int{
    case Low = 0
    case High
}

enum PinMode:Int{
    case Unknown = -1
    case Input
    case Output
    case Analog
    case PWM
    case Servo
}

class PinCell: UITableViewCell {
    
    var delegate:PinCellDelegate?
    var pinLabel:UILabel!
    var modeLabel:UILabel!
    var valueLabel:UILabel!
    var toggleButton:UIButton!
    var modeControl:UISegmentedControl!
    var digitalControl:UISegmentedControl!
    var valueSlider:UISlider!
    var digitalPin:Int!
    
    var analogPin:Int! {
        didSet {
            if (analogPin > -1) {
                self.isAnalog = true
            }
            else {
                self.isAnalog = false
            }
        }
    }
    
    var isAnalog:Bool! {
        didSet {
            if oldValue != self.isAnalog {
                configureModeControl()
            }
        }
    }
    
    var mode:PinMode! {
        didSet {
            //Change cell mode - Digital/Analog/PWM
            respondToNewMode(self.mode)
            
            if (oldValue != self.mode) {
                delegate!.cellModeUpdated(self)
            }
        }
    }
    
    var isPWM:Bool! = true{
        didSet {
            if oldValue != self.isPWM {
                configureModeControl();
            }
        }
    }
    
    var isServo:Bool! = false
    
    
    override init() {
        super.init()
    }
    
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    func setDigitalValue(value:Int){
        
        //Set a cell's digital Low/High value
        
        if ((self.mode == PinMode.Input) || (self.mode == PinMode.Output)) {
            switch (value) {
            case 0:
                self.valueLabel.text = "Low"
                break
            case 1:
                self.valueLabel.text = "High"
                break
            default:
                println("Attempting to set digital pin \(self.digitalPin) to analog value")
                break
            }
        }
            
        else{
            
            println("Attempting to set non-digital pin \(self.analogPin) to digital value")
        }
        
    }
    
    
    func setAnalogValue(value:Int){
        
        //Set a cell's analog value
        
        if (self.mode == PinMode.Analog){
            
            self.valueLabel.text = "\(value)";
            
        }
            
        else {
            
            println("Attempting to set digital pin \(self.digitalPin) to analog value")
        }
        
    }
    
    
    func setPwmValue(value:Int){
        
        //Set a cell's PWM value
        
        if (self.mode == PinMode.PWM){
            
            self.valueLabel.text = "\(value)"
            
        }
            
        else {
            
            println("Attempting to set PWM Pin \(self.digitalPin) to non-PWM value")
        }
        
    }
    
    
    func respondToNewMode(newValue:PinMode){
        
        //Set default display values & controls
        
        switch (newValue) {
        case PinMode.Input:
            self.modeLabel.text = "Input"
            self.valueLabel.text = "Low"
            hideDigitalControl(true)
            hideValueSlider(true)
            break;
        case PinMode.Output:
            self.modeLabel.text = "Output"
            self.valueLabel.text = "Low"
            hideDigitalControl(false)
            hideValueSlider(true)
            break;
        case PinMode.Analog:
            self.modeLabel.text = "Analog"
            self.valueLabel.text = "0"
            hideDigitalControl(true)
            hideValueSlider(true)
            break;
        case PinMode.PWM:
            self.modeLabel.text = "PWM"
            self.valueLabel.text = "0"
            hideDigitalControl(true)
            hideValueSlider(false)
            break;
        case PinMode.Servo:
            self.modeLabel.text = "Servo"
            self.valueLabel.text = "0"
            hideDigitalControl(true)
            hideValueSlider(false)
            break;
        default:
            self.modeLabel.text = ""
            self.valueLabel.text = ""
            hideDigitalControl(true)
            hideValueSlider(true)
            break;
        }
    }
    
    
    func hideDigitalControl(hide:Bool){
        
        self.digitalControl.hidden = hide
        
        if (hide){
            self.digitalControl.selectedSegmentIndex = 0
        }
    }
    
    
    func hideValueSlider(hide:Bool){
    
        self.valueSlider.hidden = hide
        
        if (hide) {
            self.valueSlider.value = 0.0
        }
    
    }
    
    
    func setDefaultsWithMode(aMode:PinMode){
    
        //load initial default values
    
        modeControl.selectedSegmentIndex = aMode.toRaw()
    
        mode = aMode
    
        digitalControl.selectedSegmentIndex = PinState.Low.toRaw()
    
        valueSlider.setValue(0.0, animated: false)
    
    }
    
    
    func configureModeControl(){
        
        //Configure Mode segmented control per pin capabilities …
        
        modeControl.removeAllSegments()
        
        //All cells are digital capable
        modeControl.insertSegmentWithTitle("Input", atIndex: 0, animated: false)
        modeControl.insertSegmentWithTitle("Output", atIndex: 1, animated: false)
        
        if isAnalog == true {
            modeControl.insertSegmentWithTitle("Analog", atIndex: modeControl.numberOfSegments, animated: false)
        }
        
        if isPWM == true {
            modeControl.insertSegmentWithTitle("PWM", atIndex: modeControl.numberOfSegments, animated: false)
        }
        
        if isServo == true {
            modeControl.insertSegmentWithTitle("Servo", atIndex: modeControl.numberOfSegments, animated: false)
        }
        
        //    //Default to Output selected
        modeControl.selectedSegmentIndex = PinMode.Input.toRaw()
    }
    
}