//
//  SettingsViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO

/*
 Sections: Theme, Notifications & Sounds, Support - then logout/signout & delete account
 - Theme: daytime/light, nighttime/dark, automatic
 - Notifications & Sounds: maybe find a way to enable/disable in app? with a switch like whatsapp - ask for permissions on start up
    - if enabled, allow the user to choose sounds and/or vibrations (if possible)
    - pause notifications for a certain period of time
 - Support: FAQ, Feedback, Report
 */

class SettingsViewController: UIViewController {
    
    // MARK: Instance variables
    var socket: SocketIOClient?
    
    @IBOutlet var settingsView: UIView!
    @IBOutlet var settingsViewLeftConstraint: NSLayoutConstraint!
    @IBOutlet var navigationLeftConstraint: NSLayoutConstraint!
    @IBOutlet var navigationViewWidth: NSLayoutConstraint!
    @IBOutlet var settingsViewWidth: NSLayoutConstraint!
    @IBOutlet var settingsViewHeight: NSLayoutConstraint!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize navigation menu layout and gestures
        _ = NavigationSideMenu.init(self)
        
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        
        self.view.layoutIfNeeded()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: IBOutlet Actions
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
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToGroups" {
            let destinationVC = segue.destination as! GroupsViewController
            destinationVC.socket = socket
            socket = nil
        } else if segue.identifier == "goToStarred" {
            let destinationVC = segue.destination as! StarredGroupsViewController
            destinationVC.socket = socket
            socket = nil
        } else if segue.identifier == "goToProfile" {
            let destinationVC = segue.destination as! ProfileViewController
            destinationVC.socket = socket
            socket = nil
        }
    }
    
    // MARK: Miscellaneous Methods
    @objc func closeNavMenu() {
        if navigationLeftConstraint.constant == 0 {
            NavigationSideMenu.toggleSideNav(show: false)
        }
    }
}
