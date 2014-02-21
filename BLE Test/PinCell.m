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


//- (void)setReceivedValue:(int)value{
//    
////    NSLog(@"Setting Cell: %@ Value: %d", self.pinLabel.text, value);
//    
//    if (self.mode == kPinModeAnalog){
//        
//        self.valueLabel.text = [NSString stringWithFormat:@"%d", value];
//
//    }
//    
//    else if (self.mode == kPinModeInput) {
//        switch (value) {
//            case 0:
//                self.valueLabel.text = @"Low";
//                break;
//            case 1:
//                self.valueLabel.text = @"High";
//                break;
//            default:
//                NSLog(@"Attempting to set digital pin to analog value");
//                break;
//        }
//    }
//    
//    //    else NSLog(@"Attempting to set received value to an output cell");
//    
//}


- (void)setDigitalValue:(int)value{
    
    if ((self.mode == kPinModeInput) || (self.mode == kPinModeOutput)) {
        switch (value) {
            case 0:
                self.valueLabel.text = @"Low";
                break;
            case 1:
                self.valueLabel.text = @"High";
                break;
            default:
                NSLog(@"Attempting to set Digital pin %d to Analog value", self.digitalPin);
                break;
        }
    }
    
    else{
        
        NSLog(@"Attempting to set Analog Pin %d to Digital value", self.analogPin);
    }
    
}



- (void)setAnalogValue:(int)value{
    
    if (self.mode == kPinModeAnalog){
        
        self.valueLabel.text = [NSString stringWithFormat:@"%d", value];
        
    }
    
    else {
        
        NSLog(@"Attempting to set Digital Pin %d to Analog value", self.digitalPin);
    }
    
}


- (void)setPwmValue:(int)value{
    
    if (self.mode == kPinModePWM){
        
        self.valueLabel.text = [NSString stringWithFormat:@"%d", value];
        
    }
    
    else {
        
        NSLog(@"Attempting to set PWM Pin %d to non-PWM value", self.digitalPin);
    }
    
}


- (void)setMode:(PinMode)mode{
    
    //Set default display values & controls
    switch (mode) {
        case kPinModeInput:
            self.modeLabel.text = @"Input";
            self.valueLabel.text = @"Low";
            [self hideDigitalControl:YES];
            [self hideValueSlider:YES];
            break;
        case kPinModeOutput:
            self.modeLabel.text = @"Output";
            self.valueLabel.text = @"Low";
            [self hideDigitalControl:NO];
            [self hideValueSlider:YES];
            break;
        case kPinModeAnalog:
            self.modeLabel.text = @"Analog";
            self.valueLabel.text = @"0";
            [self hideDigitalControl:YES];
            [self hideValueSlider:YES];
            break;
        case kPinModePWM:
            self.modeLabel.text = @"PWM";
            self.valueLabel.text = @"0";
            [self hideDigitalControl:YES];
            [self hideValueSlider:NO];
            break;
        case kPinModeServo:
            self.modeLabel.text = @"Servo";
            self.valueLabel.text = @"0";
            [self hideDigitalControl:YES];
            [self hideValueSlider:NO];
            break;
        default:
            self.modeLabel.text = @"";
            self.valueLabel.text = @"";
            [self hideDigitalControl:YES];
            [self hideValueSlider:YES];
            break;
    }
    
    if (mode != _mode) {
        _mode = mode;
        [self.delegate cellModeUpdated:self];
    }
}


- (void)hideDigitalControl:(BOOL)hide{
    
    self.digitalControl.hidden = hide;
    if (hide) self.digitalControl.selectedSegmentIndex = 0;
}


- (void)hideValueSlider:(BOOL)hide{
    
    self.valueSlider.hidden = hide;
    if (hide) self.valueSlider.value = 0.0f;
    
}


- (void)setDefaultsWithMode:(PinMode)aMode{
    
    defaultPinMode = aMode;
    
    [self.modeControl setSelectedSegmentIndex:defaultPinMode];
    [self setMode:defaultPinMode];
    
    [self.digitalControl setSelectedSegmentIndex:kPinStateLow];
    
    [self.valueSlider setValue:0.0f animated:NO];
    
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
    
    [self.modeControl removeAllSegments];
    
    //All cells are digital capable
    [self.modeControl insertSegmentWithTitle:@"Input" atIndex:0 animated:NO];
    
    [self.modeControl insertSegmentWithTitle:@"Output" atIndex:1 animated:NO];
    
    if (self.isAnalog == YES) {
        [self.modeControl insertSegmentWithTitle:@"Analog" atIndex:self.modeControl.numberOfSegments animated:NO];
    }
    
    if (self.isPWM == YES) {
        [self.modeControl insertSegmentWithTitle:@"PWM" atIndex:self.modeControl.numberOfSegments animated:NO];
    }
    
    if (self.isServo == YES) {
        [self.modeControl insertSegmentWithTitle:@"Servo" atIndex:self.modeControl.numberOfSegments animated:NO];
    }
    
//    //Default to Output selected
    [self.modeControl setSelectedSegmentIndex:kPinModeInput];
}


- (void)setAnalogPin:(int)analogPin{
    
    _analogPin = analogPin;
    
    if (analogPin > -1) {
        [self setIsAnalog:YES];
    }
    else [self setIsAnalog:NO];
}


@end
