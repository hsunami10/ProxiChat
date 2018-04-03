//
//  AlertMessages.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/10/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import Foundation

/// This holds all the reused UIAlertController alert messages.
struct AlertMessages {
    static let unavailableCamera = "The camera is unavailable right now. It may already be in use."
    static let unavailablePhotoLibrary = "The photo library is unavailable right now. It may already be in use."
    static let deniedPhotoLibrary = "You have not allowed this app to access the photo library. Please go to Settings to update permissions."
    static let deniedCamera = "You have not allowed this app to access the camera. Please go to Settings to update permissions."
    static let locationError = "There was a problem getting your location. Please check your permissions in Settings and/or internet connection."
    static let authError = "Oops! This wasn't supposed to happen. Please restart the app and try again."
}
