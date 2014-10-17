
//  UARTViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 9/30/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit
import dispatch


@objc protocol UARTViewControllerDelegate: HelpViewControllerDelegate {
    
    func sendData(newData:NSData)
    
}


class UARTViewController: UIViewController, UITextFieldDelegate {

    enum ConsoleDataType {
        case LOGGING
        case RX
        case TX
    }
    
    enum ConsoleMode {
        case ASCII
        case HEX
    }
    
    weak var delegate:UARTViewControllerDelegate?
    @IBOutlet var helpViewController:HelpViewController!
    @IBOutlet weak var consoleView:UITextView!
    @IBOutlet weak var msgInputView:UIView!
    @IBOutlet var msgInputYContraint:NSLayoutConstraint?    //iPad
    @IBOutlet weak var inputField:UITextField!
    @IBOutlet weak var consoleCopyButton:UIButton!
    @IBOutlet weak var consoleClearButton:UIButton!
    @IBOutlet weak var consoleModeControl:UISegmentedControl!
    
    private var keyboardIsShown:Bool = false
    private var consoleAsciiText:NSAttributedString? = NSAttributedString(string: "")
    private var consoleHexText: NSAttributedString? = NSAttributedString(string: "")
    private let backgroundQueue = dispatch_queue_create("com.adafruit.bluefruitconnect.bgqueue", nil)
    private var lastScroll:CFTimeInterval = 0.0
    private let scrollIntvl:CFTimeInterval = 1.0
    private var blueFontDict:NSDictionary!
    private var redFontDict:NSDictionary!
    private let unkownCharString:NSString = "�"
    private let kKeyboardAnimationDuration = 0.3
    
    
    convenience init(aDelegate:UARTViewControllerDelegate){
        
        //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
        
        var nibName:NSString
        
        if IS_IPHONE_4{
            nibName = "UARTViewController_iPhone"
        }
        else if IS_IPHONE_5{
            nibName = "UARTViewController_iPhone568px"
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
        
        //retrieve console font
        let consoleFont = consoleView.font
        blueFontDict = NSDictionary(objects: [consoleFont!, UIColor.blueColor()], forKeys: [NSFontAttributeName,NSForegroundColorAttributeName])
        redFontDict = NSDictionary(objects: [consoleFont!, UIColor.redColor()], forKeys: [NSFontAttributeName,NSForegroundColorAttributeName])
        
    }
    
    
    override func didReceiveMemoryWarning(){
        
        super.didReceiveMemoryWarning()
    
        clearConsole(self)
        
    }
    
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        //register for keyboard notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillShow:"), name: "UIKeyboardWillShowNotification", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("keyboardWillHide:"), name: "UIKeyboardWillHideNotification", object: nil)
        
        //register for textfield notifications
        //        NSNotificationCenter.defaultCenter().addObserver(self, selector: "textFieldDidChange", name: "UITextFieldTextDidChangeNotification", object:self.view.window)
        
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
            
            //Update ASCII text on background thread A
            
            let attrAString = NSAttributedString(string: (newString+"\n"), attributes: self.redFontDict)
            let newAsciiText = NSMutableAttributedString(attributedString: self.consoleAsciiText!)
            newAsciiText.appendAttributedString(attrAString)
            
            let newHexString = newData.hexRepresentationWithSpaces(true)
            let attrHString = NSAttributedString(string: newHexString, attributes: self.redFontDict)
            let newHexText = NSMutableAttributedString(attributedString: self.consoleHexText!)
            newHexText.appendAttributedString(attrHString)
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.updateConsole(newAsciiText, hexText: newHexText)
            })
        })
        
    }
    
    
    func updateConsole(asciiText: NSAttributedString, hexText: NSAttributedString){
        
        consoleAsciiText = asciiText
        consoleHexText = hexText
        
        
        //scroll output to bottom
        let time = CACurrentMediaTime()
        if ((time - lastScroll) > scrollIntvl) {
            
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
            
            scrollConsoleToBottom()
            lastScroll = time
        }
        
        //    [self scrollConsoleToBottom]
        
    }
    
    
    func scrollConsoleToBottom() {
    
//        let caretRect = consoleView.caretRectForPosition(consoleView.endOfDocument)
//        consoleView.scrollRectToVisible(caretRect, animated: true)
    
        consoleView.scrollRangeToVisible(NSMakeRange(countElements(consoleView.text)-1, 1))
//        consoleView.scrollEnabled = false
//        consoleView.scrollEnabled = true
        
        updateConsoleButtons()
    
    }
    
    
    func updateConsoleWithOutgoingString(newString:NSString){
        
        //Write new sent data to the console text view
        
        //Update ASCII text
        let attrString = NSAttributedString(string: (newString+"\n"), attributes: blueFontDict )
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
        scrollConsoleToBottom()
        
    }
 
    
    func updateConsoleButtons(){
        
        //Disable console buttons if console has no text
        
        let enabled = !(consoleView.text == "")
        consoleCopyButton.enabled = enabled
        consoleClearButton.enabled = enabled
        
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
        
        updateConsoleButtons()
        
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
    
    
    func sendMessage(sender:AnyObject){
        
//        sendButton.enabled = false
        
        if (inputField.text == ""){
            return
        }
        
        let newString:NSString = inputField.text
        let data = NSData(bytes: newString.UTF8String, length: newString.length)
        delegate?.sendData(data)
        
        inputField.text = ""
        
        updateConsoleWithOutgoingString(newString)
        
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
            
            if IS_IPAD {
                msgInputYContraint?.constant += yOffset     //Using autolayout on iPad
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
            println("keyboardWillHide - Keyboard frame not found")
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
            if (IS_IPAD){
                msgInputYContraint?.constant -= yOffset     //Using autolayout on iPad
                var newRect = CGRectMake(oldRect.origin.x, oldRect.origin.y - yOffset, oldRect.size.width, oldRect.size.height)
                self.msgInputView.frame = newRect   //frame animates automatically
            }
            
            else {  //iPhone
             
                var newRect = CGRectMake(oldRect.origin.x, oldRect.origin.y - yOffset, oldRect.size.width, oldRect.size.height)
                self.msgInputView.frame = newRect   //frame animates automatically
                
            }
            
            keyboardIsShown = true
            
        }
        
        else {
            println("keyboardWillShow - Keyboard frame not found")
        }
    
    }
    
    
    func textFieldShouldReturn(textField: UITextField) ->Bool {
        
        //Keyboard's Done button was tapped
        
        sendMessage(self)
        
        inputField.resignFirstResponder()
        
        return true
    }
    
    
    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        return true
    }
    
    
    func textFieldDidBeginEditing(textField: UITextField) {
        
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
    
    
}





