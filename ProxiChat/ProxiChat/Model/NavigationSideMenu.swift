//
//  NavigationSideMenu.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import Foundation
import UIKit

// TODO: Change stack view buttons into table view later

/**
 Holds all the necessary properties of the navigation side menu
 */
struct NavigationSideMenu {
    
    /// Differentiates which views the user is on.
    enum ViewControllerEnum {
        case groups, starred, profile, settings
    }
    private let shiftFactor: CGFloat = 0.70
    
    /**
     Differentiates which views the user is on.
     - 0 - GroupsViewController
     - 1 - StarredGroupsViewController
     - 2 - ProfileViewController
     - 3 - SettingsViewController
    */
    static var currentView: ViewControllerEnum = .groups
    static var groupsObj: GroupsViewController!
    static var starredObj: StarredGroupsViewController!
    static var profileObj: ProfileViewController!
    static var settingsObj: SettingsViewController!
    
    /// Initialize layout and any necessary gestures.
    init(_ object: Any?) {
        if object is GroupsViewController {
            NavigationSideMenu.groupsObj = object as! GroupsViewController
            NavigationSideMenu.groupsObj.groupsViewWidth.constant = NavigationSideMenu.groupsObj.view.frame.size.width // Set groups view width to main view width
            NavigationSideMenu.groupsObj.groupsViewHeight.constant = NavigationSideMenu.groupsObj.view.frame.size.height - UIApplication.shared.statusBarFrame.height
            NavigationSideMenu.groupsObj.groupsLeftConstraint.constant = 0 // Set groups view to normal position
            NavigationSideMenu.groupsObj.navigationViewWidth.constant = NavigationSideMenu.groupsObj.groupsViewWidth.constant * shiftFactor // Set width to a factor of groups view
            NavigationSideMenu.groupsObj.navigationLeftConstraint.constant = -NavigationSideMenu.groupsObj.navigationViewWidth.constant // Hide from view
            
            let tapGesture = UITapGestureRecognizer(target: NavigationSideMenu.groupsObj, action: #selector(NavigationSideMenu.groupsObj.closeNavMenu))
            tapGesture.cancelsTouchesInView = false
            NavigationSideMenu.groupsObj.groupsView.addGestureRecognizer(tapGesture)
            
            NavigationSideMenu.currentView = .groups
        } else if object is StarredGroupsViewController {
            NavigationSideMenu.starredObj = object as! StarredGroupsViewController
            NavigationSideMenu.starredObj.starredGroupsViewWidth.constant = NavigationSideMenu.starredObj.view.frame.size.width
            NavigationSideMenu.starredObj.starredGroupsViewHeight.constant = NavigationSideMenu.starredObj.view.frame.size.height - UIApplication.shared.statusBarFrame.height
            NavigationSideMenu.starredObj.starredGroupsViewLeftConstraint.constant = 0
            NavigationSideMenu.starredObj.navigationViewWidth.constant = NavigationSideMenu.starredObj.starredGroupsViewWidth.constant * shiftFactor
            NavigationSideMenu.starredObj.navigationLeftConstraint.constant = -NavigationSideMenu.starredObj.navigationViewWidth.constant
            
            let tapGesture = UITapGestureRecognizer(target: NavigationSideMenu.starredObj, action: #selector(NavigationSideMenu.starredObj.closeNavMenu))
            tapGesture.cancelsTouchesInView = false
            NavigationSideMenu.starredObj.starredGroupsView.addGestureRecognizer(tapGesture)
            
            NavigationSideMenu.currentView = .starred
        } else if object is ProfileViewController {
            NavigationSideMenu.profileObj = object as! ProfileViewController
            NavigationSideMenu.profileObj.profileViewWidth.constant = NavigationSideMenu.profileObj.view.frame.size.width
            NavigationSideMenu.profileObj.profileViewHeight.constant = NavigationSideMenu.profileObj.view.frame.size.height - UIApplication.shared.statusBarFrame.height
            NavigationSideMenu.profileObj.profileViewLeftConstraint.constant = 0
            NavigationSideMenu.profileObj.navigationViewWidth.constant = NavigationSideMenu.profileObj.profileViewWidth.constant * shiftFactor
            NavigationSideMenu.profileObj.navigationLeftConstraint.constant = -NavigationSideMenu.profileObj.navigationViewWidth.constant
            
            let tapGesture = UITapGestureRecognizer(target: NavigationSideMenu.profileObj, action: #selector(NavigationSideMenu.profileObj.closeNavMenu))
            tapGesture.cancelsTouchesInView = false
            NavigationSideMenu.profileObj.profileView.addGestureRecognizer(tapGesture)
            
            NavigationSideMenu.currentView = .profile
        } else if object is SettingsViewController {
            NavigationSideMenu.settingsObj = object as! SettingsViewController
            NavigationSideMenu.settingsObj.settingsViewWidth.constant = NavigationSideMenu.settingsObj.view.frame.size.width
            NavigationSideMenu.settingsObj.settingsViewHeight.constant = NavigationSideMenu.settingsObj.view.frame.size.height - UIApplication.shared.statusBarFrame.height
            NavigationSideMenu.settingsObj.settingsViewLeftConstraint.constant = 0
            NavigationSideMenu.settingsObj.navigationViewWidth.constant = NavigationSideMenu.settingsObj.settingsViewWidth.constant * shiftFactor
            NavigationSideMenu.settingsObj.navigationLeftConstraint.constant = -NavigationSideMenu.settingsObj.navigationViewWidth.constant
            
            let tapGesture = UITapGestureRecognizer(target: NavigationSideMenu.settingsObj, action: #selector(NavigationSideMenu.settingsObj.closeNavMenu))
            tapGesture.cancelsTouchesInView = false
            NavigationSideMenu.settingsObj.settingsView.addGestureRecognizer(tapGesture)
            
            NavigationSideMenu.currentView = .settings
        }
    }
    
    /// Toggle side navigation menu.
    static func toggleSideNav(show: Bool) {
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        
        switch NavigationSideMenu.currentView {
        case .groups:
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
        case .starred:
            if show {
                UIView.animate(withDuration: Durations.sideNavDuration) {
                    NavigationSideMenu.starredObj.navigationLeftConstraint.constant = 0
                    NavigationSideMenu.starredObj.starredGroupsViewLeftConstraint.constant = NavigationSideMenu.starredObj.navigationViewWidth.constant
                    NavigationSideMenu.starredObj.view.layoutIfNeeded()
                }
                NavigationSideMenu.starredObj.starredGroupsTableView.allowsSelection = false
            } else {
                UIView.animate(withDuration: Durations.sideNavDuration, animations: {
                    NavigationSideMenu.starredObj.navigationLeftConstraint.constant = -NavigationSideMenu.starredObj.navigationViewWidth.constant
                    NavigationSideMenu.starredObj.starredGroupsViewLeftConstraint.constant = 0
                    NavigationSideMenu.starredObj.view.layoutIfNeeded()
                }, completion: { (complete) in
                    NavigationSideMenu.starredObj.starredGroupsTableView.allowsSelection = complete
                })
            }
            break
        case .profile:
            if show {
                UIView.animate(withDuration: Durations.sideNavDuration) {
                    NavigationSideMenu.profileObj.navigationLeftConstraint.constant = 0
                    NavigationSideMenu.profileObj.profileViewLeftConstraint.constant = NavigationSideMenu.profileObj.navigationViewWidth.constant
                    NavigationSideMenu.profileObj.view.layoutIfNeeded()
                }
                NavigationSideMenu.profileObj.profileTableView.allowsSelection = false
            } else {
                UIView.animate(withDuration: Durations.sideNavDuration, animations: {
                    NavigationSideMenu.profileObj.navigationLeftConstraint.constant = -NavigationSideMenu.profileObj.navigationViewWidth.constant
                    NavigationSideMenu.profileObj.profileViewLeftConstraint.constant = 0
                    NavigationSideMenu.profileObj.view.layoutIfNeeded()
                }, completion: { (complete) in
                    NavigationSideMenu.profileObj.profileTableView.allowsSelection = complete
                })
            }
            break
        case .settings:
            if show {
                UIView.animate(withDuration: Durations.sideNavDuration) {
                    NavigationSideMenu.settingsObj.navigationLeftConstraint.constant = 0
                    NavigationSideMenu.settingsObj.settingsViewLeftConstraint.constant = NavigationSideMenu.settingsObj.navigationViewWidth.constant
                    NavigationSideMenu.settingsObj.view.layoutIfNeeded()
                }
                NavigationSideMenu.settingsObj.settingsTableView.allowsSelection = false
            } else {
                UIView.animate(withDuration: Durations.sideNavDuration, animations: {
                    NavigationSideMenu.settingsObj.navigationLeftConstraint.constant = -NavigationSideMenu.settingsObj.navigationViewWidth.constant
                    NavigationSideMenu.settingsObj.settingsViewLeftConstraint.constant = 0
                    NavigationSideMenu.settingsObj.view.layoutIfNeeded()
                }, completion: { (complete) in
                    NavigationSideMenu.settingsObj.settingsTableView.allowsSelection = complete
                })
            }
            break
        default:
            break
        }
    }
    
    /**
     Add the necessary transition from view controller to view controller once a side navigation item is clicked.
     Also sets UIView animations to false.
    */
    static func addTransition(sender: Any?) {
        let transition = CATransition()
        transition.duration = Durations.navigationDuration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionMoveIn
        transition.subtype = kCATransitionFromRight
        
        if sender is GroupsViewController {
            groupsObj.view.window?.layer.add(transition, forKey: nil)
        } else if sender is StarredGroupsViewController {
            starredObj.view.window?.layer.add(transition, forKey: nil)
        } else if sender is ProfileViewController {
            profileObj.view.window?.layer.add(transition, forKey: nil)
        } else if sender is SettingsViewController {
            settingsObj.view.window?.layer.add(transition, forKey: nil)
        }
        UIView.setAnimationsEnabled(false)
    }
}
