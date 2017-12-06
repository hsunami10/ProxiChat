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
        
        // Initialize navigation menu layout and gestures
        _ = NavigationSideMenu.init(self)
        
        // Add a tap gesture to groups view (for navigation side menu)
        // TOOD: Add drag / swipe close side navigation menu
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeNavMenu))
        tapGesture.cancelsTouchesInView = false
        starredGroupsView.addGestureRecognizer(tapGesture)
        
        self.view.layoutIfNeeded()
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
