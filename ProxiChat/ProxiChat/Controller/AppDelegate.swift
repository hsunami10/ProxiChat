//
//  AppDelegate.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/13/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO

/*
 Key things to remember:
 - Even if you dismiss a ViewController, it still exists, so those socket events will still be run unless socket = nil
 */

// MARK: Custom Protocols
/// Join group
protocol JoinGroupDelegate {
    func joinGroup(_ group: Group)
}

// MARK: Extensions
extension String {
    /// Gets pixel height of a string
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        
        return ceil(boundingBox.height)
    }
    
    /// Gets pixel width of a string
    func width(withConstraintedHeight height: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        
        return ceil(boundingBox.width)
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // TODO: Remove these later
//        UserDefaults.standard.removeObject(forKey: "isUserLoggedInProxiChat")
//        UserDefaults.standard.removeObject(forKey: "proxiChatUsername")
        
        // Go to groups page if already logged in
        let logInStatus = UserDefaults.standard.bool(forKey: "isUserLoggedInProxiChat") // Can be nil
        if logInStatus {
            let mainStoryBoard = UIStoryboard(name: "Main", bundle: nil) // Get Main Storyboard
            let page = mainStoryBoard.instantiateViewController(withIdentifier: "groups") as! GroupsViewController // Cast main storyboard as GroupsViewController
            
            if let username = UserDefaults.standard.object(forKey: "proxiChatUsername") {
                page.username = username as! String // Set saved username
                page.socket = SocketIOClient(socketURL: URL(string: "http://localhost:3000")!)
                page.justStarted = true
            }
            window?.rootViewController = page // Set root view controller
            window?.makeKeyAndVisible()
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

