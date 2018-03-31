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
import Firebase

/*
 TODO
 - paginate - add UIRefreshControl to message table view & paginate PostgreSQL
 - dragging to hide keyboard
 - display images (find how to show images uploaded from phone - url? path?)
 - figure out what to do with starred joining and leaving
 - when terminating app, request from database, if no results, then send leave group event
 - maybe find a way to cache whether or not the keyboard is showing / hiding?
 
 BUGS
 - when scrolling and showing keyboard at same time, quick drop at top of messagetableview
 */

/// Holds the text left over in a certain conversation whenever the user goes back to the groups page. [group_id : text view content]
var contentNotSent: [String : String] = [:]

class MessageViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, JoinGroupDelegate {
    
    // MARK: Private Access
    private var messageArray: [Message] = [Message]()
    private var groupInfoArray = ["# Online", "# Stars", "Settings or View Creator Profile"] // If this is changed, cmd+f "CHANGE INDICES" or "CHANGE STRING"
    private var lastLines = 1 // Saves the last number of lines
    private var lastContentHeight: CGFloat = 0
    private var isMessageSent = false // Tag for whether or not a message has been sent - don't hide keyboard on message send
    private var observed = false
    
    private var lastLoadedDate = ""
    
    // Storing values for responsive layout
    private var heightTypingView: CGFloat = 0 // Starting height of typing view - Only change in viewDidLoad
    private var startingContentHeight: CGFloat = 0 // Only change in viewDidLoad
    private var maxContentHeight: CGFloat = 0 // Max height of text view, Only change in viewDidLoad
    private var heightMessageView: CGFloat = 0 // Starting height of message view
    private var heightMessageTableView: CGFloat = 0 // Starting height of message table view
    private var cellHeightDict: [Int : CGFloat] = [:] // Stores actual cell heights
    
    // Constants
    private let maxLines = 5 // 5 lines - max number of text view lines
    private let placeholder = "Enter a message..."
    private let placeholderColor: UIColor = UIColor.lightGray
    private let groupInfoRatio: CGFloat = 0.66 // Proportion of the screeen the group info view takes up
    private let paddingTextView = Dimensions.getPoints(10) // Top and bottom padding of text view
    
    // MARK: Public Access
    /// Keeps track of which groups view controller to go back to. 0 -- GroupsViewController, 1 -- StarredGroupsViewController.
    var fromViewController = -1
    var groupInformation: Group!
    var socket: SocketIOClient?
    
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
    @IBOutlet var infoViewLabel: UILabel!
    
    @IBOutlet var typingView: UIView!
    @IBOutlet var typingViewHeight: NSLayoutConstraint!
    
    @IBOutlet var groupInfoViewWidth: NSLayoutConstraint!
    @IBOutlet var groupInfoViewRightConstraint: NSLayoutConstraint!
    @IBOutlet var groupInfoTableView: UITableView!
    @IBOutlet var groupInfoTableViewHeight: NSLayoutConstraint!
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var creatorLabel: UILabel!
    
    @IBOutlet var groupImageView: UIImageView!
    @IBOutlet var groupImageViewWidth: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        groupTitle.text = groupInformation.title
        groupTitle.font = Font.getFont(Font.infoViewFontSize)
        titleLabel.font = Font.getFont(17, "\(Font.fontName)-Bold")
        creatorLabel.font = Font.getFont(17)
        messageTextView.font = Font.getFont(16)
        sendButton.titleLabel?.font = Font.getFont(15)
        
        messageTableView.delegate = self
        messageTableView.dataSource = self
        messageTextView.delegate = self
        groupInfoTableView.delegate = self
        groupInfoTableView.dataSource = self
        
        // Set up action on keyboard show and hide
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        // Add an observer to track whenever the contentSize has changed
        messageTextView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        observed = true
        
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
        initializeLayout()
        
        // Get messages
        getMessagesOnLoad()
//        retrieveMessages()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if observed {
            messageTextView.removeObserver(self, forKeyPath: "contentSize")
            observed = false
        }
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
            
            DispatchQueue.main.async {
                self.groupInfoTableView.reloadRows(at: [indexPath], with: .automatic)
            }
        })
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
        messageTextView.text = ""
        
