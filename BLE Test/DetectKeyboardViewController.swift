//
//  AutoScrollOnKeyboardViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 30/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

class KeyboardAwareViewController: UIViewController {
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        registerKeyboardNotifications(true)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        registerKeyboardNotifications(false)
    }
    
    func registerKeyboardNotifications(enable : Bool) {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        if (enable) {
            notificationCenter.addObserver(self, selector: "keyboardWillBeShown:", name: UIKeyboardWillShowNotification, object: nil)
            notificationCenter.addObserver(self, selector: "keyboardWillBeHidden:", name: UIKeyboardWillHideNotification, object: nil)
        } else {
            notificationCenter.removeObserver(self, name: UIKeyboardWillShowNotification, object: nil)
            notificationCenter.removeObserver(self, name: UIKeyboardWillHideNotification, object: nil)
        }
    }
    
    func keyboardWillBeShown(notification : NSNotification) {
        var info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
       
        keyboardPositionChanged(keyboardFrame, keyboardShown: true)
    }
    
    func keyboardWillBeHidden(notification : NSNotification) {
       keyboardPositionChanged(CGRectZero, keyboardShown: false)
    }
    
    func keyboardPositionChanged(keyboardFrame : CGRect, keyboardShown : Bool) {
        // to be implemented by subclass
    }
}
