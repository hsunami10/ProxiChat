//
//  AppDelegate.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/13/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import Firebase

/*
 Key things to remember / notes:
 - Even if you dismiss a ViewController, it still exists, so those socket events will still be run unless socket = nil
 - To fully customize segue animations:
    - Uncheck "Animates" in Main.storyboard
    - Dismiss without animation
 - have status bar color to be the same as the info view color
 - Delegates & Protocols
    - the class which conforms to the protocol gets sent the events (receiver / delegate)
        - when performing segue, set destination view controller's delegate property to self
    - the sender calls delegate's protocol's methods to send data BACK to delegate (delegate property)
 - contentoffset vs contentinset - https://fizzbuzzer.com/understanding-the-contentoffset-and-contentinset-properties-of-the-uiscrollview-class/
 */

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
extension UITextView {
    func centerVertically() {
        let fittingSize = CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
        let size = sizeThatFits(fittingSize)
        let topOffset = (bounds.size.height - size.height * zoomScale) / 2
        let positiveTopOffset = max(1, topOffset)
        contentOffset = CGPoint(x: contentOffset.x, y: -positiveTopOffset)
    }
}
extension UIScrollView {
    /// A Bool value that determines whether the scroll view is at the bottom.
    var isAtBottom: Bool {
        let distanceFromBottom = contentSize.height - contentOffset.y
        return distanceFromBottom < frame.size.height
    }
    
    /// A Bool value that determines whether the scroll view needs to scroll.
    var needToScroll: Bool {
        return contentSize.height > frame.size.height
    }
}
extension UITableView {
    /**
     Scroll to the bottom of the table view.
     - parameters:
        - content: Array of table view objects. (ex. array of message objects)
        - animated: Determines whether or not the animate the scrolling.
     */
    func scrollToBottom(_ content: [Any], _ animated: Bool) {
        if content.count > 0 {
            let lastItem = IndexPath(item: content.count-1, section: 0)
            scrollToRow(at: lastItem, at: .bottom, animated: animated)
        }
    }
}

// TODO: background app refresh -> most apps use this - figure out how to use this
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        Dimensions.safeAreaHeight = (window?.frame.height)! - UIApplication.shared.statusBarFrame.height
        Dimensions.safeAreaWidth = (window?.frame.width)!
        
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        // Go to groups page if already logged in
        let logInStatus = UserDefaults.standard.bool(forKey: "isUserLoggedInProxiChat") // Can be nil
        if logInStatus {
            let mainStoryBoard = UIStoryboard(name: "Main", bundle: nil) // Get Main Storyboard
            let page = mainStoryBoard.instantiateViewController(withIdentifier: "groups") as! GroupsViewController // Cast main storyboard as GroupsViewController
            
            if let username = UserDefaults.standard.object(forKey: "proxiChatUsername") {
                page.username = username as! String // Set saved username
            }
            window?.rootViewController = page // Set root view controller
            window?.makeKeyAndVisible()
        }
        
        // If the key exists, use the dictionary, otherwise, start with an empty dictionary.
        if let savedContent = UserDefaults.standard.dictionary(forKey: "proxiChatContentNotSent") as? [String : String] {
            contentNotSent = savedContent
        } else {
            contentNotSent = [:]
        }
        
        // Initialize and configure Firebase
        FirebaseApp.configure()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        UserDefaults.standard.set(contentNotSent, forKey: "proxiChatContentNotSent")
        goOffline()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        UserDefaults.standard.set(contentNotSent, forKey: "proxiChatContentNotSent")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        UserDefaults.standard.set(contentNotSent, forKey: "proxiChatContentNotSent")
        goOffline()
    }
    
    func goOffline() {
        guard let username = UserDefaults.standard.value(forKey: "proxiChatUsername") as? String else { return }
        Database.database().reference().child("Users").child(username).updateChildValues(["is_online" : false])
    }
    
}

