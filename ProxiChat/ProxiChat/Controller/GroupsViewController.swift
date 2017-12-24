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

/*
 TODO / BUGS
 - add swipe/drag close to side navigation menu
 - maybe change all SVProgressHUD.showError to UIAlertControllers?
 - only store in database when starred and delete when unstarred
 - ADD SEARCH BAR
 */

class GroupsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate {

    // MARK: Instance variables
    var locationManager = CLLocationManager()
    var socket: SocketIOClient?
    var username: String = ""
    var refreshControl: UIRefreshControl!
    var groupArray: [Group] = [Group]()
    var selectedGroup = Group()
    var delegate: JoinGroupDelegate?
    /// Stores the last visited message view controller. Set the socket of this object to "nil" if the user navigates to another view that's not messages.
    var messageObj: MessageViewController?
    let locationErrorAlert = UIAlertController(title: "Oops!", message: AlertMessages.locationError, preferredStyle: .alert)
    
    // TODO: Add label in order to change label text?
    @IBOutlet var groupsTableView: UITableView!
    
    @IBOutlet var groupsViewWidth: NSLayoutConstraint!
    @IBOutlet var groupsViewHeight: NSLayoutConstraint!
    @IBOutlet var groupsView: UIView!
    @IBOutlet var navigationViewWidth: NSLayoutConstraint!
    @IBOutlet var navigationLeftConstraint: NSLayoutConstraint!
    @IBOutlet var groupsLeftConstraint: NSLayoutConstraint!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIView.setAnimationsEnabled(true)
        eventHandlers()
        
        // Initialize navigation menu layout and gestures
        _ = NavigationSideMenu.init(self)
        
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        
        // UITableView initialization
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
        
        // If the user is not connected, then connect to the server and request location usage.
        if !UserData.connected {
            // TODO: Add reconnecting later - socket.reconnect()
            socket?.connect(timeoutAfter: 5.0, withHandler: {
                SVProgressHUD.showError(withStatus: "Connection Failed.")
                // TODO: Add UIAlertController to reconnect and show failure.
            })
            socket?.joinNamespace("/proxichat_namespace")
            locationManager.requestWhenInUseAuthorization()
        } else {
            // Update last saved location here
            updateTableWithGroups(LocalGroupsData.data)
        }
        self.view.layoutIfNeeded()
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        // Once you successfully joined the namespace, get user info
        socket?.on("join_success", callback: { (data, ack) in
            // TODO: Get the user's profile picture
            self.socket?.emit("get_user_info", self.username)
        })
        // Get user info
        socket?.on("get_user_info_response", callback: { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            
            if success {
                let user = JSON(data[0])["data"].dictionaryObject!
                
                // Cache user data in global struct
                UserData.bio = String(describing: user["bio"]!)
                UserData.coordinates = String(describing: user["coordinates"]!)
                UserData.email = String(describing: user["email"]!)
                UserData.is_online = user["is_online"] as! Bool
                UserData.password = String(describing: user["password"]!)
                UserData.picture = String(describing: user["picture"]!)
                UserData.radius = user["radius"] as! Int
                UserData.username = String(describing: user["username"]!)
            } else {
                SVProgressHUD.dismiss()
                SVProgressHUD.showError(withStatus: error_msg)
            }
        })
        // Update array of GroupCell objects to display on uitableview
        socket?.on("update_location_and_get_groups_response", callback: { (data, ack) in
            self.updateTableWithGroups(data[0])
        })
        // Join private group response
        socket?.on("join_private_group_response") { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            
            if success {
                let row = JSON(data[0])["row_index"].intValue
                self.joinGroup(row)
            } else {
                // TODO: Maybe have a "try again" option
                let alert = UIAlertController(title: "Oops!", message: error_msg, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
        socket?.on("join_success") { (data, ack) in
            self.socket?.emit("go_online", self.username)
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
            let alert = UIAlertController(title: groupArray[indexPath.row].title + " is private!", message: "Please enter a password:", preferredStyle: .alert)
            alert.addTextField(configurationHandler: { (textField) in
                textField.placeholder = "Enter a password"
                textField.isSecureTextEntry = true
            })
            alert.addAction(UIAlertAction(title: "Submit", style: .default, handler: { (action) in
                self.socket?.emit("join_private_group", [
                    "id": self.groupArray[indexPath.row].id,
                    "passwordEntered": alert.textFields?.first?.text!,
                    "rowIndex": String(indexPath.row)
                    ])
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
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
                socket?.emit("update_location_and_get_groups", [
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "username": username,
                    "radius": UserData.radius
                    ])
                manager.stopUpdatingLocation()
            }
        }
    }
    
    /// Start updating location if the user is not connected and if the user authorized location when in use. This happens ONLY on start up.
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse && !UserData.connected {
            SVProgressHUD.show()
            UserData.connected = true
            manager.startUpdatingLocation()
        } else if status == .denied {
            // TODO: Should I have this here, or is it too annoying?
            present(locationErrorAlert, animated: true, completion: nil)
        }
    }
    
    // TODO: Change location error handling later
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
        stopLoading()
        present(locationErrorAlert, animated: true, completion: nil)
    }
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Set MessageViewController socket to nil
        if segue.identifier != "joinGroup" {
            if let mObj = messageObj {
                mObj.socket = nil
            }
        }
        
        if segue.identifier == "joinGroup" {
            let destinationVC = segue.destination as! MessageViewController
            destinationVC.groupInformation = selectedGroup
            destinationVC.socket = socket
            destinationVC.fromViewController = 0
            socket = nil // Won't receive duplicate events
        } else if segue.identifier == "createGroup" {
            let destinationVC = segue.destination as! CreateGroupViewController
            destinationVC.socket = socket
            destinationVC.groupsObj = self // Handle socket = nil only if a group is created
        } else if segue.identifier == "goToStarred" {
            let destinationVC = segue.destination as! StarredGroupsViewController
            destinationVC.socket = socket
            socket = nil
            UserData.createNewMessageViewController = true
        } else if segue.identifier == "goToProfile" {
            let destinationVC = segue.destination as! ProfileViewController
            destinationVC.socket = socket
            socket = nil
            UserData.createNewMessageViewController = true
        } else if segue.identifier == "goToSettings" {
            let destinationVC = segue.destination as! SettingsViewController
            destinationVC.socket = socket
            socket = nil
            UserData.createNewMessageViewController = true
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
    
    /// Take JSON data and update UITableView.
    func updateTableWithGroups(_ data: Any) {
        let success = JSON(data)["success"].boolValue
        let groups = JSON(data)["groups"].arrayValue // Array of groups
        let error_msg = JSON(data)["error_msg"].stringValue
        
        // If getting data was successful
        if success {
            LocalGroupsData.data = data
            self.groupArray = [Group]()
            for group in groups {
                let groupObj = Group()
                let cd = ConvertDate(date: group["date_created"].stringValue)
                
                groupObj.coordinates = group["coordinates"].stringValue
                groupObj.creator = group["created_by"].stringValue
                groupObj.dateCreated = cd.convert()
                groupObj.id = group["id"].stringValue
                groupObj.is_public = group["is_public"].boolValue
                groupObj.numMembers = group["number_members"].intValue
                groupObj.password = group["password"].stringValue
                groupObj.title = group["title"].stringValue
                groupObj.rawDate = group["date_created"].stringValue
                
                self.groupArray.append(groupObj)
            }
            self.groupsTableView.reloadData() // cellforRowAt
            self.stopLoading()
        } else {
            SVProgressHUD.showError(withStatus: error_msg)
            self.stopLoading()
        }
    }
    
    /// Stop refreshing and cancel progress indicator.
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
