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
 - have an option for the user to choose when to update
 */

class GroupsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate {

    /// Instance variables
    var locationManager = CLLocationManager()
    var socket: SocketIOClient!
    var username: String = ""
    var refreshControl: UIRefreshControl!
    var groupArray: [Group] = [Group]()

    @IBOutlet var groupsTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        eventHandlers()
        
        // TODO: Add reconnecting later - socket.reconnect()
        socket.connect(timeoutAfter: 5.0, withHandler: {
            SVProgressHUD.showError(withStatus: "Connection Failed.")
            // TODO: Add UIAlertController to reconnect and show failure.
        })
        socket.joinNamespace("/proxichat_namespace")
        socket.emit("go_online", username)
        
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
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    // MARK: Socket event handlers
    func eventHandlers() {
        // Update array of GroupCell objects to display on uitableview
        socket.on("update_location_and_get_groups_response", callback: { (data, ack) in
            
            let success = JSON(data[0])["success"].boolValue
            let groups = JSON(data[0])["data"].arrayValue // Array of groups
            self.groupArray = [Group]()
            
            // If getting data was successful
            if success {
                for group in groups {
                    let groupObj = Group()
                    
                    // Group Info
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
        })
    }
    
    func stopEverything() {
        refreshControl.endRefreshing()
        locationManager.stopUpdatingLocation()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UITableView Methods
    
    /// Refresh groups in proximity
    @objc func refreshGroups(_ sender: AnyObject) {
        locationManager.startUpdatingLocation()
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
    func sendUpdateLocation(_ latitude: CLLocationDegrees, _ longitude: CLLocationDegrees, _ username: String, _ radius: Int) {
        socket.emit("update_location_and_get_groups", [
            "latitude": latitude,
            "longitude": longitude,
            "username": username,
            "radius": radius
            ])
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            // If the current location (timestamps are the same)
            if String(describing: Date()) == String(describing: location.timestamp) {
                sendUpdateLocation(location.coordinate.latitude, location.coordinate.longitude, username, 800000)
            }
        }
    }
    // TODO: Change this later
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
        SVProgressHUD.showError(withStatus: "Location unavailable. Check your internet connection.")
    }
}
