//
//  Dimensions.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/16/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import Foundation
import UIKit

struct Dimensions {
    
    // MARK: Current Device Dimensions
    /// Current device safe area height
    static var safeAreaHeight: CGFloat = -1
    /// Current device safe area width
    static var safeAreaWidth: CGFloat = -1
    
    // MARK: iPhone 8 Plus Dimensions
    static let iPhone8PlusSafeAreaHeight: CGFloat = 716
    static let iPhone8PlusSafeAreaWidth: CGFloat = 414
    /// Height of the information views - on the top of all view controllers
    static let infoViewHeight: CGFloat = 50
    
    // MARK: Profile Factors
    static let pictureDimension: CGFloat = Dimensions.getPixels(170)
    static let infoViewDimension: CGFloat = Dimensions.getPixels(50)
    
    /// Get the factor. The number of pixels is relative to the iPhone 8 Plus resolution.
    static func getFactor(_ num: CGFloat, _ isHeight: Bool) -> CGFloat {
        if isHeight {
            return num / Dimensions.iPhone8PlusSafeAreaHeight
        } else {
            return num / Dimensions.iPhone8PlusSafeAreaWidth
        }
    }
    
    /**
     Get the pixels.
     This takes in the number of pixels (in iPhone 8 Plus) and returns the number of pixels relative to the current device's safe area dimension.
    */
    static func getPixels(_ numberOfPixels: CGFloat, _ isHeight: Bool = true) -> CGFloat {
        if isHeight {
            return Dimensions.safeAreaHeight * Dimensions.getFactor(numberOfPixels, isHeight)
        } else {
            return Dimensions.safeAreaWidth * Dimensions.getFactor(numberOfPixels, isHeight)
        }
    }
}
