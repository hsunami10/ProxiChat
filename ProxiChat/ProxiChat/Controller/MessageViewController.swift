//
//  MessageViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/18/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO
import SwiftyJSON
import SVProgressHUD
import SwiftDate

/*
 TODO: TODO / BUGS
 - paginate - add UIRefreshControl to message table view & paginate PostgreSQL
 - display images (find how to show images uploaded from phone - url? path?)
 - figure out what to do with starred joining and leaving
 - when terminating app, request from database, if no results, then send leave group event
 
 BUGS
 - keyboard hiding when send button is pressed - find out how to force keyboard to stop hiding
 - on keyboard show, when table view is "shifted up", can't scroll to top messages
    - maybe shift up by x and shrink table view height by x?
 - table view scrolls down when going from scrolling table view to non scrolling - text view stays on scroll to bottom, so either scroll to top or disable scroll to bottom
 - text view changing height doesn't perfectly shift, some overscrolling - try to VERTICALLY CENTER text, or change height/2 top and bottom, not only one side, because changing the height on one side makes it unbalanced
 - table view scrolls when the message view as a whole is shifted up -> ***** IMPORTANT NEED TO FIX ASAP ***** - NO IDEA WHY
 - Fix scrolling when sending / receiving messages - doesn't work for Case 1 & 3
    - if you're the sender, scroll to bottom including last message
    - if you're not the sender
        - on bottom, then scroll to bottom including last message
        - not on bottom, then don't scroll at all
 */

/// Holds the text left over in a certain conversation whenever the user goes back to the groups page. [group_id : text view content]
var contentNotSent: [String : String] = [:]

class MessageViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, JoinGroupDelegate {
    
    /// Keeps track of which groups view controller to go back to. 0 -- GroupsViewController, 1 -- StarredGroupsViewController.
    var fromViewController = -1
    var groupInformation: Group!
    var socket: SocketIOClient?
    var messageArray: [Message] = [Message]()
    var groupInfoArray = ["# Online", "# Stars", "Settings or View Creator Profile"] // If this is changed, cmd+f "CHANGE INDICES" or "CHANGE STRING"
    var lastLines = 1 // Saves the last number of lines
    let maxLines = 5 // 5 lines - max number of text view lines
    let placeholder = "Enter a message..."
    let placeholderColor: UIColor = UIColor.lightGray
    var typingHeight: CGFloat = 0 // Starting height of typing view - Only change in viewDidLoad
    let paddingTextView = Dimensions.getPoints(10) // Top and bottom padding of text view
    var startingContentHeight: CGFloat = 0 // Only change in viewDidLoad
    var lastContentHeight: CGFloat = 0
    var maxContentHeight: CGFloat = 0 // Max height of text view, Only change in viewDidLoad
    var isMessageSent = false // Tag for whether or not a message has been sent - don't hide keyboard on message send
    let groupInfoRatio: CGFloat = 0.66 // Proportion of the screeen the group info view takes up
    
    @IBOutlet var groupTitle: UILabel!
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var dimView: UIView!
    @IBOutlet var coverStatusViewHeight: NSLayoutConstraint!
    
    @IBOutlet var messageTableView: UITableView!
    @IBOutlet var messageTableViewBottomConstraint: NSLayoutConstraint! // Same as typing view height
    @IBOutlet var messageTableViewHeight: NSLayoutConstraint!
    
    @IBOutlet var messageTextView: UITextView!
    
    @IBOutlet var messageView: UIView!
    @IBOutlet var messageViewHeight: NSLayoutConstraint!
    @IBOutlet var messageViewBottomConstraint: NSLayoutConstraint! // Changed only when the table view content is overflowing
    
    @IBOutlet var infoView: UIView!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    
    @IBOutlet var typingView: UIView!
    @IBOutlet var typingViewHeight: NSLayoutConstraint!
    @IBOutlet var typingViewBottomConstraint: NSLayoutConstraint! // Changed only when table view content is not overflowing
    
    @IBOutlet var groupInfoViewWidth: NSLayoutConstraint!
    @IBOutlet var groupInfoViewRightConstraint: NSLayoutConstraint!
    @IBOutlet var groupInfoTableView: UITableView!
    @IBOutlet var groupInfoTableViewHeight: NSLayoutConstraint!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var groupImageView: UIImageView!
    @IBOutlet var groupImageViewWidth: NSLayoutConstraint!
    @IBOutlet var creatorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        groupTitle.text = groupInformation.title
        eventHandlers()
        
