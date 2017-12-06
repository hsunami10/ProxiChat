//
//  ProfileViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO

class ProfileViewController: UIViewController {
    
    var socket: SocketIOClient!
    var username = ""

    @IBOutlet var navigationLeftConstraint: NSLayoutConstraint!
    @IBOutlet var profileViewLeftConstraint: NSLayoutConstraint!
    @IBOutlet var profileView: UIView!
    @IBOutlet var profileViewWidth: NSLayoutConstraint!
    @IBOutlet var navigationViewWidth: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIView.setAnimationsEnabled(true)
        
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
        if navigationLeftConstraint.constant != 0 {
            NavigationSideMenu.toggleSideNav(show: true)
        } else {
            NavigationSideMenu.toggleSideNav(show: false)
        }
    }
    @IBAction func navItemClicked(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            performSegue(withIdentifier: "goToGroups", sender: self)
            break
        case 1:
            performSegue(withIdentifier: "goToStarred", sender: self)
            break
        case 2:
            NavigationSideMenu.toggleSideNav(show: false)
            break
        case 3:
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
        } else if segue.identifier == "goToStarred" {
            let destinationVC = segue.destination as! StarredGroupsViewController
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
