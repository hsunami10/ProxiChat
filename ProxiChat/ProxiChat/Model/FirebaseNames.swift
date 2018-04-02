//
//  FirebaseNames.swift
//  ProxiChat
//
//  Created by Michael Hsu on 3/29/18.
//  Copyright © 2018 Michael Hsu. All rights reserved.
//

import Foundation

struct FirebaseNames {
    /// Holds all the users and user information.
    static let users = "Users" // usersDB
    
    /// Holds all the groups, group information, group settings, members.
    static let groups = "Groups" // groupsDB
    
    /// Holds all the group locations (for Geofire).
    static let group_locations = "Group_Locations" // groupLocationsDB
    
    /// Holds all the messages in each group.
    static let messages = "Messages" // messagesDB
}
