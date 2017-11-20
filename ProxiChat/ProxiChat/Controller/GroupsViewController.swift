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
 - have an option for the user to choose when to update (maybe?)
 - only store in database when starred and delete when unstarred
 */

class GroupsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate {

    /// Instance variables
    var locationManager = CLLocationManager()
    var socket: SocketIOClient!
    var username: String = ""
    var refreshControl: UIRefreshControl!
    var groupArray: [Group] = [Group]()
    var selectedGroup = Group()
    var justStarted = false
    var delegate: JoinGroupDelegate?

    @IBOutlet var groupsTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIView.setAnimationsEnabled(true)
        
        eventHandlers()
        
        // UITableView initialization
        groupsTableView.delegate = self
        groupsTableView.dataSource = self
        groupsTableView.register(UINib(nibName: "GroupCell", bundle: nil), forCellReuseIdentifier: "groupCell")
        
        // Implement pull to refresh
        refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(refreshGroups(_:)), for: .valueChanged)
        
        // Add Refresh Control to Table View
        if #available(iOS 10.0, *) {
            groupsTableView.refreshControl = refreshControl
        } else {
            groupsTableView.addSubview(refreshControl)
        }
        
        // Core location initialization
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Handle what to do when visiting for the first time
        if justStarted {
            // TODO: Add reconnecting later - socket.reconnect()
            socket.connect(timeoutAfter: 5.0, withHandler: {
                SVProgressHUD.showError(withStatus: "Connection Failed.")
                // TODO: Add UIAlertController to reconnect and show failure.
            })
            socket.joinNamespace("/proxichat_namespace")
            
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        } else {
            // Update last saved location here
            updateTableWithGroups(UserDefaults.standard.object(forKey: "proxichatLastGroupUpdate")!)
        }
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        // Update array of GroupCell objects to display on uitableview
        socket.on("update_location_and_get_groups_response", callback: { (data, ack) in
            UserDefaults.standard.set(data[0], forKey: "proxichatLastGroupUpdate")
            UserDefaults.standard.synchronize()
            
            self.updateTableWithGroups(data[0])
        })
        // Join private group response
        socket.on("join_private_group_response") { (data, ack) in
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
        socket.on("join_success") { (data, ack) in
            self.socket.emit("go_online", self.username)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UITableView Methods
    
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
                self.socket.emit("join_private_group", [
                    "id": self.groupArray[indexPath.row].id,
                    "passwordEntered": alert.textFields?.first?.text!,
                    "rowIndex": String(indexPath.row)
                    ])
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
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
    
    // MARK: CLLocationManager Methods
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            // If the current location (timestamps are the same)
            if String(describing: Date()) == String(describing: location.timestamp) {
                socket.emit("update_location_and_get_groups", [
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "username": username,
                    "radius": 800000
                    ])
            }
        }
    }
    
    // TODO: Change this later
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
        SVProgressHUD.showError(withStatus: "Location unavailable. Check your internet connection.")
    }
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "joinGroup" {
            let destinationVC = segue.destination as! MessageViewController
            destinationVC.groupInformation = selectedGroup
            destinationVC.socket = socket
            destinationVC.username = username
        }
    }
    
    // MARK: Miscellaneous Methods
    /// Take JSON data and update UITableView
    func updateTableWithGroups(_ data: Any) {
        let success = JSON(data)["success"].boolValue
        let groups = JSON(data)["data"].arrayValue // Array of groups
        self.groupArray = [Group]()
        
        // If getting data was successful
        if success {
            for group in groups {
                let groupObj = Group()
                
                groupObj.coordinates = group["coordinates"].stringValue
                groupObj.creator = group["created_by"].stringValue
                groupObj.dateCreated = group["date_created"].stringValue
                groupObj.description = group["description"].stringValue
                groupObj.id = group["id"].stringValue
                groupObj.is_public = group["is_public"].boolValue
                groupObj.numMembers = group["num_members"].intValue
                groupObj.password = group["password"].stringValue
                groupObj.title = group["title"].stringValue
                
                self.groupArray.append(groupObj)
            }
            self.groupsTableView.reloadData() // cellforRowAt
            self.stopEverything()
        } else {
            SVProgressHUD.showError(withStatus: "There was a problem getting groups. Please try again.")
            self.stopEverything()
        }
    }
    func stopEverything() {
        refreshControl.endRefreshing()
        locationManager.stopUpdatingLocation()
    }
    
    /// Refresh groups in proximity
    @objc func refreshGroups(_ sender: AnyObject) {
        locationManager.startUpdatingLocation()
    }
    
    /// Selects group, and performs segue to MessageViewController
    func joinGroup(_ row: Int) {
        selectedGroup = groupArray[row]
        if justStarted {
            slideLeftTransition()
            UIView.setAnimationsEnabled(false)
            performSegue(withIdentifier: "joinGroup", sender: self)
        } else {
            delegate?.joinGroup(selectedGroup.id)
            slideLeftTransition()
            UIView.setAnimationsEnabled(false)
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func slideLeftTransition() {
        let transition = CATransition()
        transition.duration = 0.5
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromRight
        self.view.window?.layer.add(transition, forKey: nil)
    }
}
