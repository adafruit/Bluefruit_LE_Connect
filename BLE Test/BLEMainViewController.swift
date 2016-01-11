//
//  BLEMainViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/13/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

enum ConnectionMode:Int {
    case None
    case PinIO
    case UART
    case Info
    case Controller
    case DFU
}

protocol BLEMainViewControllerDelegate : Any {
    func onDeviceConnectionChange(peripheral:CBPeripheral)
}

class BLEMainViewController : UIViewController, UINavigationControllerDelegate, HelpViewControllerDelegate, CBCentralManagerDelegate,
                              BLEPeripheralDelegate, UARTViewControllerDelegate, PinIOViewControllerDelegate, DeviceListViewControllerDelegate, FirmwareUpdaterDelegate {
    
    enum ConnectionStatus:Int {
        case Idle = 0
        case Scanning
        case Connected
        case Connecting
    }
    
    var connectionMode:ConnectionMode = ConnectionMode.None
    var connectionStatus:ConnectionStatus = ConnectionStatus.Idle
    var helpPopoverController:UIPopoverController?
    var navController:UINavigationController!
    var pinIoViewController:PinIOViewController!
    var uartViewController:UARTViewController!
    var deviceListViewController:DeviceListViewController!
    var deviceInfoViewController:DeviceInfoViewController!
    var controllerViewController:ControllerViewController!
    var dfuViewController:DFUViewController!
    var delegate:BLEMainViewControllerDelegate?
    
    @IBOutlet var infoButton:UIButton!
    @IBOutlet var warningLabel:UILabel!
    
    @IBOutlet var helpViewController:HelpViewController!
    
    private var cm:CBCentralManager?
    private var currentAlertView:UIAlertController?
    private var currentPeripheral:BLEPeripheral?
    private var dfuPeripheral:CBPeripheral?
    private var infoBarButton:UIBarButtonItem?
    private var scanIndicator:UIActivityIndicatorView?
    private var scanIndicatorItem:UIBarButtonItem?
    private var scanButtonItem:UIBarButtonItem?
    private let cbcmQueue = dispatch_queue_create("com.adafruit.bluefruitconnect.cbcmqueue", DISPATCH_QUEUE_CONCURRENT)
    private let connectionTimeOutIntvl:NSTimeInterval = 30.0
    private var connectionTimer:NSTimer?
    private var firmwareUpdater : FirmwareUpdater?
    
    static let sharedInstance = BLEMainViewController()
    
    
    func centralManager()->CBCentralManager{
        
        return cm!;
        
    }
    
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        
        var newNibName:String
        
        if (IS_IPHONE){
            newNibName = "BLEMainViewController_iPhone"
        }
            
        else{
            newNibName = "BLEMainViewController_iPad"
        }
        
        super.init(nibName: newNibName, bundle: NSBundle.mainBundle())
        
        //        println("init with NIB " + self.description)
        
    }
    
    
    required init(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)!
        
    }
    
    
    //for Objective-C delegate compatibility
    func setDelegate(newDelegate:AnyObject){
        
        if newDelegate.respondsToSelector(Selector("onDeviceConnectionChange:")){
            delegate = newDelegate as? BLEMainViewControllerDelegate
        }
        else {
            printLog(self, funcName: "setDelegate", logString: "failed to set delegate")
        }
        
    }
    
    
    //MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createDeviceListViewController()
        
        navController = UINavigationController(rootViewController: deviceListViewController)
        navController.delegate = self
        navController.navigationBar.barStyle = UIBarStyle.Black
        navController.navigationBar.translucent = false
        navController.toolbar.barStyle = UIBarStyle.Black
        navController.toolbar.translucent = false
        navController.toolbarHidden = false
        navController.interactivePopGestureRecognizer?.enabled = false
        
        if IS_IPHONE {
            addChildViewController(navController)
            view.addSubview(navController.view)
        }
        
        // Create core bluetooth manager on launch
        if (cm == nil) {
            cm = CBCentralManager(delegate: self, queue: cbcmQueue)
            
            connectionMode = ConnectionMode.None
            connectionStatus = ConnectionStatus.Idle
            currentAlertView = nil
        }
        
        //refresh updates for DFU
        FirmwareUpdater.refreshSoftwareUpdatesDatabase()
        let areAutomaticFirmwareUpdatesEnabled = NSUserDefaults.standardUserDefaults().boolForKey("updatescheck_preference");
        if (areAutomaticFirmwareUpdatesEnabled) {
            firmwareUpdater = FirmwareUpdater()
        }
    }
    
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if (IS_IPAD) {
            addChildViewController(navController)
            view.addSubview(navController.view)
        }
        
        
        //FOR SCREENSHOTS
        //        connectionMode = ConnectionMode.Info
        //        connectionStatus = ConnectionStatus.Connected
        //        deviceInfoViewController = DeviceInfoViewController(cbPeripheral: <#CBPeripheral#>, delegate: <#HelpViewControllerDelegate#>)
        //        uartViewController.navigationItem.rightBarButtonItem = infoBarButton
        //        pushViewController(uartViewController)
        
    }
    
    
    func didBecomeActive() {
        
        // Application returned from background state
        
        // Adjust warning label
        if cm?.state == CBCentralManagerState.PoweredOff {
            
            warningLabel.text = "Bluetooth disabled"
            
        }
        else if deviceListViewController.devices.count == 0 {
            
            warningLabel.text = "No peripherals found"
            
        }
        else {
            warningLabel.text = ""
        }
        
    }
    
    
    //MARK: UI etc
    
    func helpViewControllerDidFinish(controller: HelpViewController) {
        
        //Called when help view's done button is tapped
        
        if (IS_IPHONE) {
            dismissViewControllerAnimated(true, completion: nil)
        }
            
        else {
            helpPopoverController?.dismissPopoverAnimated(true)
        }
        
    }
    
    
    func createDeviceListViewController(){
        
        //add info bar button to mode controllers
        let archivedData = NSKeyedArchiver.archivedDataWithRootObject(infoButton)
        let buttonCopy = NSKeyedUnarchiver.unarchiveObjectWithData(archivedData) as! UIButton
        buttonCopy.addTarget(self, action: Selector("showInfo:"), forControlEvents: UIControlEvents.TouchUpInside)
        infoBarButton = UIBarButtonItem(customView: buttonCopy)
        deviceListViewController = DeviceListViewController(aDelegate: self)
        deviceListViewController.navigationItem.rightBarButtonItem = infoBarButton
        deviceListViewController.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Disconnect", style: UIBarButtonItemStyle.Plain, target: nil, action: nil)
        //add scan indicator to toolbar
        scanIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.White)
        scanIndicator!.hidesWhenStopped = false
        scanIndicatorItem = UIBarButtonItem(customView: scanIndicator!)
        let space = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil)
        scanButtonItem = UIBarButtonItem(title: "Scan for peripherals", style: UIBarButtonItemStyle.Plain, target: self, action: Selector("toggleScan:"))
        deviceListViewController.toolbarItems = [space, scanButtonItem!, space]
        
    }
    
    
    func toggleScan(sender:UIBarButtonItem?){
        
        // Stop scan
        if connectionStatus == ConnectionStatus.Scanning {
            stopScan()
        }
            
            // Start scan
        else {
            startScan()
        }
        
    }
    
    
    func stopScan(){
        
        if (connectionMode == ConnectionMode.None) {
            cm?.stopScan()
            scanIndicator?.stopAnimating()
            
            //If scan indicator is in toolbar items, remove it
            let count:Int = deviceListViewController.toolbarItems!.count
//            var index = -1
            for i in 0...(count-1) {
                if deviceListViewController.toolbarItems?[i] === scanIndicatorItem {
                    deviceListViewController.toolbarItems?.removeAtIndex(i)
                    break
                }
            }
            
            connectionStatus = ConnectionStatus.Idle
            scanButtonItem?.title = "Scan for peripherals"
        }
        
        
        //        else if (connectionMode == ConnectionMode.UART) {
        //
        //        }
        
    }
    
    
    func startScan() {
        //Check if Bluetooth is enabled
        if cm?.state == CBCentralManagerState.PoweredOff {
            onBluetoothDisabled()
            return
        }
        
        cm!.scanForPeripheralsWithServices(nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        //Check if scan indicator is in toolbar items
        var indicatorShown = false
        for i in deviceListViewController.toolbarItems! {
            if i === scanIndicatorItem {
                indicatorShown = true
            }
        }
        //Insert scan indicator if not already in toolbar items
        if indicatorShown == false {
            deviceListViewController.toolbarItems?.insert(scanIndicatorItem!, atIndex: 1)
        }
        
        scanIndicator?.startAnimating()
        connectionStatus = ConnectionStatus.Scanning
        scanButtonItem?.title = "Scanning"
    }
    
    
    func onBluetoothDisabled(){
        
        //Show alert to enable bluetooth
        let alert = UIAlertController(title: "Bluetooth disabled", message: "Enable Bluetooth in system settings", preferredStyle: UIAlertControllerStyle.Alert)
        let aaOK = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil)
        alert.addAction(aaOK)
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    
    func currentHelpViewController()->HelpViewController {
        
        //Determine which help view to show based on the current view shown
        
        var hvc:HelpViewController
        
        if navController.topViewController!.isKindOfClass(PinIOViewController){
            hvc = pinIoViewController.helpViewController
        }
            
        else if navController.topViewController!.isKindOfClass(UARTViewController){
            hvc = uartViewController.helpViewController
        }
        else if navController.topViewController!.isKindOfClass(DeviceListViewController){
            hvc = deviceListViewController.helpViewController
        }
        else if navController.topViewController!.isKindOfClass(DeviceInfoViewController){
            hvc = deviceInfoViewController.helpViewController
        }
        else if navController.topViewController!.isKindOfClass(ControllerViewController){
            hvc = controllerViewController.helpViewController
        }
            //Add DFU help
            
        else{
            hvc = helpViewController
        }
        
        return hvc
        
    }
    
    
    @IBAction func showInfo(sender:AnyObject) {
        
        // Show help info view on iPhone via flip transition, called via "i" button in navbar
        
        if (IS_IPHONE) {
            presentViewController(currentHelpViewController(), animated: true, completion: nil)
        }
            
            //iPad
        else if (IS_IPAD) {
            
            //close popover it is being shown
            //            if helpPopoverController != nil {
            //                if helpPopoverController!.popoverVisible {
            //                    helpPopoverController?.dismissPopoverAnimated(true)
            //                    helpPopoverController = nil
            //                }
            //
            //            }
            
            //show popover if it isn't shown
            //            else {
            helpPopoverController?.dismissPopoverAnimated(true)
            
            helpPopoverController = UIPopoverController(contentViewController: currentHelpViewController())
            helpPopoverController?.backgroundColor = UIColor.darkGrayColor()
            
            let rightBBI:UIBarButtonItem! = navController.navigationBar.items!.last!.rightBarButtonItem
            let aFrame:CGRect = rightBBI!.customView!.frame
            helpPopoverController?.presentPopoverFromRect(aFrame,
                inView: rightBBI.customView!.superview!,
                permittedArrowDirections: UIPopoverArrowDirection.Any,
                animated: true)
            //            }
        }
    }
    
    
    func connectPeripheral(peripheral:CBPeripheral, mode:ConnectionMode) {
        
        //Check if Bluetooth is enabled
        if cm?.state == CBCentralManagerState.PoweredOff {
            onBluetoothDisabled()
            return
        }
        
        printLog(self, funcName: "connectPeripheral", logString: "")
        
        connectionTimer?.invalidate()
        
        if cm == nil {
            //            println(self.description)
            printLog(self, funcName: (__FUNCTION__), logString: "No central Manager found, unable to connect peripheral")
            return
        }
        
        stopScan()
        
        //Show connection activity alert view
        let alert = UIAlertController(title: "Connecting …", message: nil, preferredStyle: UIAlertControllerStyle.Alert)
        //        let aaCancel = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler:{ (aa:UIAlertAction!) -> Void in
        //            self.currentAlertView = nil
        //            self.abortConnection()
        //        })
        //        alert.addAction(aaCancel)
        currentAlertView = alert
        self.presentViewController(alert, animated: true, completion: nil)
        
        //Cancel any current or pending connection to the peripheral
        if peripheral.state == CBPeripheralState.Connected || peripheral.state == CBPeripheralState.Connecting {
            cm!.cancelPeripheralConnection(peripheral)
        }
        
        //Connect
        currentPeripheral = BLEPeripheral(peripheral: peripheral, delegate: self)
        cm!.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(bool:true)])
        
        connectionMode = mode
        connectionStatus = ConnectionStatus.Connecting
        
        // Start connection timeout timer
        connectionTimer = NSTimer.scheduledTimerWithTimeInterval(connectionTimeOutIntvl, target: self, selector: Selector("connectionTimedOut:"), userInfo: nil, repeats: false)
    }
    
    
    func connectPeripheralForDFU(peripheral:CBPeripheral) {
        
        //        connect device w services: dfuServiceUUID, deviceInfoServiceUUID
        
        printLog(self, funcName: (__FUNCTION__), logString: self.description)
        
        if cm == nil {
            //            println(self.description)
            printLog(self, funcName: (__FUNCTION__), logString: "No central Manager found, unable to connect peripheral")
            return
        }
        
        stopScan()
        
        dfuPeripheral = peripheral
        
        //Show connection activity alert view
        //        currentAlertView = UIAlertView(title: "Connecting …", message: nil, delegate: self, cancelButtonTitle: nil)
        //        currentAlertView!.show()
        
        //Cancel any current or pending connection to the peripheral
        if peripheral.state == CBPeripheralState.Connected || peripheral.state == CBPeripheralState.Connecting {
            cm!.cancelPeripheralConnection(peripheral)
        }
        
        //Connect
        //        currentPeripheral = BLEPeripheral(peripheral: peripheral, delegate: self)
        cm!.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(bool:true)])
        
        connectionMode = ConnectionMode.DFU
        connectionStatus = ConnectionStatus.Connecting
        
        
    }
    
    
    func connectionTimedOut(timer:NSTimer) {
        
        if connectionStatus != ConnectionStatus.Connecting {
            return
        }
        
        //dismiss "Connecting" alert view
        if currentAlertView != nil {
            currentAlertView?.dismissViewControllerAnimated(true, completion: nil)
            currentAlertView = nil
        }
        
        //Cancel current connection
        abortConnection()
        
        //Notify user that connection timed out
        let alert = UIAlertController(title: "Connection timed out", message: "No response from peripheral", preferredStyle: UIAlertControllerStyle.Alert)
        let aaOk = UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel) { (aa:UIAlertAction!) -> Void in }
        alert.addAction(aaOk)
        self.presentViewController(alert, animated: true) { () -> Void in }
        
    }
    
    
    func abortConnection() {
        
        connectionTimer?.invalidate()
        
        if (cm != nil) && (currentPeripheral != nil) {
            cm!.cancelPeripheralConnection(currentPeripheral!.currentPeripheral)
        }
        
        currentPeripheral = nil
        
        connectionMode = ConnectionMode.None
        connectionStatus = ConnectionStatus.Idle
    }
    
    
    func disconnect() {
        
        printLog(self, funcName: (__FUNCTION__), logString: "")
        
        if connectionMode == ConnectionMode.DFU && dfuPeripheral != nil{
            cm!.cancelPeripheralConnection(dfuPeripheral!)
            dfuPeripheral = nil
            return
        }
        
        if cm == nil {
            printLog(self, funcName: (__FUNCTION__), logString: "No central Manager found, unable to disconnect peripheral")
            return
        }
            
        else if currentPeripheral == nil {
            printLog(self, funcName: (__FUNCTION__), logString: "No current peripheral found, unable to disconnect peripheral")
            return
        }
        
        //Cancel any current or pending connection to the peripheral
        let peripheral = currentPeripheral!.currentPeripheral
        if peripheral.state == CBPeripheralState.Connected || peripheral.state == CBPeripheralState.Connecting {
            cm!.cancelPeripheralConnection(peripheral)
        }
        
    }
    
    
    func alertDismissedOnError() {
        
        //        if buttonIndex == 77 {
        //            currentAlertView = nil
        //        }
        
        if (connectionStatus == ConnectionStatus.Connected) {
            disconnect()
        }
        else if (connectionStatus == ConnectionStatus.Scanning){
            
            if cm == nil {
                printLog(self, funcName: "alertView clickedButtonAtIndex", logString: "No central Manager found, unable to stop scan")
                return
            }
            
            stopScan()
        }
        
        connectionStatus = ConnectionStatus.Idle
        connectionMode = ConnectionMode.None
        
        currentAlertView = nil
        
        //alert dismisses automatically @ return
        
    }
    
    
    func pushViewController(vc:UIViewController) {
        
        //if currentAlertView != nil {
        if ((self.presentedViewController) != nil) {
            self.presentedViewController!.dismissViewControllerAnimated(false, completion: { () -> Void in
                self.navController.pushViewController(vc, animated: true)
              //  self.currentAlertView = nil
            })
        }
        else {
            navController.pushViewController(vc, animated: true)
        }
        
        self.currentAlertView = nil
    }
    
    
    //MARK: Navigation Controller delegate methods
    
    func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
        
        // Returning from a module, about to show device list ...
        if viewController === deviceListViewController {
            
            // Returning from Device Info
            if connectionMode == ConnectionMode.Info {
                if connectionStatus == ConnectionStatus.Connected {
                    disconnect()
                }
            }
                
                // Returning from UART
            else if connectionMode == ConnectionMode.UART {
                uartViewController?.inputTextView.resignFirstResponder()
                
                if connectionStatus == ConnectionStatus.Connected {
                    disconnect()
                }
            }
                
                // Returning from Pin I/O
            else if connectionMode == ConnectionMode.PinIO {
                if connectionStatus == ConnectionStatus.Connected {
                    pinIoViewController.systemReset()
                    disconnect()
                }
            }
                
                // Returning from Controller
            else if connectionMode == ConnectionMode.Controller {
                controllerViewController?.stopSensorUpdates()
                
                if connectionStatus == ConnectionStatus.Connected {
                    disconnect()
                }
            }
                
                // Returning from DFU
            else if connectionMode == ConnectionMode.DFU {
                //                if connectionStatus == ConnectionStatus.Connected {
                disconnect()
                //                }
                //return cbcentralmanager delegation to self
                cm?.delegate = self
                connectionMode = ConnectionMode.None
                dereferenceModeController()
            }
                
                // Starting in device list
                // Start scaning if bluetooth is enabled
            else if (connectionStatus == ConnectionStatus.Idle) && (cm?.state != CBCentralManagerState.PoweredOff) {
                startScan()
            }
            
            //All modes hide toolbar except for device list
            navController.setToolbarHidden(false, animated: true)
        }
            //DFU mode doesn't maintain a connection, so back button sez "Back"!
        else if dfuViewController != nil && viewController == dfuViewController {
            deviceListViewController.navigationItem.backBarButtonItem?.title = "Back"
        }
            
            //All modes hide toolbar except for device list
        else {
            deviceListViewController.navigationItem.backBarButtonItem?.title = "Disconnect"
            navController.setToolbarHidden(true, animated: false)
        }
    }
    
    
    //MARK: CBCentralManagerDelegate methods
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        
        if (central.state == CBCentralManagerState.PoweredOn){
            
            //respond to powered on
        }
            
        else if (central.state == CBCentralManagerState.PoweredOff){
            
            //respond to powered off
        }
        
    }
    
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        if connectionMode == ConnectionMode.None {
            dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                if self.deviceListViewController == nil {
                    self.createDeviceListViewController()
                }
                self.deviceListViewController.didFindPeripheral(peripheral, advertisementData: advertisementData, RSSI:RSSI)
            })
            
            if navController.topViewController != deviceListViewController {
                dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                    self.pushViewController(self.deviceListViewController)
                })
            }
            
        }
    }
    
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        
        if (delegate != nil) {
            delegate!.onDeviceConnectionChange(peripheral)
        }
        
        //Connecting in DFU mode, discover specific services
        if connectionMode == ConnectionMode.DFU {
            peripheral.discoverServices([dfuServiceUUID(), deviceInformationServiceUUID()])
        }
        
        if currentPeripheral == nil {
            printLog(self, funcName: "didConnectPeripheral", logString: "No current peripheral found, unable to connect")
            return
        }
        
        
        if currentPeripheral!.currentPeripheral == peripheral {
            
            printLog(self, funcName: "didConnectPeripheral", logString: "\(peripheral.name)")
            
            //Discover Services for device
            if((peripheral.services) != nil){
                printLog(self, funcName: "didConnectPeripheral", logString: "Did connect to existing peripheral \(peripheral.name)")
                currentPeripheral!.peripheral(peripheral, didDiscoverServices: nil)  //already discovered services, DO NOT re-discover. Just pass along the peripheral.
            }
            else {
                currentPeripheral!.didConnect(connectionMode)
            }
            
        }
    }
    
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        
        //respond to disconnection
        
        if (delegate != nil) {
            delegate!.onDeviceConnectionChange(peripheral)
        }
        
        if connectionMode == ConnectionMode.DFU {
            connectionStatus = ConnectionStatus.Idle
            return
        }
        else if connectionMode == ConnectionMode.Controller {
            controllerViewController.showNavbar()
        }
        
        printLog(self, funcName: "didDisconnectPeripheral", logString: "")
        
        if currentPeripheral == nil {
            printLog(self, funcName: "didDisconnectPeripheral", logString: "No current peripheral found, unable to disconnect")
            return
        }
        
        //if we were in the process of scanning/connecting, dismiss alert
        if (currentAlertView != nil) {
            uartDidEncounterError("Peripheral disconnected")
        }
        
        //if status was connected, then disconnect was unexpected by the user, show alert
        let topVC = navController.topViewController
        if  connectionStatus == ConnectionStatus.Connected && isModuleController(topVC!) {
            
            printLog(self, funcName: "centralManager:didDisconnectPeripheral", logString: "unexpected disconnect while connected")
            
            //return to main view
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.respondToUnexpectedDisconnect()
            })
        }
            
            // Disconnected while connecting
        else if connectionStatus == ConnectionStatus.Connecting {
            
            abortConnection()
            
            printLog(self, funcName: "centralManager:didDisconnectPeripheral", logString: "unexpected disconnect while connecting")
            
            //return to main view
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.respondToUnexpectedDisconnect()
            })
            
        }
        
        connectionStatus = ConnectionStatus.Idle
        connectionMode = ConnectionMode.None
        currentPeripheral = nil
        
        // Dereference mode controllers
        dereferenceModeController()
        
    }
    
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        
        if (delegate != nil) {
            delegate!.onDeviceConnectionChange(peripheral)
        }
        
    }
    
    
    func respondToUnexpectedDisconnect() {
        
        self.navController.popToRootViewControllerAnimated(true)
        
        //display disconnect alert
        let alert = UIAlertView(title:"Disconnected",
            message:"BlE device disconnected",
            delegate:self,
            cancelButtonTitle:"OK")
        
        let note = UILocalNotification()
        note.fireDate = NSDate().dateByAddingTimeInterval(0.0)
        note.alertBody = "BLE device disconnected"
        note.soundName =  UILocalNotificationDefaultSoundName
        UIApplication.sharedApplication().scheduleLocalNotification(note)
        
        alert.show()
        
        
    }


    func dereferenceModeController() {
        
        pinIoViewController = nil
        uartViewController = nil
        deviceInfoViewController = nil
        controllerViewController = nil
        dfuViewController = nil
    }
    
    
    func isModuleController(anObject:AnyObject)->Bool{
        
        var verdict = false
        if     anObject.isMemberOfClass(PinIOViewController)
            || anObject.isMemberOfClass(UARTViewController)
            || anObject.isMemberOfClass(DeviceInfoViewController)
            || anObject.isMemberOfClass(ControllerViewController)
            || anObject.isMemberOfClass(DFUViewController)
            || (anObject.title == "Control Pad")
            || (anObject.title == "Color Picker") {
                verdict = true
        }
        
        //all controllers are modules except BLEMainViewController - weak
        //        var verdict = true
        //        if anObject.isMemberOfClass(BLEMainViewController) {
        //            verdict = false
        //        }
        
        return verdict
        
    }
    
    
    //MARK: BLEPeripheralDelegate methods
    
    func connectionFinalized() {
        
        //Bail if we aren't in the process of connecting
        if connectionStatus != ConnectionStatus.Connecting {
            printLog(self, funcName: "connectionFinalized", logString: "with incorrect state")
            return
        }
        
        if (currentPeripheral == nil) {
            printLog(self, funcName: "connectionFinalized", logString: "Unable to start info w nil currentPeripheral")
            return
        }
        
        //stop time out timer
        connectionTimer?.invalidate()
        
        connectionStatus = ConnectionStatus.Connected
        
        // Check if automatic update should be presented to the user
        if (firmwareUpdater != nil && connectionMode != .DFU) {
            // Wait till an updates are checked
             printLog(self, funcName: "connectionFinalized", logString: "Check if updates are available")
            firmwareUpdater!.checkUpdatesForPeripheral(currentPeripheral!.currentPeripheral, delegate: self)
        }
        else {
            // Automatic updates not enabled. Just go to the mode selected by the user
            launchViewControllerForSelectedMode()
        }
    }
    

    func launchViewControllerForSelectedMode() {
        //Push appropriate viewcontroller onto the navcontroller
        var vc:UIViewController? = nil
        switch connectionMode {
        case ConnectionMode.PinIO:
            pinIoViewController = PinIOViewController(delegate: self)
            pinIoViewController.didConnect()
            vc = pinIoViewController
            break
        case ConnectionMode.UART:
            uartViewController = UARTViewController(aDelegate: self)
            uartViewController.didConnect()
            vc = uartViewController
            break
        case ConnectionMode.Info:
            deviceInfoViewController = DeviceInfoViewController(cbPeripheral: currentPeripheral!.currentPeripheral, delegate: self)
            vc = deviceInfoViewController
            break
        case ConnectionMode.Controller:
            controllerViewController = ControllerViewController(aDelegate: self)
            vc = controllerViewController
        case ConnectionMode.DFU:
            printLog(self, funcName: (__FUNCTION__), logString: "DFU mode")
        default:
            printLog(self, funcName: (__FUNCTION__), logString: "No connection mode set")
            break
        }
        
        if (vc != nil) {
            vc?.navigationItem.rightBarButtonItem = infoBarButton
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.pushViewController(vc!)
            })
        }
    }
    
    
    func launchDFU(peripheral:CBPeripheral){
        
        printLog(self, funcName: (__FUNCTION__), logString: self.description)
        
        connectionMode = ConnectionMode.DFU
        dfuViewController = DFUViewController()
        dfuViewController.peripheral = peripheral
        //        dfuViewController.navigationItem.rightBarButtonItem = infoBarButton
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.pushViewController(self.dfuViewController!)
        })
        
    }
    
    
    func uartDidEncounterError(error: NSString) {
        
        //Dismiss "scanning …" alert view if shown
        if (currentAlertView != nil) {
            currentAlertView?.dismissViewControllerAnimated(true, completion: { () -> Void in
                self.alertDismissedOnError()
            })
        }
        
        //Display error alert
        let alert = UIAlertController(title: "Error", message: error as String, preferredStyle: UIAlertControllerStyle.Alert)
        let aaOK = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil)
        alert.addAction(aaOK)
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    
    func didReceiveData(newData: NSData) {
        
        //Data incoming from UART peripheral, forward to current view controller
        
        printLog(self, funcName: "didReceiveData", logString: "\(newData.hexRepresentationWithSpaces(true))")
        
        if (connectionStatus == ConnectionStatus.Connected ) {
            //UART
            if (connectionMode == ConnectionMode.UART) {
                //send data to UART Controller
                uartViewController.receiveData(newData)
            }
                
                //Pin I/O
            else if (connectionMode == ConnectionMode.PinIO) {
                //send data to PIN IO Controller
                pinIoViewController.receiveData(newData)
            }
        }
        else {
            printLog(self, funcName: "didReceiveData", logString: "Received data without connection")
        }
        
    }
    
    
    func peripheralDidDisconnect() {
        
        //respond to device disconnecting
        
        printLog(self, funcName: "peripheralDidDisconnect", logString: "")
        
        //if we were in the process of scanning/connecting, dismiss alert
        if (currentAlertView != nil) {
            uartDidEncounterError("Peripheral disconnected")
        }
        
        //if status was connected, then disconnect was unexpected by the user, show alert
        let topVC = navController.topViewController
        if  connectionStatus == ConnectionStatus.Connected && isModuleController(topVC!) {
            
            printLog(self, funcName: "peripheralDidDisconnect", logString: "unexpected disconnect while connected")
            
            //return to main view
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.respondToUnexpectedDisconnect()
            })
        }
        
        connectionStatus = ConnectionStatus.Idle
        connectionMode = ConnectionMode.None
        currentPeripheral = nil
        
        // Dereference mode controllers
        dereferenceModeController()
        
    }
    
    
    func alertBluetoothPowerOff() {
        
        //Respond to system's bluetooth disabled
        
        let title = "Bluetooth Power"
        let message = "You must turn on Bluetooth in Settings in order to connect to a device"
        let alertView = UIAlertView(title: title, message: message, delegate: nil, cancelButtonTitle: "OK")
        alertView.show()
    }
    
    
    func alertFailedConnection() {
        
        //Respond to unsuccessful connection
        
        let title = "Unable to connect"
        let message = "Please check power & wiring,\nthen reset your Arduino"
        let alertView = UIAlertView(title: title, message: message, delegate: nil, cancelButtonTitle: "OK")
        alertView.show()
        
    }
    
    
    //MARK: UartViewControllerDelegate / PinIOViewControllerDelegate methods
    
    func sendData(newData: NSData) {
        
        //Output data to UART peripheral
        
        let hexString = newData.hexRepresentationWithSpaces(true)
        
        printLog(self, funcName: "sendData", logString: "\(hexString)")
        
        
        if currentPeripheral == nil {
            printLog(self, funcName: "sendData", logString: "No current peripheral found, unable to send data")
            return
        }
        
        currentPeripheral!.writeRawData(newData)
        
    }
    
    
    //WatchKit requests
    
    func connectedInControllerMode()->Bool{
        
        if connectionStatus == ConnectionStatus.Connected &&
            connectionMode == ConnectionMode.Controller   &&
            controllerViewController != nil {
                return true
        }
        else {
            return false
        }
    }
    
    
    func disconnectviaWatch(){
        
//        NSLog("disconnectviaWatch")
        
        controllerViewController?.stopSensorUpdates()
        disconnect()
//        navController.popToRootViewControllerAnimated(true)
        
    }
    
    
    // MARK: - FirmwareUpdaterDelegate
    
    func onFirmwareUpdatesAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo!, deviceInfoData: DeviceInfoData!, allReleases: [NSObject : AnyObject]!) {
        printLog(self, funcName: "onFirmwareUpdatesAvailable", logString: "\(isUpdateAvailable)")
        
        cm?.delegate = self
        
        if (isUpdateAvailable) {
            dispatch_async(dispatch_get_main_queue(), { [unowned self] in
                
                // Dismiss current dialog
                self.currentAlertView = nil
                if (self.presentedViewController != nil) {
                    self.presentedViewController!.dismissViewControllerAnimated(true, completion: { _ in
                        self.currentAlertView = nil
                        self.showUpdateAvailableForRelease(latestRelease)
                    })
                }
                else {
                    self.showUpdateAvailableForRelease(latestRelease)
                }
            })
        }
        else {
            launchViewControllerForSelectedMode()
        }
    }
    
    func dfuServiceNotFound() {
        printLog(self, funcName: "dfuServiceNotFound", logString: "")
        
        cm?.delegate = self
        launchViewControllerForSelectedMode()
    }
    
    func showUpdateAvailableForRelease(latestRelease: FirmwareInfo!) {
        let alert = UIAlertController(title:"Update available", message: "Software version \(latestRelease.version) is available", preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: "Go to updates", style: UIAlertActionStyle.Default, handler: { _ in
            self.launchDFU(self.currentPeripheral!.currentPeripheral)
        }))
        alert.addAction(UIAlertAction(title: "Ask later", style: UIAlertActionStyle.Default, handler: { _ in
            self.launchViewControllerForSelectedMode()
        }))
        alert.addAction(UIAlertAction(title: "Ignore", style: UIAlertActionStyle.Cancel, handler: { _ in
            NSUserDefaults.standardUserDefaults().setObject(latestRelease.version, forKey: "softwareUpdateIgnoredVersion")
            self.launchViewControllerForSelectedMode()
        }))
        self.presentViewController(alert, animated: true, completion: nil)
        //self.currentAlertView = alert


    }
    
}


