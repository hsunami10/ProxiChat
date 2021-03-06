//
//  AppDelegate.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/13/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import Firebase
import GeoFire
import SVProgressHUD

/*
 Key things to remember / notes:
 - To fully customize segue animations:
    - Uncheck "Animates" in Main.storyboard
    - Dismiss without animation
 - have status bar color to be the same as the info view color
 - Delegates & Protocols
    - the class which conforms to the protocol gets sent the events (receiver / delegate)
        - when performing segue, set destination view controller's delegate property to self
    - the sender calls delegate's protocol's methods to send data BACK to delegate (delegate property)
 - contentoffset vs contentinset - https://fizzbuzzer.com/understanding-the-contentoffset-and-contentinset-properties-of-the-uiscrollview-class/
 GeoFire Tutorial - http://kylegoslan.co.uk/firebase-geofire-swift-tutorial/
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
    
    /// Checks text to make sure doesn't contain `. # $ [ ] /` (for firebase keys).
    func isValidFIRKey() -> Bool {
        return !(self.contains(".") || self.contains("#") || self.contains("$") || self.contains("[") || self.contains("]") || self.contains("/"))
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
    
    /// A Bool value that determines whether the scroll view is at the top.
    var isAtTop: Bool {
        return contentOffset.y <= verticalOffsetForTop
    }
    
    /// A Bool value that determines whether the scroll view is at the bottom.
    var isAtBottom: Bool {
        return contentOffset.y >= verticalOffsetForBottom
    }
    
    var verticalOffsetForTop: CGFloat {
        let topInset = contentInset.top
        return -topInset
    }
    
    var verticalOffsetForBottom: CGFloat {
        let scrollViewHeight = bounds.height
        let scrollContentSizeHeight = contentSize.height
        let bottomInset = contentInset.bottom
        let scrollViewBottomOffset = scrollContentSizeHeight + bottomInset - scrollViewHeight
        return scrollViewBottomOffset
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
extension Character {
    var asciiValue: UInt32? {
        return String(self).unicodeScalars.filter{$0.isASCII}.first?.value
    }
}

// MARK: Enums
enum EditProfile {
    case password, bio, email
}

// TODO: background app refresh -> most apps use this - figure out how to use this
// IMPORTANT BUG - how to wait until FirebaseApp is finished configuring? so error won't pop up
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var isBackground = false
    
    override init() {
        super.init()
        FirebaseApp.configure()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        Dimensions.safeAreaHeight = (window?.frame.height)! - UIApplication.shared.statusBarFrame.height
        Dimensions.safeAreaWidth = (window?.frame.width)!
        
        // TODO: Remove later - for testing purposes only
//        let domain = Bundle.main.bundleIdentifier!
//        UserDefaults.standard.removePersistentDomain(forName: domain)
//        UserDefaults.standard.synchronize()
        
        if let username = UserDefaults.standard.object(forKey: "proxiChatUsername") {
            UserData.username = username as! String
        }
        if let password = UserDefaults.standard.object(forKey: "proxiChatPassword") {
            UserData.password = password as! String
        }
        if let email = UserDefaults.standard.object(forKey: "proxiChatEmail") {
            UserData.email = email as! String
        }
        UserData.connected = false
        UserData.signedIn = false
        
        // Go to groups page if already logged in
        let logInStatus = UserDefaults.standard.bool(forKey: "isUserLoggedInProxiChat") // Can be nil
        if logInStatus {
            let mainStoryBoard = UIStoryboard(name: "Main", bundle: nil) // Get Main Storyboard
            let page = mainStoryBoard.instantiateViewController(withIdentifier: "groups") as! GroupsViewController // Cast main storyboard as GroupsViewController
            window?.rootViewController = page // Set root view controller
            window?.makeKeyAndVisible()
        }
        
        // If the key exists, use the dictionary, otherwise, start with an empty dictionary.
        if let savedContent = UserDefaults.standard.dictionary(forKey: "proxiChatContentNotSent") as? [String : String] {
            contentNotSent = savedContent
        } else {
            contentNotSent = [:]
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        print("resign active")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        print("enter background")
        UserDefaults.standard.set(contentNotSent, forKey: "proxiChatContentNotSent")
        goOffline()
        deleteAnon()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        print("enter foreground")
        goOnline()
        createAnon()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        print("become active")
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        print("will terminate")
        UserDefaults.standard.set(contentNotSent, forKey: "proxiChatContentNotSent")
        goOffline()
        deleteAnon()
    }
    
    func goOnline() {
        guard let username = UserDefaults.standard.value(forKey: "proxiChatUsername") as? String else { return }
        Database.database().reference().child("Users").child(username).updateChildValues(["is_online" : true])
    }
    
    func goOffline() {
        guard let username = UserDefaults.standard.value(forKey: "proxiChatUsername") as? String else { return }
        Database.database().reference().child("Users").child(username).updateChildValues(["is_online" : false])
    }
    
    func deleteAnon() {
        // If current user exists and is anonymous, then delete
        if Auth.auth().currentUser != nil {
            print("user exists")
            if (Auth.auth().currentUser?.isAnonymous)! {
                print("delete anonymous user")
                Auth.auth().currentUser?.delete(completion: { (error) in
                    print(error)
                    if error != nil {
                        print(error!.localizedDescription)
                        try! Auth.auth().signOut()
                    } else {
                        print("delete success")
                    }
                })
            }
        }
    }
    
    func createAnon() {
        // If no existing user, then create and sign in as an anonymous user
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { (user, error) in
                if error != nil {
                    print(error!.localizedDescription)
                    SVProgressHUD.showError(withStatus: error!.localizedDescription)
                } else {
                    print("sign in success")
                }
            }
        }
    }
    
}

