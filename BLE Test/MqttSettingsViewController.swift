//
//  MqttSettingsViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 28/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit


class MqttSettingsViewController: KeyboardAwareViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource, MqttManagerDelegate {
    // Constants
    private static let defaultHeaderCellHeight : CGFloat = 50;
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!
    @IBOutlet var pickerView: UIPickerView!
    @IBOutlet var pickerToolbar: UIToolbar!
    
    // Data
    private enum SettingsSections : Int {
        case Status = 0
        case Server = 1
        case Publish = 2
        case Subscribe = 3
        case Advanced = 4
    }
    
    private enum PickerViewType {
        case Qos
        case Action
    }
    
    private var selectedIndexPath = NSIndexPath(forRow: 0, inSection: 0)
    private var pickerViewType = PickerViewType.Qos
    private var previousSubscriptionTopic : String?
    
    //
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "MQTT Settings"
        
        // Register custom cell nibs
        baseTableView.registerNib(UINib(nibName: "MqttSettingsHeaderCell", bundle: nil), forCellReuseIdentifier: "HeaderCell")
        baseTableView.registerNib(UINib(nibName: "MqttSettingsStatusCell", bundle: nil), forCellReuseIdentifier: "StatusCell")
        baseTableView.registerNib(UINib(nibName: "MqttSettingsEditValueCell", bundle: nil), forCellReuseIdentifier: "EditValueCell")
        baseTableView.registerNib(UINib(nibName: "MqttSettingsEditValuePickerCell", bundle: nil), forCellReuseIdentifier: "EditValuePickerCell")
        baseTableView.registerNib(UINib(nibName: "MqttSettingsEditPickerCell", bundle: nil), forCellReuseIdentifier: "EditPickerCell")
        
        // Note: baseTableView is grouped to make the section titles no to overlap the section rows
        baseTableView.backgroundColor = UIColor.clearColor()
        
