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
    case PinIO
    case UART
    case DeviceList //TODO: Remove after UI flow finalized
    case Info
    case Controller
}

class BLEMainViewController : UIViewController, UINavigationControllerDelegate, HelpViewControllerDelegate, CBCentralManagerDelegate,
                              BLEPeripheralDelegate, UARTViewControllerDelegate, PinIOViewControllerDelegate, UIAlertViewDelegate,
                              DeviceListViewControllerDelegate {

    
    
    enum ConnectionStatus:Int {
        case Idle = 0
        case Scanning
        case Connected
        case Connecting
    }
    
    var connectionMode:ConnectionMode = ConnectionMode.DeviceList
    var connectionStatus:ConnectionStatus = ConnectionStatus.Idle
    var helpPopoverController:UIPopoverController?
    var navController:UINavigationController!
    var pinIoViewController:PinIOViewController!
    var uartViewController:UARTViewController!
    var deviceListViewController:DeviceListViewController!
    var deviceInfoViewController:DeviceInfoViewController!
    var controllerViewController:ControllerViewController!
    @IBOutlet var infoButton:UIButton!
    @IBOutlet var warningLabel:UILabel!
    
    @IBOutlet var helpViewController:HelpViewController!
    
    private var cm:CBCentralManager?
    private var currentAlertView:UIAlertView?
    private var currentPeripheral:BLEPeripheral?
    private var infoBarButton:UIBarButtonItem?
    private var scanIndicator:UIActivityIndicatorView?
    private var scanIndicatorItem:UIBarButtonItem?
    private var scanButtonItem:UIBarButtonItem?
    private let cbcmQueue = dispatch_queue_create("com.adafruit.bluefruitconnect.cbcmqueue", DISPATCH_QUEUE_CONCURRENT)
    private let connectionTimeOutIntvl:NSTimeInterval = 30.0
    private var connectionTimer:NSTimer?
    
    
    //MARK: View Lifecycle
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        
        var newNibName:String
        
        if (IS_IPHONE){
            newNibName = "BLEMainViewController_iPhone"
        }
//        else if (IS_IPHONE_5){
//            newNibName = "BLEMainViewController_iPhone568px"
//        }
        else{
            newNibName = "BLEMainViewController_iPad"
        }
        
        super.init(nibName: newNibName, bundle: NSBundle.mainBundle())
        
        
    }
    
    
    required init(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)
        
    }
    
    
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
        navController.interactivePopGestureRecognizer.enabled = false
        
        if IS_IPHONE {
            addChildViewController(navController)
            view.addSubview(navController.view)
        }
        
        // Create core bluetooth manager on launch
        if (cm == nil) {
            cm = CBCentralManager(delegate: self, queue: cbcmQueue)
            
            connectionMode = ConnectionMode.DeviceList
            connectionStatus = ConnectionStatus.Idle
            currentAlertView = nil
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
        let buttonCopy = NSKeyedUnarchiver.unarchiveObjectWithData(archivedData) as UIButton
        buttonCopy.addTarget(self, action: Selector("showInfo:"), forControlEvents: UIControlEvents.TouchUpInside)
        infoBarButton = UIBarButtonItem(customView: buttonCopy)
        deviceListViewController = DeviceListViewController(aDelegate: self)
        deviceListViewController.navigationItem.rightBarButtonItem = infoBarButton
        deviceListViewController.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Disconnect", style: UIBarButtonItemStyle.Plain, target: nil, action: nil)
        //add scan indicator to toolbar
        scanIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.White)
        scanIndicator!.hidesWhenStopped = false
