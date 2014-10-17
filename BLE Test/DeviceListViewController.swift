//
//  DeviceListViewController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/15/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

@objc protocol DeviceListViewControllerDelegate: HelpViewControllerDelegate {
    
    func sendData(newData:NSData)
    
}

class DeviceListViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate {
    
    weak var delegate:DeviceListViewControllerDelegate?
    @IBOutlet var tableView:UITableView!
    @IBOutlet var helpViewController:HelpViewController!
    
    
    convenience init(aDelegate:DeviceListViewControllerDelegate){
        
        //Separate NIBs for iPhone 3.5", iPhone 4", & iPad
        
        var nibName:NSString
        
        if IS_IPHONE_4{
            nibName = "DeviceListViewController_iPhone"
        }
        else if IS_IPHONE_5{
            nibName = "DeviceListViewController_iPhone568px"
        }
        else{   //IPAD
            nibName = "DeviceListViewController_iPad"
        }
        
        self.init(nibName: nibName, bundle: NSBundle.mainBundle())
        
        self.delegate = aDelegate
        self.title = "Devices"
        
    }
    
    
    //MARK: UITableViewDataSource functions
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        return UITableViewCell()
        
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 1
    }
    
    
    //MARK: UITableViewDelegate functions
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
    
    //MARK: CBCentralManagerDelegate functuions
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        
    }
    
    
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        
        println("Discovered peripheral: \(peripheral.description)")
        println("   RSSI: \(RSSI)")
        println("   Advertisement Data:")
        println("       Local Name:              \(advertisementData[CBAdvertisementDataLocalNameKey])")
        println("       Manufacturer Data:       \(advertisementData[CBAdvertisementDataManufacturerDataKey])")
        println("       Service Data:            \(advertisementData[CBAdvertisementDataServiceDataKey])")
        println("       Service UUID:            \(advertisementData[CBAdvertisementDataServiceUUIDsKey])")
        println("       Overflow Service UUIDs:  \(advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey])")
        println("       TX Power Level:          \(advertisementData[CBAdvertisementDataTxPowerLevelKey])")
        println("       Is Connectable:          \(advertisementData[CBAdvertisementDataIsConnectable])")
        println("       Solicited Service UUIDs: \(advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey])")
        println("-")
        
    }
    
    
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        
    }
    
    
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        
    }
    
    
}