//
//  BLEAppDelegate.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Collin Cunningham on 10/13/14.
//  Copyright (c) 2014 Adafruit Industries. All rights reserved.
//

import Foundation
import UIKit

@UIApplicationMain
class BLEAppDelegate: UIResponder, UIApplicationDelegate {
    
    var window:UIWindow?
    var mainViewController:BLEMainViewController?
    
    required override init() {
        super.init()
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        
        // Load NIB based on current platform
        var nibName:String
        if IS_IPHONE {
            nibName = "BLEMainViewController_iPhone"
        }
        else{
            nibName = "BLEMainViewController_iPad"
        }
        self.mainViewController = BLEMainViewController(nibName: nibName, bundle: NSBundle.mainBundle())    //TODO: check for redundancy
        
        window!.rootViewController = mainViewController
        window!.makeKeyAndVisible()
        
        // Ask user for permision to show local notifications
        if(UIApplication.instancesRespondToSelector(Selector("registerUserNotificationSettings:")))
        {
            application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: UIUserNotificationType.Sound | UIUserNotificationType.Alert | UIUserNotificationType.Badge, categories: nil))
        }
        else
        {
            //do iOS 7 stuff, which is pretty much nothing for local notifications.
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
//    
//    - (void)applicationWillTerminate:(UIApplication*)application
//    {
//    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
//    }
    
}
