//
//  CreateGroupViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/21/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import CoreLocation
import SwiftyJSON
import SVProgressHUD
import SocketIO
import Firebase

/**
 - TODO:
    - Fix unwrapping optional bug for coordinates? - LINE 87 - possible because there are multiple view controllers?
 - maybe only update location when creating, don't get groups???
 
 FINISH GETTING GROUPS BY LOCATION WITH FIREBASE
 */
class CreateGroupViewController: UIViewController, CLLocationManagerDelegate {
    
    // MARK: Private Access
    private var locationManager = CLLocationManager()
    private var newGroup = Group() // Saved for MessageViewController group info
    private var data: Any!
    private var coordinates = ""
    private let locationErrorAlert = UIAlertController(title: "Oops!", message: AlertMessages.locationError, preferredStyle: .alert)
    private let usersDB = Database.database().reference().child("Users")
    private let groupsDB = Database.database().reference().child("Groups")
    
    // MARK: Public Access
    var socket: SocketIOClient?
    /// Store the groups view controller to set socket to nil if a group is created
    var groupsObj: GroupsViewController?
    var starredGroupsObj: StarredGroupsViewController?
    
    @IBOutlet var groupNameTextField: UITextField!
    @IBOutlet var privateSwitch: UISwitch!
    @IBOutlet var groupPasswordTextField: UITextField!
    @IBOutlet var confirmPasswordTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    @IBOutlet var infoViewLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        
        // Initialize error alert
        locationErrorAlert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { (action) in
            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
        }))
        locationErrorAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        privateSwitch.isOn = false
        groupPasswordTextField.isHidden = true
        confirmPasswordTextField.isHidden = true
        errorLabel.text = ""
        infoViewLabel.font = Font.getFont(Font.infoViewFontSize)
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        // Only update location when group has been successfully created
        socket?.on("create_group_response") { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            
            if success {
                // After updating location and creating group, cache the new location groups
                LocalGroupsData.data = self.data
                SVProgressHUD.dismiss()
                
                self.slideLeftTransition()
                self.performSegue(withIdentifier: "goToMessagesAfterCreate", sender: self)
            } else {
                SVProgressHUD.dismiss()
                SVProgressHUD.showError(withStatus: error_msg)
            }
        }
        // Same as update_location_and_get_groups_response, but with data[1] added - socket may be nil
        socket?.on("update_location_and_get_groups_create_response") { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            if success {
                self.data = data[0] // Save groups in new proximity
//                self.newGroup.coordinates = UserData.coordinates
//                self.socket?.emit("create_group", [
//                    "created_by": self.newGroup.creator,
//                    "is_public": self.newGroup.is_public,
//                    "group_name": self.newGroup.title,
//                    "group_password": self.newGroup.password,
//                    "group_coordinates": self.newGroup.coordinates,
//                    "group_date": self.newGroup.dateCreated
//                    ])
            } else {
                SVProgressHUD.dismiss()
                SVProgressHUD.showError(withStatus: error_msg)
            }
        }
    }
    
    // MARK: CLLocationManagerDelegate Methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            if String(describing: Date()) == String(describing: location.timestamp) {
                UserData.latitude = location.coordinate.latitude
                UserData.longitude = location.coordinate.longitude
                newGroup.latitude = location.coordinate.latitude
                newGroup.longitude = location.coordinate.longitude
                
                // TODO: Finish this - get groups by location and radius
                // Store group first, then update location, then get new groups
                // Create group only if the group title doesn't already exist
                groupsDB.observeSingleEvent(of: .value, with: { (snapshot) in
                    if !snapshot.hasChild(self.newGroup.title) {
                        self.groupsDB.child(self.newGroup.title).setValue([
                            "num_members": 1,
                            "num_online": 1,
                            "is_public": self.newGroup.is_public,
                            "password": self.newGroup.password,
                            "creator": self.newGroup.creator,
                            "latitude": location.coordinate.latitude,
                            "longitude": location.coordinate.longitude,
                            "date_created": self.newGroup.dateCreated,
                            "image": ""
                            ])
                        
                        // Update user's location
                        self.usersDB.child(UserData.username).updateChildValues(
                            ["latitude" : UserData.latitude, "longitude" : UserData.longitude], withCompletionBlock: { (error, ref) in
                                SVProgressHUD.dismiss()
                                if error != nil {
                                    SVProgressHUD.showError(withStatus: error?.localizedDescription)
                                } else {
                                    // TODO: Get new groups with new location here
                                }
                        })
                    } else {
                        SVProgressHUD.showError(withStatus: "Group name already exists. Please try again.")
                    }
                })
                manager.stopUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
        manager.stopUpdatingLocation()
        present(locationErrorAlert, animated: true, completion: nil)
    }
    
    // MARK: IBOutlet Actions
    @IBAction func submit(_ sender: Any) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Warning", message: "Submitting this will update your location as well.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { (action) in
                // If it is a private group
                if self.privateSwitch.isOn {
                    // Has to be valid text in group name and password can't have any spaces
                    if Validate.isInvalidInput(self.groupNameTextField.text!) || !Validate.isOneWord(self.groupPasswordTextField.text!) || !Validate.isOneWord(self.confirmPasswordTextField.text!) {
                        self.showError("Invalid input. Please try again.")
                    } else if self.groupPasswordTextField.text != self.confirmPasswordTextField.text { // Check for matching passwords
                        self.showError("Passwords do not match.")
                    } else {
                        SVProgressHUD.show()
                        self.storeGroup(UserData.username, false, self.groupNameTextField.text!, self.groupPasswordTextField.text!)
                        self.locationManager.startUpdatingLocation()
                    }
                } else {
                    if Validate.isInvalidInput(self.groupNameTextField.text!) {
                        self.showError("Invalid input. Please try again.")
                    } else {
                        SVProgressHUD.show()
                        self.storeGroup(UserData.username, true, self.groupNameTextField.text!, "")
                        self.locationManager.startUpdatingLocation()
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            if !UIView.areAnimationsEnabled {
                UIView.setAnimationsEnabled(true)
            }
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func switchChange(_ sender: Any) {
        groupPasswordTextField.isHidden = !groupPasswordTextField.isHidden
        confirmPasswordTextField.isHidden = !confirmPasswordTextField.isHidden
    }
    
    @IBAction func cancel(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToMessagesAfterCreate" {
            let destinationVC = segue.destination as! MessageViewController
            destinationVC.groupInformation = newGroup
            
            // Don't receive duplicate events
            if groupsObj != nil {
                destinationVC.fromViewController = 0
            } else if starredGroupsObj != nil {
                destinationVC.fromViewController = 1
            }
        }
    }
    
    /// Edit UIViewController transition right -> left
    func slideLeftTransition() {
        let transition = CATransition()
        transition.duration = Durations.messageTransitionDuration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromRight
        self.view.window?.layer.add(transition, forKey: nil)
    }
    
    // MARK: Miscellaneous Methods
    
    /**
     Stores data for the newly created group to use after the user's location has been updated.
     
     - parameters:
         - created_by: The username who created the group.
         - is_public: Whether the group is public or not.
         - group_name: The name of this group.
         - group_password: The password for this group, only if it's private.
     */

    func storeGroup(_ created_by: String, _ is_public: Bool, _ group_name: String, _ group_password: String) {
        newGroup.creator = created_by
        newGroup.dateCreated = String(describing: Date())
        newGroup.is_public = is_public
        newGroup.numMembers = 1
        if !is_public { // Check for whether is public
            newGroup.password = group_password
        } else {
            newGroup.password = ""
        }
        newGroup.title = group_name
    }
    
    /**
     Shows the label error message when given invalid UITextField values
     
     - parameters:
        - message: The error message.
     */
    func showError(_ message: String) {
        errorLabel.text = message
    }
}
