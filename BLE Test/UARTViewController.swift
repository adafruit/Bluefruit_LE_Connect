
//  UARTViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 9/30/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit
import dispatch


protocol UARTViewControllerDelegate: HelpViewControllerDelegate {
    
    func sendData(newData:NSData)
    
}


class UARTViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {

    enum ConsoleDataType {
        case Log
        case RX
        case TX
    }
    
    enum ConsoleMode {
        case ASCII
        case HEX
    }
    
    var delegate:UARTViewControllerDelegate?
    @IBOutlet var helpViewController:HelpViewController!
    @IBOutlet weak var consoleView:UITextView!
    @IBOutlet weak var msgInputView:UIView!
    @IBOutlet var msgInputYContraint:NSLayoutConstraint?    //iPad
    @IBOutlet weak var inputField:UITextField!
    @IBOutlet weak var inputTextView:UITextView!
    @IBOutlet weak var consoleCopyButton:UIButton!
    @IBOutlet weak var consoleClearButton:UIButton!
    @IBOutlet weak var consoleModeControl:UISegmentedControl!
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var echoSwitch:UISwitch!
    
    private var echoLocal:Bool = false
    private var keyboardIsShown:Bool = false
    private var consoleAsciiText:NSAttributedString? = NSAttributedString(string: "")
    private var consoleHexText: NSAttributedString? = NSAttributedString(string: "")
    private let backgroundQueue : dispatch_queue_t = dispatch_queue_create("com.adafruit.bluefruitconnect.bgqueue", nil)
    private var lastScroll:CFTimeInterval = 0.0
    private let scrollIntvl:CFTimeInterval = 1.0
    private var lastScrolledLength = 0
    private var scrollTimer:NSTimer?
    private var blueFontDict:NSDictionary!
    private var redFontDict:NSDictionary!
    private let unkownCharString:NSString = "�"
    private let kKeyboardAnimationDuration = 0.3
    private let notificationCommandString = "N!"
    
    
    convenience init(aDelegate:UARTViewControllerDelegate){
        
        //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
        
        var nibName:NSString
        
        if IS_IPHONE {
            nibName = "UARTViewController_iPhone"
        }
        else{   //IPAD
            nibName = "UARTViewController_iPad"
        }
        
        self.init(nibName: nibName, bundle: NSBundle.mainBundle())
        
        self.delegate = aDelegate
        self.title = "UART"
        
    }
    
    
    override func viewDidLoad(){
        
        //setup help view
        self.helpViewController.title = "UART Help"
        self.helpViewController.delegate = delegate
        
        //round corners on console
        self.consoleView.clipsToBounds = true
        self.consoleView.layer.cornerRadius = 4.0
        
        //round corners on inputTextView
        self.inputTextView.clipsToBounds = true
        self.inputTextView.layer.cornerRadius = 4.0
        
        //retrieve console font
        let consoleFont = consoleView.font
        blueFontDict = NSDictionary(objects: [consoleFont!, UIColor.blueColor()], forKeys: [NSFontAttributeName,NSForegroundColorAttributeName])
        redFontDict = NSDictionary(objects: [consoleFont!, UIColor.redColor()], forKeys: [NSFontAttributeName,NSForegroundColorAttributeName])
        
        //fix for UITextView
        consoleView.layoutManager.allowsNonContiguousLayout = false
        
    }
    
    
    override func didReceiveMemoryWarning(){
        
        super.didReceiveMemoryWarning()
    
        clearConsole(self)
        
    }
    
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        //update per prefs
        echoLocal = uartShouldEchoLocal()
        echoSwitch.setOn(echoLocal, animated: false)
        
        //register for keyboard notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillShow:"), name: "UIKeyboardWillShowNotification", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillHide:"), name: "UIKeyboardWillHideNotification", object: nil)
        
