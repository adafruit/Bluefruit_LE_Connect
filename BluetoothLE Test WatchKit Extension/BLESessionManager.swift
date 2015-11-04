//
//  BLESessionManager.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 11/3/15.
//  Copyright © 2015 Adafruit Industries. All rights reserved.
//

import Foundation
import WatchConnectivity

class BLESessionManager: NSObject, WCSessionDelegate {
    
    static let sharedInstance = BLESessionManager()
//    var session:WCSession?
    var deviceConnected:Bool = false
    
    
    override init(){
        super.init()
        
        if WCSession.isSupported() {
            let session = WCSession.defaultSession()
            session.delegate = self
            session.activateSession()
        }
        
    }
    
    
    func sendRequest(message:[String:AnyObject], sender:BLEInterfaceController) {
        
        sender.showDebugInfo("attempting to send request")
        
        if WCSession.defaultSession().reachable == false {
            sender.showDebugInfo("WCSession is unreachable")
            return
        }
        
        WCSession.defaultSession().sendMessage(message,
            replyHandler: { (replyInfo) -> Void in
                switch (replyInfo["connected"] as? Bool) { //received correctly formatted reply
                case let connected where connected != nil:
                    if connected == true {  //app has connection to ble device
                        sender.showDebugInfo("device connected")
                        sender.respondToConnected()
                        self.deviceConnected = true
                    }
                    else {  //app has NO connection to ble device
                        sender.showDebugInfo("no device connected")
                        sender.respondToNotConnected()
                        self.deviceConnected = false
                    }
                default:
                    sender.showDebugInfo("no connection info in reply")
                    sender.respondToNotConnected()
                    self.deviceConnected = false
                }
            },
            errorHandler: { (error) -> Void in
                sender.showDebugInfo("\(error)") // received reply w error
        })
        
    }
    
    
}