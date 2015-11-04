//
//  HelpViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/6/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit


@objc protocol HelpViewControllerDelegate : Any{
    
    func helpViewControllerDidFinish(controller : HelpViewController)
    
}


class HelpViewController : UIViewController {
    
    
    @IBOutlet var delegate : HelpViewControllerDelegate?
    @IBOutlet var versionLabel : UILabel?
    @IBOutlet var textView : UITextView?
    
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    
//    override init() {
//        super.init()
//    }
    
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        preferredContentSize = CGSizeMake(320.0, 480.0)   //popover size on iPad
        
    }
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        if (IS_IPAD == true) {
            self.preferredContentSize = self.view.frame.size;   //popover size on iPad
        }
        
        else if (IS_IPHONE == true) {
            self.modalTransitionStyle = UIModalTransitionStyle.FlipHorizontal
        }
        
        //Set the app version # in the Help/Info view
        let versionString: String = "v" + ((NSBundle.mainBundle().infoDictionary)?["CFBundleShortVersionString"] as! String!)
        
        //        let bundleVersionString: String =  "b" + ((NSBundle.mainBundle().infoDictionary)?["CFBundleVersion"] as String!)  // Build number
//        versionLabel?.text =  versionString + " " + bundleVersionString
        
        versionLabel?.text =  versionString
        
    }
    
    
    override func viewDidAppear(animated : Bool){
        super.viewDidAppear(animated)
        
        textView?.flashScrollIndicators()  //indicate add'l content below screen
        
        
    }
    
    
    @IBAction func done(sender : AnyObject) {
        
        delegate?.helpViewControllerDidFinish(self)
        
    }
    
    
}