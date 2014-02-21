//
//  utils.m
//  CircuitPlayground
//
//  Created by Collin Cunningham on 3/17/12.
//  Copyright (c) 2012 Narb-Inst. All rights reserved.
//

#import "utils.h"
#import <QuartzCore/QuartzCore.h>


@implementation utils


+ (void)roundedLayer:(CALayer*)viewLayer radius:(float)r shadow:(BOOL)s{
    
    [viewLayer setMasksToBounds:!s];
    [viewLayer setCornerRadius:r];        
    //[viewLayer setBorderColor:[RGB(180, 180, 180) CGColor]];
//    [viewLayer setBorderWidth:1.0f];
    
    if(s)
    {
        [viewLayer setShadowColor:[UIColor blackColor].CGColor];
        [viewLayer setShadowOffset:CGSizeMake(0.0f, 5.0f)];
        [viewLayer setShadowOpacity:0.5];
        [viewLayer setShadowRadius:10.0f];
    }
    return;
}


+ (void)addShadowToLayer:(CALayer*)viewLayer radius:(float)r opacity:(float)o{

    [viewLayer setMasksToBounds:NO];
    [viewLayer setShadowColor:[UIColor blackColor].CGColor];
    [viewLayer setShadowOffset:CGSizeMake(0.0f, 3.0f)];
    [viewLayer setShadowOpacity:o];
    [viewLayer setShadowRadius:r];

}


+ (void)addShadowToLayer:(CALayer*)viewLayer radius:(float)r opacity:(float)o offset:(CGSize)offset{
    
    
    [viewLayer setMasksToBounds:NO];
    [viewLayer setShadowColor:[UIColor blackColor].CGColor];
    [viewLayer setShadowOffset:offset];
    [viewLayer setShadowOpacity:o];
    [viewLayer setShadowRadius:r];
    
}


+ (void)addGrayBorderToLayer:(CALayer*)viewLayer{
    
    [self addBorderToLayer:viewLayer withColor:[UIColor colorWithWhite:0.4 alpha:0.9] andWidth:2.0];
    
}


+ (void)addBorderToLayer:(CALayer*)viewLayer withColor:(UIColor*)color andWidth:(CGFloat)width{
    
    
    [viewLayer setBorderWidth:width];
    [viewLayer setBorderColor:color.CGColor];
    
    
}


+ (void)addBorderInsetToLayer:(CALayer*)viewLayer withWidth:(CGFloat)width{
    
    
    //EXPERIMENTAL
    
    
    //turning off bounds clipping allows the shadow to extend beyond the rect of the view
//    [viewLayer masksToBounds:NO];
    
    
    //the colors for the gradient.  highColor is at the top, lowColor as at the bottom
    UIColor * highColor = [UIColor whiteColor];
    UIColor * lowColor = [UIColor darkGrayColor];
    
    //The gradient, simply enough.  It is a rectangle
    CAGradientLayer * gradient = [CAGradientLayer layer];
    [gradient setFrame:[viewLayer bounds]];
    [gradient setColors:[NSArray arrayWithObjects:(id)[highColor CGColor], (id)[lowColor CGColor], nil]];
    
    //the rounded rect, with a corner radius of 6 points.
    //this *does* maskToBounds so that any sublayers are masked
    //this allows the gradient to appear to have rounded corners
    CALayer * roundRect = [CALayer layer];
    [roundRect setFrame:[viewLayer bounds]];
    [roundRect setCornerRadius:2.0f];
    [roundRect setMasksToBounds:YES];
    [roundRect addSublayer:gradient];
    [roundRect setMasksToBounds:YES];

    CALayer* roundRectInset = [CAShapeLayer layer];
    [roundRectInset setCornerRadius:2.0f];
    [roundRectInset setFrame:CGRectInset(viewLayer.bounds, width, width)];
//    [roundRectInset setFillColor:[UIColor blackColor].CGColor];
    [roundRect setMask:roundRectInset];
    
    //add the rounded rect layer underneath all other layers of the view
    [viewLayer insertSublayer:roundRect atIndex:0];
    
    //set the shadow on the view's layer
//    [[self layer] setShadowColor:[[UIColor blackColor] CGColor]];
//    [[self layer] setShadowOffset:CGSizeMake(0, 6)];
//    [[self layer] setShadowOpacity:1.0];
//    [[self layer] setShadowRadius:10.0];
    
}


