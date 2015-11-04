//
//  ControllerViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 11/25/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import UIKit
import CoreMotion
import CoreLocation

protocol ControllerViewControllerDelegate: HelpViewControllerDelegate {
    
    func sendData(newData:NSData)
    
}

class ControllerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate, ColorPickerViewControllerDelegate {
    
    
    var delegate:UARTViewControllerDelegate?
    @IBOutlet var helpViewController:HelpViewController!
    @IBOutlet var controlPadViewController:UIViewController!
    @IBOutlet var buttons:[UIButton]!
    @IBOutlet var exitButton:UIButton!
    @IBOutlet var controlTable:UITableView!
    @IBOutlet var valueCell:SensorValueCell!
    
    var accelButton:BLESensorButton!
    var gyroButton: BLESensorButton!
    var magnetometerButton: BLESensorButton!
    var gpsButton:BLESensorButton!
    var quatButton:BLESensorButton!
    var buttonColor:UIColor!
    var exitButtonColor:UIColor!
    
    enum SensorType:Int {   //raw values used for reference
        case Qtn
        case Accel
        case Gyro
        case Mag
        case GPS
    }
    
    struct Sensor {
        var type:SensorType
        var data:NSData?
        var prefix:String
        var valueCells:[SensorValueCell]
        var toggleButton:BLESensorButton
        var enabled:Bool
    }
    
//    struct gpsData {
//        var x:Double
//        var y:Double
//        var z:Double
//    }
    
    private let cmm = CMMotionManager()
    private var locationManager:CLLocationManager?
    private let accelDataPrefix = "!A"
    private let gyroDataPrefix  = "!G"
    private let magDataPrefix   = "!M"
    private let gpsDataPrefix   = "!L"
    private let qtnDataPrefix   = "!Q"
    private let updateInterval  = 0.1
    private let pollInterval    = 0.1     //nonmatching update & poll intervals can interfere w switch animation even when using qeueus & timer tolerance
    private let gpsInterval     = 30.0
    private var gpsFlag         = false
    private var lastGPSData:NSData?
    var sensorArray:[Sensor]!
    private var sendSensorIndex = 0
    private var sendTimer:NSTimer?
    private var gpsTimer:NSTimer?   //send gps data at interval even if it hasn't changed
    private let buttonPrefix = "!B"
    private let colorPrefix = "!C"
//    private let sensorQueue = dispatch_queue_create("com.adafruit.bluefruitconnect.sensorQueue", DISPATCH_QUEUE_SERIAL)
    private var locationAlert:UIAlertController?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //setup help view
        self.helpViewController.title = "Controller Help"
        self.helpViewController.delegate = delegate
        
        
        
        //button stuff
        buttonColor = buttons[0].backgroundColor
        for b in buttons {
            b.layer.cornerRadius = 4.0
        }
        exitButtonColor = exitButton.backgroundColor
        exitButton.layer.cornerRadius = 4.0
        
        sensorArray = [
            Sensor(type: SensorType.Qtn,
                data: nil, prefix: qtnDataPrefix,
                valueCells:[newValueCell("x"), newValueCell("y"), newValueCell("z"), newValueCell("w")],
                toggleButton: self.newSensorButton(0),
                enabled: false),
            Sensor(type: SensorType.Accel,
                data: nil, prefix: accelDataPrefix,
                valueCells:[newValueCell("x"), newValueCell("y"), newValueCell("z")],
                toggleButton: self.newSensorButton(1),
                enabled: false),
            Sensor(type: SensorType.Gyro,
                data: nil, prefix: gyroDataPrefix,
                valueCells:[newValueCell("x"), newValueCell("y"), newValueCell("z")],
                toggleButton: self.newSensorButton(2),
                enabled: false),
            Sensor(type: SensorType.Mag,
                data: nil, prefix: magDataPrefix,
                valueCells:[newValueCell("x"), newValueCell("y"), newValueCell("z")],
                toggleButton: self.newSensorButton(3),
                enabled: false),
            Sensor(type: SensorType.GPS,
                data: nil, prefix: gpsDataPrefix,
                valueCells:[newValueCell("lat"), newValueCell("lng"), newValueCell("alt")],
                toggleButton: self.newSensorButton(4),
                enabled: false)
        ]
        
