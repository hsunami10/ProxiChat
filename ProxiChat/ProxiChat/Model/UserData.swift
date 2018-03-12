//
//  UserData.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import Foundation

/// Holds all of the user data, and is globally accessible. Updated only on start up and whenever the user's profile is updated.
struct UserData {
    static var picture = "" // NOTE: This might not work - change to UIImage later?
    static var password = ""
    static var radius = 0
    static var is_online = true // TODO: Change values later
    static var coordinates = ""
    static var username = ""
    static var bio = ""
    static var email = ""
    
    /**
     Shows whether or not the user visited the "groups" view controllers for the first time, without visiting "messages" before.
     For example, this would be true if the user visited "find groups", but then false when the user visits "messages" and back.
     
     This is set to ```true``` whenever the user leaves the "groups" view controllers.
    */
    static var createNewMessageViewController = true
    
    /// Shows whether or not the user is connected to the server.
    static var connected = false
}
