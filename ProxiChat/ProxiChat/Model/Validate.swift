//
//  Validate.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/11/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import Foundation

// TODO: Maybe add password requirements?

/// This holds all of the functions needed to validate all inputs in textfields and/or textviews.
class Validate {
    
    /**
     Checks whether or not the string is one word. If yes, return ```true```. If no, return ```false```.
     This is used mainly for usernames and passwords.
    */
    static func isOneWord(_ text: String) -> Bool {
        return text.split(separator: " ").count == 1
    }
    
    /// Checks whether the email is valid using regex.
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"+"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"+"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"+"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"+"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"+"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"+"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])"
        let emailTest = NSPredicate(format: "SELF MATCHES[c] %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }
    
    /**
     Checks whether or not there is an empty string or a string of spaces.
     If there is at least one character, return ```false```. Otherwise return ```true```.
     This is used mainly for messaging and group names.
    */
    static func isInvalidInput(_ text: String) -> Bool {
        return text.split(separator: " ").count == 0
    }
}
