//
//  GroupsViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/15/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
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
 - get groups that you're NOT a member of
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
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        
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
        
        SVProgressHUD.show()
        
        // CoreLocation initialization
        // didChangeAuthorization runs every time these values are set
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: IBOutlet Actions
    @IBAction func createGroup(_ sender: Any) {
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        performSegue(withIdentifier: "createGroup", sender: self)
    }
    
    @IBAction func showNavMenu(_ sender: Any) {
        if UserData.username.count > 0 {
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
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        
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
                            let group = groups[self.groupArray[indexPath.row].title]
                            let groupPassword = group["information"]["password"].stringValue
                            
                            if let password = alert.textFields?.first?.text {
                                if password == groupPassword {
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
        cell.numberOfMembers.text = String(groupArray[indexPath.row].members.count)
        
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
                                        let group = JSON(snapshot.value!)[key]
                                        let groupInfo = group["information"]
                                        
                                        if groupInfo["creator"].stringValue != UserData.username {
                                            let groupMembers = group["members"]
                                            let groupObj = Group.init(groupInfo["title"].string, groupInfo["num_online"].int, groupInfo["is_public"].bool, groupInfo["password"].string, groupInfo["creator"].string, groupInfo["latitude"].double, groupInfo["longitude"].double, groupInfo["date_created"].string, groupInfo["image"].string, groupMembers.dictionaryObject)
                                            self.groupArray.append(groupObj)
                                        }
                                    } else {
                                        LocalGroupsData.lastGroupsKeys.remove(at: LocalGroupsData.lastGroupsKeys.index(of: key)!)
                                    }
                                }
                                
                                DispatchQueue.main.async {
                                    LocalGroupsData.cachedSnapshot = snapshot
                                    UserData.connected = true
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
    
    // Start updating location on change authorization. This happens every time the delegate is set - so every time this view loads
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse && !UserData.connected { // Very first view load, when user data hasn't been fetched yet
            // If not signed in from sign up or log in
            if !UserData.signedIn {
                Auth.auth().signIn(withEmail: UserData.email, password: UserData.password) { (user, error) in
                    if error != nil {
                        print(error!.localizedDescription)
                        SVProgressHUD.dismiss()
                        SVProgressHUD.showError(withStatus: error!.localizedDescription)
                    } else {
                        UserData.signedIn = true
                        self.getGroups()
                    }
                }
            } else {
                getGroups()
            }
        } else if status == .authorizedWhenInUse && UserData.connected { // Rest of the view loads, when there's already existing data
            // Update table with last snapshot of database
            DispatchQueue.global().async {
                let val = JSON(LocalGroupsData.cachedSnapshot.value!)
                self.groupArray = [Group]()
                
                LocalGroupsData.lastGroupsKeys.forEach({ (key) in
                    let group = val[key]
                    let groupInfo = group["information"]
                    
                    if groupInfo["creator"].stringValue != UserData.username {
                        let groupMembers = group["members"]
                        let groupObj = Group.init(groupInfo["title"].string, groupInfo["num_online"].int, groupInfo["is_public"].bool, groupInfo["password"].string, groupInfo["creator"].string, groupInfo["latitude"].double, groupInfo["longitude"].double, groupInfo["date_created"].string, groupInfo["image"].string, groupMembers.dictionaryObject)
                        self.groupArray.append(groupObj)
                    }
                })
                DispatchQueue.main.async {
                    self.groupsTableView.reloadData()
                    self.stopLoading()
                }
            }
            
        } else if status == .denied {
            SVProgressHUD.dismiss()
            DispatchQueue.main.async {
                self.present(self.locationErrorAlert, animated: true, completion: nil)
            }
        } else if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
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
        // If user navigates to any other view besides message view, then must create new message view controller
        if segue.identifier != "joinGroup" {
            UserData.createNewMessageViewController = true
        }
        
        if segue.identifier == "joinGroup" {
            let destinationVC = segue.destination as! MessageViewController
            destinationVC.groupInformation = selectedGroup
            destinationVC.fromViewController = 0
        } else if segue.identifier == "createGroup" {
            let destinationVC = segue.destination as! CreateGroupViewController
            destinationVC.groupsObj = self // MessageView - handle which screen to go back to
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
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    // MARK: Miscellaneous Methods
    
    /**
     Handles **2 things**:
     1. If viewing for the first time, get user data and update location and groups.
     2. If not viewing for the first time, update the table view with the cached groups.
     */
    func getGroups() {
        // If the user is not already connected, then sign in, get user data and request location usage.
        if !UserData.connected {
            let usersDB = Database.database().reference().child(FirebaseNames.users)
            
            // Check if the user exists
            usersDB.observeSingleEvent(of: .value, with: { (snapshot) in
                if snapshot.hasChild(UserData.username) {
                    let allUsers = JSON(snapshot.value!)
                    guard let user = allUsers[UserData.username].dictionary else {
                        SVProgressHUD.dismiss()
                        SVProgressHUD.showError(withStatus: "Unable to get user information. Please restart the app.")
                        return
                    }
                    
                    // Cache other user data
                    UserData.bio = (user["bio"]?.stringValue)!
                    UserData.is_online = (user["is_online"]?.boolValue)!
                    UserData.latitude = (user["latitude"]?.doubleValue)!
                    UserData.longitude = (user["longitude"]?.doubleValue)!
                    UserData.picture = (user["picture"]?.stringValue)!
                    UserData.radius = (user["radius"]?.doubleValue)!
                    
                    // Update location
                    self.locationManager.startUpdatingLocation()
                } else {
                    SVProgressHUD.dismiss()
                    SVProgressHUD.showError(withStatus: "The account with the specified username does not exist. Please try again.")
                }
            })
        } else {
            // Update table with last snapshot of database
            DispatchQueue.global().async {
                let val = JSON(LocalGroupsData.cachedSnapshot.value!)
                self.groupArray = [Group]()
                
                LocalGroupsData.lastGroupsKeys.forEach({ (key) in
                    let group = val[key]
                    let groupInfo = group["information"]
                    
                    if groupInfo["creator"].stringValue != UserData.username {
                        let groupMembers = group["members"]
                        let groupObj = Group.init(groupInfo["title"].string, groupInfo["num_online"].int, groupInfo["is_public"].bool, groupInfo["password"].string, groupInfo["creator"].string, groupInfo["latitude"].double, groupInfo["longitude"].double, groupInfo["date_created"].string, groupInfo["image"].string, groupMembers.dictionaryObject)
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
        if (groupsTableView.refreshControl?.isRefreshing)! {
            refreshControl.endRefreshing()
        }
        if SVProgressHUD.isVisible() {
            SVProgressHUD.dismiss()
        }
    }
    
    /// Refresh groups in proximity.
    @objc func refreshGroups(_ sender: AnyObject) {
        refreshControl.beginRefreshing()
        locationManager.startUpdatingLocation()
    }
    
    @objc func closeNavMenu() {
        if navigationLeftConstraint.constant == 0 {
            NavigationSideMenu.toggleSideNav(show: false)
        }
    }
}
