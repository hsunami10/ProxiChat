//
//  Durations.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import Foundation

/// Holds all of the duration lengths.
struct Durations {
    /// Duration for showing / hiding side navigation menu.
    static let sideNavDuration: TimeInterval = 0.25
    
    /// Duration for left to right and right to left view controller transitions. Mainly for navigating from messages to groups and back.
    static let messageTransitionDuration: TimeInterval = 0.5
    
    /// Duration for view controller transitions when a side navigation item is clicked. Also for custom segue transitions.
    static let navigationDuration: TimeInterval = 0.5
    
    /// Duration for showing the group information in the MessageViewController.
    static let showGroupInfoDuration: TimeInterval = 0.25
    
    /// Duration for which the text view height changes when the number of lines change.
    static let textViewHeightDuration: TimeInterval = 0.1
}
