//
//  StarredGroupsViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO
import SwiftyJSON
import SVProgressHUD

// TODO: ADD SEARCH BAR

class StarredGroupsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: Instance variables
    var socket: SocketIOClient?
    var groupArray: [Group] = [Group]()
    var selectedGroup = Group()
    var delegate: JoinGroupDelegate?
    var messageObj: MessageViewController?
    
    @IBOutlet var starredGroupsViewLeftConstraint: NSLayoutConstraint!
    @IBOutlet var starredGroupsViewWidth: NSLayoutConstraint!
    @IBOutlet var starredGroupsViewHeight: NSLayoutConstraint!
    @IBOutlet var starredGroupsView: UIView!
    @IBOutlet var navigationLeftConstraint: NSLayoutConstraint!
    @IBOutlet var navigationViewWidth: NSLayoutConstraint!
    
    @IBOutlet var infoViewLabel: UILabel!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    @IBOutlet var starredGroupsTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIView.setAnimationsEnabled(true)
        infoViewLabel.font = Font.getFont(Font.infoViewFontSize)
        eventHandlers()
        
        // Initialize navigation menu layout and gestures
        _ = NavigationSideMenu.init(self)
        
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        
        // Initialize table view
        starredGroupsTableView.delegate = self
        starredGroupsTableView.dataSource = self
        starredGroupsTableView.register(UINib.init(nibName: "GroupCell", bundle: nil), forCellReuseIdentifier: "groupCell")
        
        SVProgressHUD.show()
        socket?.emit("get_starred_groups", UserData.username)
        self.view.layoutIfNeeded()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        socket?.on("get_starred_groups_response", callback: { (data, ack) in
            if JSON(data[0])["success"].boolValue {
                let groups = JSON(data[0])["groups"].arrayValue
                self.groupArray = [Group]()
                for group in groups {
                    var groupObj = Group()
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
                
                DispatchQueue.main.async {
                    self.starredGroupsTableView.reloadData()
                }
                SVProgressHUD.dismiss()
            } else {
                SVProgressHUD.dismiss()
                SVProgressHUD.showError(withStatus: JSON(data[0])["error_msg"].stringValue)
            }
        })
    }
    
    // MARK: UITableView Delegate and DataSource Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        joinGroup(indexPath.row)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groupArray.count
    }
    
    // Exactly the same as "find groups" table view
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "groupCell", for: indexPath) as! GroupCell
        
        cell.groupName.text = groupArray[indexPath.row].title
        if groupArray[indexPath.row].is_public {
            cell.lockIcon.image = UIImage()
        } else {
            cell.lockIcon.image = UIImage(named: "locked")
        }
        cell.numberOfMembers.text = String(groupArray[indexPath.row].numMembers)
        
        return cell
    }
    
    // MARK: IBOutlet Actions
    @IBAction func createGroup(_ sender: Any) {
        UIView.setAnimationsEnabled(true)
        performSegue(withIdentifier: "createGroupStarred", sender: self)
    }
    @IBAction func showNavMenu(_ sender: Any) {
        UIView.setAnimationsEnabled(true)
        if navigationLeftConstraint.constant != 0 {
            NavigationSideMenu.toggleSideNav(show: true)
        } else {
            NavigationSideMenu.toggleSideNav(show: false)
        }
    }
    @IBAction func navItemClicked(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            NavigationSideMenu.addTransition(sender: self)
            performSegue(withIdentifier: "goToGroups", sender: self)
            break
        case 1:
            NavigationSideMenu.toggleSideNav(show: false)
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
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier != "joinGroupStarred" {
            if let mObj = messageObj {
                mObj.socket?.off("group_stats")
                mObj.socket?.off("receive_message")
                mObj.socket?.off("get_messages_on_start_response")
                mObj.socket = nil
            }
        }
        if segue.identifier == "joinGroupStarred" {
            let destinationVC = segue.destination as! MessageViewController
            destinationVC.groupInformation = selectedGroup
            destinationVC.socket = socket
            destinationVC.fromViewController = 1
        } else if segue.identifier == "createGroupStarred" {
            let destinationVC = segue.destination as! CreateGroupViewController
            destinationVC.socket = socket
            destinationVC.starredGroupsObj = self // Handle socket = nil only if a group is created
        } else if segue.identifier == "goToGroups" {
            let destinationVC = segue.destination as! GroupsViewController
            destinationVC.socket = socket
            destinationVC.username = UserData.username
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
        
        if segue.identifier != "createGroupStarred" {
            socket?.off("get_starred_groups_response")
            socket = nil // Won't receive duplicate events
        }
    }
    
    func joinGroup(_ row: Int) {
        selectedGroup = groupArray[row]
        if UserData.createNewMessageViewController { // Create MessageViewController
            slideLeftTransition()
            performSegue(withIdentifier: "joinGroupStarred", sender: self)
        } else { // Pass chosen group data back to the same MessageViewController and dismiss
            delegate?.joinGroup(selectedGroup)
            slideLeftTransition()
            socket = nil // Won't receive duplicate events
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    // MARK: Miscellaneous Methods
    func slideLeftTransition() {
        let transition = CATransition()
        transition.duration = Durations.messageTransitionDuration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromRight
        self.view.window?.layer.add(transition, forKey: nil)
    }
    
    @objc func closeNavMenu() {
        if navigationLeftConstraint.constant == 0 {
            NavigationSideMenu.toggleSideNav(show: false)
        }
    }
}
