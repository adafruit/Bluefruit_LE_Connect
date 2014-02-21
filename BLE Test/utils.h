//
//  utils.h
//  CircuitPlayground
//
//  Created by Collin Cunningham on 3/17/12.
//  Copyright (c) 2012 Narb-Inst. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface utils : NSObject


+ (void)roundedLayer:(CALayer*)viewLayer radius:(float)r shadow:(BOOL)s;
+ (void)addShadowToLayer:(CALayer*)viewLayer radius:(float)r opacity:(float)o;
+ (void)addShadowToLayer:(CALayer*)viewLayer radius:(float)r opacity:(float)o offset:(CGSize)offset;
+ (void)addGrayBorderToLayer:(CALayer*)viewLayer;
+ (void)addBorderToLayer:(CALayer*)viewLayer withColor:(UIColor*)color andWidth:(CGFloat)width;
+ (void)addBorderInsetToLayer:(CALayer*)viewLayer withWidth:(CGFloat)width;
+ (void)arrangeViews:(NSArray*)views withinView:(UIView*)parentView andAddToParentView:(BOOL)add;
+ (UIImage*)imageByScalingImage:(UIImage*)anImage ToSize:(CGSize)targetSize andPreserveAspect:(BOOL)preserveAspect;
+ (void)makeCPModuleButton:(UIButton*)button;
+ (void)makeModeButton:(UIButton*)button;
+ (void)makeCPGridButton:(UIButton*)button;
+ (void)makeCPHelpButton:(UIButton*)button;
- (void)listSubviewsOfView:(UIView*)view;
- (void)listSubviewsOfView:(UIView*)view withIndent:(NSString*)indent;

@end