        messageTableView.delegate = self
        messageTableView.dataSource = self
        messageTextView.delegate = self
        groupInfoTableView.delegate = self
        groupInfoTableView.dataSource = self
        
        // Set up action on keyboard show and hide
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        // Initialize gestures
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tableViewTapped))
        messageTableView.addGestureRecognizer(tapGesture)
        let dimTap = UITapGestureRecognizer(target: self, action: #selector(closeGroupInfo))
        dimView.addGestureRecognizer(dimTap)
        
        // Register nibs
        messageTableView.register(UINib.init(nibName: "MessageCell", bundle: nil), forCellReuseIdentifier: "messageCell")
        groupInfoTableView.register(UINib.init(nibName: "GroupInfoCell", bundle: nil), forCellReuseIdentifier: "groupInfoCell")
        messageTableView.separatorStyle = .none
        
        messageTextView.keyboardType = .alphabet
        messageTextView.isScrollEnabled = true
        messageTextView.alwaysBounceVertical = false
        
        // Initialize group info view content
        initializeGroupInfo()
        groupImageViewWidth.constant = groupInfoViewWidth.constant - Dimensions.getPoints(32) // 16 margins on left and right side
        
        // Get messages - on response, join room
        // TODO: Paginate messages
        socket?.emit("get_messages_on_start", groupInformation.id)
        configureTableView()

        initializeLayout()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        // Receive number of people online whenever someone joins or leaves
        socket?.on("group_stats", callback: { (data, ack) in
            // CHANGE INDICES
            self.groupInfoArray[0] = String(JSON(data[0])["number_online"].intValue) + " Online"
            let indexPath = IndexPath(row: 0, section: 0)
            self.groupInfoTableView.reloadRows(at: [indexPath], with: .automatic)
        })
        // Realtime receiving messages
        socket?.on("receive_message") { (data, ack) in
            let messageObj = Message()
            
            messageObj.author = JSON(data[0])["author"].stringValue
            messageObj.content = JSON(data[0])["content"].stringValue
            messageObj.dateSent = JSON(data[0])["date_sent"].stringValue
            messageObj.id = JSON(data[0])["id"].stringValue
            messageObj.groupID = JSON(data[0])["group_id"].stringValue
            messageObj.picture = JSON(data[0])["picture"].stringValue
            
            self.messageArray.append(messageObj)
            
            self.configureTableView()
            self.messageTableView.reloadData()
            
            // If you are the sender
            // TODO: If you're at the bottom, scroll
            if messageObj.author == UserData.username {
                self.scrollToBottom()
            }
        }
        
        // Get messages from database on join room
        socket?.on("get_messages_on_start_response") { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            let messages = JSON(data[0])["messages"].arrayValue
            UIView.setAnimationsEnabled(true)
            
            if success {
                for message in messages {
                    let messageObj = Message()
                    
                    messageObj.author = message["author"].stringValue
                    messageObj.content = message["content"].stringValue
                    messageObj.dateSent = message["date_sent"].stringValue
                    messageObj.groupID = message["group_id"].stringValue
                    messageObj.id = message["id"].stringValue
                    messageObj.picture = message["picture"].stringValue
                    
                    self.messageArray.append(messageObj)
                }
                self.configureTableView()
                self.messageTableView.reloadData()
                
                // Join room after you get messages
                self.socket?.emit("join_room", [
                    "group_id": self.groupInformation.id,
                    "username": UserData.username
                    ])
                self.scrollToBottom()
            } else {
                SVProgressHUD.showError(withStatus: error_msg)
            }
        }
    }
    
    // MARK: IBOutlet Actions
    @IBAction func goBack(_ sender: Any) {
        slideRightTransition()
        
        // Check which view controller it came from
        switch fromViewController {
        case 0:
            performSegue(withIdentifier: "goBackToGroups", sender: self)
            break
        case 1:
            performSegue(withIdentifier: "goBackToStarredGroups", sender: self)
            break
        default:
            break
        }
        
        socket?.emit("leave_room", [
            "group_id": groupInformation.id,
            "username": UserData.username
            ])
    }
    
    @IBAction func showGroupInfo(_ sender: Any) {
        dimView.isUserInteractionEnabled = true
        
        UIView.animate(withDuration: Durations.showGroupInfoDuration) {
            self.dimView.alpha = 0.5
            self.groupInfoViewRightConstraint.constant = 0
            self.view.layoutIfNeeded()
        }
    }
    
    // TODO: Don't hide keyboard on send
    @IBAction func sendPressed(_ sender: Any) {
        if !Validate.isInvalidInput(messageTextView.text!) && messageTextView.textColor != UIColor.lightGray {
            isMessageSent = true
            messageTextView.isEditable = false
            sendButton.isEnabled = false
            
            // TODO: *** Get picture ***
            socket?.emit("send_message", [
                "username": UserData.username,
                "content": messageTextView.text!,
                "date_sent": String(describing: Date()),
                "group_id": groupInformation.id,
                "id": String(describing: UUID()),
                "picture": ""
                ])
            
            // Reset
            messageTextView.isEditable = true
            sendButton.isEnabled = true
            messageTextView.text = placeholder
            messageTextView.textColor = UIColor.lightGray
            lastLines = 1
            lastContentHeight = startingContentHeight
            contentNotSent.removeValue(forKey: groupInformation.id)
        }
    }
    
    // MARK: UITableView Delegate and DataSource Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView.restorationIdentifier == "message" {
            return messageArray.count
        } else {
            return groupInfoArray.count
        }
    }
    
    /*
     2 types of cells:
        - Message
        - Group Info
    */
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView.restorationIdentifier! == "message" {
            // TODO: Add date later
            let cell = messageTableView.dequeueReusableCell(withIdentifier: "messageCell", for: indexPath) as! MessageCell
            cell.content.text = messageArray[indexPath.row].content // TODO: BUG - happens rarely (index out of bounds?)
            cell.username.text = messageArray[indexPath.row].author
            
            if messageArray[indexPath.row].picture == "" {
                cell.userPicture.image = UIImage(named: "noPicture")
            } else {
                cell.userPicture.image = UIImage(named: messageArray[indexPath.row].picture)
            }
            return cell
        } else {
            let cell = groupInfoTableView.dequeueReusableCell(withIdentifier: "groupInfoCell", for: indexPath) as! GroupInfoCell
            // TODO: Change image
            cell.descriptionLabel.text = groupInfoArray[indexPath.row]
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.restorationIdentifier == "message" {
            messageTableView.deselectRow(at: indexPath, animated: true)
        } else {
            // CHANGE STRING
            if groupInfoArray[indexPath.row].contains("Star") || groupInfoArray[indexPath.row].contains("Online") {
                performSegue(withIdentifier: "goToMembers", sender: self)
            }
            groupInfoTableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    // MARK: UITextViewDelegate Methods
    func textViewDidBeginEditing(_ textView: UITextView) {
        // Change placeholder to actual text
        if textView.textColor == placeholderColor {
            textView.text = ""
            textView.textColor = UIColor.black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        print("end editing")
        // Change spaces and empty text to placeholder
        if Validate.isInvalidInput(textView.text!) {
            textView.text = placeholder
            textView.textColor = placeholderColor
        }
    }
    
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        print("textViewShouldEndEditing: \(!isMessageSent)")
        textView.becomeFirstResponder()
        return !isMessageSent
    }
    
    // TODO: BUG - Text is not vertically centered? - FIX THIS
    func textViewDidChange(_ textView: UITextView) {
        let lines = textView.contentSize.height / (textView.font?.lineHeight)! // Float
        let wholeLines = Int(floorf(Float(lines))) // Whole number
        
        // Check to see whether or not the number of lines changed
        if wholeLines != lastLines {
            // If adding text and greator than the max number of lines, then don't change the height
            if lastLines < maxLines || wholeLines < maxLines {
                // Get the change in height
                var changeInHeight: CGFloat = 0
                if wholeLines >= maxLines {
                    changeInHeight = maxContentHeight - lastContentHeight
                } else {
                    changeInHeight = textView.contentSize.height - lastContentHeight
                }
                
                if !UIView.areAnimationsEnabled {
                    UIView.setAnimationsEnabled(true)
                }
                
                UIView.animate(withDuration: Durations.textViewHeightDuration, animations: {
                    // If no overflow, then only move the table view up accordingly
                    if self.messageTableViewHeight.constant < self.messageTableView.contentSize.height {
                        self.messageTableViewBottomConstraint.constant = self.messageTableViewBottomConstraint.constant + CGFloat(changeInHeight)
                    }
                    
                    self.typingViewHeight.constant = self.typingViewHeight.constant + CGFloat(changeInHeight)
                    print("typingview height: \(self.typingViewHeight.constant)")
                    print("change in height: \(changeInHeight)")
                    self.view.layoutIfNeeded()
                })
                
                lastLines = wholeLines
                lastContentHeight = textView.contentSize.height
            }
        }
        
        // If not empty text, then save the text left over in text view
        if textView.text!.count == 0 {
            contentNotSent.removeValue(forKey: groupInformation.id)
        } else {
            contentNotSent[groupInformation.id] = textView.text!
        }
    }
    
    // MARK: Scrolling Methods
    func scrollToBottom() {
        if(needToScroll()) {
            let path = NSIndexPath(row: messageArray.count-1, section: 0)
            messageTableView.scrollToRow(at: path as IndexPath, at: .bottom, animated: true)
        } else {
            // TODO: "Scroll" to top - take no messages into account
            // TODO: BUG - when switching from need to scroll to don't need to scroll message views
        }
    }
    
    /// Is the table view scrolled to the bottom or no?
    // NOTE: This doesn't work
    func didScrollToBottom() -> Bool {
        let distanceFromBottom = messageTableView.contentSize.height - messageTableView.contentOffset.y
        return distanceFromBottom <= messageTableView.frame.size.height
    }
    
    /// Do you need to scroll or no?
    func needToScroll() -> Bool {
        return messageTableView.contentSize.height > messageTableView.frame.size.height
    }
    
    // MARK: JoinGroupDelegate Methods
    func joinGroup(_ group: Group) {
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        
        // TODO: Check if the content is scrollable, if it isn't then scroll to top
        messageArray = [Message]()
        groupInformation = group
        groupTitle.text = group.title
        lastLines = 1
        
        initializeGroupInfo()
        initializeLayout()
        
        socket?.emit("get_messages_on_start", group.id)
    }
    
    // MARK: Keyboard (NotificationCenter) Methods
    @objc func keyboardWillShow(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo {
            // Get keyboard animation duration
            let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            
            // Get keyboard height
            let keyboardHeight: CGFloat = ((userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)!
            
            // Get the number of lines to calculate the height of the typing view
            var numLines = floorf(Float(messageTextView.contentSize.height / (messageTextView.font?.lineHeight)!))
            if Int(numLines) >= maxLines { // Don't go over the max number of lines
                numLines = Float(maxLines)
            }
            // Height to change starting from the default 1 line text view height
            let changeInHeight = CGFloat(floorf(Float((messageTextView.font?.lineHeight)!)) * (numLines - 1))
            
            UIView.animate(withDuration: duration) {
                /*
                 Handle 3 cases
                    Case 1 - Don't shift table view up (no scrolling)
                    Case 2 - Shift up table view and keyboard TOGETHER (scrolling even when keyboard is hidden)
                    Case 3 - Like 2, but NOT together (keyboard showing will block messages)
                 */
                let leftOverSpace = self.messageTableViewHeight.constant - self.messageTableView.contentSize.height
                
                if leftOverSpace > 0 {
                    if leftOverSpace < keyboardHeight + self.typingHeight {
                        // TODO: BUG - This isn't accurate - it matches up, but sometimes the table view shifts down???
                        // Check hello!!! 4:28 VS. greetings: 4:28 again
                        self.messageTableViewBottomConstraint.constant = self.messageTableViewBottomConstraint.constant + (keyboardHeight - leftOverSpace)
                        self.typingViewBottomConstraint.constant = keyboardHeight
                    } else {
                        self.typingViewBottomConstraint.constant = keyboardHeight
                    }
                } else {
                    self.messageViewBottomConstraint.constant = keyboardHeight
                }
                self.typingViewHeight.constant = self.typingViewHeight.constant + changeInHeight
                self.messageTableViewBottomConstraint.constant = self.messageTableViewBottomConstraint.constant + changeInHeight
                self.isMessageSent = false
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc func keyboardWillHide(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo {
            if !isMessageSent {
                let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
                UIView.animate(withDuration: duration) {
                    self.messageViewBottomConstraint.constant = 0
                    self.typingViewBottomConstraint.constant = 0
                    self.typingViewHeight.constant = self.typingHeight
                    self.messageTableViewBottomConstraint.constant = self.typingViewHeight.constant
                    self.view.layoutIfNeeded()
                }
            } else {
                messageTextView.becomeFirstResponder()
            }
        }
    }
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goBackToGroups" {
            let destinationVC = segue.destination as! GroupsViewController
            destinationVC.delegate = self
            destinationVC.socket = socket
            destinationVC.username = UserData.username
            destinationVC.messageObj = self // If the user navigates to any other view controller, then set the socket = nil
            UserData.createNewMessageViewController = false
        } else if segue.identifier == "goBackToStarredGroups" {
            let destinationVC = segue.destination as! StarredGroupsViewController
            destinationVC.delegate = self
            destinationVC.socket = socket
            destinationVC.messageObj = self // If the user navigates to any other view controller, then set the socket = nil
            UserData.createNewMessageViewController = false
        } else if segue.identifier == "goToMembers" {
            let destinationVC = segue.destination as! MembersViewController
            destinationVC.socket = socket
            // TODO: Finish this later if needed
        }
    }
    
    // MARK: Miscellaneous Methods
    func initializeLayout() {
        messageTextView.text = " " // Used to store default height of 1 line (startingContentHeight)
        startingContentHeight = messageTextView.contentSize.height
        lastContentHeight = startingContentHeight
        maxContentHeight = CGFloat(floorf(Float(startingContentHeight + (messageTextView.font?.lineHeight)! * CGFloat(maxLines - 1))))
        
        let keyExists = contentNotSent[groupInformation.id] != nil
        if !keyExists {
            messageTextView.text = placeholder
            messageTextView.textColor = placeholderColor
        } else {
            messageTextView.text = contentNotSent[groupInformation.id]
            messageTextView.textColor = UIColor.black
        }
        
        // Responsive layout
        coverStatusViewHeight.constant = UIApplication.shared.statusBarFrame.height
        typingHeight = startingContentHeight + paddingTextView * 2 // Relative to text view starting content size + 10 padding top + 10 padding bottom
        typingViewHeight.constant = typingHeight
        messageTableViewBottomConstraint.constant = typingViewHeight.constant
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        messageViewHeight.constant = Dimensions.safeAreaHeight - infoViewHeight.constant
        messageTableViewHeight.constant = messageViewHeight.constant - typingViewHeight.constant
        
        // Initialize group info view
        groupInfoViewWidth.constant = self.view.frame.width * groupInfoRatio
        groupInfoViewRightConstraint.constant = -groupInfoViewWidth.constant
        groupInfoTableView.rowHeight = Dimensions.getPoints(60) // Height of each row - TODO: Change row height later for better UI
        groupInfoTableViewHeight.constant = groupInfoTableView.rowHeight * CGFloat(groupInfoArray.count)
        groupInfoTableView.isScrollEnabled = false
        
        self.view.layoutIfNeeded()
    }
    
    func initializeGroupInfo() {
        // CHANGE INDICES
        // CHANGE STRING
        let cd = ConvertDate(date: groupInformation.rawDate)
        
        if groupInformation.creator == UserData.username {
            groupInfoArray[groupInfoArray.count-1] = "Settings"
        } else {
            groupInfoArray[groupInfoArray.count-1] = "View Creator Profile"
        }
        if groupInformation.numMembers == 1 {
            groupInfoArray[1] = String(groupInformation.numMembers) + " Star"
        } else {
            groupInfoArray[1] = String(groupInformation.numMembers) + " Stars"
        }
        creatorLabel.text = "Created by \(groupInformation.creator) on \(cd.convertWithFormat("MMM d, yyyy"))"
        titleLabel.text = groupInformation.title
        groupImageView.image = UIImage(named: "noPicture") // TODO: Get group picture
    }
    
    /// Edit UIViewController transition left -> right
    func slideRightTransition() {
        let transition = CATransition()
        transition.duration = Durations.messageTransitionDuration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromLeft
        self.view.window?.layer.add(transition, forKey: nil)
    }
    
    /// Change the height based on content. If estimated height is wrong, then change height based on constraints
    func configureTableView() {
        messageTableView.rowHeight = UITableViewAutomaticDimension
        messageTableView.estimatedRowHeight = 120.0
    }
    
    @objc func closeGroupInfo() {
        UIView.animate(withDuration: Durations.showGroupInfoDuration, animations: {
            self.dimView.alpha = 0
            self.groupInfoViewRightConstraint.constant = -self.groupInfoViewWidth.constant
            self.view.layoutIfNeeded()
        }) { (complete) in
            self.dimView.isUserInteractionEnabled = false
        }
    }
    
    @objc func tableViewTapped() {
        messageTextView.endEditing(true)
    }
}
