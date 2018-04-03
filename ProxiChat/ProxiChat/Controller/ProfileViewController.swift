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
import SwiftyJSON
import Firebase

/*
 TODO
 - have a way to edit the profile picture after choosing one - into a "circular" frame
 - TODO: MAKE EVERYTHING RESPONSIVE
 - make sure the picture is actually cut - can still click on the rectangular part, even thought it's circular
 - maybe add conversions to other distance units?
 - change all SVProgressHUDs to UIAlertControllers?
 
 BUGS
 - radius sometimes resets to 0 in database?
 */

class ProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, UpdateProfileDelegate, UpdatePictureDelegate {
    
    // MARK: Private Access
    private var rowSelected = -1
    private let imagePicker = UIImagePickerController()
    private var image: UIImage?
    
    /// This string is nil if a profile field is not edited
    private var editedContent: String?
    
    /// TableView number of rows
    private let numOfRows = 4
    
    /// Alert dialog to show when the user denies permissions.
    let deniedAlert = UIAlertController(title: "Oops!", message: "", preferredStyle: UIAlertControllerStyle.alert)
    let unavailableAlert = UIAlertController(title: "Sorry!", message: "", preferredStyle: .alert)
    
    // MARK: Public Access
    var socket: SocketIOClient?
    
    @IBOutlet var navigationLeftConstraint: NSLayoutConstraint!
    @IBOutlet var profileViewLeftConstraint: NSLayoutConstraint!
    @IBOutlet var profileView: UIView!
    @IBOutlet var profileViewWidth: NSLayoutConstraint!
    @IBOutlet var profileViewHeight: NSLayoutConstraint!
    @IBOutlet var navigationViewWidth: NSLayoutConstraint!
    
    @IBOutlet var profilePicture: UIImageView!
    
    // Responsive layout
    @IBOutlet var infoViewLabel: UILabel!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    @IBOutlet var profilePictureHeight: NSLayoutConstraint!
    @IBOutlet var profilePictureWidth: NSLayoutConstraint!
    @IBOutlet var radiusLabelTopConstraint: NSLayoutConstraint!
    @IBOutlet var radiusViewTopConstraint: NSLayoutConstraint!
    @IBOutlet var tableViewTopConstraint: NSLayoutConstraint!
    
    @IBOutlet var profileTableView: UITableView!
    @IBOutlet var profileTableViewHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet var radiusTextField: UITextField!
    @IBOutlet var radiusSlider: UISlider!
    @IBOutlet var radiusView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        infoViewLabel.font = Font.getFont(Font.infoViewFontSize)
        eventHandlers()
        
        // Initialize navigation menu layout and gestures
        _ = NavigationSideMenu.init(self)
        
        // Add custom cell to table view
        profileTableView.register(UINib(nibName: "ProfileCell", bundle: nil), forCellReuseIdentifier: "profileCell")
        profileTableView.isScrollEnabled = false
        
        // TODO: Get the user profile picture here
        
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        profilePictureHeight.constant = Dimensions.pictureDimension
        profilePictureWidth.constant = profilePictureHeight.constant
        radiusLabelTopConstraint.constant = Dimensions.getPoints(radiusLabelTopConstraint.constant)
        radiusViewTopConstraint.constant = Dimensions.getPoints(radiusViewTopConstraint.constant)
        tableViewTopConstraint.constant = Dimensions.getPoints(tableViewTopConstraint.constant)
        
        // Circular image view
        profilePicture.layer.borderWidth = 1
        profilePicture.layer.borderColor = UIColor.lightGray.cgColor
        profilePicture.layer.cornerRadius = profilePictureHeight.constant / 2
        profilePicture.clipsToBounds = true
        
        // Initialize elements
        let profileTap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        profilePicture.addGestureRecognizer(profileTap)
        
