//
//  StarredGroupsViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO

class StarredGroupsViewController: UIViewController {
    
    var socket: SocketIOClient!
    var username = ""

    @IBOutlet var starredGroupsViewLeftConstraint: NSLayoutConstraint!
    @IBOutlet var starredGroupsViewWidth: NSLayoutConstraint!
    @IBOutlet var starredGroupsView: UIView!
    @IBOutlet var navigationLeftConstraint: NSLayoutConstraint!
    @IBOutlet var navigationViewWidth: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIView.setAnimationsEnabled(true)
        UserData.createNewMessageViewController = true
        
        // Initialize navigation menu layout and gestures
        _ = NavigationSideMenu.init(self)
        
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
            NavigationSideMenu.toggleSideNav(show: false)
            break
        case 2:
            NavigationSideMenu.addTransition(sender: self)
            performSegue(withIdentifier: "goToProfile", sender: self)
            break
        case 3:
            NavigationSideMenu.addTransition(sender: self)
            performSegue(withIdentifier: "goToSettings", sender: self)
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
            destinationVC.username = username
            socket = nil
        } else if segue.identifier == "goToProfile" {
            let destinationVC = segue.destination as! ProfileViewController
            destinationVC.socket = socket
            destinationVC.username = username
            socket = nil
        } else if segue.identifier == "goToSettings" {
            let destinationVC = segue.destination as! SettingsViewController
            destinationVC.socket = socket
            destinationVC.username = username
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