        quatButton = sensorArray[0].toggleButton
        accelButton = sensorArray[1].toggleButton
        gyroButton = sensorArray[2].toggleButton
        magnetometerButton = sensorArray[3].toggleButton
        gpsButton = sensorArray[4].toggleButton
        
        //Set up recurring timer for sending sensor data
        sendTimer = NSTimer(timeInterval: updateInterval, target: self, selector: Selector("sendSensorData:"), userInfo: nil, repeats: true)
        sendTimer!.tolerance = 0.25
        NSRunLoop.currentRunLoop().addTimer(sendTimer!, forMode: NSDefaultRunLoopMode)
        
        //Set up minimum recurring timer for sending gps data when unchanged
        gpsTimer = newGPSTimer()
        //gpsTimer is added to the loop when gps data is enabled
        
        //Register to be notified when app returns to active
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("checkLocationServices"), name: UIApplicationDidBecomeActiveNotification, object: nil)
        
    }
    
    
    override func viewDidAppear(animated: Bool) {
        
        super.viewDidAppear(animated)
        
        //Check to see if location services are enabled
//        checkLocationServices()
        
//        if checkLocationServices() == false {
//            //Warn the user that GPS isn't available
//            locationAlert = UIAlertController(title: "Location Services disabled", message: "Enable Location Services in \nSettings->Privacy to allow location data to be sent over Bluetooth", preferredStyle: UIAlertControllerStyle.Alert)
//            let aaOK = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil)
//            locationAlert!.addAction(aaOK)
//            self.presentViewController(locationAlert!, animated: true, completion: { () -> Void in
//                //Set switch enabled again after alert close in case the user enabled services
//                let verdict = self.checkLocationServices()
//            })
//        }
//        
//        else {
//            locationAlert?.dismissViewControllerAnimated(true, completion: { () -> Void in
//            })
//            
//            self.checkLocationServices()
//        }
        
    }
    
    
    func checkLocationServices()->Bool {
        
        var verdict = false
        if (CLLocationManager.locationServicesEnabled() && CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedWhenInUse) {
            verdict = true
        }
//        gpsButton.dimmed = !verdict
        return verdict
        
    }
    
    
    func showLocationServicesAlert(){
        
        //Warn the user that GPS isn't available
        locationAlert = UIAlertController(title: "Location Services disabled", message: "Enable Location Services in \nSettings->Privacy to allow location data to be sent over Bluetooth", preferredStyle: UIAlertControllerStyle.Alert)
        let aaOK = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (aa:UIAlertAction!) -> Void in
            
        })
        locationAlert!.addAction(aaOK)
        self.presentViewController(locationAlert!, animated: true, completion: { () -> Void in
            //Set switch enabled again after alert close in case the user enabled services
            //                self.gpsButton.enabled = CLLocationManager.locationServicesEnabled()
        })
        
    }
    
    
    func newGPSTimer()->NSTimer {
        
        let newTimer = NSTimer(timeInterval: gpsInterval, target: self, selector: Selector("gpsIntervalComplete:"), userInfo: nil, repeats: true)
        newTimer.tolerance = 1.0
        
        return newTimer
    }
    
    
    func removeGPSTimer() {
        
        gpsTimer?.invalidate()
        gpsTimer = nil
        
    }
    
    
    override func viewWillDisappear(animated: Bool) {
        
        // Stop updates if we're returning to main view
        if self.isMovingFromParentViewController() {
            stopSensorUpdates()
            //Stop receiving app active notification
            NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidBecomeActiveNotification, object: nil)
        }
        
        super.viewWillDisappear(animated)
        
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    convenience init(aDelegate:UARTViewControllerDelegate){
        
        //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
        
        var nibName:NSString
        
        if IS_IPHONE {
            nibName = "ControllerViewController_iPhone"
        }
        else{   //IPAD
            nibName = "ControllerViewController_iPad"
        }
        
        self.init(nibName: nibName as String, bundle: NSBundle.mainBundle())
        
        self.delegate = aDelegate
        self.title = "Controller"
        self.sensorArray = []
    }
    

    func sensorButtonTapped(sender: UIButton) {
        
        
//        print("--------> button \(sender.tag) state is ")
//        if sender.selected {
//            print("SELECTED")
//        }
//        else {
//            print("DESELECTED")
//        }
        
        
        
        
//        //Check to ensure switch is not being set redundantly
//        if sensorArray[sender.tag].enabled == sender.selected {
////            println(" - redundant!")
//            sender.userInteractionEnabled = true
//            return
//        }
//        else {
////            println("")
//            sensorArray[sender.tag].enabled = sender.selected
//        }
        
        //Accelerometer
        if sender === accelButton {
            
            //rows to add or remove
            let valuePaths: [NSIndexPath] = [
                NSIndexPath(forRow: 1, inSection: 1),
                NSIndexPath(forRow: 2, inSection: 1),
                NSIndexPath(forRow: 3, inSection: 1)
            ]
            
            if (sender.selected == false) {
                
                if cmm.accelerometerAvailable == true {
                    cmm.accelerometerUpdateInterval = pollInterval
                    cmm.startAccelerometerUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (data:CMAccelerometerData?, error:NSError?) -> Void in
                        self.didReceiveAccelData(data, error: error)
                    })
                    
                    sender.selected = true
                    
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRowsAtIndexPaths(valuePaths , withRowAnimation: UITableViewRowAnimation.Fade)
                    controlTable.endUpdates()
                    
                }
                else {
                    printLog(self, funcName: "buttonValueChanged", logString: "accelerometer unavailable")
                }
            }
                //button switched off
            else {
                
                sender.selected = false
                
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                controlTable.endUpdates()
                
                cmm.stopAccelerometerUpdates()
                
            }
        }
         
        //Gyro
        else if sender === gyroButton {
            
            //rows to add or remove
            let valuePaths: [NSIndexPath] = [
                NSIndexPath(forRow: 1, inSection: 2),
                NSIndexPath(forRow: 2, inSection: 2),
                NSIndexPath(forRow: 3, inSection: 2)
            ]
            
            if (sender.selected == false) {
                
                if cmm.gyroAvailable == true {
                    cmm.gyroUpdateInterval = pollInterval
                    cmm.startGyroUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (data:CMGyroData?, error:NSError?) -> Void in
                        self.didReceiveGyroData(data, error: error)
                    })
                    sender.selected = true
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                    controlTable.endUpdates()
                }
                else {
                    printLog(self, funcName: "buttonValueChanged", logString: "gyro unavailable")
                }
                
            }
                //button switched off
            else {
                sender.selected = false
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                controlTable.endUpdates()
                
                cmm.stopGyroUpdates()
            }
        }
            
        //Magnetometer
        else if sender === magnetometerButton {
            
            //rows to add or remove
            let valuePaths: [NSIndexPath] = [
                NSIndexPath(forRow: 1, inSection: 3),
                NSIndexPath(forRow: 2, inSection: 3),
                NSIndexPath(forRow: 3, inSection: 3)
            ]
            
            if (sender.selected == false) {
                if cmm.magnetometerAvailable == true {
                    cmm.magnetometerUpdateInterval = pollInterval
                    cmm.startMagnetometerUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (data:CMMagnetometerData?, error:NSError?) -> Void in
                        self.didReceiveMagnetometerData(data, error: error)
                    })
                    sender.selected = true
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                    controlTable.endUpdates()
                }
                else {
                    printLog(self, funcName: "buttonValueChanged", logString: "magnetometer unavailable")
                }
            }
                //button switched off
            else {
                sender.selected = false
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                controlTable.endUpdates()
                
                cmm.stopMagnetometerUpdates()
                
            }
        }
            
        //GPS
        else if sender === gpsButton {
            
            //rows to add or remove
            let valuePaths: [NSIndexPath] = [
                NSIndexPath(forRow: 1, inSection: 4),
                NSIndexPath(forRow: 2, inSection: 4),
                NSIndexPath(forRow: 3, inSection: 4)
            ]
            
            if (sender.selected == false) {
                
                if locationManager == nil {
                    
                    locationManager = CLLocationManager()
                    locationManager?.delegate = self
                    locationManager?.desiredAccuracy = kCLLocationAccuracyBest
                    locationManager?.distanceFilter = kCLDistanceFilterNone
                    
                    //Check for authorization
                    if locationManager?.respondsToSelector(Selector("requestWhenInUseAuthorization")) == true {
                        if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.AuthorizedWhenInUse {
                            locationManager?.requestWhenInUseAuthorization()
                            gpsButton.selected = false
                            return
                        }
                    }
                    else {
                        printLog(self, funcName: "buttonValueChanged", logString: "Location Manager authorization not found")
                        gpsButton.selected = false
                        removeGPSTimer()
                        locationManager = nil
                        return
                    }
                }
                
                if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedWhenInUse {
                    locationManager?.startUpdatingLocation()
                    
                    //add gpstimer to loop
                    if gpsTimer == nil { gpsTimer = newGPSTimer() }
                    NSRunLoop.currentRunLoop().addTimer(gpsTimer!, forMode: NSDefaultRunLoopMode)
                    
                    sender.selected = true
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                    controlTable.endUpdates()
                    
                }
                else {
//                    printLog(self, "buttonValueChanged", "Location Manager not authorized")
                    showLocationServicesAlert()
                    return
                }
                
            }
                //button switched off
            else {
                sender.selected = false
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                controlTable.endUpdates()
                
                //remove gpstimer from loop
                removeGPSTimer()
                
                locationManager?.stopUpdatingLocation()
            }
        }
            
        //Quaternion / Device Motion
        else if sender === quatButton {
            //rows to add or remove
            let valuePaths: [NSIndexPath] = [
                NSIndexPath(forRow: 1, inSection: 0),
                NSIndexPath(forRow: 2, inSection: 0),
                NSIndexPath(forRow: 3, inSection: 0),
                NSIndexPath(forRow: 4, inSection: 0)
            ]
            
            if (sender.selected == false) {
                if cmm.deviceMotionAvailable == true {
                    cmm.deviceMotionUpdateInterval = pollInterval
                    cmm.startDeviceMotionUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (cmdm:CMDeviceMotion?, error:NSError?) -> Void in
                        self.didReceivedDeviceMotion(cmdm, error: error)
                    })
                    
                    sender.selected = true
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                    controlTable.endUpdates()
                }
                else {
                    printLog(self, funcName: "buttonValueChanged", logString: "device motion unavailable")
                }
            }
                //button switched off
            else {
                
                sender.selected = false
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                controlTable.endUpdates()
                
                cmm.stopDeviceMotionUpdates()
            }
        }
       
    }
    
    
    func newSensorButton(tag:Int)->BLESensorButton {
        
        
        let aButton = BLESensorButton()
        aButton.tag = tag
        
//        let offColor = bleBlueColor
//        let onColor = UIColor.whiteColor()
//        aButton.titleLabel?.font = UIFont.systemFontOfSize(14.0)
//        aButton.setTitle("OFF", forState: UIControlState.Normal)
//        aButton.setTitle("ON", forState: UIControlState.Selected)
//        aButton.setTitleColor(offColor, forState: UIControlState.Normal)
//        aButton.setTitleColor(onColor, forState: UIControlState.Selected)
//        aButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
//        aButton.backgroundColor = UIColor.whiteColor()
//        aButton.setBackgroundImage(UIImage(named: "ble_blue_1px.png"), forState: UIControlState.Selected)
//        aButton.layer.cornerRadius = 8.0
//        aButton.clipsToBounds = true
//        aButton.layer.borderColor = offColor.CGColor
//        aButton.layer.borderWidth = 1.0
        
        
        aButton.selected = false
        aButton.addTarget(self, action: Selector("sensorButtonTapped:"), forControlEvents: UIControlEvents.TouchUpInside)
        aButton.frame = CGRectMake(0.0, 0.0, 75.0, 30.0)
        
        return aButton
    }
    
    
    func newValueCell(prefixString:String!)->SensorValueCell {
        
        let cellData = NSKeyedArchiver.archivedDataWithRootObject(self.valueCell)
        let cell:SensorValueCell = NSKeyedUnarchiver.unarchiveObjectWithData(cellData) as! SensorValueCell
        cell.selectionStyle = UITableViewCellSelectionStyle.None
        cell.valueLabel = cell.viewWithTag(100) as! UILabel
//        let cell = SensorValueCell()
        
        cell.prefixString = prefixString
        
        return cell
        
    }
    
    
    func showNavbar(){
        
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
    }
    
    
    //MARK: Sensor data
    
    func didReceivedDeviceMotion(cmdm:CMDeviceMotion!, error:NSError!) {
        
        storeSensorData(SensorType.Qtn, x: cmdm.attitude.quaternion.x, y: cmdm.attitude.quaternion.y, z: cmdm.attitude.quaternion.z, w: cmdm.attitude.quaternion.w)
        
    }
    
    
    func didReceiveAccelData(aData:CMAccelerometerData!, error:NSError!) {
        
//        println("ACC X:\(Float(accelData.acceleration.x)) Y:\(Float(accelData.acceleration.y)) Z:\(Float(accelData.acceleration.z))")
        
        storeSensorData(SensorType.Accel, x: aData.acceleration.x, y: aData.acceleration.y, z: aData.acceleration.z, w:nil)
        
        
    }
    
    
    func didReceiveGyroData(gData:CMGyroData!, error:NSError!) {
        
//        println("GYR X:\(gyroData.rotationRate.x) Y:\(gyroData.rotationRate.y) Z:\(gyroData.rotationRate.z)")
        
        storeSensorData(SensorType.Gyro, x: gData.rotationRate.x, y: gData.rotationRate.y, z: gData.rotationRate.z, w:nil)
        
    }
    
    
    func didReceiveMagnetometerData(mData:CMMagnetometerData!, error:NSError!) {
        
//        println("MAG X:\(magData.magneticField.x) Y:\(magData.magneticField.y) Z:\(magData.magneticField.z)")
        
        storeSensorData(SensorType.Mag, x: mData.magneticField.x, y: mData.magneticField.y, z: mData.magneticField.z, w:nil)
        
    }
    
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let loc = locations.last as CLLocation!
        
        let eventDate = loc.timestamp
        let howRecent = eventDate.timeIntervalSinceNow
        if (abs(howRecent) < 15)
