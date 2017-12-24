//
//  Group.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/16/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit

/// Holds all of a certain group's information.
class Group {
    var title = ""
    var numMembers = 1
    var is_public = true
    var password = ""
    var creator = ""
    var coordinates = ""
    var dateCreated = ""
    var id = "" // Generated in node - shortid
    var image: UIImage?
    var rawDate = ""
}
