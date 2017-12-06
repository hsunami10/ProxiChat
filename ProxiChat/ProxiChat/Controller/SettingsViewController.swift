//
//  SettingsViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO

class SettingsViewController: UIViewController {
    
    var socket: SocketIOClient!
    var username = ""
    
    @IBOutlet var settingsView: UIView!
    @IBOutlet var settingsViewLeftConstraint: NSLayoutConstraint!
    @IBOutlet var navigationLeftConstraint: NSLayoutConstraint!
    @IBOutlet var navigationViewWidth: NSLayoutConstraint!
    @IBOutlet var settingsViewWidth: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize navigation menu layout and gestures
        _ = NavigationSideMenu.init(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: IBOutlet Actions
    @IBAction func navItemClicked(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            print("go to find groups")
            break
        case 1:
            print("go to your groups")
            break
        case 2:
            print("go to your profile")
            break
        case 3:
            print("go to settings")
            break
        default:
            break
        }
    }
    
    // MARK: Miscellaneous Methods
    @objc func closeNavMenu() {
        if navigationLeftConstraint.constant == 0 {
            NavigationSideMenu.toggleSideNav(show: false)
        }
    }
}