        //register for textfield notifications
        //        NSNotificationCenter.defaultCenter().addObserver(self, selector: "textFieldDidChange", name: "UITextFieldTextDidChangeNotification", object:self.view.window)
        
    }
    
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        scrollTimer?.invalidate()
        
        scrollTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: Selector("scrollConsoleToBottom:"), userInfo: nil, repeats: true)
        scrollTimer?.tolerance = 0.75
    }
    
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        scrollTimer?.invalidate()
    }
    
    
    override func viewWillDisappear(animated: Bool) {
        
        //unregister for keyboard notifications
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIKeyboardWillHideNotification, object: nil)
        
        super.viewWillDisappear(animated)
        
    }
    
    
    func updateConsoleWithIncomingData(newData:NSData) {
        
        //Write new received data to the console text view
        dispatch_async(backgroundQueue, { () -> Void in
            //convert data to string & replace characters we can't display
            let dataLength:Int = newData.length
            var data = [UInt8](count: dataLength, repeatedValue: 0)
            
            newData.getBytes(&data, length: dataLength)
            
            for index in 0...dataLength-1 {
                if (data[index] <= 0x1f) || (data[index] >= 0x80) { //null characters
                    if (data[index] != 0x9)       //0x9 == TAB
                        && (data[index] != 0xa)   //0xA == NL
                        && (data[index] != 0xd) { //0xD == CR
                            data[index] = 0xA9
                    }
                    
                }
            }
            
            
            let newString = NSString(bytes: &data, length: dataLength, encoding: NSUTF8StringEncoding)
            printLog(self, "updateConsoleWithIncomingData", newString!)
            
            //Check for notification command & send if needed
//            if newString?.containsString(self.notificationCommandString) == true {
//                printLog(self, "Checking for notification", "does contain match")
//                let msgString = newString!.stringByReplacingOccurrencesOfString(self.notificationCommandString, withString: "")
//                self.sendNotification(msgString)
//            }
            
            
            //Update ASCII text on background thread A
            let appendString = "" // or "\n"
            let attrAString = NSAttributedString(string: (newString!+appendString), attributes: self.redFontDict)
            let newAsciiText = NSMutableAttributedString(attributedString: self.consoleAsciiText!)
            newAsciiText.appendAttributedString(attrAString)
            
            let newHexString = newData.hexRepresentationWithSpaces(true)
            let attrHString = NSAttributedString(string: newHexString, attributes: self.redFontDict)
            let newHexText = NSMutableAttributedString(attributedString: self.consoleHexText!)
            newHexText.appendAttributedString(attrHString)
            
            
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.updateConsole(newAsciiText, hexText: newHexText)
//                self.insertConsoleText(attrAString.string, hexText: attrHString.string)
            })
        })
        
    }
    
    
    func updateConsole(asciiText: NSAttributedString, hexText: NSAttributedString){
        
        consoleAsciiText = asciiText
        consoleHexText = hexText
        
        
        //scroll output to bottom
//        let time = CACurrentMediaTime()
//        if ((time - lastScroll) > scrollIntvl) {
        
            //write string to console based on mode selection
            switch (consoleModeControl.selectedSegmentIndex) {
            case 0:
                //ASCII
                consoleView.attributedText = consoleAsciiText
                break
            case 1:
                //Hex
                consoleView.attributedText = consoleHexText
                break
            default:
                consoleView.attributedText = consoleAsciiText
                break
            }
            
//            scrollConsoleToBottom()
//            lastScroll = time
//        }
        
        
    }
    
    
    func scrollConsoleToBottom(timer:NSTimer) {
    
//        printLog(self, "scrollConsoleToBottom", "")
        
        let newLength = consoleView.attributedText.length
        
        if lastScrolledLength != newLength {
            
            consoleView.scrollRangeToVisible(NSMakeRange(newLength-1, 1))
            
            lastScrolledLength = newLength
            
        }
        
    }
    
    
    func updateConsoleWithOutgoingString(newString:NSString){
        
        //Write new sent data to the console text view
        
        //Update ASCII text
        let appendString = "" // or "\n"
        let attrString = NSAttributedString(string: (newString+appendString), attributes: blueFontDict )
        let newAsciiText = NSMutableAttributedString(attributedString: self.consoleAsciiText!)
        newAsciiText.appendAttributedString(attrString)
        consoleAsciiText = newAsciiText
        
        
        //Update Hex text
        let attrHexString = NSAttributedString(string: newString.toHexSpaceSeparated(), attributes: blueFontDict )
        let newHexText = NSMutableAttributedString(attributedString: self.consoleHexText!)
        newHexText.appendAttributedString(attrHexString)
        consoleHexText = newHexText
        
        //write string to console based on mode selection
        switch consoleModeControl.selectedSegmentIndex {
        case 0: //ASCII
            consoleView.attributedText = consoleAsciiText
            break
        case 1: //Hex
            consoleView.attributedText = consoleHexText
            break
        default:
            consoleView.attributedText = consoleAsciiText
            break
        }
        
        //scroll output
//        scrollConsoleToBottom()
        
    }
    
    
    func resetUI() {
        
        //Clear console & update buttons
        if consoleView != nil{
            clearConsole(self)
        }
        
        //Dismiss keyboard
        if inputField != nil {
            inputField.resignFirstResponder()
        }
        
    }
    
    
    @IBAction func clearConsole(sender : AnyObject) {
        
        consoleView.text = ""
        consoleAsciiText = NSAttributedString()
        consoleHexText = NSAttributedString()
        
    }
    
    
    @IBAction func copyConsole(sender : AnyObject) {
        
        let pasteBoard = UIPasteboard.generalPasteboard()
        pasteBoard.string = consoleView.text
        let cyan = UIColor(red: 32.0/255.0, green: 149.0/255.0, blue: 251.0/255.0, alpha: 1.0)
        consoleView.backgroundColor = cyan
        
        UIView.animateWithDuration(0.45, delay: 0.0, options: UIViewAnimationOptions.CurveEaseIn, animations: { () -> Void in
            self.consoleView.backgroundColor = UIColor.whiteColor()
        }) { (finished) -> Void in
            
        }
        
    }
    
    
    @IBAction func sendMessage(sender:AnyObject){
        
//        sendButton.enabled = false
        
//        if (inputField.text == ""){
//            return
//        }
//        let newString:NSString = inputField.text
        
        if (inputTextView.text == ""){
            return
        }
        let newString:NSString = inputTextView.text
        let data = NSData(bytes: newString.UTF8String, length: newString.length)
        delegate?.sendData(data)
        
//        inputField.text = ""
        inputTextView.text = ""
        
        if echoLocal == true {
            updateConsoleWithOutgoingString(newString)
        }
        
    }
    
    
    @IBAction func echoSwitchValueChanged(sender:UISwitch) {
        
        let boo = sender.on
        uartShouldEchoLocalSet(boo)
        echoLocal = boo
        
    }
    
    
    func receiveData(newData : NSData){
        
        if (isViewLoaded() && view.window != nil) {
            
            updateConsoleWithIncomingData(newData)
        }
        
    }
    
    
    func keyboardWillHide(sender : NSNotification) {
        
        if let keyboardSize = (sender.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
            
            var yOffset:CGFloat = keyboardSize.height
            var oldRect:CGRect = msgInputView.frame
            msgInputYContraint?.constant += yOffset
            
            if IS_IPAD {
                let newRect = CGRectMake(oldRect.origin.x, oldRect.origin.y + yOffset, oldRect.size.width, oldRect.size.height)
                msgInputView.frame = newRect    //frame animates automatically
            }
         
            else {
                
                let newRect = CGRectMake(oldRect.origin.x, oldRect.origin.y + yOffset, oldRect.size.width, oldRect.size.height)
                msgInputView.frame = newRect    //frame animates automatically
                
            }
            
            keyboardIsShown = false
            
        }
        else {
            printLog(self, "keyboardWillHide", "Keyboard frame not found")
        }
        
    }
    
    
    func keyboardWillShow(sender : NSNotification) {
    
        //Raise input view when keyboard shows
    
        if keyboardIsShown {
            return
        }
    
        //calculate new position for input view
        if let keyboardSize = (sender.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
            
            var yOffset:CGFloat = keyboardSize.height
            var oldRect:CGRect = msgInputView.frame
            msgInputYContraint?.constant -= yOffset     //Using autolayout on iPad
            
//            if (IS_IPAD){
            
                var newRect = CGRectMake(oldRect.origin.x, oldRect.origin.y - yOffset, oldRect.size.width, oldRect.size.height)
                self.msgInputView.frame = newRect   //frame animates automatically
//            }
//            
//            else {  //iPhone
//             
//                var newRect = CGRectMake(oldRect.origin.x, oldRect.origin.y - yOffset, oldRect.size.width, oldRect.size.height)
//                self.msgInputView.frame = newRect   //frame animates automatically
//                
//            }
            
            keyboardIsShown = true
            
        }
        
        else {
            printLog(self, "keyboardWillHide", "Keyboard frame not found")
        }
    
    }
    
    
    //MARK: UITextViewDelegate methods
    
    func textViewShouldBeginEditing(textView: UITextView) -> Bool {
        
        if textView === consoleView {
            //tapping on consoleview dismisses keyboard
            inputTextView.resignFirstResponder()
            return false
        }
        
        return true
    }
    
    
