//
//  UserData.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import Foundation

/// Holds all of the user data, and is globally excessible. Updated only on start up and whenever the user's profile is updated.
struct UserData {
    static var picture = ""
    static var password = ""
    static var radius = 0
    static var is_online = true // TODO: Change online later
    static var coordinates = ""
    static var username = ""
    static var bio = ""
    
    /**
     Shows whether or not the user visited the "find groups" view controller for the first time, without visiting "messages" before.
     For example, this would be true if the user visited "find groups", but then false when the user visits "messages" and back.
     
     This is set to ```true```
    */
    static var createNewMessageViewController = true
    
    /// Shows whether or not the user is connected to the server.
    static var connected = false
}