//        scanIndicator!.startAnimating()
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
        
        if (connectionMode == ConnectionMode.DeviceList) {
            cm?.stopScan()
            scanIndicator?.stopAnimating()
            
            //If scan indicator is in toolbar items, remove it
            let count:Int = deviceListViewController.toolbarItems!.count
            var index = -1
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
            //Show alert to enable bluetooth
            let alert = UIAlertController(title: "Bluetooth disabled", message: "Enable Bluetooth in system settings", preferredStyle: UIAlertControllerStyle.Alert)
            let aaOK = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (aa:UIAlertAction!) -> Void in
                
            })
            alert.addAction(aaOK)
            self.presentViewController(alert, animated: true, completion: { () -> Void in
                
            })
            return
        }
        
        cm!.scanForPeripheralsWithServices(nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(bool:true)])
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
    
    
    func currentHelpViewController()->HelpViewController {
        
        //Determine which help view to show based on the current view shown
        
        var hvc:HelpViewController
        
        if navController.topViewController.isKindOfClass(PinIOViewController){
            hvc = pinIoViewController.helpViewController
        }
            
        else if navController.topViewController.isKindOfClass(UARTViewController){
            hvc = uartViewController.helpViewController
        }
        else if navController.topViewController.isKindOfClass(DeviceListViewController){
            hvc = deviceListViewController.helpViewController
        }
        else if navController.topViewController.isKindOfClass(DeviceInfoViewController){
            hvc = deviceInfoViewController.helpViewController
        }
        else if navController.topViewController.isKindOfClass(ControllerViewController){
            hvc = controllerViewController.helpViewController
        }
            
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
                
                let rightBBI:UIBarButtonItem! = navController.navigationBar.items.last!.rightBarButtonItem
                let aFrame:CGRect = rightBBI!.customView!.frame
                helpPopoverController?.presentPopoverFromRect(aFrame,
                    inView: rightBBI.customView!.superview!,
                    permittedArrowDirections: UIPopoverArrowDirection.Any,
                    animated: true)
//            }
        }
    }
    
    
    func connectPeripheral(peripheral:CBPeripheral, mode:ConnectionMode) {
        
        printLog(self, "connectPeripheral", "")
        
        connectionTimer?.invalidate()
        
        if cm == nil {
            printLog(self, "ConnectPeripheral", "No central Manager found, unable to connect peripheral")
            return
        }
        
        stopScan()
        
        //Show connection activity alert view
        currentAlertView = UIAlertView(title: "Connecting …", message: nil, delegate: self, cancelButtonTitle: nil)
        currentAlertView!.show()
        
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
    
    
    func connectionTimedOut(timer:NSTimer) {
        
        if connectionStatus != ConnectionStatus.Connecting {
            return
        }
        
        //dismiss "Connecting" alert view
        if currentAlertView?.visible == true {
            currentAlertView?.dismissWithClickedButtonIndex(-77, animated: true)
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
        
        cm?.cancelPeripheralConnection(currentPeripheral?.currentPeripheral)
        
        currentPeripheral = nil
        
        connectionMode = ConnectionMode.DeviceList
        connectionStatus = ConnectionStatus.Idle
    }
    
    
    func disconnect() {
        
        printLog(self, "disconnect()", "")
        
        if cm == nil {
            printLog(self, "disconnect", "No central Manager found, unable to disconnect peripheral")
            return
        }
            
        else if currentPeripheral == nil {
            printLog(self, "disconnect", "No current peripheral found, unable to disconnect peripheral")
            return
        }
        
        //Cancel any current or pending connection to the peripheral
        let peripheral = currentPeripheral!.currentPeripheral
        if peripheral.state == CBPeripheralState.Connected || peripheral.state == CBPeripheralState.Connecting {
            cm!.cancelPeripheralConnection(peripheral)
        }
        
    }
    
    
    //MARK: UIAlertView delegate methods
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        
        //the only button in our alert views is cancel, no need to check button index
        
        if buttonIndex == 77 {
            currentAlertView = nil
        }
        
        if (connectionStatus == ConnectionStatus.Connected) {
            disconnect()
        }
        else if (connectionStatus == ConnectionStatus.Scanning){
            
            if cm == nil {
                printLog(self, "alertView clickedButtonAtIndex", "No central Manager found, unable to stop scan")
                return
            }
            
            stopScan()
        }
        
        connectionStatus = ConnectionStatus.Idle
        connectionMode = ConnectionMode.DeviceList
        
        currentAlertView = nil
        
        //alert dismisses automatically @ return
        
    }
    
    
    func pushViewController(vc:UIViewController) {
        
        if currentAlertView != nil {
            self.currentAlertView?.dismissWithClickedButtonIndex(77, animated: false)
            self.currentAlertView = nil
        }
        
        navController.pushViewController(vc, animated: true)
        
    }
    
    
    //MARK: Navigation Controller delegate methods
    
    func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
        
        
        // About to show device list ...
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
            
            // Starting in device list
            // Start scaning if bluetooth is enabled
            else if (connectionStatus == ConnectionStatus.Idle) && (cm?.state != CBCentralManagerState.PoweredOff) {
                startScan()
            }
            
            //All modes hide toolbar except for device list
            navController.setToolbarHidden(false, animated: true)
        }
        
        //All modes hide toolbar except for device list
        else {
            navController.setToolbarHidden(true, animated: false)
        }
    }
    
    
    //MARK: CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        
        if (central.state == CBCentralManagerState.PoweredOn){
            
            //respond to powered on
        }
            
        else if (central.state == CBCentralManagerState.PoweredOff){
            
            //respond to powered off
        }
        
    }
    
    
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {

        if connectionMode == ConnectionMode.DeviceList {
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
    
    
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        
        if currentPeripheral == nil {
            printLog(self, "didConnectPeripheral", "No current peripheral found, unable to connect")
            return
        }
        
        if currentPeripheral!.currentPeripheral == peripheral {
            
            printLog(self, "didConnectPeripheral", "\(peripheral.name)")
            
            //Discover Services for device
            if((peripheral.services) != nil){
                printLog(self, "didConnectPeripheral", "Did connect to existing peripheral \(peripheral.name)")
                currentPeripheral!.peripheral(peripheral, didDiscoverServices: nil)  //already discovered services, DO NOT re-discover. Just pass along the peripheral.
            }
            else {
                currentPeripheral!.didConnect(connectionMode)
            }
            
        }
    }
    
    
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        
        //respond to disconnection
        
        printLog(self, "didDisconnectPeripheral", "")
        
        if currentPeripheral == nil {
            printLog(self, "didDisconnectPeripheral", "No current peripheral found, unable to disconnect")
            return
        }
        
        //if we were in the process of scanning/connecting, dismiss alert
        if (currentAlertView != nil) {
            uartDidEncounterError("Peripheral disconnected")
        }
        
        //if status was connected, then disconnect was unexpected by the user, show alert
        let topVC = navController.topViewController
        if  connectionStatus == ConnectionStatus.Connected && isModuleController(topVC) {
                
                printLog(self, "centralManager:didDisconnectPeripheral", "unexpected disconnect while connected")
                
                //return to main view
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.navController.popToRootViewControllerAnimated(true)
                    
                    //display disconnect alert
                    let alert = UIAlertView(title:"Disconnected",
                        message:"Peripheral disconnected unexpectedly",
                        delegate:self,
                        cancelButtonTitle:"OK")
                    
                    alert.show()
                })
        }
        
        // Disconnected while connecting
        else if connectionStatus == ConnectionStatus.Connecting {
            
            abortConnection()
            
            printLog(self, "centralManager:didDisconnectPeripheral", "unexpected disconnect while connecting")
            
            //return to main view
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.navController.popToRootViewControllerAnimated(true)
                
                //display disconnect alert
                let alert = UIAlertView(title:"Disconnected",
                    message:"Peripheral disconnected unexpectedly",
                    delegate:self,
                    cancelButtonTitle:"OK")
                
                alert.show()
            })
            
        }
        
        connectionStatus = ConnectionStatus.Idle
        connectionMode = ConnectionMode.DeviceList
        currentPeripheral = nil
        
        // Dereference mode controllers
        dereferenceModeController()
        
    }
    
    
    func dereferenceModeController() {
        
        pinIoViewController = nil
        uartViewController = nil
        deviceInfoViewController = nil
        
    }
    
    
    func isModuleController(anObject:AnyObject)->Bool{
        
        var verdict = false
        if     anObject.isMemberOfClass(PinIOViewController)
            || anObject.isMemberOfClass(UARTViewController)
            || anObject.isMemberOfClass(DeviceInfoViewController)
            || anObject.isMemberOfClass(ControllerViewController)
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
    
    
    //MARK: BLEPeripheralDelegate
    
    func connectionFinalized() {
        
        //Bail if we aren't in the process of connecting
        if connectionStatus != ConnectionStatus.Connecting {
            printLog(self, "connectionFinalized", "with incorrect state")
            return
        }
        
        if (currentPeripheral == nil) {
            printLog(self, "connectionFinalized", "Unable to start info w nil currentPeripheral")
            return
        }
        
        //stop time out timer
        connectionTimer?.invalidate()
        
        connectionStatus = ConnectionStatus.Connected
        
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
        default:
            printLog(self, "connectionFinalized", "No connection mode set")
            break
        }
        
        if (vc != nil) {
            vc?.navigationItem.rightBarButtonItem = infoBarButton
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.pushViewController(vc!)
            })
        }
        
    }
    
    
    func uartDidEncounterError(error: NSString) {
        
        //Dismiss "scanning …" alert view if shown
        if (currentAlertView != nil) {
            currentAlertView?.dismissWithClickedButtonIndex(0, animated: false)
        }
        
        //Display error alert
        let alert = UIAlertView(title: "Error", message: error, delegate: nil, cancelButtonTitle: "OK")
        alert.show()
    }
    
    
    func didReceiveData(newData: NSData) {
        
        //Data incoming from UART peripheral, forward to current view controller
        
        printLog(self, "didReceiveData", "\(newData.stringRepresentation())")
        
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
            printLog(self, "didReceiveData", "Received data without connection")
        }
        
    }
    
    
    func peripheralDidDisconnect() {
        
        //respond to device disconnecting
        
        printLog(self, "peripheralDidDisconnect", "")
        
        //if we were in the process of scanning/connecting, dismiss alert
        if (currentAlertView != nil) {
            uartDidEncounterError("Peripheral disconnected")
        }
        
        //if status was connected, then disconnect was unexpected by the user, show alert
        let topVC = navController.topViewController
        if  connectionStatus == ConnectionStatus.Connected && isModuleController(topVC) {
                
                printLog(self, "peripheralDidDisconnect", "unexpected disconnect while connected")
                
                    //return to main view
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.navController.popToRootViewControllerAnimated(true)
                        
                        //display disconnect alert
                        let alert = UIAlertView(title:"Disconnected",
                            message:"Peripheral disconnected unexpectedly",
                            delegate:nil,
                            cancelButtonTitle:"OK")
                        
                        alert.show()
                    })
        }
        
        connectionStatus = ConnectionStatus.Idle
        connectionMode = ConnectionMode.DeviceList
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
    
    
    //MARK: UartViewControllerDelegate / PinIOViewControllerDelegate
    
    func sendData(newData: NSData) {
        
        //Output data to UART peripheral
        
        let hexString = newData.hexRepresentationWithSpaces(true)
        
        printLog(self, "sendData", "\(hexString)")
        
        
        if currentPeripheral == nil {
            printLog(self, "sendData", "No current peripheral found, unable to send data")
            return
        }
        
        currentPeripheral!.writeRawData(newData)
        
    }
    
    
}