+ (void)arrangeViews:(NSArray*)views withinView:(UIView*)parentView andAddToParentView:(BOOL)add{
    
    //assumes each child view is equal size and smaller than parent view
    
    CGRect parentRect = parentView.frame;
    UIView * firstView = (UIView*)[views objectAtIndex:0];
    CGRect firstRect = firstView.frame;
    NSInteger childCount = [views count];
    
    __block float columnCount = floorf(parentRect.size.width / firstRect.size.width);
    if (columnCount > childCount) {
        columnCount = childCount;
    }
    
    __block float rowCount = ceilf(childCount / columnCount);
    
//    NSLog(@"rowCount == %f, columnCount = %f", rowCount, columnCount);
    
    __block float padX = (parentRect.size.width - (firstRect.size.width * columnCount)) / (columnCount + 1);
    __block float padY = (parentRect.size.height - (firstRect.size.height * (float)rowCount)) / ((float)rowCount + 1.0f);
    
    __block UIView *aParentView = parentView;
    __block BOOL shouldAdd = add;
    
    [views enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        
        CGFloat column = (idx < columnCount) ? idx : (idx % (int)columnCount);
        CGFloat row = (idx < columnCount) ? 0.0 : floorf((idx / columnCount));
        
        CGFloat aPadX = (padX * column) + padX;
        CGFloat origX = aPadX + (view.frame.size.width * column);
        CGFloat aPadY = (padY * row) + padY;
        CGFloat origY = aPadY + (view.frame.size.height * row);
        
        CGRect newFrame = CGRectMake(origX, origY, view.frame.size.width, view.frame.size.height);
        [view setFrame:newFrame];
        
        if (shouldAdd) {
            [aParentView addSubview:view];
        }
    }];
    
    
}


+ (UIImage*)imageByScalingImage:(UIImage*)anImage ToSize:(CGSize)targetSize andPreserveAspect:(BOOL)preserveAspect{
    
    UIImage* sourceImage = anImage;
    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;
    
    
    CGImageRef imageRef = [sourceImage CGImage];
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    CGColorSpaceRef colorSpaceInfo = CGImageGetColorSpace(imageRef);
    
    if (bitmapInfo == kCGImageAlphaNone) {
        bitmapInfo = (CGBitmapInfo)kCGImageAlphaNoneSkipLast;   //added cast - CC
    }
    
    CGContextRef bitmap;
    
    if (sourceImage.imageOrientation == UIImageOrientationUp || sourceImage.imageOrientation == UIImageOrientationDown) {
        
        if (preserveAspect) {
            float hfactor = sourceImage.size.width / targetWidth;
            float vfactor = sourceImage.size.height / targetHeight;
            float factor = fmax(hfactor, vfactor);
            targetWidth = sourceImage.size.width / factor;
            targetHeight = sourceImage.size.height / factor;
        }
        
        bitmap = CGBitmapContextCreate(NULL, targetWidth, targetHeight, CGImageGetBitsPerComponent(imageRef), CGImageGetBytesPerRow(imageRef), colorSpaceInfo, bitmapInfo);
        
    } else {
        
        if (preserveAspect) {
            float hfactor = sourceImage.size.height / targetWidth;
            float vfactor = sourceImage.size.width / targetHeight;
            float factor = fmax(hfactor, vfactor);
            targetWidth = sourceImage.size.height / factor;
            targetHeight = sourceImage.size.width / factor;
        }
        
        bitmap = CGBitmapContextCreate(NULL, targetHeight, targetWidth, CGImageGetBitsPerComponent(imageRef), CGImageGetBytesPerRow(imageRef), colorSpaceInfo, bitmapInfo);
        
    }
    
    if (sourceImage.imageOrientation == UIImageOrientationLeft) {
        CGContextRotateCTM (bitmap, radians(90));
        CGContextTranslateCTM (bitmap, 0, -targetHeight);
        
    } else if (sourceImage.imageOrientation == UIImageOrientationRight) {
        CGContextRotateCTM (bitmap, radians(-90));
        CGContextTranslateCTM (bitmap, -targetWidth, 0);
        
    } else if (sourceImage.imageOrientation == UIImageOrientationUp) {
        // NOTHING
    } else if (sourceImage.imageOrientation == UIImageOrientationDown) {
        CGContextTranslateCTM (bitmap, targetWidth, targetHeight);
        CGContextRotateCTM (bitmap, radians(-180.));
    }
    
    CGContextDrawImage(bitmap, CGRectMake(0, 0, targetWidth, targetHeight), imageRef);
    CGImageRef ref = CGBitmapContextCreateImage(bitmap);
    UIImage* newImage = [UIImage imageWithCGImage:ref];
    
    CGContextRelease(bitmap);
    CGImageRelease(ref);
    
    return newImage;
}


