//
//  ProfileViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO
import AVFoundation
import Photos
import SVProgressHUD

/*
 - FIX textview editing
 */

class ProfileViewController: UIViewController, UITextViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var socket: SocketIOClient!
    var username = ""
    let placeholder = "Edit Bio"
    let placeholderColor: UIColor = UIColor.lightGray
    let imagePicker = UIImagePickerController()
    
    /// Alert dialog to show when the user denies permissions.
    let deniedAlert = UIAlertController(title: "Oops!", message: "", preferredStyle: UIAlertControllerStyle.alert)
    let unavailableAlert = UIAlertController(title: "Sorry!", message: "", preferredStyle: .alert)
    
    @IBOutlet var navigationLeftConstraint: NSLayoutConstraint!
    @IBOutlet var profileViewLeftConstraint: NSLayoutConstraint!
    @IBOutlet var profileView: UIView!
    @IBOutlet var profileViewWidth: NSLayoutConstraint!
    @IBOutlet var navigationViewWidth: NSLayoutConstraint!
    
    @IBOutlet var profilePicture: UIImageView!
    @IBOutlet var usernameLabel: UILabel!
    @IBOutlet var bioTextView: UITextView!
    @IBOutlet var saveButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UserData.createNewMessageViewController = true
        
        // TODO: Figure out how to convert to string to any to UIImage and figure out how to store the user's profile picture
        // TODO: Fix this
        print("image: " + UserData.picture)
        if UserData.picture.split(separator: " ").count == 0 {
            profilePicture.image = UIImage(named: "noPicture")
        } else {
            profilePicture.image = (UserData.picture as Any?) as? UIImage
        }
        
        // Initialize navigation menu layout and gestures
        _ = NavigationSideMenu.init(self)
        
        // Add tap gesture to image view
        let tapGesure = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        profilePicture.addGestureRecognizer(tapGesure)
        
        usernameLabel.text = UserData.username
        if UserData.bio.split(separator: " ").count == 0 {
            bioTextView.text = placeholder
            bioTextView.textColor = placeholderColor
        } else {
            bioTextView.text = UserData.bio
        }
        bioTextView.layer.borderWidth = 2
        bioTextView.layer.borderColor = UIColor.lightGray.cgColor
        
        bioTextView.delegate = self
        imagePicker.delegate = self
        imagePicker.allowsEditing = false // Don't allow the user to edit images - TODO: Change this?
        
        // Initialize alerts
        deniedAlert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { (action) in
            // Open Settings app
            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
        }))
        deniedAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        unavailableAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        
        self.view.layoutIfNeeded()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UIImagePickerController Delegate Methods
    // TODO: Add some way for the users to preview what their picture would look like
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let image = info[UIImagePickerControllerOriginalImage]
        print(image)
        UserData.picture = String(describing: image!)
        if let chosenImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            profilePicture.contentMode = .scaleAspectFit
            profilePicture.image = chosenImage
        }
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: UITextView Delegate Methods
    func textViewDidBeginEditing(_ textView: UITextView) {
        // Fake placeholder
        if textView.textColor == placeholderColor {
            textView.text = ""
            textView.textColor = UIColor.black
        }
    }
    func textViewDidEndEditing(_ textView: UITextView) {
        // Change spaces and empty text to the placeholder
        if textView.text.split(separator: " ").count == 0 {
            textView.text = placeholder
            textView.textColor = placeholderColor
        }
    }
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        print("should end editing")
        return true
    }
    
    // MARK: IBOutlet Actions
    @IBAction func saveProfile(_ sender: UIButton) {
        // TODO: Use sockets to update in database and update realtime in UserData
    }
    @IBAction func showNavMenu(_ sender: Any) {
        UIView.setAnimationsEnabled(true)
        if navigationLeftConstraint.constant != 0 {
            NavigationSideMenu.toggleSideNav(show: true)
        } else {
            NavigationSideMenu.toggleSideNav(show: false)
        }
    }
    @IBAction func navItemClicked(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            NavigationSideMenu.addTransition(sender: self)
            performSegue(withIdentifier: "goToGroups", sender: self)
            break
        case 1:
            NavigationSideMenu.addTransition(sender: self)
            performSegue(withIdentifier: "goToStarred", sender: self)
            break
        case 2:
            NavigationSideMenu.toggleSideNav(show: false)
            break
        case 3:
            NavigationSideMenu.addTransition(sender: self)
            performSegue(withIdentifier: "goToSettings", sender: self)
            break
        default:
            break
        }
    }
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToGroups" {
            let destinationVC = segue.destination as! GroupsViewController
            destinationVC.socket = socket
            destinationVC.username = username
            socket = nil
        } else if segue.identifier == "goToStarred" {
            let destinationVC = segue.destination as! StarredGroupsViewController
            destinationVC.socket = socket
            destinationVC.username = username
            socket = nil
        } else if segue.identifier == "goToSettings" {
            let destinationVC = segue.destination as! SettingsViewController
            destinationVC.socket = socket
            destinationVC.username = username
            socket = nil
        }
    }
    
    // MARK: Miscellaneous Methods
    /// Show an action sheet to choose between "camera" and "photo library" when the image is clicked.
    @objc func imageTapped() {
        UIView.setAnimationsEnabled(true)
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "From Camera", style: .default, handler: { (action) in
            // Camera
            switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
            case AVAuthorizationStatus.authorized:
                self.showCamera()
                break
            case AVAuthorizationStatus.notDetermined:
                // Ask for camera permissions
                AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (response) in
                    if response {
                        self.showCamera()
                    }
                })
                break
            case AVAuthorizationStatus.denied:
                // Diaplay error alert
                self.deniedAlert.message = "You have not allowed this app to access the camera. Please go to Settings to update permissions."
                self.present(self.deniedAlert, animated: true, completion: nil)
                break
            default:
                break
            }
        }))
        actionSheet.addAction(UIAlertAction(title: "From Photo Library", style: .default, handler: { (action) in
            // Photo Library
            switch PHPhotoLibrary.authorizationStatus() {
            case PHAuthorizationStatus.authorized:
                self.showPhotoLibrary()
                break
            case PHAuthorizationStatus.notDetermined:
                // Ask for photo library permissions
                PHPhotoLibrary.requestAuthorization({ (status) in
                    if status == PHAuthorizationStatus.authorized {
                        self.showPhotoLibrary()
                    }
                })
                break
            case PHAuthorizationStatus.denied:
                // Diaplay error alert
                self.deniedAlert.message = "You have not allowed this app to access the photo library. Please go to Settings to update permissions."
                self.present(self.deniedAlert, animated: true, completion: nil)
                break
            default:
                break
            }
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionSheet, animated: true, completion: nil)
    }
    
    @objc func closeNavMenu() {
        if navigationLeftConstraint.constant == 0 {
            NavigationSideMenu.toggleSideNav(show: false)
        }
    }
    
    /// Show the camera
    func showCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            imagePicker.sourceType = .camera
            present(imagePicker, animated: true, completion: nil)
        } else {
            unavailableAlert.message = "The camera is unavailable right now. It may already be in use."
            present(unavailableAlert, animated: true, completion: nil)
        }
    }
    
    /// Show the photo library
    func showPhotoLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            imagePicker.sourceType = .photoLibrary
            present(imagePicker, animated: true, completion: nil)
        } else {
            unavailableAlert.message = "The photo library is unavailable right now. It may already be in use."
            present(unavailableAlert, animated: true, completion: nil)
        }
    }
}
