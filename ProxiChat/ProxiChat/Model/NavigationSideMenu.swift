//
//  NavigationSideMenu.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import Foundation
import UIKit

/**
 Holds all the necessary properties of the navigation side menu
 */
class NavigationSideMenu {
    static let duration: TimeInterval = 0.25
    static let shiftFactor: CGFloat = 0.70
    /**
     Differentiates which views the user is on.
     - 0 - GroupsViewController
     - 1 - StarredGroupsViewController
     - 2 - ProfileViewController
     - 3 - SettingsViewController
    */
    static var currentView = -1
    
    static var groupsObj: GroupsViewController!
    static var starredObj: StarredGroupsViewController!
    static var profileObj: ProfileViewController!
    static var settingsObj: SettingsViewController!
    
    /// Initialize layout and any necessary gestures.
    init(_ object: Any?) {
        if object is GroupsViewController {
            NavigationSideMenu.groupsObj = object as! GroupsViewController
            NavigationSideMenu.groupsObj.groupsViewWidth.constant = NavigationSideMenu.groupsObj.view.frame.size.width // Set groups view width to main view width
            NavigationSideMenu.groupsObj.groupsLeftConstraint.constant = 0 // Set groups view to normal position
            NavigationSideMenu.groupsObj.navigationViewWidth.constant = NavigationSideMenu.groupsObj.groupsViewWidth.constant * NavigationSideMenu.shiftFactor // Set width to a factor of groups view
            NavigationSideMenu.groupsObj.navigationLeftConstraint.constant = -NavigationSideMenu.groupsObj.navigationViewWidth.constant // Hide from view
            
            let tapGesture = UITapGestureRecognizer(target: NavigationSideMenu.groupsObj, action: #selector(NavigationSideMenu.groupsObj.closeNavMenu))
            tapGesture.cancelsTouchesInView = false
            NavigationSideMenu.groupsObj.groupsView.addGestureRecognizer(tapGesture)
            
            NavigationSideMenu.currentView = 0
        } else if object is StarredGroupsViewController {
            NavigationSideMenu.starredObj = object as! StarredGroupsViewController
            NavigationSideMenu.starredObj.starredGroupsViewWidth.constant = NavigationSideMenu.starredObj.view.frame.size.width
            NavigationSideMenu.starredObj.starredGroupsViewLeftConstraint.constant = 0
            NavigationSideMenu.starredObj.navigationViewWidth.constant = NavigationSideMenu.starredObj.starredGroupsViewWidth.constant * NavigationSideMenu.shiftFactor
            NavigationSideMenu.starredObj.navigationLeftConstraint.constant = -NavigationSideMenu.starredObj.navigationViewWidth.constant
            
            let tapGesture = UITapGestureRecognizer(target: NavigationSideMenu.starredObj, action: #selector(NavigationSideMenu.starredObj.closeNavMenu))
            tapGesture.cancelsTouchesInView = false
            NavigationSideMenu.starredObj.starredGroupsView.addGestureRecognizer(tapGesture)
            
            NavigationSideMenu.currentView = 1
        } else if object is ProfileViewController {
            NavigationSideMenu.profileObj = object as! ProfileViewController
            NavigationSideMenu.profileObj.navigationViewWidth.constant = NavigationSideMenu.profileObj.view.frame.size.width
            NavigationSideMenu.profileObj.profileViewLeftConstraint.constant = 0
            NavigationSideMenu.profileObj.navigationViewWidth.constant = NavigationSideMenu.profileObj.profileViewWidth.constant * NavigationSideMenu.shiftFactor
            NavigationSideMenu.profileObj.navigationLeftConstraint.constant = -NavigationSideMenu.profileObj.navigationViewWidth.constant
            
            let tapGesture = UITapGestureRecognizer(target: NavigationSideMenu.profileObj, action: #selector(NavigationSideMenu.profileObj.closeNavMenu))
            tapGesture.cancelsTouchesInView = false
            NavigationSideMenu.profileObj.profileView.addGestureRecognizer(tapGesture)
            
            NavigationSideMenu.currentView = 2
        } else if object is SettingsViewController {
            NavigationSideMenu.settingsObj = object as! SettingsViewController
            NavigationSideMenu.settingsObj.navigationViewWidth.constant = NavigationSideMenu.settingsObj.view.frame.size.width
            NavigationSideMenu.settingsObj.settingsViewLeftConstraint.constant = 0
            NavigationSideMenu.settingsObj.navigationViewWidth.constant = NavigationSideMenu.settingsObj.settingsViewWidth.constant * NavigationSideMenu.shiftFactor
            NavigationSideMenu.settingsObj.navigationLeftConstraint.constant = -NavigationSideMenu.settingsObj.navigationViewWidth.constant
            
            let tapGesture = UITapGestureRecognizer(target: NavigationSideMenu.settingsObj, action: #selector(NavigationSideMenu.settingsObj.closeNavMenu))
            tapGesture.cancelsTouchesInView = false
            NavigationSideMenu.settingsObj.settingsView.addGestureRecognizer(tapGesture)
            
            NavigationSideMenu.currentView = 3
        }
    }
    
    /// Toggle side navigation menu.
    static func toggleSideNav(show: Bool) {
        switch NavigationSideMenu.currentView {
        case 0:
            UIView.setAnimationsEnabled(true)
            if show {
                UIView.animate(withDuration: Durations.sideNavDuration) {
                    NavigationSideMenu.groupsObj.navigationLeftConstraint.constant = 0
                    NavigationSideMenu.groupsObj.groupsLeftConstraint.constant = NavigationSideMenu.groupsObj.navigationViewWidth.constant
                    NavigationSideMenu.groupsObj.view.layoutIfNeeded()
                }
                NavigationSideMenu.groupsObj.groupsTableView.allowsSelection = false
            } else {
                UIView.animate(withDuration: Durations.sideNavDuration, animations: {
                    NavigationSideMenu.groupsObj.navigationLeftConstraint.constant = -NavigationSideMenu.groupsObj.navigationViewWidth.constant
                    NavigationSideMenu.groupsObj.groupsLeftConstraint.constant = 0
                    NavigationSideMenu.groupsObj.view.layoutIfNeeded()
                }, completion: { (complete) in
                    NavigationSideMenu.groupsObj.groupsTableView.allowsSelection = complete
                })
            }
            break
        case 1:
            break
        case 2:
            break
        case 3:
            break
        default:
            break
        }
    }
    
    /// Transition from view controller to view controller once a side navigation item is clicked.
    static func beginTransition(segueIdentifier: String, sender: Int) {
        let transition = CATransition()
        transition.duration = Durations.sideToSideDuration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromRight
//        self.view.window?.layer.add(transition, forKey: nil)
    }
}