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

class BLEMainViewController : UIViewController, UINavigationControllerDelegate, HelpViewControllerDelegate, CBCentralManagerDelegate, UARTPeripheralDelegate, UARTViewControllerDelegate, PinIOViewControllerDelegate, UIAlertViewDelegate {
    
    enum ConnectionMode:Int {
        case None = 0
        case PinIO
        case UART
    }
    
    enum ConnectionStatus:Int {
        case Disconnected = 0
        case Scanning
        case Connected
    }
    
    var connectionMode:ConnectionMode = ConnectionMode.None
    var connectionStatus:ConnectionStatus = ConnectionStatus.Disconnected
    var helpPopoverController:UIPopoverController?
    @IBOutlet var pinIoViewController:PinIOViewController!
    @IBOutlet var uartViewController:UARTViewController!
    @IBOutlet var deviceListViewController:DeviceListViewController!
    @IBOutlet var pinIoButton:UIButton!
    @IBOutlet var uartButton:UIButton!
    @IBOutlet var scanListButton:UIButton!
    @IBOutlet var infoButton:UIButton!
    @IBOutlet var navController:UINavigationController!
    @IBOutlet var menuViewController:UIViewController!
    @IBOutlet var helpViewController:HelpViewController!
    @IBOutlet var helpView:UIView!
    @IBOutlet var logo:UIImageView!
    
    private var cm:CBCentralManager?
    private var currentAlertView:UIAlertView?
    private var currentPeripheral:UARTPeripheral?
    private var infoBarButton:UIBarButtonItem?
    private let cbcmQueue = dispatch_queue_create("com.adafruit.bluefruitconnect.cbcmqueue", nil)
    
    //MARK: View Lifecycle
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        
        var newNibName:String
        
        if (IS_IPHONE_4){
            newNibName = "BLEMainViewController_iPhone"
        }
        else if (IS_IPHONE_5){
            newNibName = "BLEMainViewController_iPhone568px"
        }
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
        
        view.autoresizesSubviews = true
        addChildViewController(navController)
        view.addSubview(navController.view)
        
        //disable navcontroller's swiping feature
        navController.interactivePopGestureRecognizer.enabled = false
        
        cm = CBCentralManager(delegate: self, queue: cbcmQueue)
        connectionMode = ConnectionMode.None
        connectionStatus = ConnectionStatus.Disconnected
        currentAlertView = nil
        
