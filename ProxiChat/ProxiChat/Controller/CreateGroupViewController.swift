//
//  CreateGroupViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/21/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO
import CoreLocation
import SwiftyJSON
import SVProgressHUD

class CreateGroupViewController: UIViewController, CLLocationManagerDelegate {
    
    var locationManager = CLLocationManager()
    var socket: SocketIOClient!
    var username: String!
    var newGroup: Group!
    var data: Any!
    var coordinates = ""
    
    @IBOutlet var groupNameTextField: UITextField!
    @IBOutlet var groupDescriptionTextField: UITextField!
    @IBOutlet var privateSwitch: UISwitch!
    @IBOutlet var groupPasswordTextField: UITextField!
    @IBOutlet var confirmPasswordTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        eventHandlers()
        
        privateSwitch.isOn = false
        groupPasswordTextField.isHidden = true
        confirmPasswordTextField.isHidden = true
        errorLabel.text = ""
        
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
        socket.on("create_group_response") { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            
            if success {
                // After updating location and creating group, save the new location groups
                UserDefaults.standard.set(self.data, forKey: "proxichatLastGroupUpdate")
                UserDefaults.standard.synchronize()
                SVProgressHUD.dismiss()
                
                // TODO: Fix bug here
                self.slideLeftTransition()
                self.performSegue(withIdentifier: "goToMessagesAfterCreate", sender: self)
                UIView.setAnimationsEnabled(false)
            } else {
                SVProgressHUD.dismiss()
                SVProgressHUD.showError(withStatus: error_msg)
            }
        }
        // Same as update_location_and_get_groups_response, but with data[1] added
        socket.on("update_location_and_get_groups_create_response") { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            
            if success {
                self.data = data[0] // Save groups in new proximity
                self.newGroup.coordinates = self.coordinates
                self.socket.emit("create_group", [
                    "created_by": self.newGroup.creator,
                    "is_public": self.newGroup.is_public,
                    "group_id": self.newGroup.id,
                    "group_name": self.newGroup.title,
                    "group_password": self.newGroup.password,
                    "group_description": self.newGroup.description,
                    "group_coordinates": self.newGroup.coordinates
                    ])
            } else {
                SVProgressHUD.dismiss()
                SVProgressHUD.showError(withStatus: error_msg)
            }
        }
    }
    
    // MARK: CLLocationManagerDelegate Methods
    
    // TODO: Change radius
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            if String(describing: Date()) == String(describing: location.timestamp) {
                self.coordinates = String(location.coordinate.latitude) + " " + String(location.coordinate.longitude)
                socket.emit("update_location_and_get_groups_create", [
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "username": username,
                    "radius": 800000
                    ])
                manager.stopUpdatingLocation()
            }
        }
    }
    
    // MARK: IBOutlet Actions
    
    // TOOD: Update locations here
    @IBAction func submit(_ sender: Any) {
        let alert = UIAlertController(title: "Warning", message: "Submitting this will update your location as well.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { (action) in
            // If it is a private group
            if self.privateSwitch.isOn {
                // Has to be valid text in group name and password can't have any spaces
                if self.groupNameTextField.text?.split(separator: " ").count == 0 || self.groupPasswordTextField.text?.split(separator: " ").count != 1 || self.confirmPasswordTextField.text?.split(separator: " ").count != 1 {
                    self.invalidInput("Invalid input. Please try again.")
                } else if self.groupPasswordTextField.text != self.confirmPasswordTextField.text { // Check for matching passwords
                    self.invalidInput("Passwords do not match.")
                } else {
                    SVProgressHUD.show()
                    self.storeGroup(self.username, false, UUID(), self.groupNameTextField.text!, self.groupPasswordTextField.text!, self.groupDescriptionTextField.text!)
                    self.locationManager.startUpdatingLocation()
                }
            } else {
                if self.groupNameTextField.text?.split(separator: " ").count == 0 {
                    self.invalidInput("Invalid input. Please try again.")
                } else {
                    SVProgressHUD.show()
                    self.storeGroup(self.username, true, UUID(), self.groupNameTextField.text!, self.groupPasswordTextField.text!, self.groupDescriptionTextField.text!)
                    self.locationManager.startUpdatingLocation()
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
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
            destinationVC.socket = socket
            destinationVC.username = username
        }
    }
    /// Edit UIViewController transition right -> left
    func slideLeftTransition() {
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromRight
        self.view.window?.layer.add(transition, forKey: nil)
    }
    
    // MARK: Miscellaneous Methods
    
    /**
     Stores data for the newly created group to use after the user's location has been updated
     - Parameters:
        - created_by: The username who created the group
        - is_public: Whether the group is public or not
        - group_id: The UUID for this group
        - group_name: The name of this group
        - group_password: The password for this group if
        - group_description: The description for this group (optional)
    */
    func storeGroup(_ created_by: String, _ is_public: Bool, _ group_id: UUID, _ group_name: String, _ group_password: String, _ group_description: String) {
        newGroup = Group()
        newGroup.creator = created_by
        newGroup.dateCreated = String(describing: Date()) // TODO: Change this later according to date conversion and formatting
        newGroup.description = group_description
        newGroup.is_public = is_public
        newGroup.id = String(describing: group_id)
        newGroup.password = group_password
        newGroup.title = group_name
    }
    /// Shows the label error message when given invalid UITextField values
    func invalidInput(_ message: String) {
        errorLabel.text = message
    }
}
