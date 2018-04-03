//
//  StarredGroupsViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/5/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SwiftyJSON
import SVProgressHUD
import Firebase

// TODO: ADD SEARCH BAR

class StarredGroupsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: Private Access
    private var groupArray: [Group] = [Group]()
    private var selectedGroup: Group!
    
    // MARK: Public Access
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
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        infoViewLabel.font = Font.getFont(Font.infoViewFontSize)
        
        // Initialize navigation menu layout and gestures
        _ = NavigationSideMenu.init(self)
        
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        
        // Initialize table view
        starredGroupsTableView.delegate = self
        starredGroupsTableView.dataSource = self
        starredGroupsTableView.register(UINib.init(nibName: "GroupCell", bundle: nil), forCellReuseIdentifier: "groupCell")
        
        SVProgressHUD.show()
        
        // Get groups you're in
        let groupsDB = Database.database().reference().child(FirebaseNames.groups)
        groupsDB.observeSingleEvent(of: .value) { (snapshot) in
            // Get all groups as FIR database snapshots
            guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                SVProgressHUD.showError(withStatus: "There was a problem getting your groups. Please try again.")
                SVProgressHUD.dismiss()
                return
            }
            
            // Iterate through groups to find which ones the current user is in
            for child in children {
                let group = JSON(child.value!)
                let groupInfo = group["information"]
                let groupMembers = group["members"]
                
                if groupMembers[UserData.username] != JSON.null {
                    let groupObj = Group.init(groupInfo["title"].string, groupInfo["num_online"].int, groupInfo["is_public"].bool, groupInfo["password"].string, groupInfo["creator"].string, groupInfo["latitude"].double, groupInfo["longitude"].double, groupInfo["date_created"].string, groupInfo["image"].string, groupMembers.dictionaryObject)
                    self.groupArray.append(groupObj)
                }
            }
            
            DispatchQueue.main.async {
                self.starredGroupsTableView.reloadData()
                SVProgressHUD.dismiss()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
        cell.numberOfMembers.text = String(groupArray[indexPath.row].members.count)
        
        return cell
    }
    
    // MARK: IBOutlet Actions
    @IBAction func createGroup(_ sender: Any) {
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
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
        // Make new message view controller
        if segue.identifier != "joinGroupStarred" && segue.identifier != "createGroupStarred" {
            UserData.createNewMessageViewController = true
        }
        
        if segue.identifier == "joinGroupStarred" {
            let destinationVC = segue.destination as! MessageViewController
            destinationVC.groupInformation = selectedGroup
            destinationVC.fromViewController = 1
        } else if segue.identifier == "createGroupStarred" {
            let destinationVC = segue.destination as! CreateGroupViewController
            destinationVC.starredGroupsObj = self // MessageView - handle which screen to go back to
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
