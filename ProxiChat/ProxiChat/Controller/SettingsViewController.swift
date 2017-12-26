//
//  SettingsViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO
import SwiftyJSON
import SVProgressHUD

/*
 Sections: Theme, Notifications & Sounds, Support - then logout/signout & delete account
 - Theme: daytime/light, nighttime/dark, automatic?
 - Notifications & Sounds: maybe find a way to enable/disable in app? with a switch like whatsapp - ask for permissions on start up
    - if enabled, allow the user to choose sounds and/or vibrations (if possible)
    - pause notifications for a certain period of time
 - Support: Contact, FAQ?, Feedback, Report
 */

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: Instance variables
    var socket: SocketIOClient?
    let sectionTitles: [String] = ["Color Theme", "Notifications & Sounds", "Support"]
    
    @IBOutlet var settingsView: UIView!
    @IBOutlet var settingsViewLeftConstraint: NSLayoutConstraint!
    @IBOutlet var navigationLeftConstraint: NSLayoutConstraint!
    @IBOutlet var navigationViewWidth: NSLayoutConstraint!
    @IBOutlet var settingsViewWidth: NSLayoutConstraint!
    @IBOutlet var settingsViewHeight: NSLayoutConstraint!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    
    @IBOutlet var settingsTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        eventHandlers()
        
        // Initialize navigation menu layout and gestures
        _ = NavigationSideMenu.init(self)
        
        // Initialize table view
        settingsTableView.delegate = self
        settingsTableView.dataSource = self
        settingsTableView.register(UINib.init(nibName: "SettingsCell", bundle: nil), forCellReuseIdentifier: "settingsCell")
        settingsTableView.isScrollEnabled = false
        
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        
        self.view.layoutIfNeeded()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        socket?.on("delete_account_response", callback: { (data, ack) in
            SVProgressHUD.dismiss()
            if JSON(data[0])["success"].boolValue {
                self.removeUserDefaults()
                self.revealTopToBottomTransition()
                self.performSegue(withIdentifier: "logOutDelete", sender: self)
            } else {
                SVProgressHUD.showError(withStatus: "There was a problem deleting your account. Please try again.")
            }
        })
    }
    
    // MARK: IBOutlet Actions
    @IBAction func deleteAccount(_ sender: Any) {
        let alert = UIAlertController(title: "Delete Account", message: "Are you sure you want to remove your account? This action cannot be reversed.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (action) in
            self.socket?.emit("delete_account", UserData.username)
            SVProgressHUD.show()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func logOut(_ sender: Any) {
        removeUserDefaults()
        revealTopToBottomTransition()
        performSegue(withIdentifier: "logOutDelete", sender: self)
    }
    
    @IBAction func showNavMenu(_ sender: Any) {
        UIView.setAnimationsEnabled(true)
        if navigationLeftConstraint.constant != 0 {
            NavigationSideMenu.toggleSideNav(show: true)
        } else {
            NavigationSideMenu.toggleSideNav(show: false)
        }
    }
    
    @IBAction func navItemClicked(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            NavigationSideMenu.addTransition(sender: self)
            performSegue(withIdentifier: "goToGroups", sender: self)
            break
        case 1:
            NavigationSideMenu.addTransition(sender: self)
            performSegue(withIdentifier: "goToStarred", sender: self)
            break
        case 2:
            NavigationSideMenu.addTransition(sender: self)
            performSegue(withIdentifier: "goToProfile", sender: self)
            break
        case 3:
            NavigationSideMenu.toggleSideNav(show: false)
            break
        default:
            break
        }
    }
    
    // MARK: UITableView Delegate and DataSource Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("go to another view")
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2
        case 1:
            // TODO: Check whether they have turned on or off notifications?
            return 1
        case 2:
            return 3
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // TODO: Check whether or not it's in the notifications and sounds section, because cells there are different
        let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath) as! SettingsCell
        cell.contentLabel.text = sectionTitles[indexPath.section]
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionTitles.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToGroups" {
            let destinationVC = segue.destination as! GroupsViewController
            destinationVC.socket = socket
        } else if segue.identifier == "goToStarred" {
            let destinationVC = segue.destination as! StarredGroupsViewController
            destinationVC.socket = socket
        } else if segue.identifier == "goToProfile" {
            let destinationVC = segue.destination as! ProfileViewController
            destinationVC.socket = socket
        } else if segue.identifier == "logOutDelete" {
            let destinationVC = segue.destination as! WelcomeViewController
            destinationVC.socket = socket
            socket?.leaveNamespace()
        }
        socket = nil
    }
    
    // MARK: Miscellaneous Methods
    func removeUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "isUserLoggedInProxiChat")
        UserDefaults.standard.removeObject(forKey: "proxiChatUsername")
    }
    
    func revealTopToBottomTransition() {
        // TODO: Fix this later to match the dismiss transition
        let transition = CATransition()
        transition.duration = Durations.navigationDuration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionReveal
        transition.subtype = kCATransitionFromBottom
        self.view.window?.layer.add(transition, forKey: nil)
    }
    
    @objc func closeNavMenu() {
        if navigationLeftConstraint.constant == 0 {
            NavigationSideMenu.toggleSideNav(show: false)
        }
    }
}