+ (void)makeCPModuleButton:(UIButton*)button{
    
    CGFloat fontSize = IS_IPAD ? 18.f : 14.f;
    
    [button setBackgroundImage:[[UIImage imageNamed:@"CPModuleButtonStretchable.png"]
                                          stretchableImageWithLeftCapWidth:9 topCapHeight:22] forState:UIControlStateNormal];
    [button setBackgroundImage:[[UIImage imageNamed:@"CPModuleButtonStretchableDisabled.png"]
                                stretchableImageWithLeftCapWidth:9 topCapHeight:22] forState:UIControlStateDisabled];
    [button.titleLabel setFont: [UIFont fontWithName:@"HelveticaNeue-Bold" size:fontSize]];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    [button setTintColor:[UIColor grayColor]];
    [button.titleLabel setShadowColor: [UIColor colorWithWhite:0.2f alpha:0.8f]];
    [button.titleLabel setShadowOffset: CGSizeMake(0.0f, -1.0f)];
    [button setNeedsDisplay];
}


+ (void)makeModeButton:(UIButton*)button{
    
    CGFloat fontSize = IS_IPAD ? 20.f : 14.f;
    
    [button setBackgroundImage:[[UIImage imageNamed:@"CPModuleButtonStretchable.png"]
                                stretchableImageWithLeftCapWidth:9 topCapHeight:22] forState:UIControlStateNormal];
    [button setBackgroundImage:[[UIImage imageNamed:@"CPModuleButtonStretchableDisabled.png"]
                                stretchableImageWithLeftCapWidth:9 topCapHeight:22] forState:UIControlStateDisabled];
    [button.titleLabel setFont: [UIFont fontWithName:@"HelveticaNeue-Bold" size:fontSize]];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    [button setTintColor:[UIColor grayColor]];
    [button.titleLabel setShadowColor: [UIColor blackColor]];
    [button.titleLabel setShadowOffset: CGSizeMake(0.0f, -1.0f)];
    [button setNeedsDisplay];
}


+ (void)makeCPGridButton:(UIButton*)button{
    
    CGFloat fontSize = IS_IPAD ? 16.f : 14.f;
    
    [button setBackgroundImage:[[UIImage imageNamed:@"CPGridButtonStretchable.png"]
                                stretchableImageWithLeftCapWidth:10 topCapHeight:10] forState:UIControlStateNormal];
    [button.titleLabel setFont: [UIFont fontWithName:@"HelveticaNeue-Bold" size:fontSize]];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor darkGrayColor] forState:UIControlStateDisabled];
    [button setTintColor:[UIColor grayColor]];
    [button.titleLabel setShadowColor: [UIColor colorWithWhite:0.2f alpha:0.8f]];
    [button.titleLabel setShadowOffset: CGSizeMake(0.0f, -1.0f)];
    [button setNeedsDisplay];
}


+ (void)makeCPHelpButton:(UIButton*)button{
    
    CGFloat fontSize = 16.f;
    
    [button setBackgroundImage:[[UIImage imageNamed:@"CPModuleButtonStretchable.png"]
                                stretchableImageWithLeftCapWidth:9 topCapHeight:22] forState:UIControlStateNormal];
    [button setBackgroundImage:[[UIImage imageNamed:@"CPModuleButtonStretchableDisabled.png"]
                                stretchableImageWithLeftCapWidth:9 topCapHeight:22] forState:UIControlStateDisabled];
    [button.titleLabel setFont: [UIFont fontWithName:@"HelveticaNeue-Bold" size:fontSize]];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    [button setTintColor:[UIColor grayColor]];
    [button.titleLabel setShadowColor: [UIColor colorWithWhite:0.2f alpha:0.8f]];
    [button.titleLabel setShadowOffset: CGSizeMake(0.0f, -1.0f)];
    [button setNeedsDisplay];
}


- (void)listSubviewsOfView:(UIView*)view {
    
    [self listSubviewsOfView:view withIndent:nil];
}


- (void)listSubviewsOfView:(UIView*)view withIndent:(NSString*)indent{
    
    if (indent == nil) indent = @"";
    else indent = [indent stringByAppendingString:@" "];
    
    // Get the subviews of the view
    NSArray *subviews = [view subviews];
    
    // Return if there are no subviews
    if ([subviews count] == 0) return;
    
    for (UIView *subview in subviews) {
        
        NSLog(@"%@%@", indent, [subview class]);
        
        // List the subviews of subview
        [self listSubviewsOfView:subview withIndent:indent];
    }
    
}


static inline double radians (double degrees){

    return degrees * M_PI/180;

}


@end
























