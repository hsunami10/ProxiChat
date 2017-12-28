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

/**
 - TODO:
    - Fix unwrapping optional bug for coordinates? - LINE 87 - possible because there are multiple view controllers?
 */
class CreateGroupViewController: UIViewController, CLLocationManagerDelegate {
    
    var locationManager = CLLocationManager()
    var socket: SocketIOClient?
    var newGroup = Group() // Saved for MessageViewController group info
    var data: Any!
    var coordinates = ""
    
    /// Store the groups view controller to set socket to nil if a group is created
    var groupsObj: GroupsViewController?
    var starredGroupsObj: StarredGroupsViewController?
    
    @IBOutlet var groupNameTextField: UITextField!
    @IBOutlet var privateSwitch: UISwitch!
    @IBOutlet var groupPasswordTextField: UITextField!
    @IBOutlet var confirmPasswordTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        eventHandlers()
        
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        
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
        socket?.on("create_group_response") { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            let group_id = JSON(data[0])["group_id"].stringValue
            
            if success {
                // After updating location and creating group, cache the new location groups
                LocalGroupsData.data = self.data
                self.newGroup.id = group_id
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
                self.newGroup.coordinates = UserData.coordinates
                self.socket?.emit("create_group", [
                    "created_by": self.newGroup.creator,
                    "is_public": self.newGroup.is_public,
                    "group_name": self.newGroup.title,
                    "group_password": self.newGroup.password,
                    "group_coordinates": self.newGroup.coordinates,
                    "group_date": self.newGroup.dateCreated
                    ])
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
                socket?.emit("update_location_and_get_groups_create", [
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "username": UserData.username,
                    "radius": UserData.radius
                    ])
                UserData.coordinates = "\(location.coordinate.latitude) \(location.coordinate.longitude)"
                manager.stopUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
        SVProgressHUD.showError(withStatus: "Location unavailable. Check your internet connection.")
    }
    
    // MARK: IBOutlet Actions
    @IBAction func submit(_ sender: Any) {
        let alert = UIAlertController(title: "Warning", message: "Submitting this will update your location as well.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { (action) in
            // If it is a private group
            if self.privateSwitch.isOn {
                // Has to be valid text in group name and password can't have any spaces
                if Validate.isInvalidInput(self.groupNameTextField.text!) || !Validate.isOneWord(self.groupPasswordTextField.text!) || !Validate.isOneWord(self.confirmPasswordTextField.text!) {
                    self.invalidInput("Invalid input. Please try again.")
                } else if self.groupPasswordTextField.text != self.confirmPasswordTextField.text { // Check for matching passwords
                    self.invalidInput("Passwords do not match.")
                } else {
                    SVProgressHUD.show()
                    self.storeGroup(UserData.username, false, self.groupNameTextField.text!, self.groupPasswordTextField.text!)
                    self.locationManager.startUpdatingLocation()
                }
            } else {
                if Validate.isInvalidInput(self.groupNameTextField.text!) {
                    self.invalidInput("Invalid input. Please try again.")
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
    
    @IBAction func switchChange(_ sender: Any) {
        groupPasswordTextField.isHidden = !groupPasswordTextField.isHidden
        confirmPasswordTextField.isHidden = !confirmPasswordTextField.isHidden
    }
    
    @IBAction func cancel(_ sender: Any) {
        socket = nil // Won't receive duplicate events
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToMessagesAfterCreate" {
            let destinationVC = segue.destination as! MessageViewController
            destinationVC.groupInformation = newGroup
            destinationVC.socket = socket
            
            socket?.off("create_group_response")
            socket?.off("update_location_and_get_groups_create_response")
            socket = nil
            
            // Don't receive duplicate events
            if let gObj = groupsObj {
                gObj.socket?.off("join_private_group_response")
                gObj.socket?.off("update_location_and_get_groups_response")
                gObj.socket?.off("get_user_info_response")
                gObj.socket?.off("join_success")
                gObj.socket = nil
                destinationVC.fromViewController = 0
            }
            if let sObj = starredGroupsObj {
                sObj.socket?.off("get_starred_groups_response")
                sObj.socket = nil
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
     Stores data for the newly created group to use after the user's location has been updated
     - Parameters:
        - created_by: The username who created the group
        - is_public: Whether the group is public or not
        - group_id: The UUID for this group
        - group_name: The name of this group
        - group_password: The password for this group if
        - group_description: The description for this group (optional)
    */
    func storeGroup(_ created_by: String, _ is_public: Bool, _ group_name: String, _ group_password: String) {
        let cd = ConvertDate(date: String(describing: Date()))
        newGroup.creator = created_by
        newGroup.dateCreated = cd.convert()
        newGroup.rawDate = cd.date
        newGroup.is_public = is_public
        if !is_public { // Check for whether is public
            newGroup.password = group_password
        } else {
            newGroup.password = ""
        }
        newGroup.title = group_name
    }
    
    /// Shows the label error message when given invalid UITextField values
    func invalidInput(_ message: String) {
        errorLabel.text = message
    }
}
