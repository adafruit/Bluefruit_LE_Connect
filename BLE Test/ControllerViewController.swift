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

class ControllerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate {
    
    
    var delegate:UARTViewControllerDelegate?
    @IBOutlet var helpViewController:HelpViewController!
    @IBOutlet var controlPadViewController:UIViewController!
    @IBOutlet var buttons:[UIButton]!
    @IBOutlet var exitButton:UIButton!
    @IBOutlet var controlTable:UITableView!
    @IBOutlet var valueCell:SensorValueCell!
    
    var accelSwitch:UISwitch!
    var gyroSwitch: UISwitch!
    var magnetometerSwitch: UISwitch!
    var gpsSwitch:UISwitch!
    var quatSwitch:UISwitch!
    var buttonColor:UIColor!
    var exitButtonColor:UIColor!
    
    enum SensorType:Int {
        case Accel
        case Gyro
        case Mag
        case GPS
        case Qtn
    }
    
    struct Sensor {
        var type:SensorType
        var data:NSData?
        var prefix:String
        var valueCells:[SensorValueCell]
        var toggleSwitch:UISwitch
    }
    
    private let cmm = CMMotionManager()
    private var locationManager:CLLocationManager?
    private let accelDataPrefix = "!A"
    private let gyroDataPrefix  = "!G"
    private let magDataPrefix   = "!M"
    private let gpsDataPrefix   = "!L"
    private let qtnDataPrefix   = "!Q"
    private let updateInterval  = 0.1
    private let pollInterval  = 0.05
    var sensorArray:[Sensor]!
    private var sendSensorIndex = 0
    private var sendTimer:NSTimer?
    private let buttonPrefix = "!B"
    
    
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
            Sensor(type: SensorType.Qtn,   data: nil, prefix: qtnDataPrefix, valueCells:[newValueCell("x"), newValueCell("y"), newValueCell("z"), newValueCell("w")], toggleSwitch: self.newSwitch()),
            Sensor(type: SensorType.Accel, data: nil, prefix: accelDataPrefix, valueCells:[newValueCell("x"), newValueCell("y"), newValueCell("z")], toggleSwitch: self.newSwitch()),
            Sensor(type: SensorType.Gyro,  data: nil, prefix: gyroDataPrefix, valueCells:[newValueCell("x"), newValueCell("y"), newValueCell("z")], toggleSwitch: self.newSwitch()),
            Sensor(type: SensorType.Mag,   data: nil, prefix: magDataPrefix, valueCells:[newValueCell("x"), newValueCell("y"), newValueCell("z")], toggleSwitch: self.newSwitch()),
            Sensor(type: SensorType.GPS,   data: nil, prefix: gpsDataPrefix, valueCells:[newValueCell("lat"), newValueCell("lng"), newValueCell("alt")], toggleSwitch: self.newSwitch())
        ]
        
        quatSwitch = sensorArray[0].toggleSwitch
        accelSwitch = sensorArray[1].toggleSwitch
        gyroSwitch = sensorArray[2].toggleSwitch
        magnetometerSwitch = sensorArray[3].toggleSwitch
        gpsSwitch = sensorArray[4].toggleSwitch
        
        sendTimer = NSTimer.scheduledTimerWithTimeInterval(updateInterval, target: self, selector: Selector("sendSensorData:"), userInfo: nil, repeats: true)
        
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
        
        self.init(nibName: nibName, bundle: NSBundle.mainBundle())
        
        self.delegate = aDelegate
        self.title = "Controller"
        self.sensorArray = []
    }
    

    func switchValueChanged(sender: UISwitch) {
        
        //Accelerometer
        if sender === accelSwitch {
            
            //rows to add or remove
            var valuePaths: [NSIndexPath] = [
                NSIndexPath(forRow: 1, inSection: 1),
                NSIndexPath(forRow: 2, inSection: 1),
                NSIndexPath(forRow: 3, inSection: 1)
            ]
            
            if sender.on {
                
                if cmm.accelerometerAvailable == true {
                    cmm.accelerometerUpdateInterval = pollInterval
                    cmm.startAccelerometerUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (data:CMAccelerometerData!, error:NSError!) -> Void in
                        self.didReceiveAccelData(data, error: error)
                    })
                    
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                    controlTable.endUpdates()
                }
                else {
                    printLog(self, "switchValueChanged", "accelerometer unavailable")
                }
            }
                //button switched off
            else {
                cmm.stopAccelerometerUpdates()
                
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                controlTable.endUpdates()
            }
        }
            
            //Gyro
        else if sender === gyroSwitch {
            
            //rows to add or remove
            var valuePaths: [NSIndexPath] = [
                NSIndexPath(forRow: 1, inSection: 2),
                NSIndexPath(forRow: 2, inSection: 2),
                NSIndexPath(forRow: 3, inSection: 2)
            ]
            
            if sender.on {
                
                if cmm.gyroAvailable == true {
                    cmm.gyroUpdateInterval = pollInterval
                    cmm.startGyroUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (data:CMGyroData!, error:NSError!) -> Void in
                        self.didReceiveGyroData(data, error: error)
                    })
                    
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                    controlTable.endUpdates()
                }
                else {
                    printLog(self, "switchValueChanged", "gyro unavailable")
                }
            }
                //button switched off
            else {
                cmm.stopGyroUpdates()
                
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                controlTable.endUpdates()
            }
        }
            
            
            //Magnetometer
        else if sender === magnetometerSwitch {
            
            //rows to add or remove
            var valuePaths: [NSIndexPath] = [
                NSIndexPath(forRow: 1, inSection: 3),
                NSIndexPath(forRow: 2, inSection: 3),
                NSIndexPath(forRow: 3, inSection: 3)
            ]
            
            if sender.on {
                if cmm.magnetometerAvailable == true {
                    cmm.magnetometerUpdateInterval = pollInterval
                    cmm.startMagnetometerUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (data:CMMagnetometerData!, error:NSError!) -> Void in
                        self.didReceiveMagnetometerData(data, error: error)
                    })
                    
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                    controlTable.endUpdates()
                    
                }
                else {
                    printLog(self, "switchValueChanged", "magnetometer unavailable")
                }
            }
                //button switched off
            else {
                cmm.stopMagnetometerUpdates()
                
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                controlTable.endUpdates()
            }
        }
            
            //GPS
        else if sender === gpsSwitch {
            
            //rows to add or remove
            var valuePaths: [NSIndexPath] = [
                NSIndexPath(forRow: 1, inSection: 4),
                NSIndexPath(forRow: 2, inSection: 4),
                NSIndexPath(forRow: 3, inSection: 4)
            ]
            
            if sender.on {
                
                if locationManager == nil {
                    
                    locationManager = CLLocationManager()
                    locationManager?.delegate = self
                    locationManager?.desiredAccuracy = kCLLocationAccuracyBest
                    locationManager?.distanceFilter = kCLDistanceFilterNone
                    
                    //Check for authorization
                    if locationManager?.respondsToSelector(Selector("requestWhenInUseAuthorization")) == true {
                        if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.AuthorizedWhenInUse {
                            locationManager?.requestWhenInUseAuthorization()
                            gpsSwitch.on = false
                            return
                        }
                    }
                    else {
                        printLog(self, "switchValueChanged", "Location Manager authorization not found")
                        gpsSwitch.on = false
                        locationManager = nil
                        return
                    }
                }
                
                if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.AuthorizedWhenInUse {
                    locationManager?.startUpdatingLocation()
                    
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                    controlTable.endUpdates()
                    
                }
                else {
                    printLog(self, "switchValueChanged", "Location Manager not authorized")
                    return
                }
                
            }
                //button switched off
            else {
                locationManager?.stopUpdatingLocation()
                
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                controlTable.endUpdates()
            }
        }
            
            //Quaternion / Device Motion
        else if sender === quatSwitch {
            //rows to add or remove
            var valuePaths: [NSIndexPath] = [
                NSIndexPath(forRow: 1, inSection: 0),
                NSIndexPath(forRow: 2, inSection: 0),
                NSIndexPath(forRow: 3, inSection: 0),
                NSIndexPath(forRow: 4, inSection: 0)
            ]
            
            if sender.on {
                if cmm.deviceMotionAvailable == true {
                    cmm.deviceMotionUpdateInterval = pollInterval
                    cmm.startDeviceMotionUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (cmdm:CMDeviceMotion!, error:NSError!) -> Void in
                        self.didReceivedDeviceMotion(cmdm, error: error)
                    })
                    //add rows for sensor values
                    controlTable.beginUpdates()
                    controlTable.insertRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                    controlTable.endUpdates()
                }
                else {
                    printLog(self, "switchValueChanged", "device motion unavailable")
                }
            }
                //button switched off
            else {
                cmm.stopDeviceMotionUpdates()
                //remove rows for sensor values
                controlTable.beginUpdates()
                controlTable.deleteRowsAtIndexPaths(valuePaths, withRowAnimation: UITableViewRowAnimation.Fade)
                controlTable.endUpdates()
            }
        }
        
    }
    
    
    func newSwitch()->UISwitch {
        
        let aSwitch = UISwitch()
        aSwitch.addTarget(self, action: Selector("switchValueChanged:"), forControlEvents: UIControlEvents.ValueChanged)
        aSwitch.onTintColor = UIColor(red: 25.0/255.0, green: 148/255.0, blue: 250/255.0, alpha: 1.0)
        aSwitch.tintColor = UIColor(red: 126/255.0, green: 194/255.0, blue: 250/255.0, alpha: 1.0)
        
        return aSwitch
    }
    
    
    func newValueCell(prefixString:String!)->SensorValueCell {
        
        let cellData = NSKeyedArchiver.archivedDataWithRootObject(self.valueCell)
        let cell:SensorValueCell = NSKeyedUnarchiver.unarchiveObjectWithData(cellData) as SensorValueCell
        cell.valueLabel = cell.viewWithTag(100) as UILabel
//        let cell = SensorValueCell()
        
        cell.prefixString = prefixString
        
        return cell
        
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
    
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        
        let loc = locations.last as CLLocation
        
        let eventDate = loc.timestamp
        let howRecent = eventDate.timeIntervalSinceNow
        if abs(howRecent) < 15 {
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
    
    
    func storeSensorData(type:SensorType, x:Double, y:Double, z:Double, w:Double?) {
        
        var idx = -1
        for var i = 0; i < sensorArray.count; i++ {
            if sensorArray[i].type == type {
//                println("------------------> Found type \(sensorArray[i].prefix)")
                idx = i
            }
        }
        
        if idx > -1 {
            //as data
            var data = NSMutableData(capacity: 0)!
            var pfx = NSString(string: sensorArray[idx].prefix)
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
            
            sensorArray[idx].data = data
        }
        
    }
    
    
    func sendSensorData(timer:NSTimer) {
        
        var startIdx = sendSensorIndex
        var foundIdx:Int
        
        var data:NSData?
        
        while data == nil {
            data = sensorArray[sendSensorIndex].data
            if data != nil {
//                println("------------------> Found sensor data \(sensorArray[sendSensorIndex].prefix)")
                delegate?.sendData(data!)
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
    
    
    func incrementSensorIndex(){
        
        sendSensorIndex++
        if sendSensorIndex >= sensorArray.count {
            sendSensorIndex = 0
        }
        
    }
    
    
    func stopSensorUpdates(){
        
        sendTimer?.invalidate()
        
        accelSwitch.on = false
        cmm.stopAccelerometerUpdates()
        
        gyroSwitch.on = false
        cmm.stopGyroUpdates()
        
        magnetometerSwitch.on = false
        cmm.stopMagnetometerUpdates()
        
        
        cmm.stopDeviceMotionUpdates()
        
        gpsSwitch.on = false
        locationManager?.stopUpdatingLocation()
        
    }
    
    
    //MARK: TableView
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: nil)
        var switchView:UISwitch?
        
        if indexPath.section == sensorArray.count {
            cell.textLabel.text = "Control Pad"
            cell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
            cell.selectionStyle = UITableViewCellSelectionStyle.Blue
            return cell
        }
        
        cell.selectionStyle = UITableViewCellSelectionStyle.None
        
        if indexPath.row == 0 {
            switch indexPath.section {
            case 0:
                cell.textLabel.text = "Quaternion"
                switchView = quatSwitch
            case 1:
                cell.textLabel.text = "Accelerometer"
                switchView = accelSwitch
            case 2:
                cell.textLabel.text = "Gyro"
                switchView = gyroSwitch
            case 3:
                cell.textLabel.text = "Magnetometer"
                switchView = magnetometerSwitch
            case 4:
                cell.textLabel.text = "Location"
                switchView = gpsSwitch
            default:
                break
            }
            
            cell.accessoryView = switchView
            return cell
        }
        
        else {
            
//            switch indexPath.section {
//            case 0:
//                break
//            case 1: //Accel
//                cell.textLabel.text = "TEST"
//            case 2: //Gyro
//                cell.textLabel.text = "TEST"
//            case 3: //Mag
//                cell.textLabel.text = "TEST"
//            case 4: //GPS
//                cell.textLabel.text = "TEST"
//            default:
//                break
//            }
            
            return sensorArray[indexPath.section].valueCells[indexPath.row-1]
            
        }
        
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section < sensorArray.count {
            var snsr = sensorArray[section]
            if snsr.toggleSwitch.on == true {
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
    
        return sensorArray.count + 1
    
    }
    
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == 0 {
            return "Stream Sensor Data"
        }
        
        else if section == sensorArray.count {
            return "Interface"
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
        
    }
    
    
    //MARK: Control Pad
    
    @IBAction func controlPadButtonPressed(sender:UIButton) {
    
//        println("PRESSED \(sender.tag)")
        
        sender.backgroundColor = cellSelectionColor
        
        var str = NSString(string: buttonPrefix + "\(sender.tag)" + "1")
        let data = NSData(bytes: str.UTF8String, length: str.length)
        
        delegate?.sendData(data)
    
    }
    
    
    @IBAction func controlPadButtonReleased(sender:UIButton) {
        
//        println("RELEASED \(sender.tag)")
        
        sender.backgroundColor = buttonColor
        
        var str = NSString(string: buttonPrefix + "\(sender.tag)" + "0")
        let data = NSData(bytes: str.UTF8String, length: str.length)
        
        delegate?.sendData(data)
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
    
}