        previousSubscriptionTopic = MqttSettings.sharedInstance.subscribeTopic
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        MqttManager.sharedInstance.delegate = self
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)

        if (IS_IPAD) {
            self.view.endEditing(true)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func headerTitleForSection(section: Int) -> String? {
        switch(section) {
        case SettingsSections.Status.rawValue: return nil
        case SettingsSections.Server.rawValue: return "Server"
        case SettingsSections.Publish.rawValue: return "Publish"
        case SettingsSections.Subscribe.rawValue: return "Subscribe"
        case SettingsSections.Advanced.rawValue: return "Advanced"
        default: return nil
        }
    }

    func subscriptionTopicChanged(newTopic: String?, qos: MqttManager.MqttQos) {
        printLog(self, funcName: (__FUNCTION__), logString: "subscription changed from: \(previousSubscriptionTopic) to: \(newTopic)");
        
        let mqttManager = MqttManager.sharedInstance
        if (previousSubscriptionTopic != nil) {
            mqttManager.unsubscribe(previousSubscriptionTopic!)
        }
        if (newTopic != nil) {
            mqttManager.subscribe(newTopic!, qos: qos)
        }
        previousSubscriptionTopic = newTopic
    }
    
    func indexPathFromTag(tag: Int) -> NSIndexPath {
        // To help identify each textfield a tag is added with this format: 12 (1 is the section, 2 is the row)
        return NSIndexPath(forRow: tag % 10, inSection: tag / 10)
    }
    
    func tagFromIndexPath(indexPath : NSIndexPath) -> Int {
        // To help identify each textfield a tag is added with this format: 12 (1 is the section, 2 is the row)
        return indexPath.section * 10 + indexPath.row
    }
    
    // MARK: - UITableViewDelegate
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return SettingsSections.Advanced.rawValue + 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch(section) {
        case SettingsSections.Status.rawValue: return 1
        case SettingsSections.Server.rawValue: return 2
        case SettingsSections.Publish.rawValue: return 2
        case SettingsSections.Subscribe.rawValue: return 2
        case SettingsSections.Advanced.rawValue: return 2
        default: return 0
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        let section = indexPath.section
        let row = indexPath.row;
        
        let cell : UITableViewCell
        
        if(section == SettingsSections.Status.rawValue) {
            
            let statusCell = tableView.dequeueReusableCellWithIdentifier("StatusCell", forIndexPath: indexPath) as! MqttSettingsStatusCell
            
            let status = MqttManager.sharedInstance.status
            let showWait = status == .Connecting || status == .Disconnecting
            if (showWait) {
                statusCell.waitView.startAnimating()
            }else {
                statusCell.waitView.stopAnimating()
            }
            statusCell.actionButton.hidden = showWait
            
            let statusText : String;
            switch(status) {
            case .Connected: statusText = "Connected"
            case .Connecting: statusText = "Connecting..."
            case .Disconnecting: statusText = "Disconnecting..."
            case .Error: statusText = "Error"
            default: statusText = "Disconnected"
            }
            
            statusCell.statusLabel.text = statusText
            
            UIView.performWithoutAnimation({ () -> Void in      // Change title disabling animations (if enabled the user can see the old title for a moment)
                statusCell.actionButton.setTitle(status == .Connected ?"Disconnect":"Connect", forState: UIControlState.Normal)
                statusCell.layoutIfNeeded()
            })

            statusCell.onClickAction = {
                [unowned self] in

                // End editing
                self.view.endEditing(true)
                
                // Connect / Disconnect
                let mqttManager = MqttManager.sharedInstance
                let status = mqttManager.status
                if (status == .Disconnected || status == .None || status == .Error) {
                    mqttManager.connectFromSavedSettings()
                } else {
                    mqttManager.disconnect()
                    MqttSettings.sharedInstance.isConnected = false
                }
                
                self.baseTableView?.reloadData()
            }
            
            cell = statusCell
        }
        else {
            let mqttSettings = MqttSettings.sharedInstance
            let editValueCell : MqttSettingsEditValueCell
            
            switch(section) {
            case SettingsSections.Server.rawValue:
                editValueCell = tableView.dequeueReusableCellWithIdentifier("EditValueCell", forIndexPath: indexPath) as! MqttSettingsEditValueCell
                editValueCell.reset()
                
                let labels = ["Address:", "Port:"]
                editValueCell.nameLabel.text = labels[row]
                let valueTextField = editValueCell.valueTextField!      // valueTextField should exist on this cell
                if (row == 0) {
                    valueTextField.text = mqttSettings.serverAddress
                }
                else if (row == 1) {
                    valueTextField.placeholder = "\(MqttSettings.defaultServerPort)"
                    if (mqttSettings.serverPort != MqttSettings.defaultServerPort) {
                        valueTextField.text = "\(mqttSettings.serverPort)"
                    }
                    valueTextField.keyboardType = UIKeyboardType.NumberPad;
                }

            case SettingsSections.Publish.rawValue:
                editValueCell = tableView.dequeueReusableCellWithIdentifier("EditValuePickerCell", forIndexPath: indexPath) as! MqttSettingsEditValueCell
                editValueCell.reset()

                let labels = ["UART RX:", "UART TX:"]
                editValueCell.nameLabel.text = labels[row]
                
                let valueTextField = editValueCell.valueTextField!
                valueTextField.text = mqttSettings.getPublishTopic(row)
                
                let typeTextField = editValueCell.typeTextField!
                typeTextField.text = titleForQos(mqttSettings.getPublishQos(row))
                setupTextFieldForPickerInput(typeTextField, indexPath: indexPath)
                
            case SettingsSections.Subscribe.rawValue:
                editValueCell = tableView.dequeueReusableCellWithIdentifier(row==0 ? "EditValuePickerCell":"EditPickerCell", forIndexPath: indexPath) as! MqttSettingsEditValueCell
                editValueCell.reset()
                
                let labels = ["Topic:", "Action:"]
                editValueCell.nameLabel.text = labels[row]
                
                let typeTextField = editValueCell.typeTextField!
                if (row == 0) {
                    let valueTextField = editValueCell.valueTextField!
                    valueTextField.text = mqttSettings.subscribeTopic

                    typeTextField.text = titleForQos(mqttSettings.subscribeQos)
                    setupTextFieldForPickerInput(typeTextField, indexPath: indexPath)
                }
                else if (row == 1) {
                    typeTextField.text = titleForSubscribeBehaviour(mqttSettings.subscribeBehaviour)
                    setupTextFieldForPickerInput(typeTextField, indexPath: indexPath)
                }

            case SettingsSections.Advanced.rawValue:
                editValueCell = tableView.dequeueReusableCellWithIdentifier("EditValueCell", forIndexPath: indexPath) as! MqttSettingsEditValueCell
                editValueCell.reset()

                let labels = ["Username:", "Password:"]
                editValueCell.nameLabel.text = labels[row]
                
                let valueTextField = editValueCell.valueTextField!
                if (row == 0) {
                    valueTextField.text = mqttSettings.username
                }
                else if (row == 1) {
                    valueTextField.text = mqttSettings.password
                }

            default:
                editValueCell = tableView.dequeueReusableCellWithIdentifier("EditValueCell", forIndexPath: indexPath) as! MqttSettingsEditValueCell
                editValueCell.reset()
                
                break;
            }

            if let valueTextField = editValueCell.valueTextField {
                valueTextField.returnKeyType = UIReturnKeyType.Next
                valueTextField.delegate = self;
                valueTextField.tag = tagFromIndexPath(indexPath)
            }

            cell = editValueCell
        }

        return cell
    }
    
    func setupTextFieldForPickerInput(textField : UITextField, indexPath : NSIndexPath) {
        textField.inputView = pickerView
        textField.inputAccessoryView = pickerToolbar
        textField.delegate = self
        textField.tag = tagFromIndexPath(indexPath);
        textField.textColor = self.view.tintColor
        textField.tintColor = UIColor.clearColor()  // remove caret
    }
    
    func titleForSubscribeBehaviour(behaviour: MqttSettings.SubscribeBehaviour) -> String {
        switch(behaviour) {
        case .LocalOnly: return "Local Only"
        case .Transmit: return "Transmit"
        }
    }
    
    func titleForQos(qos: MqttManager.MqttQos) -> String {
        switch(qos) {
        case .AtLeastOnce : return "At Least Once"
        case .AtMostOnce : return "At Most Once"
        case .ExactlyOnce : return "Exactly Once"
        }
    }
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
            cell.backgroundColor = UIColor.clearColor()
    }

    // MARK: UITableViewDataSource
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerCell = tableView.dequeueReusableCellWithIdentifier("HeaderCell") as! MqttSettingsHeaderCell
        headerCell.backgroundColor = UIColor.clearColor()
        headerCell.nameLabel.text = headerTitleForSection(section)
        let hasSwitch = section == SettingsSections.Publish.rawValue || section == SettingsSections.Subscribe.rawValue;
        headerCell.isOnSwitch.hidden = !hasSwitch;
        if (hasSwitch) {
            let mqttSettings = MqttSettings.sharedInstance;
            if (section == SettingsSections.Publish.rawValue) {
                headerCell.isOnSwitch.on = mqttSettings.isPublishEnabled
                headerCell.isOnChanged = { isOn in
                    mqttSettings.isPublishEnabled = isOn;
                }
            }
            else if (section == SettingsSections.Subscribe.rawValue) {
                headerCell.isOnSwitch.on = mqttSettings.isSubscribeEnabled
                headerCell.isOnChanged = { [unowned self] isOn in
                    mqttSettings.isSubscribeEnabled = isOn;
                    self.subscriptionTopicChanged(nil, qos: mqttSettings.subscribeQos)
                }
            }
        }
        
        return headerCell;
    }

    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if (headerTitleForSection(section) == nil) {
            UITableViewAutomaticDimension
            return 0.5;       // no title, so 0 height (hack: set to 0.5 because 0 height is not correctly displayed)
        }
        else {
            return MqttSettingsViewController.defaultHeaderCellHeight;
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        // Focus on textfield if present
        if let editValueCell = tableView.cellForRowAtIndexPath(indexPath) as? MqttSettingsEditValueCell {
            editValueCell.valueTextField?.becomeFirstResponder()
        }
    }

    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        
        // Go to next textField
        if (textField.returnKeyType == UIReturnKeyType.Next) {
            let tag = textField.tag;
            var nextView = baseTableView.viewWithTag(tag+1)
            if (nextView == nil || nextView!.inputView != nil) {
                nextView = baseTableView.viewWithTag(((tag/10)+1)*10)
            }
            if let next = nextView {
                next.becomeFirstResponder()
                
                // Scroll to show it
                baseTableView.scrollToRowAtIndexPath(indexPathFromTag(next.tag), atScrollPosition: .Middle, animated: true)
            }
            else {
                textField.resignFirstResponder()
            }
        }
        
        return true;
    }
    
    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        // Update selected indexpath
        selectedIndexPath = indexPathFromTag(textField.tag)
        
        // Setup inputView if needed
        if (textField.inputView != nil) {
            // Setup valueTextField
            let isAction = selectedIndexPath.section ==  SettingsSections.Subscribe.rawValue && selectedIndexPath.row == 1
            pickerViewType = isAction ? PickerViewType.Action:PickerViewType.Qos
            pickerView .reloadAllComponents()
            pickerView.tag = textField.tag      // pass the current textfield tag to the pickerView
            //pickerView.selectRow(<#row: Int#>, inComponent: 0, animated: false)
        }
        
        return true;
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        if (textField.inputView == nil) {       // textfields with input view are not managed here
            let indexPath = indexPathFromTag(textField.tag)
            let section = indexPath.section
            let row = indexPath.row
            let mqttSettings = MqttSettings.sharedInstance;
            
            // Update settings with new values
            switch(section) {
            case SettingsSections.Server.rawValue:
                if (row == 0) {         // Server Address
                    mqttSettings.serverAddress = textField.text
                }
                else if (row == 1) {    // Server Port
                    if let port = Int(textField.text!) {
                        mqttSettings.serverPort = port
                    }
                    else {
                        textField.text = nil;
                        mqttSettings.serverPort = MqttSettings.defaultServerPort
                    }
                }
                
            case SettingsSections.Publish.rawValue:
                mqttSettings.setPublishTopic(row, topic: textField.text)
                
            case SettingsSections.Subscribe.rawValue:
                let topic = textField.text
                mqttSettings.subscribeTopic = topic
                subscriptionTopicChanged(topic, qos: mqttSettings.subscribeQos)
                
            case SettingsSections.Advanced.rawValue:
                if (row == 0) {            // Username
                    mqttSettings.username = textField.text;
                }
                else if (row == 1) {      // Password
                    mqttSettings.password = textField.text;
                }
                
            default:
                break;
            }
        }
    }

     // MARK: - KeyboardAwareViewController
    override func keyboardPositionChanged(keyboardFrame : CGRect, keyboardShown : Bool) {
        super.keyboardPositionChanged(keyboardFrame, keyboardShown:keyboardShown )
        
        if (IS_IPHONE) {
            let height = keyboardFrame.height
            baseTableView.contentInset =  UIEdgeInsetsMake(0, 0, height, 0);
        }
        
        //printLog(self, (__FUNCTION__), "keyboard size: \(height) appearing: \(keyboardShown)");
        if (keyboardShown) {
            baseTableView.scrollToRowAtIndexPath(selectedIndexPath, atScrollPosition: .Middle, animated: true)
        }
    }
    
    // MARK: - Input Toolbar
    
    @IBAction func onClickInputToolbarDone(sender: AnyObject) {
        let selectedPickerRow = pickerView.selectedRowInComponent(0);
        
        let indexPath = indexPathFromTag(pickerView.tag)
        let section = indexPath.section
        let row = indexPath.row
        let mqttSettings = MqttSettings.sharedInstance;

        // Update settings with new values
        switch(section) {
        case SettingsSections.Publish.rawValue:
            mqttSettings.setPublishQos(row, qos: MqttManager.MqttQos(rawValue: selectedPickerRow)!)

        case SettingsSections.Subscribe.rawValue:
            if (row == 0) {     // Topic Qos
                let qos = MqttManager.MqttQos(rawValue: selectedPickerRow)!
                mqttSettings.subscribeQos =  qos
                subscriptionTopicChanged(mqttSettings.subscribeTopic, qos: qos)
            }
            else if (row == 1) {    // Action
                mqttSettings.subscribeBehaviour = MqttSettings.SubscribeBehaviour(rawValue: selectedPickerRow)!
            }
        default:
            break;
        }

        // End editing
        self.view.endEditing(true)
        baseTableView.reloadData()      // refresh values
    }
    
    
    // MARK: - UIPickerViewDataSource

    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerViewType == .Action ? 2:3
    }

    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String?
    {
//        let labels : [String];

        switch(pickerViewType) {
        case .Qos:
            return titleForQos(MqttManager.MqttQos(rawValue: row)!)
        case .Action:
            return titleForSubscribeBehaviour(MqttSettings.SubscribeBehaviour(rawValue: row)!)
        }
        
        
    }
    
    // MARK: UIPickerViewDelegate
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
    }
    
    // MARK: - MqttManagerDelegate
    
    func onMqttConnected() {
        // Update status
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.baseTableView.reloadData()
            })
    }
   
    func onMqttDisconnected() {
        // Update status
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.baseTableView.reloadData()
            })

    }
    
    func onMqttMessageReceived(message : String, topic: String) {
    }
    
    func onMqttError(message : String) {
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            let alert = UIAlertController(title:"Error", message: message, preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)
            
            // Update status
            self.baseTableView.reloadData()
            })
    }
}