        //add info bar button to mode controllers
        let archivedData = NSKeyedArchiver.archivedDataWithRootObject(infoButton)
        let buttonCopy = NSKeyedUnarchiver.unarchiveObjectWithData(archivedData) as UIButton
        buttonCopy.addTarget(self, action: Selector("showInfo:"), forControlEvents: UIControlEvents.TouchUpInside)
        infoBarButton = UIBarButtonItem(customView: buttonCopy)
        
    }
    
    
    //MARK: Root UI
    
    func helpViewControllerDidFinish(controller: HelpViewController) {
        
        //Called when help view's done button is tapped
        
        if (IS_IPHONE) {
            dismissViewControllerAnimated(true, completion: nil)
        }
            
        else {
            helpPopoverController?.dismissPopoverAnimated(true)
        }
        
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
            if helpPopoverController != nil {
                if helpPopoverController!.popoverVisible {
                    helpPopoverController?.dismissPopoverAnimated(true)
                    helpPopoverController = nil
                }
                
            }
                
                //show popover if it isn't shown
            else {
                helpPopoverController = UIPopoverController(contentViewController: currentHelpViewController())
                helpPopoverController?.backgroundColor = UIColor.darkGrayColor()
                
                let rightBBI:UIBarButtonItem! = navController.navigationBar.items.last!.rightBarButtonItem
                let aFrame:CGRect = rightBBI!.customView!.frame
                helpPopoverController?.presentPopoverFromRect(aFrame,
                    inView: rightBBI.customView!.superview!,
                    permittedArrowDirections: UIPopoverArrowDirection.Any,
                    animated: true)
            }
        }
    }
    
    
    @IBAction func buttonTapped(sender:UIButton){
        
        //Called by Pin I/O or UART Monitor connect buttons
        
        if currentAlertView != nil && currentAlertView!.visible {
            println("ALERT VIEW ALREADY SHOWN")
            return
        }
        
        if sender === pinIoButton {    //Pin I/O
            println("Starting Pin I/O Mode …")
            connectionMode = ConnectionMode.PinIO
            
        }
        else if sender === uartButton{ //UART
            println("Starting UART Mode …")
            connectionMode = ConnectionMode.UART
        }
        else if sender === scanListButton {
            
        }
        else {
            println("Scanning all devices …")
            cm!.scanForPeripheralsWithServices(nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            return
        }
        
        connectionStatus = ConnectionStatus.Scanning
        disableConnectionButtons()
        scanForPeripherals()
        
        currentAlertView = UIAlertView(title: "Scanning …", message: nil, delegate: self, cancelButtonTitle: "Cancel")
        currentAlertView!.show()
        
    }
    
    
    func scanForPeripherals() {
        
        //Look for available Bluetooth LE devices
        
        if cm == nil {
            println("No central Manager found, unable to scan for peripherals")
            return
        }
        
        //skip scanning if UART is already connected
        let connectedPeripherals = cm!.retrieveConnectedPeripheralsWithServices([UARTPeripheral.uartServiceUUID()])
        
        if connectedPeripherals.count > 0 {
            //connect to first peripheral in array
            connectPeripheral(connectedPeripherals[0] as CBPeripheral)
        }
            
        else{
            cm!.scanForPeripheralsWithServices([UARTPeripheral.uartServiceUUID()], options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber.numberWithBool(false)])
        }
        
    }
    
    
    func connectPeripheral(peripheral:CBPeripheral) {
        
        //Connect Bluetooth LE device
        
        if cm == nil {
            println("No central Manager found, unable to connect peripheral")
            return
        }
        
        //Clear off any pending connections
        cm!.cancelPeripheralConnection(peripheral)
        
        //Connect
        currentPeripheral = UARTPeripheral(peripheral: peripheral, delegate: self)
        cm!.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber.numberWithBool(true)])
        
    }
    
    
    func disconnect() {
        
        //Disconnect Bluetooth LE device
        
        connectionStatus = ConnectionStatus.Disconnected
        connectionMode = ConnectionMode.None
        
        if cm == nil {
            println("No central Manager found, unable to disconnect peripheral")
            return
        }
            
        else if currentPeripheral == nil {
            println("No current peripheral found, unable to disconnect peripheral")
            return
        }
        
        cm!.cancelPeripheralConnection(currentPeripheral!.currentPeripheral)
        
    }
    
    
    func disableConnectionButtons() {
        
        uartButton.enabled = false
        pinIoButton.enabled = false
        
        self.view.setNeedsDisplay()
        
    }
    
    
    func enableConnectionButtons(timer:NSTimer) {
        
        enableConnectionButtons()
    }
    
    
    func enableConnectionButtons() {
        
        uartButton.enabled = true
        pinIoButton.enabled = true
        scanListButton.enabled = true
        
    }
    
    
    //MARK: UIAlertView delegate methods
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        
        //the only button in our alert views is cancel, no need to check button index
        
        if (connectionStatus == ConnectionStatus.Connected) {
            disconnect()
        }
        else if (connectionStatus == ConnectionStatus.Scanning){
            
            if cm == nil {
                println("No central Manager found, unable to stop scan")
                return
            }
            
            cm!.stopScan()
        }
        
        connectionStatus = ConnectionStatus.Disconnected
        connectionMode = ConnectionMode.None
        
        currentAlertView = nil
        
        enableConnectionButtons()
        
        //alert dismisses automatically @ return
        

        
    }
    
    
    //MARK: Navigation Controller delegate methods
    
    func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
        
        //disconnect when returning to main view
        if (connectionStatus == ConnectionStatus.Connected && viewController === menuViewController) {
            disconnect()
            
            //dismiss UART keyboard
            uartViewController?.inputField.resignFirstResponder()
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
        
        //TODO: Delete after debug
        println("Discovered peripheral: \(peripheral.description)")
        println("   RSSI: \(RSSI)")
        println("   Advertisement Data:")
        println("       Local Name:              \( (advertisementData[CBAdvertisementDataLocalNameKey] as? NSString)!)")
        println("       Manufacturer Data:       \( (advertisementData[CBAdvertisementDataManufacturerDataKey] as? NSData)?.description )")
        println("       Service Data:            \( (advertisementData[CBAdvertisementDataServiceDataKey] as? NSDictionary)?.description )")
        print(  "       Service UUIDs:           ")
        
        let advData = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? NSArray
        advData?.enumerateObjectsUsingBlock({ (obj:AnyObject!, idx:Int, stop:UnsafeMutablePointer<ObjCBool>) -> Void in
            let objUUID = obj as? CBUUID
            if idx != 0 { print("                               ")}
            println("\(objUUID!.UUIDString)")
        })
        
        println("       Overflow Service UUIDs:  \( (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? NSArray)?.description )")
        println("       TX Power Level:          \( (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)! )")
        println("       Is Connectable:          \( (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)!.boolValue )")
        println("       Solicited Service UUIDs: \( (advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? NSArray)?.description ) ")
        println("-")
        
        
        println("Did discover peripheral \(peripheral.name)")
        
        if cm == nil {
            println("No central Manager found, unable to stop scan")
            return
        }
        
        cm!.stopScan()
        
        connectPeripheral(peripheral)
    }
    
    
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        
        if currentPeripheral == nil {
            println("No current peripheral found, unable to connect")
            return
        }
        
        if currentPeripheral!.currentPeripheral == peripheral {
            
            if((peripheral.services) != nil){
                println("Did connect to existing peripheral \(peripheral.name)")
                currentPeripheral!.peripheral(peripheral, didDiscoverServices: nil)  //already discovered services, DO NOT re-discover. Just pass along the peripheral.
            }
                
            else{
                println("Did connect peripheral \(peripheral.name)")
                currentPeripheral!.didConnect()
            }
        }
    }
    
    
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        
        println("Did disconnect peripheral \(peripheral.name)")
        
        if currentPeripheral == nil {
            println("No current peripheral found, unable to disconnect")
            return
        }
        
        //respond to disconnected
        peripheralDidDisconnect()
        
        if currentPeripheral!.currentPeripheral == peripheral {
            currentPeripheral!.didDisconnect()
        }
        
    }
    
    
    //MARK: UARTPeripheralDelegate
    
    func didReadSoftwareRevisionString(string: NSString) {
        
        //Once hardware revision string is read, connection to Bluefruit is complete
        
        println("Software Revision: \(string)")
        
        //Bail if we aren't in the process of connecting
        if (currentAlertView == nil){
            return
        }
        
        connectionStatus = ConnectionStatus.Connected
        
        //Load appropriate view controller …
        
        //Pin I/O mode
        if (connectionMode == ConnectionMode.PinIO) {
            pinIoViewController = PinIOViewController(delegate: self)
            pinIoViewController.navigationItem.rightBarButtonItem = infoBarButton
            pinIoViewController.didConnect()
        }
            
            //UART mode
        else if connectionMode == ConnectionMode.UART {
            uartViewController = UARTViewController(aDelegate: self)
            uartViewController.navigationItem.rightBarButtonItem = infoBarButton
            uartViewController.didConnect()
        }
        
        //Dismiss Alert view & update main view
        currentAlertView?.dismissWithClickedButtonIndex(-1, animated: false)
        
        //Push appropriate viewcontroller onto the navcontroller
        var vc:UIViewController? = nil
        
        if connectionMode == ConnectionMode.PinIO{
            vc = pinIoViewController
        }
            
        else if connectionMode == ConnectionMode.UART {
            vc = uartViewController
        }
        
        if (vc != nil) {
            navController.pushViewController(vc!, animated: true)
        }
            
        else {
            println("CONNECTED WITH NO CONNECTION MODE SET!")
        }
        
        currentAlertView = nil
        
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
        
        //Debug
        let hexString = newData.hexRepresentationWithSpaces(true)
        
        if LOGGING {
            println("Received: \(hexString)")
        }
        
        if (connectionStatus == ConnectionStatus.Connected || connectionStatus == ConnectionStatus.Scanning) {
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
    }
    
    
    func peripheralDidDisconnect() {
        
        //respond to device disconnecting
        
        //if we were in the process of scanning/connecting, dismiss alert
        if (currentAlertView != nil) {
            uartDidEncounterError("Peripheral disconnected")
        }
        
        //if status was connected, then disconnect was unexpected by the user, show alert
        let topVC = navController.topViewController
        if ((connectionStatus == ConnectionStatus.Connected) &&
            (topVC.isMemberOfClass(PinIOViewController) ||
                topVC.isMemberOfClass(UARTViewController))) {
                    
                    //return to main view
                    navController.popToRootViewControllerAnimated(true)
                    
                    //display disconnect alert
                    let alert = UIAlertView(title:"Disconnected",
                        message:"BLE peripheral has disconnected",
                        delegate:nil,
                        cancelButtonTitle:"OK")
                    
                    alert.show()
        }
        
        connectionStatus = ConnectionStatus.Disconnected
        connectionMode = ConnectionMode.None
        
        //dereference mode controllers
        pinIoViewController = nil
        uartViewController = nil
        
        delay(1.0, { () -> () in
            self.enableConnectionButtons()
            return
        })
        
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
        
        if LOGGING {
            println("Sending: \(hexString)")
        }
        
        if currentPeripheral == nil {
            println("No current peripheral found, unable to send data")
            return
        }
        
        currentPeripheral!.writeRawData(newData)
        
    }
    
    
}