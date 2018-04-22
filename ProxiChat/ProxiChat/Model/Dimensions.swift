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
    static let infoViewHeight: CGFloat = Dimensions.getPoints(50, true)
    
    // MARK: Profile Factors
    static let pictureDimension: CGFloat = Dimensions.getPoints(170, true)
    static let infoViewDimension: CGFloat = Dimensions.getPoints(50, true)
    
    /**
     Get the relative points.
     This takes in the number of points in the **iPhone 8 Plus**, converts it,
     and returns the number of points relative to the current device's safe area dimension.
     
     - parameters:
        - numberOfPoints: The number of points to specify.
        - isHeight: Determines whether the height (vertical) or width (horizontal) is measured.
    */
    static func getPoints(_ numberOfPoints: CGFloat, _ isHeight: Bool) -> CGFloat {
        if isHeight {
            return (Dimensions.safeAreaHeight / Dimensions.iPhone8PlusSafeAreaHeight) * numberOfPoints
        } else {
            return (Dimensions.safeAreaWidth / Dimensions.iPhone8PlusSafeAreaWidth) * numberOfPoints
        }
    }
}
