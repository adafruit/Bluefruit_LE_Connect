/*
 By: Justin Meiners
 
 Copyright (c) 2013 Inline Studios
 Licensed under the MIT license: http://www.opensource.org/licenses/mit-license.php
*/

#import <UIKit/UIKit.h>

@class ISColorWheel;

@protocol ISColorWheelDelegate <NSObject>
@required
- (void)colorWheelDidChangeColor:(ISColorWheel*)colorWheel;
@end


@interface ISColorWheel : UIView

@property(nonatomic, retain)UIView* knobView;
@property(nonatomic, assign)CGSize knobSize;
@property(nonatomic, assign)float brightness;
@property(nonatomic, assign)BOOL continuous;
@property(nonatomic, assign)id <ISColorWheelDelegate> delegate;

- (void)updateImage;

- (void)setTouchPoint:(CGPoint)point;

- (void)setCurrentColor:(UIColor*)color;

- (UIColor*)currentColor;

@end
