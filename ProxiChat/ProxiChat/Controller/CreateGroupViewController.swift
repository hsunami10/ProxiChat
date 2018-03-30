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
import Firebase
import GeoFire

/**
 - TODO:
    - Fix unwrapping optional bug for coordinates? - LINE 87 - possible because there are multiple view controllers?
 - maybe only update location when creating, don't get groups???
 
 FINISH GETTING GROUPS BY LOCATION WITH FIREBASE
 */
class CreateGroupViewController: UIViewController, CLLocationManagerDelegate {
    
    // MARK: Private Access
    private var locationManager = CLLocationManager()
    private var newGroup: Group! // Saved for MessageViewController group info
    private var data: Any!
    private var coordinates = ""
    private let locationErrorAlert = UIAlertController(title: "Oops!", message: AlertMessages.locationError, preferredStyle: .alert)
    
    // MARK: Public Access
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
    
    // MARK: CLLocationManagerDelegate Methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            if String(describing: Date()) == String(describing: location.timestamp) {
                UserData.latitude = location.coordinate.latitude
                UserData.longitude = location.coordinate.longitude
                newGroup.latitude = location.coordinate.latitude
                newGroup.longitude = location.coordinate.longitude
                
                // TODO: Finish this - get groups by location and radius
                // Store group first and update location, then update user location, then get new groups
                // If an error occurs, then undo what was done before
                let usersDB = Database.database().reference().child(FirebaseNames.users)
                let groupsDB = Database.database().reference().child(FirebaseNames.groups)
                let groupLocationsDB = GeoFire(firebaseRef: Database.database().reference().child(FirebaseNames.group_locations))
                
                // Create group only if the group title doesn't already exist
                groupsDB.observeSingleEvent(of: .value, with: { (snapshot) in
                    if !snapshot.hasChild(self.newGroup.title) {
                        groupsDB.child(self.newGroup.title).setValue([
                            "num_members": 1,
                            "num_online": 1,
                            "is_public": self.newGroup.is_public,
                            "password": self.newGroup.password,
                            "creator": self.newGroup.creator,
                            "latitude": location.coordinate.latitude,
                            "longitude": location.coordinate.longitude,
                            "date_created": self.newGroup.dateCreated,
                            "image": "",
                            "title": self.newGroup.title
                            ])
                        
                        // Set the location of the group
                        groupLocationsDB.setLocation(location, forKey: self.newGroup.title, withCompletionBlock: { (error) in
                            if error != nil {
                                groupsDB.child(self.newGroup.title).removeValue()
                                SVProgressHUD.showError(withStatus: "There was a problem with updating the location of the group. Please try again.")
                            } else {
                                // Update user's location
                                usersDB.child(UserData.username).updateChildValues(["latitude" : UserData.latitude, "longitude" : UserData.longitude], withCompletionBlock: { (error, ref) in
                                    SVProgressHUD.dismiss()
                                    if error != nil {
                                        groupsDB.child(self.newGroup.title).removeValue()
                                        SVProgressHUD.showError(withStatus: error?.localizedDescription)
                                    } else {
                                        // Get groups with new location - only update snapshot and keys
                                        // Get all group keys in proximity
                                        let groupLocationsDB = GeoFire(firebaseRef: Database.database().reference().child(FirebaseNames.group_locations))
                                        let geoQuery = groupLocationsDB.query(at: location, withRadius: UserData.radius)
                                        
                                        LocalGroupsData.lastGroupsKeys = [String]()
                                        let registration = geoQuery.observe(.keyEntered, with: { (key, location) in
                                            LocalGroupsData.lastGroupsKeys.append(key)
                                        })
                                        geoQuery.observeReady({
                                            geoQuery.removeObserver(withFirebaseHandle: registration)
                                            
                                            let groupsDB = Database.database().reference().child(FirebaseNames.groups)
                                            
                                            // Get all groups' info - async
                                            groupsDB.observe(.value, with: { (snapshot) in
                                                LocalGroupsData.cachedSnapshot = snapshot
                                                self.performSegue(withIdentifier: "goToMessagesAfterCreate", sender: self)
                                            })
                                        })
                                    }
                                })
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
                    } else if !self.isValid(self.groupNameTextField.text!) {
                        self.showError("Group title cannot contain . # $ [ ] / characters.")
                    } else {
                        SVProgressHUD.show()
                        self.storeGroup(UserData.username, false, self.groupNameTextField.text!, self.groupPasswordTextField.text!)
                        self.locationManager.startUpdatingLocation()
                    }
                } else {
                    if Validate.isInvalidInput(self.groupNameTextField.text!) {
                        self.showError("Invalid input. Please try again.")
                    } else if !self.isValid(self.groupNameTextField.text!) {
                        self.showError("Group title cannot contain . # $ [ ] / characters.")
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
    
    /// Checks text to make sure doesn't contain `. # $ [ ] /`
    func isValid(_ text: String) -> Bool {
        return !(text.contains(".") || text.contains("#") || text.contains("$") || text.contains("[") || text.contains("]") || text.contains("/"))
    }
    
    /**
     Stores data for the newly created group to use after the user's location has been updated.
     
     - parameters:
         - created_by: The username who created the group.
         - is_public: Whether the group is public or not.
         - group_name: The name of this group.
         - group_password: The password for this group, only if it's private.
     */

    func storeGroup(_ created_by: String, _ is_public: Bool, _ group_name: String, _ group_password: String) {
        newGroup = Group.init(group_name, 1, 1, is_public, (!is_public ? group_password : ""), created_by, 0.0, 0.0, String(describing: Date()), "")
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
