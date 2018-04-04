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
    
    var unixTime = 0.0
    
    init(date: TimeInterval) {
        self.unixTime = date
    }
    
    /// Converts a unix timestamp to the device's locale's formatted date.
    func convert() -> String {
        let dateFormatter = DateFormatter()
        
        dateFormatter.locale = getLocale()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        
        return dateFormatter.string(from: Date(timeIntervalSince1970: self.unixTime))
    }
    
    /// Gets the current locale based on the device's preferred language. If unavailable, then return the current locale.
    func getLocale() -> Locale {
        guard let language = Locale.preferredLanguages.first else {
            return Locale.current
        }
        return Locale(identifier: language)
    }
}