        // Initialize slider
        radiusSlider.minimumValue = 1
        radiusSlider.maximumValue = 100
        radiusSlider.isContinuous = true
        radiusSlider.addTarget(self, action: #selector(endSliding(_:)), for: UIControlEvents.touchUpInside)
        radiusSlider.addTarget(self, action: #selector(endSliding(_:)), for: UIControlEvents.touchUpOutside)
        
        radiusTextField.delegate = self
        radiusTextField.keyboardType = .numberPad
        radiusTextField.text = String(Int(UserData.radius))
        
        if UserData.radius > 100 {
            radiusSlider.value = radiusSlider.maximumValue
        } else {
            radiusSlider.value = Float(UserData.radius)
        }
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = false // Don't allow the user to edit images - TODO: Change this?
        
        profileTableView.delegate = self
        profileTableView.dataSource = self
        
        // Space from bottom left corner of radius view to the bottom of the profile view
        let leftOverSpace = Dimensions.safeAreaHeight - (infoViewHeight.constant + tableViewTopConstraint.constant)
        // Subtract top constraint and bottom constraint - bottom constraint is equal to the cell labels' distance from left
        profileTableViewHeightConstraint.constant = leftOverSpace - Dimensions.getPoints(8) - Dimensions.getPoints(16)
        profileTableView.rowHeight = profileTableViewHeightConstraint.constant / CGFloat(numOfRows)
        
        // Initialize alerts
        deniedAlert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { (action) in
            // Open Settings app
            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
        }))
        deniedAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        unavailableAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: SocketIO Event Handlers
    /// These are only received when an error has occurred.
    func eventHandlers() {
        socket?.on("update_radius_response", callback: { (data, ack) in
            SVProgressHUD.showError(withStatus: JSON(data[0])["error_msg"].stringValue)
        })
        socket?.on("update_profile_response", callback: { (data, ack) in
            SVProgressHUD.showError(withStatus: JSON(data[0])["error_msg"].stringValue)
        })
    }
    
    // MARK: UpdatePictureDelegate Methods
    func updatePicture(_ image: UIImage) {
        print("received image and save")
        profilePicture.image = image
        self.view.layoutIfNeeded()
    }
    
    // MARK: UpdateProfileDelegate Methods
    func updateProfile(_ type: EditProfile, _ content: String) {
        
        switch type {
        case .password:
            UserData.password = content
            var i = content.count
            var pwd = ""
            while(i > 0) {
                pwd.append("●")
                i -= 1
            }
            editedContent = pwd
            
            UserDefaults.standard.set(UserData.password, forKey: "proxiChatPassword")
            UserDefaults.standard.synchronize()
            break
        case .bio:
            UserData.bio = content
            editedContent = content
            break
        case .email:
            UserData.email = content
            editedContent = content
            
            UserDefaults.standard.set(UserData.email, forKey: "proxiChatEmail")
            UserDefaults.standard.synchronize()
            break
        }
        
        let indexPath = IndexPath(row: type.hashValue + 1, section: 0)
        profileTableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    // MARK: UITableView Delegate and DataSource Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        rowSelected = indexPath.row
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        slideLeftTransition()
        performSegue(withIdentifier: "goToEditProfile", sender: self)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "profileCell", for: indexPath) as! ProfileCell
        cell.titleLabel.isEnabled = false // Always gray title label
        
        switch indexPath.row {
        case 0:
            cell.titleLabel.text = "Username"
            cell.contentLabel.text = UserData.username
            cell.contentLabel.isEnabled = false
            cell.accessoryType = .none
            cell.isUserInteractionEnabled = false
            break
        case 1:
            cell.titleLabel.text = "Password"
            // Make fake password
            var i = UserData.password.count
            if let content = editedContent { // Account for change in password
                i = content.count
            }
            var pwd = ""
            while(i > 0) {
                pwd.append("●")
                i -= 1
            }
            cell.contentLabel.text = pwd
            break
        case 2:
            cell.titleLabel.text = "Bio"
            if let content = editedContent {
                if content.split(separator: " ").count == 0 {
                    cell.contentLabel.text = "Edit Bio"
                } else {
                    cell.contentLabel.text = content
                }
            } else {
                if UserData.bio.split(separator: " ").count == 0 {
                    cell.contentLabel.text = "Edit Bio"
                } else {
                    cell.contentLabel.text = UserData.bio
                }
            }
            break
        case 3:
            cell.titleLabel.text = "Email"
            if let content = editedContent {
                cell.contentLabel.text = content
            } else {
                cell.contentLabel.text = UserData.email
            }
            break
        default:
            break
        }
        
