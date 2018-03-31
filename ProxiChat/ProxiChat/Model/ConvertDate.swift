//
//  ConvertDate.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/1/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import Foundation
import SwiftDate

/**
 This handles converting UTC timezone dates to local time, from database and realtime.
 For more information on date formatting, visit http://nsdateformatter.com/.
 */
struct ConvertDate {
    
    var date = ""
    let date_format = "MMM d, yyyy h:mm a" // Ex: Dec 5, 1998 4:19 PM
    
    init(date: String) {
        self.date = date
    }
    
    /**
     Convert 2 date formats (UTC) to local time
     - 2017-12-02 22:57:06 +0000 - Dec 2, 2017 4:57 PM
     - 2017-12-02T22:38:20.878Z - Dec 2, 2017 4:38 PM
     
     Format is: ```MMM d, yyyy h:mm a```.
     */
    func convert() -> String {
        let arr = date.split(separator: " ")
        
        // If from database
        if arr.count == 1 {
            let d = self.date.date(format: .custom("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"), fromRegion: Region.GMT())! // Convert string to DateRegion object
            let localDate = d.toRegion(Region.Local()) // Convert to local region
            return localDate.string(custom: date_format) // Customize & add new format
        } else { // If realtime (swift)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z" // Choose original date format
            let dateObj = dateFormatter.date(from: self.date)! // Convert string to Date object
            return dateObj.string(format: .custom(date_format)) // Customize & add new format
        }
    }
    
    /// Convert a date with a custom format.
    func convertWithFormat(_ format: String) -> String {
        let arr = date.split(separator: " ")
        
        if arr.count == 1 {
            let d = self.date.date(format: .custom("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"), fromRegion: Region.GMT())!
            let localDate = d.toRegion(Region.Local())
            return localDate.string(custom: format)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
            print(self.date)
            let dateObj = dateFormatter.date(from: self.date)!
            return dateObj.string(format: .custom(format))
        }
    }
}
