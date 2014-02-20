//
//  PinCell.m
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 2/3/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import "PinCell.h"


@interface PinCell(){
    
    PinMode    defaultPinMode;
}
@end


@implementation PinCell


- (void)setReceivedValue:(int)value{
    
//    NSLog(@"Setting Cell: %@ Value: %d", self.pinLabel.text, value);
    
    if (_mode == kPinModeInput) {
        switch (value) {
            case 0:
                _valueLabel.text = @"Low";
                break;
            case 1:
                _valueLabel.text = @"High";
                break;
            default:
                NSLog(@"Attempting to set digital pin to analog value");
                break;
        }
    }
    
    else if (_mode == kPinModeAnalog){
        
        _valueLabel.text = [NSString stringWithFormat:@"%d", value];
    }
    
    //    else NSLog(@"Attempting to set received value to an output cell");
    
}


- (void)setWrittenValue:(int)value{
    
    if (_mode == kPinModeOutput) {
        switch (value) {
            case 0:
                _valueLabel.text = @"Low";
                break;
            case 1:
                _valueLabel.text = @"High";
                break;
            default:
                NSLog(@"Attempting to set digital pin to analog value");
                break;
        }
    }
    
    else if (_mode == kPinModePWM || _mode == kPinModeServo){
        
        _valueLabel.text = [NSString stringWithFormat:@"%d", value];
    }
    
    //    else NSLog(@"Attempting to set written value to an input cell");
    
}


- (void)setMode:(PinMode)mode{
    
    //Set default display values & controls
    switch (mode) {
        case kPinModeInput:
            _modeLabel.text = @"Input";
            _valueLabel.text = @"Low";
            [self hideDigitalControl:YES];
            [self hideValueSlider:YES];
            break;
        case kPinModeOutput:
            _modeLabel.text = @"Output";
            _valueLabel.text = @"Low";
            [self hideDigitalControl:NO];
            [self hideValueSlider:YES];
            break;
        case kPinModeAnalog:
            _modeLabel.text = @"Analog";
            _valueLabel.text = @"0";
            [self hideDigitalControl:YES];
            [self hideValueSlider:YES];
            break;
        case kPinModePWM:
            _modeLabel.text = @"PWM";
            _valueLabel.text = @"0";
            [self hideDigitalControl:YES];
            [self hideValueSlider:NO];
            break;
        case kPinModeServo:
            _modeLabel.text = @"Servo";
            _valueLabel.text = @"0";
            [self hideDigitalControl:YES];
            [self hideValueSlider:NO];
            break;
        default:
            _modeLabel.text = @"";
            _valueLabel.text = @"";
            [self hideDigitalControl:YES];
            [self hideValueSlider:YES];
            break;
    }
    
    if (mode != _mode) {
        _mode = mode;
        [_delegate cellModeUpdated:self];
    }
}


- (void)hideDigitalControl:(BOOL)hide{
    
    _digitalControl.hidden = hide;
    if (hide) _digitalControl.selectedSegmentIndex = 0;
}


- (void)hideValueSlider:(BOOL)hide{
    
    _valueSlider.hidden = hide;
    if (hide) _valueSlider.value = 0.0f;
    
}


- (void)setDefaultsWithMode:(PinMode)aMode{
    
    defaultPinMode = aMode;
    
    [_modeControl setSelectedSegmentIndex:defaultPinMode];
    [self setMode:defaultPinMode];
    
    [_digitalControl setSelectedSegmentIndex:kPinStateLow];
    
    [_valueSlider setValue:0.0f animated:NO];
    
}


- (BOOL)isDigital{
    
    return YES;
}


- (void)setIsAnalog:(BOOL)isAnalog{
    
    //Adjust modeControl for capability
    if (_isAnalog != isAnalog) {
        _isAnalog = isAnalog;
        [self configureModeControl];
    }
}


- (void)setIsPWM:(BOOL)isPWM{
    
    //Adjust modeControl for capability
    if (_isPWM != isPWM) {
        _isPWM = isPWM;
        [self configureModeControl];
    }
}


- (void)configureModeControl{
    
    [_modeControl removeAllSegments];
    
    //All cells are digital capable
    [_modeControl insertSegmentWithTitle:@"Input" atIndex:0 animated:NO];
    
    [_modeControl insertSegmentWithTitle:@"Output" atIndex:1 animated:NO];
    
    if (_isAnalog == YES) {
        [_modeControl insertSegmentWithTitle:@"Analog" atIndex:_modeControl.numberOfSegments animated:NO];
    }
    
    if (_isPWM == YES) {
        [_modeControl insertSegmentWithTitle:@"PWM" atIndex:_modeControl.numberOfSegments animated:NO];
    }
    
    if (_isServo == YES) {
        [_modeControl insertSegmentWithTitle:@"Servo" atIndex:_modeControl.numberOfSegments animated:NO];
    }
    
//    //Default to Output selected
    [_modeControl setSelectedSegmentIndex:kPinModeInput];
}


- (void)setAnalogPin:(int)analogPin{
    
    _analogPin = analogPin;
    
    if (analogPin > -1) {
        [self setIsAnalog:YES];
    }
    else [self setIsAnalog:NO];
}


@end
