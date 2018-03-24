//
//  Font.swift
//  ProxiChat
//
//  Created by Michael Hsu on 3/23/18.
//  Copyright © 2018 Michael Hsu. All rights reserved.
//
//  List of font names: https://gist.github.com/tadija/cb4ec0cbf0a89886d488d1d8b595d0e9

import Foundation
import UIKit

/// This struct is used to store all functions and constants related to fonts.
struct Font {
    
    /// Default font name for **all** text.
    static let fontName: String = "Helvetica"
    
    /// Font size of the all labels in info views.
    static let infoViewFontSize: Float = 20.0
    
    /**
     This is a wrapper function for creating fonts.
     
     - parameters:
        - size: Size of the font.
        - name: Name of the font. The default value is the `Font.fontName`.
     */
    static func getFont(_ size: Float, _ name: String = fontName) -> UIFont? {
        return UIFont(name: name, size: CGFloat(size))
    }
}