//        socket?.emit("leave_room", [
//            "group_id": groupInformation.id,
//            "username": UserData.username
//            ])
    }
    
    @IBAction func showGroupInfo(_ sender: Any) {
        dimView.isUserInteractionEnabled = true
        messageTextView.resignFirstResponder()
        
        UIView.animate(withDuration: Durations.showGroupInfoDuration) {
            self.dimView.alpha = 0.5
            self.groupInfoViewRightConstraint.constant = 0
            self.view.layoutIfNeeded()
        }
    }
    
    @IBAction func sendPressed(_ sender: Any) {
        if !Validate.isInvalidInput(messageTextView.text!) && messageTextView.textColor != UIColor.lightGray {
            isMessageSent = true
            messageTextView.isEditable = false
            sendButton.isEnabled = false
            
            // TODO: *** Get picture ***
            
            // Store message into database
            let messagesDB = Database.database().reference().child(FirebaseNames.messages)
            messagesDB.child(groupInformation.title).childByAutoId().setValue([
                "author": UserData.username,
                "group": groupInformation.title,
                "content": messageTextView.text!,
                "date_sent": String(describing: Date()),
                "picture": UserData.picture
                ])
            
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
            contentNotSent.removeValue(forKey: groupInformation.title)
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
    
    // MARK: UITextViewDelegate Methods / UITextView
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
            contentNotSent.removeValue(forKey: groupInformation.title)
        } else {
            contentNotSent[groupInformation.title] = textView.text!
        }
    }
    
    // Respond to contentSize change in messageTextView`
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
                        self.messageTableView.contentOffset.y += changeInHeight
                    }
                    
                    self.typingViewHeight.constant += changeInHeight
                    self.view.layoutIfNeeded()
                })
                
                lastLines = wholeLines
                lastContentHeight = textView.contentSize.height
            }
        }
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
        getMessagesOnLoad()
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
                        self.messageViewHeight.constant -= keyboardHeight
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
                let leftOverSpace = heightMessageTableView - self.messageTableView.contentSize.height
                
                UIView.animate(withDuration: duration) {
                    if leftOverSpace > 0 {
                        if leftOverSpace < keyboardHeight + self.heightTypingView + changeInHeight {
                            let diffY = keyboardHeight + self.heightTypingView + changeInHeight - leftOverSpace
                            self.messageTableView.contentOffset.y -= diffY
                        }
                    } else {
                        self.messageTableView.contentOffset.y -= (keyboardHeight + changeInHeight)
                    }
                    
                    // Reset to starting values
                    self.messageViewHeight.constant = self.heightMessageView
                    self.messageTableViewHeight.constant = self.heightMessageTableView
                    self.typingViewHeight.constant = self.heightTypingView
                    self.view.layoutIfNeeded()
                }
            }
        }
    }
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Remove all observers - reset
        Database.database().reference().child(FirebaseNames.messages).child(groupInformation.title).removeAllObservers()
        
        if segue.identifier == "goBackToGroups" {
            let destinationVC = segue.destination as! GroupsViewController
            destinationVC.delegate = self
            destinationVC.socket = socket
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
    
    /// Gets all messages of a certain group on join.
    func getMessagesOnLoad() {
        let messagesDB = Database.database().reference().child(FirebaseNames.messages)
        messagesDB.child(self.groupInformation.title).queryOrdered(byChild: "date_sent").observe(.value) { (snapshot) in
            // Iterate over snapshot's children
            for child in snapshot.children.allObjects as! [DataSnapshot] {
                if child.key != "dummy" {
                    let value = JSON(child.value!)
                    let messageObj = self.createMessageObj(value["author"].stringValue, value["content"].stringValue, value["date_sent"].stringValue, value["group"].stringValue, child.key, value["picture"].stringValue)
                    self.messageArray.append(messageObj)
                }
            }
            
            self.lastLoadedDate = self.messageArray[self.messageArray.count-1].dateSent
            
            DispatchQueue.main.async {
                self.messageTableView.reloadData()
                self.messageTableView.scrollToBottom(self.messageArray, false)
                messagesDB.child(self.groupInformation.title).removeAllObservers()
                self.retrieveMessages()
            }
        }
    }
    
    /// Initializes the firebase observe data event for the current group's messages.
    func retrieveMessages() {
        let messagesDB = Database.database().reference().child(FirebaseNames.messages)
        messagesDB.child(groupInformation.title).queryOrdered(byChild: "date_sent").queryStarting(atValue: lastLoadedDate).observe(.childAdded) { (snapshot) in
            // Ignore dummy message
            if snapshot.key != "dummy" {
                let value = JSON(snapshot.value!).dictionaryValue
                // Since .queryStarting is >=, ignore the =, only take >
                if (value["date_sent"]?.stringValue)! != self.lastLoadedDate {
                    let messageObj = self.createMessageObj((value["author"]?.stringValue)!, (value["content"]?.stringValue)!, (value["date_sent"]?.stringValue)!, (value["group"]?.stringValue)!, snapshot.key, (value["picture"]?.stringValue)!)
                    self.messageArray.append(messageObj)
                    
                    DispatchQueue.main.async {
                        self.insertMessage()
                        
                        // If you're at the bottom, scroll (stay at bottom)
                        if self.messageTableView.isAtBottom {
                            self.messageTableView.scrollToBottom(self.messageArray, true)
                        }
                    }
                }
            }
        }
    }
    
    func initializeLayout() {
        messageTextView.text = " " // Used to store default height of 1 line (startingContentHeight)
        startingContentHeight = messageTextView.contentSize.height
        lastContentHeight = startingContentHeight
        maxContentHeight = CGFloat(floorf(Float(startingContentHeight + (messageTextView.font?.lineHeight)! * CGFloat(maxLines - 1))))
        
        let keyExists = contentNotSent[groupInformation.title] != nil
        if !keyExists {
            messageTextView.text = placeholder
            messageTextView.textColor = placeholderColor
        } else {
            messageTextView.text = contentNotSent[groupInformation.title]
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
        let cd = ConvertDate(date: groupInformation.dateCreated)
        
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
    func createMessageObj(_ author: String, _ content: String, _ dateSent: String, _ group: String, _ id: String, _ picture: String) -> Message {
        var messageObj = Message()
        messageObj.author = author
        messageObj.content = content
        messageObj.dateSent = dateSent
        messageObj.group = group
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