//            || (gpsFlag == true)
        {
//            gpsFlag = false
            //Check for invalid accuracy
            if loc.horizontalAccuracy < 0.0 || loc.verticalAccuracy < 0.0 {
                return
            }
            
            //Debug
            //            let lat = loc.coordinate.latitude
            //            let lng = loc.coordinate.longitude
            //            let alt = loc.altitude
            //            println("-------------------------------")
            //            println(String(format: "Location Double: %.32f, %.32f", lat, lng))
            //            println(String(format: "Location Float:  %.32f, %.32f", Float(lat), Float(lng)))
            //            println("-------------------------------")
            
            storeSensorData(SensorType.GPS, x: loc.coordinate.latitude, y: loc.coordinate.longitude, z: loc.altitude, w:nil)
            
        }
    }
    
    
    func storeSensorData(type:SensorType, x:Double, y:Double, z:Double, w:Double?) {    //called in sensor queue
        
        let idx = type.rawValue
        
        let data = NSMutableData(capacity: 0)!
        let pfx = NSString(string: sensorArray[idx].prefix)
        var xv = Float(x)
        var yv = Float(y)
        var zv = Float(z)
        
        data.appendBytes(pfx.UTF8String, length: pfx.length)
        data.appendBytes(&xv, length: sizeof(Float))
        sensorArray[idx].valueCells[0].updateValue(xv)
        data.appendBytes(&yv, length: sizeof(Float))
        sensorArray[idx].valueCells[1].updateValue(yv)
        data.appendBytes(&zv, length: sizeof(Float))
        sensorArray[idx].valueCells[2].updateValue(zv)
        
        if w != nil {
            var wv = Float(w!)
            data.appendBytes(&wv, length: sizeof(Float))
            sensorArray[idx].valueCells[3].updateValue(wv)
        }
        
        appendCRCmutable(data)
        
        sensorArray[idx].data = data
        
    }
    
    
    func sendSensorData(timer:NSTimer) {
        
        let startIdx = sendSensorIndex
        
        var data:NSData?
        
        while data == nil {
            data = sensorArray[sendSensorIndex].data
            if data != nil {
                
//                println("------------------> Found sensor data \(sensorArray[sendSensorIndex].prefix)")
                delegate?.sendData(data!)
                if sensorArray[sendSensorIndex].type == SensorType.GPS { lastGPSData = data }   // Store last gps data sent for min updates
                sensorArray[sendSensorIndex].data = nil
                incrementSensorIndex()
                return
            }
            
            incrementSensorIndex()
            if startIdx == sendSensorIndex {
//                println("------------------> No new data to send")
                return
            }
        }
        
    }
    
    
    func gpsIntervalComplete(timer:NSTimer) {
        
        //set last gpsdata sent as next gpsdata to send
        for i in 0...(sensorArray.count-1) {
            if (sensorArray[i].type == SensorType.GPS) && (sensorArray[i].data == nil) {
//                println("--> gpsIntervalComplete - reloading last gps data")
                sensorArray[i].data = lastGPSData
                break
            }
        }
        
    }
    
    
    func incrementSensorIndex(){
        
        sendSensorIndex++
        if sendSensorIndex >= sensorArray.count {
            sendSensorIndex = 0
        }
        
    }
    
    
    func stopSensorUpdates(){
        
        sendTimer?.invalidate()
        
        removeGPSTimer()
        
        accelButton.selected = false
        cmm.stopAccelerometerUpdates()
        
        gyroButton.selected = false
        cmm.stopGyroUpdates()
        
        magnetometerButton.selected = false
        cmm.stopMagnetometerUpdates()
        
        cmm.stopDeviceMotionUpdates()
        
        gpsButton.selected = false
        locationManager?.stopUpdatingLocation()
        
    }
    
    
    //MARK: TableView
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: nil)
        var buttonView:UIButton?
        
        if indexPath.section == (sensorArray.count){
            cell.textLabel!.text = "Control Pad"
            cell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
            cell.selectionStyle = UITableViewCellSelectionStyle.Blue
            return cell
        }
        else if indexPath.section == sensorArray.count {
            cell.textLabel?.text = "Control Pad"
            cell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
            cell.selectionStyle = UITableViewCellSelectionStyle.Blue
            return cell
        }
        else if indexPath.section == (sensorArray.count + 1){
            cell.textLabel!.text = "Color Picker"
            cell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
            cell.selectionStyle = UITableViewCellSelectionStyle.Blue
            return cell
        }
        
        cell.selectionStyle = UITableViewCellSelectionStyle.None
        
        if indexPath.row == 0 {
            switch indexPath.section {
            case 0:
                cell.textLabel!.text = "Quaternion"
                buttonView = quatButton
            case 1:
                cell.textLabel!.text = "Accelerometer"
                buttonView = accelButton
            case 2:
                cell.textLabel!.text = "Gyro"
                buttonView = gyroButton
            case 3:
                cell.textLabel!.text = "Magnetometer"
                buttonView = magnetometerButton
            case 4:
                cell.textLabel!.text = "Location"
                buttonView = gpsButton
            default:
                break
            }
            
            cell.accessoryView = buttonView
            return cell
        }
        
        else {
            
//            switch indexPath.section {
//            case 0:
//                break
//            case 1: //Accel
//                cell.textLabel!.text = "TEST"
//            case 2: //Gyro
//                cell.textLabel!.text = "TEST"
//            case 3: //Mag
//                cell.textLabel!.text = "TEST"
//            case 4: //GPS
//                cell.textLabel!.text = "TEST"
//            default:
//                break
//            }
            
            return sensorArray[indexPath.section].valueCells[indexPath.row-1]
            
        }
        
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section < sensorArray.count {
            let snsr = sensorArray[section]
            if snsr.toggleButton.selected == true {
                return snsr.valueCells.count+1
            }
            else {
                return 1
            }
        }
        
        else {
            return 1
        }

    }
    
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        
        if indexPath.row == 0 {
            return 44.0
        }
        else {
            return 28.0
        }
        
    }
    
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        if section == 0 {
            return 44.0
        }
        else if section == sensorArray.count {
            return 44.0
        }
        else {
            return 0.5
        }
    }
    
    
    func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        return 0.5
        
    }
    
    
    func tableView(tableView: UITableView, indentationLevelForRowAtIndexPath indexPath: NSIndexPath) -> Int {
        
        if indexPath.row == 0 {
            return 0
        }
        
        else {
            return 1
        }
        
    }
    
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    
        return sensorArray.count + 2
    
    }
    
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == 0 {
            return "Stream Sensor Data"
        }
        
        else if section == sensorArray.count {
            return "Module"
        }
        
        else {
            return nil
        }
    }
    
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        if indexPath.section == sensorArray.count {
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
            self.navigationController?.pushViewController(controlPadViewController, animated: true)
            
            if IS_IPHONE {  //Hide nav bar on iphone to conserve space
                self.navigationController?.setNavigationBarHidden(true, animated: true)
            }
        }
        else if indexPath.section == (sensorArray.count + 1) {
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
            
            let colorPicker = ColorPickerViewController(aDelegate: self)
            
            self.navigationController?.pushViewController(colorPicker, animated: true)
        }
        
    }
    
    
    //MARK: Control Pad
    
    @IBAction func controlPadButtonPressed(sender:UIButton) {
    
//        println("PRESSED \(sender.tag)")
        
        sender.backgroundColor = cellSelectionColor
        
        controlPadButtonPressedWithTag(sender.tag)
    
    }
    
    
    func controlPadButtonPressedWithTag(tag:Int) {
        
        let str = NSString(string: buttonPrefix + "\(tag)" + "1")
        let data = NSData(bytes: str.UTF8String, length: str.length)
        
        delegate?.sendData(appendCRC(data))
        
    }
    
    
    @IBAction func controlPadButtonReleased(sender:UIButton) {
        
//        println("RELEASED \(sender.tag)")
        
        sender.backgroundColor = buttonColor
        
        controlPadButtonReleasedWithTag(sender.tag)
    }
    
    
    func controlPadButtonReleasedWithTag(tag:Int) {
        
        let str = NSString(string: buttonPrefix + "\(tag)" + "0")
        let data = NSData(bytes: str.UTF8String, length: str.length)
        
        delegate?.sendData(appendCRC(data))
    }
    
    
    @IBAction func controlPadExitPressed(sender:UIButton) {
        
        sender.backgroundColor = buttonColor
        
    }
    
    
    @IBAction func controlPadExitReleased(sender:UIButton) {
        
        sender.backgroundColor = exitButtonColor
        
        navigationController?.popViewControllerAnimated(true)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
    }
    
    
    @IBAction func controlPadExitDragOutside(sender:UIButton) {
        
        sender.backgroundColor = exitButtonColor
        
    }
    
    
    //WatchKit functions
    func controlPadButtonTappedWithTag(tag:Int){
        
        //Press and release button
        controlPadButtonPressedWithTag(tag)
        delay(0.1, closure: { () -> () in
            self.controlPadButtonReleasedWithTag(tag)
        })
    }
    
    
    func appendCRCmutable(data:NSMutableData) {
        
        //append crc
        let len = data.length
        var bdata = [UInt8](count: len, repeatedValue: 0)
//        var buf = [UInt8](count: len, repeatedValue: 0)
        var crc:UInt8 = 0
        data.getBytes(&bdata, length: len)
        
        for i in bdata {    //add all bytes
            crc = crc &+ i
        }
        
        crc = ~crc  //invert
        
        data.appendBytes(&crc, length: 1)
        
//        println("crc == \(crc)   length == \(data.length)")
        
    }
    
    
    func appendCRC(data:NSData)->NSMutableData {
        
        let mData = NSMutableData(length: 0)
        mData!.appendData(data)
        appendCRCmutable(mData!)
        return mData!
        
    }
    
    
    //Color Picker
    
    func sendColor(red:UInt8, green:UInt8, blue:UInt8) {
        
        let pfx = NSString(string: colorPrefix)
        var rv = red
        var gv = green
        var bv = blue
        let data = NSMutableData(capacity: 3 + pfx.length)!
        
        data.appendBytes(pfx.UTF8String, length: pfx.length)
        data.appendBytes(&rv, length: 1)
        data.appendBytes(&gv, length: 1)
        data.appendBytes(&bv, length: 1)
        
        appendCRCmutable(data)
        
        delegate?.sendData(data)
        
    }
    
    
    func helpViewControllerDidFinish(controller : HelpViewController) {
        
        delegate?.helpViewControllerDidFinish(controller)
        
    }
    
    
}










