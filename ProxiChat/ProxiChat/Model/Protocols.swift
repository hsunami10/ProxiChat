//
//  Protocols.swift
//  ProxiChat
//
//  Created by Michael Hsu on 3/25/18.
//  Copyright © 2018 Michael Hsu. All rights reserved.
//

import UIKit

/// Protocol for joining a group. Data (group info) is passed back from the GroupsViewController to the MessageViewController.
protocol JoinGroupDelegate {
    func joinGroup(_ group: Group)
}
/// Protocol for updating / editing the user's profile. Data (field info) is passed back from the EditProfileViewController to the ProfileViewController.
protocol UpdateProfileDelegate {
    /// Realtime updates and saves the user's updated field.
    func updateProfile(_ type: Int, _ content: String)
}
/// Protocol for updating / editing the user's picture. Data (image) is passed back from the EditPictureViewController to the ProfileViewController.
protocol UpdatePictureDelegate {
    /// Realtime updates and saves the user's updated picture.
    func updatePicture(_ image: UIImage)
}
