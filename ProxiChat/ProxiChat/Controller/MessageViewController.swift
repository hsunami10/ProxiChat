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
 - dragging to hide keyboard
 - display images (find how to show images uploaded from phone - url? path?)
 - figure out what to do with starred joining and leaving
 - when terminating app, request from database, if no results, then send leave group event
 - contentoffset and contentinset - https://fizzbuzzer.com/understanding-the-contentoffset-and-contentinset-properties-of-the-uiscrollview-class/
 
 BUGS
 - scrolling changes contentOffset
 - look at print outs and fix this problem - setting contentOffset after messages are sent, and keyboard is hidden
 - sending a message when keyboard is down vs up is different - down is more smooth, up is more rough?
 - fix moving table view etc when contentSize changes
 - when a message is sent, the keyboard doesn't reset back to default size (startingContentHeight)
    - shift uitableview accordingly to this shrink
 - table view scrolls down when going from scrolling table view to non scrolling - text view stays on scroll to bottom, so either scroll to top or disable scroll to bottom
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
    var lastContentHeight: CGFloat = 0
    var isMessageSent = false // Tag for whether or not a message has been sent - don't hide keyboard on message send
    var firstLoad = true
    var isScrollBottom = false
    
    // Storing values for responsive layout
    var heightTypingView: CGFloat = 0 // Starting height of typing view - Only change in viewDidLoad
    var startingContentHeight: CGFloat = 0 // Only change in viewDidLoad
    var maxContentHeight: CGFloat = 0 // Max height of text view, Only change in viewDidLoad
    var heightMessageView: CGFloat = 0 // Starting height of message view
    var heightMessageTableView: CGFloat = 0 // Starting height of message table view
    var cellHeightDict: [Int : CGFloat] = [:] // Stores actual cell heights
    
    // Constants
    let maxLines = 5 // 5 lines - max number of text view lines
    let placeholder = "Enter a message..."
    let placeholderColor: UIColor = UIColor.lightGray
    let groupInfoRatio: CGFloat = 0.66 // Proportion of the screeen the group info view takes up
    let paddingTextView = Dimensions.getPoints(10) // Top and bottom padding of text view
    
    @IBOutlet var groupTitle: UILabel!
    @IBOutlet var sendButton: UIButton!
    @IBOutlet var dimView: UIView!
    
    @IBOutlet var messageTableView: UITableView!
    @IBOutlet var messageTableViewHeight: NSLayoutConstraint!
    
    @IBOutlet var messageTextView: UITextView!
    
    @IBOutlet var messageView: UIView!
    @IBOutlet var messageViewHeight: NSLayoutConstraint!
    
    @IBOutlet var infoView: UIView!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    
    @IBOutlet var typingView: UIView!
    @IBOutlet var typingViewHeight: NSLayoutConstraint!
    
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
        
        // Add an observer to track whenever the contentSize has changed
        messageTextView.addObserver(self, forKeyPath: "contentSize", options: NSKeyValueObservingOptions.new, context: nil)
        
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
        
        initializeLayout()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        messageTableView.scrollToBottom(messageArray, false)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        messageTextView.removeObserver(self, forKeyPath: "contentSize")
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
            let messageObj = self.createMessageObj(JSON(data[0])["author"].stringValue, JSON(data[0])["content"].stringValue, JSON(data[0])["date_sent"].stringValue, JSON(data[0])["id"].stringValue, JSON(data[0])["group_id"].stringValue, JSON(data[0])["picture"].stringValue)
            
            self.messageArray.append(messageObj)
            self.insertMessage()
            
            // If you're at the bottom, scroll (stay at bottom)
            if self.messageTableView.isAtBottom {
                self.messageTableView.scrollToBottom(self.messageArray, true)
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
                    let messageObj = self.createMessageObj(message["author"].stringValue, message["content"].stringValue, message["date_sent"].stringValue, message["group_id"].stringValue, message["id"].stringValue, message["picture"].stringValue)
                    self.messageArray.append(messageObj)
                }
                self.messageTableView.reloadData()
                
                // Join room after you get messages
                self.socket?.emit("join_room", [
                    "group_id": self.groupInformation.id,
                    "username": UserData.username
                    ])
                self.messageTableView.scrollToBottom(self.messageArray, false)
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
        
        // Reset everything
        isMessageSent = false
        messageTextView.resignFirstResponder()
        
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
            
            let mID = String(describing: UUID())
            let date = String(describing: Date())
            // TODO: *** Get picture ***
            socket?.emit("send_message", [
                "username": UserData.username,
                "content": messageTextView.text!,
                "date_sent": date,
                "group_id": groupInformation.id,
                "id": mID,
                "picture": ""
                ])
            
            // Sent message to yourself
            let messageObj = createMessageObj(UserData.username, messageTextView.text!, date, groupInformation.id, mID, "")
            messageArray.append(messageObj)
            
            DispatchQueue.main.async {
                self.insertMessage()
                self.messageTableView.scrollToBottom(self.messageArray, true)
            }
            
            // Reset
            messageTextView.isEditable = true
            sendButton.isEnabled = true
            messageTextView.text = placeholder
            messageTextView.textColor = UIColor.lightGray
            
            if messageViewHeight.constant != heightMessageView {
                messageTextView.becomeFirstResponder()
            }
            
            lastLines = 1
            lastContentHeight = startingContentHeight
            contentNotSent.removeValue(forKey: groupInformation.id)
        }
    }
    
    // MARK: UITableView Delegate and DataSource Methods
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cellHeightDict[indexPath.row] = cell.frame.size.height
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if let height = cellHeightDict[indexPath.row] {
            return height
        } else {
            return UITableViewAutomaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let height = cellHeightDict[indexPath.row] {
            return height
        } else {
            return UITableViewAutomaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView.restorationIdentifier == "message" {
            return messageArray.count
        } else {
            return groupInfoArray.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView.restorationIdentifier! == "message" && indexPath.row < messageArray.count {
            // TODO: Add date later
            let cell = messageTableView.dequeueReusableCell(withIdentifier: "messageCell", for: indexPath) as! MessageCell
            cell.content.text = messageArray[indexPath.row].content // TODO: BUG - (index out of range?)
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
        // Change spaces and empty text to placeholder
        if Validate.isInvalidInput(textView.text!) {
            textView.text = placeholder
            textView.textColor = placeholderColor
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        // If not empty text, then save the text left over in text view
        if textView.text!.count == 0 {
            contentNotSent.removeValue(forKey: groupInformation.id)
        } else {
            contentNotSent[groupInformation.id] = textView.text!
        }
    }
    
    // MARK: Scrolling Methods
    // Check whether scrolled to bottom or not
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        isScrollBottom = scrollView.isAtBottom
    }
    
    // MARK: JoinGroupDelegate Methods
    func joinGroup(_ group: Group) {
        UIView.setAnimationsEnabled(true)
        
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
            // Only show keyboard if it's NOT shown
            if messageViewHeight.constant == heightMessageView {
                
                // Get keyboard animation duration
                let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
                
                // Get keyboard height
                let keyboardHeight: CGFloat = ((userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)!
                
                let changeInHeight = getHeightChange()
                
                UIView.animate(withDuration: duration) {
                    /*
                     2018-03-15 23:12:34.860010-0500 ProxiChat[11441:433028] [Snapshotting] Snapshotting a view (0x7fc0c844a840, UIInputSetHostView)
                     that has not been rendered at least once requires afterScreenUpdates:YES.
                     */
                    
                    /*
                     Handle 3 cases
                     Case 1 - Don't shift table view up (no scrolling)
                     Case 2 - Shift up table view and keyboard TOGETHER (scrolling even when keyboard is hidden)
                     Case 3 - Like 2, but NOT together (keyboard showing will block messages)
                     */
                    
                    // Empty space
                    let leftOverSpace = self.messageTableViewHeight.constant - self.messageTableView.contentSize.height
                    
                    // If content isn't overflowing
                    if leftOverSpace > 0 {
                        if leftOverSpace < keyboardHeight + self.heightTypingView + changeInHeight {
                            let diffY = keyboardHeight + self.heightTypingView + changeInHeight - leftOverSpace
                            self.messageViewHeight.constant -= keyboardHeight
                            self.messageTableViewHeight.constant -= keyboardHeight
                            self.messageTableView.contentOffset.y += diffY
                        } else {
                            self.messageViewHeight.constant -= keyboardHeight
                        }
                    } else {
                        self.messageViewHeight.constant -= (keyboardHeight + changeInHeight)
                        self.messageTableViewHeight.constant -= (keyboardHeight + changeInHeight)
                        self.messageTableView.contentOffset.y += keyboardHeight + changeInHeight
                    }
                    
                    self.typingViewHeight.constant += changeInHeight
                    self.view.layoutIfNeeded()
                }
            }
            isMessageSent = false
        }
    }
    
    @objc func keyboardWillHide(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo {
            // Only move views down if a message is not sent
            if !isMessageSent {
                let keyboardHeight: CGFloat = ((userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)!
                let changeInHeight = getHeightChange()
                let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
                
                UIView.animate(withDuration: duration) {
                    // Reset to starting values
                    self.messageViewHeight.constant = self.heightMessageView
                    self.messageTableViewHeight.constant = self.heightMessageTableView
                    self.messageTableView.contentOffset.y -= (keyboardHeight + changeInHeight)
                    self.typingViewHeight.constant = self.heightTypingView
                    self.view.layoutIfNeeded()
                }
            }
        }
    }
    
    // MARK: Observers
    // Respond to contentSize change in messageTextView
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // Safe unwrapping
        if object is UITextView, let textView = object as? UITextView {
            let lines = textView.contentSize.height / (textView.font?.lineHeight)! // Float
            let wholeLines = Int(floorf(Float(lines))) // Whole number
            
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
                
                // TODO: Table view height and bottom constraint responsiveness when contentSize of textView changes
                UIView.animate(withDuration: Durations.textViewHeightDuration, animations: {
                    // If overflow, then only move the table view up accordingly
                    if self.messageTableViewHeight.constant < self.messageTableView.contentSize.height {
                        self.messageTableViewHeight.constant -= changeInHeight
                    }
                    
                    self.typingViewHeight.constant += changeInHeight
                    self.view.layoutIfNeeded()
                })
                
                lastLines = wholeLines
                lastContentHeight = textView.contentSize.height
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
        firstLoad = true
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
        typingViewHeight.constant = startingContentHeight + paddingTextView * 2 // Relative to text view starting content size + 10 padding top + 10 padding bottom
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight)
        messageViewHeight.constant = Dimensions.safeAreaHeight - infoViewHeight.constant
        messageTableViewHeight.constant = messageViewHeight.constant - typingViewHeight.constant
        
        // Store starter dimensions / layout values
        heightTypingView = typingViewHeight.constant
        heightMessageView = messageViewHeight.constant
        heightMessageTableView = messageTableViewHeight.constant
        
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
    
    /// Gets the change in height of the text view relative to one line of text.
    func getHeightChange() -> CGFloat {
        // Get the number of lines to calculate the height of the typing view
        var numLines = floorf(Float(messageTextView.contentSize.height / (messageTextView.font?.lineHeight)!))
        if Int(numLines) >= maxLines { // Don't go over the max number of lines
            numLines = Float(maxLines)
        }
        // Height to change starting from the default 1 line text view height - in case there are multiple lines of text
        let changeInHeight = CGFloat(floorf(Float((messageTextView.font?.lineHeight)!)) * (numLines - 1))
        return changeInHeight
    }
    
    /**
     Creates a message object with the specified properties and returns it.
     
     - returns:
        A message object with the specified properties.
    
     - parameters:
        - author: The author of the message.
        - content: The content of the message.
        - dateSent: The date the message was sent.
        - groupID: The id of the group this message was sent in.
        - id: The UUID of this message (unique).
        - picture: The profile picture of the author.
     */
    func createMessageObj(_ author: String, _ content: String, _ dateSent: String, _ groupID: String, _ id: String, _ picture: String) -> Message {
        let messageObj = Message()
        messageObj.author = author
        messageObj.content = content
        messageObj.dateSent = dateSent
        messageObj.groupID = groupID
        messageObj.id = id
        messageObj.picture = picture
        return messageObj
    }
    
    /// Adds a row to the messageTableView at the bottom.
    func insertMessage() {
        let indexPath = IndexPath(row: messageArray.count-1, section: 0)
        UIView.setAnimationsEnabled(false)
        messageTableView.beginUpdates()
        messageTableView.insertRows(at: [indexPath], with: UITableViewRowAnimation.none)
        messageTableView.endUpdates()
        UIView.setAnimationsEnabled(true)
    }
}
