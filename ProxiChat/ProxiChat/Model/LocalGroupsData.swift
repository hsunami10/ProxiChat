//
//  LocalGroupsData.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import Firebase

/**
 Holds all of the data in the user's last location update.
 Also manipulates anything related to the two groups view controllers.
 */
struct LocalGroupsData {
    /// Firebase database snapshot of groups
    static var cachedSnapshot: DataSnapshot!
    
    /// All keys (group names) of the groups last queried, within the last specified radius.
    static var lastGroupsKeys = [String]()
    
    static var groupsContentOffset: CGFloat = CGFloat(MAXFLOAT)
    static var starredGroupsContentOffset: CGFloat = CGFloat(MAXFLOAT)
    
    /**
     This updates the user's location in the database and gets the groups with the new location and specified radius.
     */
    static func getNewGroups(_ radius: Int) {
        
    }
}