//    func textViewDidEndEditing(textView: UITextView) {
//        
//        sendMessage(self)
//        inputTextView.resignFirstResponder()
//        
//    }
    
    
    //MARK: UITextFieldDelegate methods
    
    func textFieldShouldReturn(textField: UITextField) ->Bool {
        
        //Keyboard's Done button was tapped
        
//        sendMessage(self)
//        inputField.resignFirstResponder()

        
        return true
    }
    
    
    @IBAction func consoleModeControlDidChange(sender : UISegmentedControl){
        
        //Respond to console's ASCII/Hex control value changed
        
        switch sender.selectedSegmentIndex {
        case 0:
            consoleView.attributedText = consoleAsciiText
            break
        case 1:
            consoleView.attributedText = consoleHexText
            break
        default:
            consoleView.attributedText = consoleAsciiText
            break
        }
        
    }
    
    
    func didConnect(){
        
        resetUI()
        
    }
    
    
    func sendNotification(msgString:String) {
        
        let note = UILocalNotification()
//        note.fireDate = NSDate().dateByAddingTimeInterval(2.0)
//        note.fireDate = NSDate()
        note.alertBody = msgString
        note.soundName =  UILocalNotificationDefaultSoundName
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            UIApplication.sharedApplication().presentLocalNotificationNow(note)
        })
        
        
    }
    
    
}





