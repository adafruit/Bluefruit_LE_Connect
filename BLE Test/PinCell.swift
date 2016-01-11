//
//  PinCell.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/10/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit

protocol PinCellDelegate {
    
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
    
    var digitalPin:Int = -1 {
        didSet {
            if oldValue != self.digitalPin{
                updatePinLabel()
            }
        }
    }
    
    var analogPin:Int = -1 {
        didSet {
            if oldValue != self.analogPin{
                updatePinLabel()
            }
        }
    }
    
    var isDigital:Bool = false {
        didSet {
            if oldValue != self.isDigital {
                configureModeControl()
            }
        }
    }
    
    var isAnalog:Bool = false {
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
    
    var isPWM:Bool = false {
        didSet {
            if oldValue != self.isPWM {
                configureModeControl();
            }
        }
    }
    
    var isServo:Bool! = false
    
    
    required init() {
        super.init(style: UITableViewCellStyle.Default, reuseIdentifier: nil)
    }
    
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    
    func updatePinLabel() {
        
        if analogPin == -1 {
            pinLabel.text = "Pin \(digitalPin)"
        }
        else {
            pinLabel.text = "Pin \(digitalPin), Analog \(analogPin)"
        }
        
    }
    
    
    func setDigitalValue(value:Int){
        
        //Set a cell's digital Low/High value
        
        if ((self.mode == PinMode.Input) || (self.mode == PinMode.Output)) {
            switch (value) {
            case 0:
                self.valueLabel.text = "Low"
//                printLog(self, funcName: "setDigitalValue", logString: "Setting pin \(self.digitalPin) LOW")
                break
            case 1:
                self.valueLabel.text = "High"
//                printLog(self, funcName: "setDigitalValue", logString: "Setting pin \(self.digitalPin) HIGH")
                break
            default:
//                printLog(self, funcName: "setDigitalValue", logString: "Attempting to set digital pin \(self.digitalPin) to analog value")
                break
            }
        }
            
        else{
            
//            printLog(self, funcName: "setDigitalValue", logString: "\(self.analogPin) to digital value")
        }
        
    }
    
    
    func setAnalogValue(value:Int){
        
        //Set a cell's analog value
        
        if (self.mode == PinMode.Analog){
            
            self.valueLabel.text = "\(value)";
            
        }
            
        else {
            
            printLog(self, funcName: "setAnalogValue", logString: "\(self.digitalPin) to analog value")
        }
        
    }
    
    
    func setPwmValue(value:Int){
        
        //Set a cell's PWM value
        
        if (self.mode == PinMode.PWM){
            
            self.valueLabel.text = "\(value)"
            
        }
            
        else {
            
            printLog(self, funcName: "setPwmValue", logString: "\(self.digitalPin) to non-PWM value")
            
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
    
    
    func setMode(modeInt:UInt8) {
        
        switch modeInt {
        case 0:
            self.mode = PinMode.Input
        case 1:
            self.mode = PinMode.Output
        case 2:
            self.mode = PinMode.Analog
        case 3:
            self.mode = PinMode.PWM
        case 4:
            self.mode = PinMode.Servo
        default:
            printLog(self, funcName: (__FUNCTION__), logString: "Attempting to set pin mode w non-matching int")
        }
        
    }
    
    
    func setDefaultsWithMode(aMode:PinMode){
    
        //load initial default values
    
        modeControl.selectedSegmentIndex = aMode.rawValue
    
        mode = aMode
    
        digitalControl.selectedSegmentIndex = PinState.Low.rawValue
    
        valueSlider.setValue(0.0, animated: false)
    
    }
    
    
    func configureModeControl(){
        
        //Configure Mode segmented control per pin capabilities …
        
        modeControl.removeAllSegments()
        
        if isDigital == true {
            modeControl.insertSegmentWithTitle("Input", atIndex: 0, animated: false)
            modeControl.insertSegmentWithTitle("Output", atIndex: 1, animated: false)
        }
        
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
        modeControl.selectedSegmentIndex = PinMode.Input.rawValue
    }
    
}