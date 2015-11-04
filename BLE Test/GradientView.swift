//
//  GradientView.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 6/29/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

class GradientView: UIView {
    
    var endColor:UIColor {
        didSet{
            self.setNeedsDisplay()
        }
    }
    
//    func setEndColor(newColor:UIColor){
//        
//        endColor = newColor
//        
//        self.setNeedsDisplay()
//    }
    required init(coder aDecoder: NSCoder) {
        endColor = UIColor.whiteColor()
        super.init(coder: aDecoder)!
    }
    
    override func drawRect(rect: CGRect) {
        
        // Create a gradient from white to red
        var red:CGFloat = 0.0
        var green:CGFloat = 0.0
        var blue:CGFloat = 0.0
        var alpha:CGFloat = 0.0
        endColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let colors:[CGFloat] = [
            0.0, 0.0, 0.0, 1.0,
            red, green, blue, alpha]
        
        let baseSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradientCreateWithColorComponents(baseSpace, colors, nil, 2)
//        CGColorSpaceRelease(baseSpace)
//        baseSpace = nil
        
        let context = UIGraphicsGetCurrentContext()
        
        CGContextSaveGState(context)
//        CGContextClip(context) 
        
        let startPoint = CGPointMake(CGRectGetMinX(rect), CGRectGetMidY(rect))
        let endPoint = CGPointMake(CGRectGetMaxX(rect), CGRectGetMidY(rect))
        
        CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, CGGradientDrawingOptions.DrawsBeforeStartLocation)
//        CGGradientRelease(gradient), gradient = NULL
        
        CGContextRestoreGState(context)
        
        //    CGContextDrawPath(context, kCGPathStroke);
    }
    

}
