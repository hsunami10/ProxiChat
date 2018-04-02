//
//  GroupsViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/15/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO
import SwiftyJSON
import SVProgressHUD
import CoreLocation
import Firebase
import GeoFire

/*
 TODO
 - add swipe/drag close to side navigation menu
 - maybe change all SVProgressHUD.showError to UIAlertControllers?
 - only store in database when starred and delete when unstarred
 - ADD SEARCH BAR
 
 TODO: Line 306
 
 BUGS
 - app sometimes crashes for no reason - check and rerun later to test
 Terminating app due to uncaught exception 'InvalidPathValidation', reason: '(child:) Must be a non-empty string and not contain '.' '#' '$' '[' or ']''
 */

class GroupsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate {

    // MARK: Private Access
    private var locationManager = CLLocationManager()
    private var refreshControl: UIRefreshControl!
    private var groupArray: [Group] = [Group]()
    private var selectedGroup: Group!
    private let locationErrorAlert = UIAlertController(title: "Oops!", message: AlertMessages.locationError, preferredStyle: .alert)
    
    // MARK: Public Access
    /**
     Stores the last visited message view controller.
     Set the socket of this object to "nil" if the user navigates to another view that's not the message view.
     */
    var messageObj: MessageViewController?
    var delegate: JoinGroupDelegate?
    var socket: SocketIOClient?
    
    // TODO: Add label in order to change label text?
    @IBOutlet var groupsTableView: UITableView!
    
    @IBOutlet var groupsViewWidth: NSLayoutConstraint!
    @IBOutlet var groupsViewHeight: NSLayoutConstraint!
    @IBOutlet var groupsView: UIView!
    @IBOutlet var navigationViewWidth: NSLayoutConstraint!
    @IBOutlet var navigationLeftConstraint: NSLayoutConstraint!
    @IBOutlet var groupsLeftConstraint: NSLayoutConstraint!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    @IBOutlet var infoViewLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIView.setAnimationsEnabled(true)
        
        // Initialize navigation menu layout and gestures
        _ = NavigationSideMenu.init(self)
        
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        groupsTableView.delegate = self
        groupsTableView.dataSource = self
        groupsTableView.register(UINib.init(nibName: "GroupCell", bundle: nil), forCellReuseIdentifier: "groupCell")
        
