//
//  Group.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/16/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit

/// Holds all of a group's data.
struct Group {
    var title = ""
    var numMembers = 1
    var numOnline = 1
    var is_public = true
    var password = ""
    var creator = ""
    var latitude = 0.0
    var longitude = 0.0
    var dateCreated = ""
    var image = ""
    var members: [String : Bool] = [:]
    
    /**
     Initialize all group object values.
     
     - parameters:
         - title: The title of the group.
         - numMembers: The number of members (stars) of the group.
         - numOnline: The number of users currently in chat.
         - is_public: Private or Public group?
         - password: The password for the group, only if it's private.
         - creator: The username of the creator of the group.
         - latitude: Latitude coordinate.
         - longitude: Longitude coordinate.
         - dateCreated: The date this group was created.
         - image: The group image.
     */
    init(_ title: Any?, _ numMembers: Any?, _ numOnline: Any?, _ is_public: Any?, _ password: Any?,
         _ creator: Any?, _ latitude: Any?, _ longitude: Any?, _ dateCreated: Any?, _ image: Any?, _ members: Any?) {
        self.creator = creator as! String
        self.dateCreated = dateCreated as! String
        self.image = image as! String
        self.is_public = is_public as! Bool
        self.latitude = latitude as! Double
        self.longitude = longitude as! Double
        self.numMembers = numMembers as! Int
        self.numOnline = numOnline as! Int
        self.password = password as! String
        self.title = title as! String
        self.members = members as! Dictionary<String, Bool>
    }
}
