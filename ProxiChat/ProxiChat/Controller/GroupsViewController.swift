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

class GroupsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate {

    /// Instance variables
    let locationManager = CLLocationManager()
    var location: CLLocation!
    var socket: SocketIOClient?
    var username: String = ""
    var refreshControl: UIRefreshControl!
    var groupArray: [GroupCell] = [GroupCell]()
    var latitudeLongitudeArray: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] = []

    @IBOutlet var groupsTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Socket initialization
        if socket == nil {
            socket = SocketIOClient(socketURL: URL(string: "http://localhost:3000")!)
        }
        eventHandlers()
        
        // TODO: Add reconnecting later - socket.reconnect()
        socket?.connect(timeoutAfter: 5.0, withHandler: {
            SVProgressHUD.showError(withStatus: "Connection Failed.")
            // TODO: Add UIAlertController to reconnect and show failure.
        })
        socket?.joinNamespace("/proxichat_namespace")
        socket?.emit("go_online", username)
        
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
        locationManager.distanceFilter = 0
        locationManager.requestWhenInUseAuthorization() // Manual update, not tracking
        locationManager.startUpdatingLocation()
    }
    
    // MARK: Socket event handlers
    func eventHandlers() {
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UITableView Methods
    
    /// Refresh groups in proximity
    @objc func refreshGroups(_ sender: AnyObject) {
        print("refresh")
        locationManager.startUpdatingLocation()
    }
    
    // TODO: Return the number of groups in proximity here
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "groupCell", for: indexPath) as! GroupCell
        
        // TODO: Set values for cell here
        
        return cell
    }
    
    // MARK: CLLocationManager Methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations[locations.count-1]
        
        // BUG: Location doesn't take the latest when stopping update
        
        if location.horizontalAccuracy > 0 {
            refreshControl.endRefreshing()
            print(location.coordinate.latitude)
            print(location.coordinate.longitude)
        }
    }
    // TODO: Change this later
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
        SVProgressHUD.showError(withStatus: "Location unavailable. Check your internet connection.")
    }
}
