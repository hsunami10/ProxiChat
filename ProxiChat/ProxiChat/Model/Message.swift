//
//  Message.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/16/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import Foundation

/// Holds all of the message's data.
struct Message {
    var id = ""
    var author = ""
    var group = ""
    var content = ""
    var dateSent: TimeInterval = 0.0
    var picture = ""
}