        return cell
    }
    
    // MARK: UIImagePickerController Delegate Methods
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let chosenImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.image = chosenImage
            dismiss(animated: true) {
                self.performSegue(withIdentifier: "goToEditPicture", sender: self)
            }
        } else {
            SVProgressHUD.showError(withStatus: "There was a problem choosing an image. Please try again.")
            dismiss(animated: true, completion: nil)
        }
    }
    
    // MARK: UITextField Delegate Methods
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        // If not an empty string
        if let value = Int(textField.text!) {
            if value < 1 {
                textField.text = "1"
                radiusSlider.value = 1
            } else if value >= Int(radiusSlider.maximumValue.rounded()) {
                // If greater than the max, set the slider to the max
                radiusSlider.value = radiusSlider.maximumValue
            } else {
                // If in range of min and max
                radiusSlider.value = Float(value)
            }
        } else {
            textField.text = "1"
            radiusSlider.value = 1
        }
        
        // Save radius and update
        updateRadius()
    }
    
    // MARK: IBOutlet Actions
    @IBAction func radiusChanged(_ sender: UISlider) {
        radiusTextField.text = String(Int(sender.value.rounded()))
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
        } else if segue.identifier == "goToStarred" {
            let destinationVC = segue.destination as! StarredGroupsViewController
            destinationVC.socket = socket
        } else if segue.identifier == "goToSettings" {
            let destinationVC = segue.destination as! SettingsViewController
            destinationVC.socket = socket
        } else if segue.identifier == "goToEditProfile" {
            let destinationVC = segue.destination as! EditProfileViewController
            destinationVC.row = rowSelected
            destinationVC.delegate = self // UpdateProfileDelegate
            editedContent = nil // Set to nil every time to track whether or not a profile field was changed
        } else if segue.identifier == "goToEditPicture" {
            let destinationVC = segue.destination as! EditPictureViewController
            destinationVC.image = image
            destinationVC.delegate = self
        }
        
        if segue.identifier != "goToEditProfile" && segue.identifier != "goToEditPicture" {
            socket?.off("update_radius_response")
            socket?.off("update_profile_response")
            socket = nil
        }
    }
    
    // MARK: Miscellaneous Methods
    func slideLeftTransition() {
        let transition = CATransition()
        transition.duration = Durations.messageTransitionDuration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromRight
        self.view.window?.layer.add(transition, forKey: nil)
    }
    
    /// Locally saves the radius and updates in the database.
    func updateRadius() {
        UserData.radius = Double(radiusTextField.text!)!
        let users = Database.database().reference().child(FirebaseNames.users)
        users.child(UserData.username).updateChildValues(["radius" : UserData.radius])
    }
    
    /// Save and update the radius ONLY when the slider has finished sliding.
    @objc func endSliding(_ aNotification: NSNotification) {
        updateRadius()
    }
    
    /// Show an action sheet to choose between "camera" and "photo library" when the image is clicked.
    @objc func imageTapped() {
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        // TODO: Maybe have an "edit picture" action?
        actionSheet.addAction(UIAlertAction(title: "Take a Photo", style: .default, handler: { (action) in
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
                self.deniedAlert.message = AlertMessages.deniedCamera
                self.present(self.deniedAlert, animated: true, completion: nil)
                break
            default:
                break
            }
        }))
        actionSheet.addAction(UIAlertAction(title: "Choose from Library", style: .default, handler: { (action) in
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
                self.deniedAlert.message = AlertMessages.deniedPhotoLibrary
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
        // If the text field is being edited, end editing
        if radiusTextField.isEditing {
            radiusTextField.endEditing(true)
        }
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
            unavailableAlert.message = AlertMessages.unavailableCamera
            present(unavailableAlert, animated: true, completion: nil)
        }
    }
    
    /// Show the photo library
    func showPhotoLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            imagePicker.sourceType = .photoLibrary
            present(imagePicker, animated: true, completion: nil)
        } else {
            unavailableAlert.message = AlertMessages.unavailablePhotoLibrary
            present(unavailableAlert, animated: true, completion: nil)
        }
    }
}
