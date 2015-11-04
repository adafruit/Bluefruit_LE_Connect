//
//  BLEAppDelegate.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/13/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit
import WatchConnectivity

@UIApplicationMain
class BLEAppDelegate: UIResponder, UIApplicationDelegate, WCSessionDelegate {
    
    var window:UIWindow?
    var mainViewController:BLEMainViewController?
    
    
    required override init() {
        super.init()
    }
    
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        
        self.mainViewController = BLEMainViewController.sharedInstance
        
        window!.rootViewController = mainViewController
        window!.makeKeyAndVisible()
        
        // Ask user for permision to show local notifications
        if(UIApplication.instancesRespondToSelector(Selector("registerUserNotificationSettings:")))
        {
            let settings = UIUserNotificationSettings(forTypes: [.Sound, .Alert, .Badge], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        else
        {
            //do iOS 7 stuff, which is pretty much nothing for local notifications.
        }
        
        // Register Settings bundle and set default values
        var appDefaults = Dictionary<String, AnyObject>()
        appDefaults["updatescheck_preference"] = true;
        appDefaults["betareleases_preference"] = false;
        NSUserDefaults.standardUserDefaults().registerDefaults(appDefaults)
        NSUserDefaults.standardUserDefaults().synchronize()
        
        if WCSession.isSupported() {
            print("creating WCSession …")
            let session = WCSession.defaultSession()
            session.delegate = self
            session.activateSession()
            
            if session.reachable == true {
                print("WCSession is reachable")
            }
            else {
                print("WCSession is not reachable")
            }
        }
        
        return true
        
    }
    
    
    func applicationWillResignActive(application: UIApplication) {
        
        // Stop scanning before entering background
        mainViewController?.stopScan()
        
        //TEST NOTIFICATION
//        let note = UILocalNotification()
//        note.fireDate = NSDate().dateByAddingTimeInterval(5.0)
//        note.alertBody = "THIS IS A TEST"
//        note.soundName =  UILocalNotificationDefaultSoundName
//        application.scheduleLocalNotification(note)
        
    }
    
    
    func applicationDidBecomeActive(application: UIApplication) {
        
        mainViewController?.didBecomeActive()
    }
    
    
//    func applicationWillTerminate(application: UIApplication) {
//        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
//    }
    
    
    //WatchKit request
    
    func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
        
        if let request = message["type"] as? String {
            if request == "isConnected" {
                //                    NSLog("app received connection status request")
                
                //check connection status
                if BLEMainViewController.sharedInstance.connectedInControllerMode() {
                    replyHandler(["connected":true])
                }
                else {
                    replyHandler(["connected":false])
                }
                return
            }
            else if request == "command" {
                if let command = message["command"] as? String {
                    if command == "disconnect" {
                        //                            NSLog("BLEAppDelegate -> Disconnect command received")
                        
                        //disconnect device
                        BLEMainViewController.sharedInstance.disconnectviaWatch()
                        
                        replyHandler(["connected":false])
                    }
                }
                
            }
            else if request == "sendData"{
                //check send data type - button or color
                if let red = message["red"] as? Int, green = message["green"] as? Int, blue = message["blue"] as? Int {
                    //                        NSLog("color request received")
                    
                    //forward data to mainviewController
                    if BLEMainViewController.sharedInstance.connectedInControllerMode() {
                        BLEMainViewController.sharedInstance.controllerViewController.sendColor(UInt8(red), green: UInt8(green), blue: UInt8(blue))
                        replyHandler(["connected":true])
                    }
                    else {
                        replyHandler(["connected":false])
                    }
                    return
                }
                else if let button = message["button"] as? Int {
                    
                    //                        NSLog("button request " + button)
                    //forward data to mainviewController
                    if BLEMainViewController.sharedInstance.connectedInControllerMode() {
                        BLEMainViewController.sharedInstance.controllerViewController.controlPadButtonTappedWithTag(button)
                        replyHandler(["connected":true])
                    }
                    else {
                        replyHandler(["connected":false])
                    }
                    return
                }
                
            }
                
            else {
                //blank reply
                replyHandler([:])
            }
        }
        
    }
    
    func application(application: UIApplication,
        handleWatchKitExtensionRequest userInfo: [NSObject : AnyObject]?,
        reply: (([NSObject : AnyObject]?) -> Void)) {
            
            // 1
            if let userInfo = userInfo, request = userInfo["type"] as? String {
                if request == "isConnected" {
//                    NSLog("app received connection status request")
                    
                    //check connection status
                    if BLEMainViewController.sharedInstance.connectedInControllerMode() {
                        reply(["connected":true])
                    }
                    else {
                        reply(["connected":false])
                    }
                    return
                }
                else if request == "command" {
                    if let command = userInfo["command"] as? String {
                        if command == "disconnect" {
//                            NSLog("BLEAppDelegate -> Disconnect command received")
                            
                            //disconnect device
                            BLEMainViewController.sharedInstance.disconnectviaWatch()
                            
                            reply(["connected":false])
                        }
                    }
                    
                }
                else if request == "sendData"{
                    //check send data type - button or color
                    if let red = userInfo["red"] as? Int, green = userInfo["green"] as? Int, blue = userInfo["blue"] as? Int {
//                        NSLog("color request received")
                        
                        //forward data to mainviewController
                        if BLEMainViewController.sharedInstance.connectedInControllerMode() {
                            BLEMainViewController.sharedInstance.controllerViewController.sendColor(UInt8(red), green: UInt8(green), blue: UInt8(blue))
                            reply(["connected":true])
                        }
                        else {
                            reply(["connected":false])
                        }
                        return
                    }
                    else if let button = userInfo["button"] as? Int {
                        
//                        NSLog("button request " + button)
                        //forward data to mainviewController
                        if BLEMainViewController.sharedInstance.connectedInControllerMode() {
                            BLEMainViewController.sharedInstance.controllerViewController.controlPadButtonTappedWithTag(button)
                            reply(["connected":true])
                        }
                        else {
                            reply(["connected":false])
                        }
                        return
                    }
                    
                }
                
                else {
                    //blank reply
                    reply([:])
                }
            }
    }
    
//
//    - (void)applicationWillResignActive:(UIApplication*)application
//    {
//    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
//    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
//    }
//    
//    - (void)applicationDidEnterBackground:(UIApplication*)application
//    {
//    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
//    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
//    }
//    
//    - (void)applicationWillEnterForeground:(UIApplication*)application
//    {
//    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
//    }
//    
//    - (void)applicationDidBecomeActive:(UIApplication*)application
//    {
//    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
//    }
    
}
