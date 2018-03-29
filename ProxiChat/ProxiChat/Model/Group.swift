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
    var is_public = true
    var password = ""
    var creator = ""
    var latitude = 0.0
    var longitude = 0.0
    var dateCreated = ""
    var image: UIImage?
    
    // Delete later
    var rawDate = ""
    var id = ""
}