        // Implement pull to refresh
        refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(refreshGroups(_:)), for: .valueChanged)
        
        // Initialize error alert
        locationErrorAlert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { (action) in
            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
        }))
        locationErrorAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        // Add Refresh Control to Table View
        if #available(iOS 10.0, *) {
            groupsTableView.refreshControl = refreshControl
        } else {
            groupsTableView.addSubview(refreshControl)
        }
        
        // CoreLocation initialization
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // If the user is not already connected, then get user data and request location usage.
        if !UserData.connected {
            let usersDB = Database.database().reference().child(FirebaseNames.users)
            
            // Check if the user exists
            usersDB.observeSingleEvent(of: .value, with: { (snapshot) in
                if snapshot.hasChild(UserData.username) {
                    let allUsers = JSON(snapshot.value!)
                    if let user = allUsers[UserData.username].dictionary {
                        
                        // Cache user data
                        UserData.bio = (user["bio"]?.stringValue)!
                        UserData.email = (user["email"]?.stringValue)!
                        UserData.is_online = (user["is_online"]?.boolValue)!
                        UserData.latitude = (user["latitude"]?.doubleValue)!
                        UserData.longitude = (user["longitude"]?.doubleValue)!
                        UserData.password = (user["password"]?.stringValue)!
                        UserData.picture = (user["picture"]?.stringValue)!
                        UserData.radius = (user["radius"]?.doubleValue)!
                        
                        // Update location
                        self.locationManager.requestWhenInUseAuthorization()
                        return
                    }
                }
                SVProgressHUD.showError(withStatus: "The account with the specified username does not exist. Please try again.")
            })
        } else {
            SVProgressHUD.show()
            
            // Update table with last snapshot of database
            DispatchQueue.global().async {
                let dict = JSON(LocalGroupsData.cachedSnapshot.value!)
                self.groupArray = [Group]()
                
                LocalGroupsData.lastGroupsKeys.forEach({ (key) in
                    let group = dict[key].dictionaryValue
                    
                    if group["creator"]?.stringValue != UserData.username {
                        let groupObj = Group.init(group["title"]?.string, group["num_members"]?.int, group["num_online"]?.int, group["is_public"]?.bool, group["password"]?.string, group["creator"]?.string, group["latitude"]?.double, group["longitude"]?.double, group["date_created"]?.string, group["image"]?.string)
                        self.groupArray.append(groupObj)
                    }
                })
                
                DispatchQueue.main.async {
                    self.groupsTableView.reloadData()
                    self.stopLoading()
                }
            }
        }
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        // Join private group response
        socket?.on("join_private_group_response") { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            
            if success {
                let row = JSON(data[0])["row_index"].intValue
                self.joinGroup(row)
            } else {
                DispatchQueue.main.async {
                    // TODO: Maybe have a "try again" option
                    let alert = UIAlertController(title: "Oops!", message: error_msg, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                    
                    if !UIView.areAnimationsEnabled {
                        UIView.setAnimationsEnabled(true)
                    }
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: IBOutlet Actions
    @IBAction func createGroup(_ sender: Any) {
        UIView.setAnimationsEnabled(true)
        performSegue(withIdentifier: "createGroup", sender: self)
    }
    
    @IBAction func showNavMenu(_ sender: Any) {
        if UserData.username.count > 0 {
            UIView.setAnimationsEnabled(true)
            // If navigation menu isn't showing
            if navigationLeftConstraint.constant != 0 {
                NavigationSideMenu.toggleSideNav(show: true)
            } else {
                NavigationSideMenu.toggleSideNav(show: false)
            }
        }
    }
    
    /**
     IBAction for all of the side navigation menu buttons
     - TAGS:
        - 0 - Search & Find Groups
        - 1 - Starred / Joined Groups
        - 2 - Profile
        - 3 - Settings
    */
    @IBAction func navItemClicked(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            NavigationSideMenu.toggleSideNav(show: false)
            break
        case 1:
            NavigationSideMenu.addTransition(sender: self)
            performSegue(withIdentifier: "goToStarred", sender: self)
            break
        case 2:
            NavigationSideMenu.addTransition(sender: self)
            performSegue(withIdentifier: "goToProfile", sender: self)
            break
        case 3:
            NavigationSideMenu.addTransition(sender: self)
            performSegue(withIdentifier: "goToSettings", sender: self)
            break
        default:
            break
        }
    }
    
    // MARK: UITableView Delegate and DataSource Methods
    // When a group is selected
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Check public or private
        if groupArray[indexPath.row].is_public {
            joinGroup(indexPath.row)
        } else {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: self.groupArray[indexPath.row].title + " is private!", message: "Please enter a password:", preferredStyle: .alert)
                alert.addTextField(configurationHandler: { (textField) in
                    textField.placeholder = "Enter a password"
                    textField.isSecureTextEntry = true
                })
                alert.addAction(UIAlertAction(title: "Submit", style: .default, handler: { (action) in
                    let groupsDB = Database.database().reference().child(FirebaseNames.groups)
                    groupsDB.observeSingleEvent(of: .value, with: { (snapshot) in
                        if snapshot.hasChild(self.groupArray[indexPath.row].title) {
                            // Check if the passwords are the same
                            let groups = JSON(snapshot.value!)
                            let group = groups[self.groupArray[indexPath.row].title].dictionaryValue
                            if let password = alert.textFields?.first?.text {
                                if password == group["password"]?.stringValue {
                                    self.joinGroup(indexPath.row)
                                } else {
                                    SVProgressHUD.showError(withStatus: "Incorrect password.")
                                }
                            }
                        } else {
                            SVProgressHUD.showError(withStatus: "\(self.groupArray[indexPath.row].title) does not exist.")
                        }
                    })
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                
                if !UIView.areAnimationsEnabled {
                    UIView.setAnimationsEnabled(true)
                }
                self.present(alert, animated: true, completion: nil)
            }
        }
        groupsTableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groupArray.count
    }
    
    // Link displayed cell with corresponding GroupCell objects
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "groupCell", for: indexPath) as! GroupCell // Gets UITableViewCell
        
        cell.groupName.text = groupArray[indexPath.row].title
        if groupArray[indexPath.row].is_public {
            cell.lockIcon.image = UIImage()
        } else {
            cell.lockIcon.image = UIImage(named: "locked")
        }
        cell.numberOfMembers.text = String(groupArray[indexPath.row].numMembers)
        
        return cell
    }
    
    // MARK: CLLocationManagerDelegate Methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            // If the current location (timestamps are the same)
            if String(describing: Date()) == String(describing: location.timestamp) {
                UserData.latitude = location.coordinate.latitude
                UserData.longitude = location.coordinate.longitude
                
                let usersDB = Database.database().reference().child(FirebaseNames.users)
                // Update user location
                usersDB.child(UserData.username).updateChildValues(
                    ["latitude" : UserData.latitude, "longitude" : UserData.longitude, "is_online" : true], withCompletionBlock: { (error, ref) in
                    if error != nil {
                        SVProgressHUD.dismiss()
                        SVProgressHUD.showError(withStatus: error?.localizedDescription)
                    } else {
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
                            self.groupArray = [Group]()
                            
                            // Get all groups' info - async
                            groupsDB.observe(.value, with: { (snapshot) in
                                for key in LocalGroupsData.lastGroupsKeys {
                                    // Check if the group still exists
                                    if snapshot.hasChild(key) {
                                        let group = JSON(snapshot.value!)[key].dictionaryValue
                                        
                                        // Filter out groups created by the current user
                                        if group["creator"]?.stringValue != UserData.username {
                                            let groupObj = Group.init(group["title"]?.string, group["num_members"]?.int, group["num_online"]?.int, group["is_public"]?.bool, group["password"]?.string, group["creator"]?.string, group["latitude"]?.double, group["longitude"]?.double, group["date_created"]?.string, group["image"]?.string)
                                            
                                            self.groupArray.append(groupObj)
                                        }
                                    } else {
                                        LocalGroupsData.lastGroupsKeys.remove(at: LocalGroupsData.lastGroupsKeys.index(of: key)!)
                                    }
                                }
                                
                                DispatchQueue.main.async {
                                    LocalGroupsData.cachedSnapshot = snapshot
                                    self.groupsTableView.reloadData()
                                    self.stopLoading()
                                }
                            })
                        })
                    }
                })
                
                manager.stopUpdatingLocation()
            }
        }
    }
    
    // Start updating location if the user is not connected and if the user authorized location when in use. This happens ONLY on start up.
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse && !UserData.connected {
            SVProgressHUD.show()
            UserData.connected = true
            manager.startUpdatingLocation()
        } else if status == .denied {
            // TODO: Should I have this here, or is it too annoying?
            DispatchQueue.main.async {
                self.present(self.locationErrorAlert, animated: true, completion: nil)
            }
        }
    }
    
    // TODO: Change location error handling later
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
        stopLoading()
        DispatchQueue.main.async {
            self.present(self.locationErrorAlert, animated: true, completion: nil)
        }
    }
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Set MessageViewController socket to nil
        if segue.identifier != "joinGroup" {
            if let mObj = messageObj {
                mObj.socket?.off("group_stats")
                mObj.socket?.off("receive_message")
                mObj.socket?.off("get_messages_on_start_response")
                mObj.socket = nil
            }
        }
        
        if segue.identifier == "joinGroup" {
            let destinationVC = segue.destination as! MessageViewController
            destinationVC.groupInformation = selectedGroup
            destinationVC.socket = socket
            destinationVC.fromViewController = 0
        } else if segue.identifier == "createGroup" {
            let destinationVC = segue.destination as! CreateGroupViewController
            destinationVC.groupsObj = self // MessageView - handle which screen to go back to
        }else if segue.identifier == "goToStarred" {
            let destinationVC = segue.destination as! StarredGroupsViewController
            destinationVC.socket = socket
            UserData.createNewMessageViewController = true
        } else if segue.identifier == "goToProfile" {
            let destinationVC = segue.destination as! ProfileViewController
            destinationVC.socket = socket
            UserData.createNewMessageViewController = true
        } else if segue.identifier == "goToSettings" {
            let destinationVC = segue.destination as! SettingsViewController
            destinationVC.socket = socket
            UserData.createNewMessageViewController = true
        }
        
        // Remove sockets for all but create group
        if segue.identifier != "createGroup" {
            socket?.off("join_private_group_response")
            socket?.off("update_location_and_get_groups_response")
            socket?.off("get_user_info_response")
            socket?.off("join_success")
            socket = nil // Won't receive duplicate events
        }
    }
    
    /// Selects group, and performs segue to MessageViewController.
    func joinGroup(_ row: Int) {
        selectedGroup = groupArray[row]
        if UserData.createNewMessageViewController { // Create MessageViewController
            slideLeftTransition()
            performSegue(withIdentifier: "joinGroup", sender: self)
        } else { // Pass chosen group data back to the same MessageViewController and dismiss
            delegate?.joinGroup(selectedGroup)
            slideLeftTransition()
            socket = nil // Won't receive duplicate events
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    // MARK: Miscellaneous Methods
    
    /// Edit UIViewController transition right -> left.
    func slideLeftTransition() {
        let transition = CATransition()
        transition.duration = Durations.messageTransitionDuration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromRight
        self.view.window?.layer.add(transition, forKey: nil)
    }
    
    /// Stop refreshing and cancel SVProgressHUD indicator.
    func stopLoading() {
        refreshControl.endRefreshing()
        if SVProgressHUD.isVisible() {
            SVProgressHUD.dismiss()
        }
    }
    
    /// Refresh groups in proximity.
    @objc func refreshGroups(_ sender: AnyObject) {
        locationManager.startUpdatingLocation()
    }
    
    @objc func closeNavMenu() {
        if navigationLeftConstraint.constant == 0 {
            NavigationSideMenu.toggleSideNav(show: false)
        }
    }
}
