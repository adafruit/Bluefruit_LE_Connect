//
//  BLEInterfaceController.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 6/27/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import WatchKit
import Foundation

class BLEInterfaceController: WKInterfaceController {
    
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        self.addMenuItemWithItemIcon(WKMenuItemIcon.Decline, title: "Disconnect", action: Selector("disconnectButtonTapped"))
        
    }
    
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        checkConnection()
    }
    
    
    func checkConnection(){
        
        let request = ["type":"isConnected"]
        sendRequest(request)
        
    }
    
    
    func respondToNotConnected(){
        
        //pop to root controller if connection is lost
        WKInterfaceController.reloadRootControllersWithNames(["Root"], contexts: nil)
        
    }
    
    
    func respondToConnected(){
        
        //override to respond to connected status
    
    }
    
    
    @IBAction func disconnectButtonTapped() {
        
        sendRequest(["type":"command", "command":"disconnect"])
        
    }

    
    func sendRequest(request:[String:AnyObject]){
        
        WKInterfaceController.openParentApplication(request,
            reply: { (replyInfo, error) -> Void in
                //parse reply info
                switch (replyInfo?["connected"] as? Bool, error) { //received correctly formatted reply
                case let (connected, nil) where connected != nil:
                    if connected == true {  //app has connection to ble device
//                        NSLog("reply received == connected")
                        self.respondToConnected()
                    }
                    else {  //app has NO connection to ble device
//                        NSLog("reply received == not connected")
                        self.respondToNotConnected()
                    }
                case let (_, .Some(error)):
                    println("reply received with error: \(error)") // received reply w error
                default:
                    println("reply received with no error or data ...") // received reply with no data or error
                }
        })
        
        
    }
    
}
