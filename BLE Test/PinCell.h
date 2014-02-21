//
//  PinCell.h
//  Bluefruit Connect
//
//  Created by Collin Cunningham on 2/3/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PinCellDelegate <NSObject>

- (void)cellModeUpdated:(id)sender;

@end

@interface PinCell : UITableViewCell

typedef enum {
    kPinStateLow  = 0,
    kPinStateHigh,
} PinState;

typedef enum {
    kPinModeUnknown = -1,
    kPinModeInput,
    kPinModeOutput,
    kPinModeAnalog,
    kPinModePWM,
    kPinModeServo
} PinMode;

@property (nonatomic, assign) id<PinCellDelegate>  delegate;
@property (strong, nonatomic) UILabel              *pinLabel;
@property (strong, nonatomic) UILabel              *modeLabel;
@property (strong, nonatomic) UILabel              *valueLabel;
@property (strong, nonatomic) UIButton             *toggleButton;
@property (strong, nonatomic) UISegmentedControl   *modeControl;
@property (strong, nonatomic) UISegmentedControl   *digitalControl;
@property (strong, nonatomic) UISlider             *valueSlider;
@property (nonatomic, assign) PinMode              mode;
@property (nonatomic, assign) int                  digitalPin;
@property (nonatomic, assign) int                  analogPin;
@property (nonatomic, readonly) BOOL               isDigital;
@property (nonatomic, assign) BOOL                 isAnalog;
@property (nonatomic, assign) BOOL                 isPWM;
@property (nonatomic, assign) BOOL                 isServo;

- (void)setDigitalValue:(int)value;
- (void)setAnalogValue:(int)value;
- (void)setPwmValue:(int)value;
- (void)setDefaultsWithMode:(PinMode)defaultMode;

@end
