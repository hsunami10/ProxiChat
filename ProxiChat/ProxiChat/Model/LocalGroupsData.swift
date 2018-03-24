//
//  LocalGroupsData.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit

/**
 Holds all of the data in the user's last location update.
 Also caches anything related to the two groups view controllers.
 */
struct LocalGroupsData {
    static var data: Any!
    
    static var groupsContentOffset: CGFloat = CGFloat(MAXFLOAT)
    static var starredGroupsContentOffset: CGFloat = CGFloat(MAXFLOAT)
}
