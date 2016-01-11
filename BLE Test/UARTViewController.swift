
//  UARTViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 9/30/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit
import Dispatch


protocol UARTViewControllerDelegate: HelpViewControllerDelegate {
    
    func sendData(newData:NSData)
    
}


class UARTViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate, MqttManagerDelegate, UIPopoverControllerDelegate {

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
    
    private var mqttBarButtonItem : UIBarButtonItem?
    private var mqttBarButtonItemImageView : UIImageView?
    private var mqttSettingsPopoverController:UIPopoverController?
    
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
    private var mqttFontDict:NSDictionary!
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
        
        self.init(nibName: nibName as String, bundle: NSBundle.mainBundle())
        
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
        mqttFontDict = NSDictionary(objects: [consoleFont!, UIColor(red: 85/255, green: 85/255, blue: 85/255, alpha: 1)], forKeys: [NSFontAttributeName,NSForegroundColorAttributeName])
    
        //fix for UITextView
        consoleView.layoutManager.allowsNonContiguousLayout = false
        
        // add MQTT button to the navigation bar
        //mqttBarButtonItem = UIBarButtonItem(image: UIImage(named: "mqtt_disconnected"), style: .Plain, target: self, action: "onClickMqtt");
        mqttBarButtonItemImageView = UIImageView(image: UIImage(named: "mqtt_disconnected")!.tintWithColor(self.view.tintColor))      // use a uiimageview as custom barbuttonitem to allow frame animations
        mqttBarButtonItemImageView!.tintColor = self.view.tintColor
        mqttBarButtonItemImageView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "onClickMqtt"))
        mqttBarButtonItem = UIBarButtonItem(customView: mqttBarButtonItemImageView!)
        
        self.navigationItem.rightBarButtonItems?.append(mqttBarButtonItem!);
        
        // MQTT init
        let mqttManager = MqttManager.sharedInstance
        if (MqttSettings.sharedInstance.isConnected) {
            mqttManager.delegate = self
            mqttManager.connectFromSavedSettings()
        }
    }
    
    
    deinit {
        let mqttManager = MqttManager.sharedInstance
        mqttManager.disconnect()
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

        // MQTT
        MqttManager.sharedInstance.delegate = self
        updateMqttStatus()

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
            printLog(self, funcName: "updateConsoleWithIncomingData", logString: newString! as String)
            
            //Check for notification command & send if needed
//            if newString?.containsString(self.notificationCommandString) == true {
//                printLog(self, "Checking for notification", "does contain match")
//                let msgString = newString!.stringByReplacingOccurrencesOfString(self.notificationCommandString, withString: "")
//                self.sendNotification(msgString)
//            }
            
            
            //Update ASCII text on background thread A
            let appendString = "" // or "\n"
            let attrAString = NSAttributedString(string: ((newString! as String)+appendString), attributes: self.redFontDict as? [String : AnyObject])
            let newAsciiText = NSMutableAttributedString(attributedString: self.consoleAsciiText!)
            newAsciiText.appendAttributedString(attrAString)
            
            let newHexString = newData.hexRepresentationWithSpaces(true)
            let attrHString = NSAttributedString(string: newHexString as String, attributes: self.redFontDict as? [String : AnyObject])
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
    
    
    func updateConsoleWithOutgoingString(newString:NSString, wasReceivedFromMqtt : Bool){
        
        //Write new sent data to the console text view
        let textColorDict = wasReceivedFromMqtt ? mqttFontDict:blueFontDict
        
        //Update ASCII text
        let appendString = "" // or "\n"
        let attrString = NSAttributedString(string: (newString as String) + appendString, attributes: textColorDict as? [String : AnyObject])
        let newAsciiText = NSMutableAttributedString(attributedString: self.consoleAsciiText!)
        newAsciiText.appendAttributedString(attrString)
        consoleAsciiText = newAsciiText
        
        
        //Update Hex text
        let attrHexString = NSAttributedString(string: newString.toHexSpaceSeparated() as String, attributes: textColorDict as? [String : AnyObject])
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
     
        sendUartMessage(newString, wasReceivedFromMqtt: false)
        
//        inputField.text = ""
        inputTextView.text = ""
        
      
        
    }
    
    
    func sendUartMessage(message: NSString, wasReceivedFromMqtt: Bool) {
        // MQTT publish to TX
        let mqttSettings = MqttSettings.sharedInstance
        if(mqttSettings.isPublishEnabled) {
            if let topic = mqttSettings.getPublishTopic(MqttSettings.PublishFeed.TX.rawValue) {
                let qos = mqttSettings.getPublishQos(MqttSettings.PublishFeed.TX.rawValue)
                MqttManager.sharedInstance.publish(message as String, topic: topic, qos: qos)
            }
        }
        
        // Send to uart
        if (!wasReceivedFromMqtt || mqttSettings.subscribeBehaviour == .Transmit) {
            let data = NSData(bytes: message.UTF8String, length: message.length)
            delegate?.sendData(data)
        }
        
        // Show on UI
        if echoLocal == true {
            updateConsoleWithOutgoingString(message, wasReceivedFromMqtt: wasReceivedFromMqtt)
        }
    }
    
    
    @IBAction func echoSwitchValueChanged(sender:UISwitch) {
        
        let boo = sender.on
        uartShouldEchoLocalSet(boo)
        echoLocal = boo
        
    }
    
    
    func receiveData(newData : NSData){
        
        if (isViewLoaded() && view.window != nil) {
            // MQTT publish to RX
            let mqttSettings = MqttSettings.sharedInstance
            if(mqttSettings.isPublishEnabled) {
                if let message = NSString(data: newData, encoding: NSUTF8StringEncoding) {
                    if let topic = mqttSettings.getPublishTopic(MqttSettings.PublishFeed.RX.rawValue) {
                        let qos = mqttSettings.getPublishQos(MqttSettings.PublishFeed.RX.rawValue)
                        MqttManager.sharedInstance.publish(message as String, topic: topic, qos: qos)
                    }
                }
            }
            
            // Update UI
            updateConsoleWithIncomingData(newData)
        }
        
    }
    
    
    func keyboardWillHide(sender : NSNotification) {
        
        if let keyboardSize = (sender.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
            
            let yOffset:CGFloat = keyboardSize.height
            let oldRect:CGRect = msgInputView.frame
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
            printLog(self, funcName: "keyboardWillHide", logString: "Keyboard frame not found")
        }
        
    }
    
    
    func keyboardWillShow(sender : NSNotification) {
    
        //Raise input view when keyboard shows
    
        if keyboardIsShown {
            return
        }
    
        //calculate new position for input view
        if let keyboardSize = (sender.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
            
            let yOffset:CGFloat = keyboardSize.height
            let oldRect:CGRect = msgInputView.frame
            msgInputYContraint?.constant -= yOffset     //Using autolayout on iPad
            
//            if (IS_IPAD){
            
                let newRect = CGRectMake(oldRect.origin.x, oldRect.origin.y - yOffset, oldRect.size.width, oldRect.size.height)
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
            printLog(self, funcName: "keyboardWillHide", logString: "Keyboard frame not found")
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

    
    // MARK: - MQTT
    
    
    func onClickMqtt() {
        let mqqtSettingsViewController = MqttSettingsViewController(nibName: "MqttSettingsViewController", bundle: nil)

        if (IS_IPHONE) {
            self.navigationController?.pushViewController(mqqtSettingsViewController, animated: true)
        }
        else if (IS_IPAD) {
            mqttSettingsPopoverController?.dismissPopoverAnimated(true)
            
            mqttSettingsPopoverController = UIPopoverController(contentViewController: mqqtSettingsViewController)
            mqttSettingsPopoverController?.delegate = self
            mqqtSettingsViewController.view.backgroundColor = UIColor.darkGrayColor()
            mqqtSettingsViewController.preferredContentSize = CGSizeMake(400, 0)
            
            let aFrame:CGRect = mqttBarButtonItem!.customView!.frame
            mqttSettingsPopoverController?.presentPopoverFromRect(aFrame,
                inView: mqttBarButtonItem!.customView!.superview!,
                permittedArrowDirections: UIPopoverArrowDirection.Any,
                animated: true)
        }
            }
    
    func updateMqttStatus() {
        if let imageView = mqttBarButtonItemImageView {
            let status = MqttManager.sharedInstance.status
            let tintColor = self.view.tintColor
            
            switch (status) {
            case .Connecting:
                let imageFrames = [
                    UIImage(named:"mqtt_connecting1")!.tintWithColor(tintColor),
                    UIImage(named:"mqtt_connecting2")!.tintWithColor(tintColor),
                    UIImage(named:"mqtt_connecting3")!.tintWithColor(tintColor)
                ]
                imageView.animationImages = imageFrames
                imageView.animationDuration = 0.5 * Double(imageFrames.count)
                imageView.animationRepeatCount = 0;
                imageView.startAnimating()
                
            case .Connected:
                imageView.stopAnimating()
                imageView.image = UIImage(named:"mqtt_connected")!.tintWithColor(tintColor)
                
            default:
                imageView.stopAnimating()
                imageView.image = UIImage(named:"mqtt_disconnected")!.tintWithColor(tintColor)
            }
        }
    }
    
    // MARK: MqttManagerDelegate
    
    func onMqttConnected() {
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.updateMqttStatus()
            })
    }
    
    func onMqttDisconnected() {
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.updateMqttStatus()
            })
    }
    
    func onMqttMessageReceived(message : String, topic: String) {
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.sendUartMessage((message as NSString), wasReceivedFromMqtt: true)
            })
    }
    
    func onMqttError(message : String) {
        let alert = UIAlertController(title:"Error", message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    // MARK: UIPopoverControllerDelegate
    
    func popoverControllerDidDismissPopover(popoverController: UIPopoverController) {
        // MQTT
        MqttManager.sharedInstance.delegate = self
        updateMqttStatus()
    }

}





