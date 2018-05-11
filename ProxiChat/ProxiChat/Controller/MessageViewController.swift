//
//  MessageViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/18/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SwiftyJSON
import SVProgressHUD
import SwiftDate
import Firebase

/*
 TODO
 - display images (find how to show images uploaded from phone - url? path?) - use firebase storage?
 - find a way to cache whether or not the keyboard is showing / hiding when leaving view - like facebook messenger
 
 BUGS
 - handle shifting up messages when height changing and it covers some messages
 - handle shiting up messages when other people send messages, and it covers some messages
 - after creating a group, when you send a message that needs multiple lines, the height isn't larger - it cuts off with ...
 - FIX -> messages jump down when paginating - keep the content in the same position
 */

/// Holds the text left over in a certain conversation whenever the user goes back to the groups page. [group_id : text view content]
var contentNotSent: [String : String] = [:]

class MessageViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, UIGestureRecognizerDelegate {
    
    private var messageArray: [Message] = [Message]()
    private var groupInfoArray = ["# Online", "# Stars", "Settings or View Creator Profile"] // If this is changed, cmd+f "CHANGE INDICES" or "CHANGE STRING"
    private var lastLines = 1 // Saves the last number of lines
    private var isMessageSent = false // Tag for whether or not a message has been sent - don't hide keyboard on message send
    private var refreshControl: UIRefreshControl!
    private var pageQuery: UInt?
    private var tapGesture: UITapGestureRecognizer?
    private var changeTableView = false
    private var isKeyboardHidden = false
    
    // For pagination and getting messages
    /**
     The date of the last (most recent) message loaded on join.
     This is used on the message loading to mark when to start listening for new messages.
     */
    private var dateToStartListening: TimeInterval = 0.0
    /// The date of earliest message retrieved - used for pagination.
    private var earliestDate: TimeInterval!
    /// The max number of messages to page each time.
    private var numMessages: UInt = 20
    
    // Storing values for responsive layout
    var heightTypingView: CGFloat = 0 // Starting height of typing view
    var startingContentHeight: CGFloat = 0
    var maxContentHeight: CGFloat = 0 // Max height of text view before scrolling
    var heightMessageTableView: CGFloat = 0 // Starting height of message table view
    var cellHeightDict: [Int : CGFloat] = [:] // Stores actual cell heights
    
    // Constants
    let maxLines = 5 // Max number of text view lines before scrolling
    let placeholder = "Enter a message..."
    let placeholderColor: UIColor = UIColor.lightGray
    let groupInfoRatio: CGFloat = 0.66 // Proportion of the screen the group info view takes up
    let paddingTextView = Dimensions.getPoints(10, true) // Top and bottom padding of text view
    
    // MARK: Public Access
    /// Keeps track of which groups view controller to go back to. 0 -- GroupsViewController, 1 -- StarredGroupsViewController.
    var fromViewController = -1
    var groupInformation: Group!
    var observed = false
    var lastContentHeight: CGFloat = 0
    
    @IBOutlet var groupTitle: UILabel!
    @IBOutlet var dimView: UIView!
    @IBOutlet var groupInfoView: UIView!
    
    @IBOutlet var messageTableView: UITableView!
    @IBOutlet var messageTableViewHeight: NSLayoutConstraint!
    
    @IBOutlet var messageView: UIView!
    @IBOutlet var messageViewHeight: NSLayoutConstraint!
    
    @IBOutlet var infoView: UIView!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    @IBOutlet var infoViewLabel: UILabel!
    
    @IBOutlet var groupInfoViewWidth: NSLayoutConstraint!
    @IBOutlet var groupInfoViewRightConstraint: NSLayoutConstraint!
    @IBOutlet var groupInfoTableView: UITableView!
    @IBOutlet var groupInfoTableViewHeight: NSLayoutConstraint!
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var creatorLabel: UILabel!
    
    @IBOutlet var groupImageView: UIImageView!
    @IBOutlet var groupImageViewWidth: NSLayoutConstraint!
    
    // Constant constraints for fake and real typing views to use
    let topBottomTextView: CGFloat = Dimensions.getPoints(10, true)
    let leftTextView: CGFloat = Dimensions.getPoints(10, false)
    let widthTextView: CGFloat = Dimensions.getPoints(352, false)
    let rightSendButton: CGFloat = Dimensions.getPoints(8, false)
    let widthHeightSendButton: CGFloat = Dimensions.getPoints(36, false)
    let bottomSendButton: CGFloat = Dimensions.getPoints(10, true)
    
    // Properties for the fake typing view - stays at bottom and doesn't move - must be changed if the actual one used for input accessory view is changed
    @IBOutlet var fakeTypingView: UIView!
    @IBOutlet var fakeTypingViewHeight: NSLayoutConstraint!
    
    @IBOutlet var fakeMessageTextView: UITextView!
    @IBOutlet var fakeMessageTextViewTop: NSLayoutConstraint!
    @IBOutlet var fakeMessageTextViewBottom: NSLayoutConstraint!
    @IBOutlet var fakeMessageTextViewLeft: NSLayoutConstraint!
    @IBOutlet var fakeMessageTextViewWidth: NSLayoutConstraint!
    
    @IBOutlet var fakeSendButton: UIButton!
    @IBOutlet var fakeSendButtonWidth: NSLayoutConstraint!
    @IBOutlet var fakeSendButtonHeight: NSLayoutConstraint!
    @IBOutlet var fakeSendButtonBottom: NSLayoutConstraint!
    @IBOutlet var fakeSendButtonRight: NSLayoutConstraint!
    
    var typingView: InputAccessoryView!
    
    // MARK: Input Accessory View Setup
    lazy var typingViewContainer: UIView = {
        typingView = InputAccessoryView(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: fakeTypingViewHeight.constant))
        return typingView
    }()

    override var inputAccessoryView: UIView? {
        get {
            return typingViewContainer
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }
    
    // MARK: iOS View Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        groupTitle.text = groupInformation.title
        groupTitle.font = Font.getFont(Font.infoViewFontSize)
        titleLabel.font = Font.getFont(17, "\(Font.fontName)-Bold")
        creatorLabel.font = Font.getFont(17)
        
        messageTableView.delegate = self
        messageTableView.dataSource = self
        groupInfoTableView.delegate = self
        groupInfoTableView.dataSource = self
        
        refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "More")
        refreshControl.addTarget(self, action: #selector(getMoreMessages(_:)), for: .valueChanged)
        
        // Detects when to close the group info
        let dimTap = UITapGestureRecognizer(target: self, action: #selector(closeGroupInfo))
        dimView.addGestureRecognizer(dimTap)
        
        // Register nibs
        messageTableView.register(UINib.init(nibName: "MessageCell", bundle: nil), forCellReuseIdentifier: "messageCell")
        groupInfoTableView.register(UINib.init(nibName: "GroupInfoCell", bundle: nil), forCellReuseIdentifier: "groupInfoCell")
        messageTableView.separatorStyle = .none
        
        messageTableView.refreshControl = refreshControl
        
        // Enable keyboard tap and drag
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tableViewTapped))
        messageTableView.addGestureRecognizer(tapGesture)
        messageTableView.keyboardDismissMode = .interactive
        
        // Show the inputAccessoryView typing view after the segue animation finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + Durations.navigationDuration) {
            self.typingView.isHidden = false
            self.typingView.isUserInteractionEnabled = true
            self.changeTableView = true
        }
        
        initializeGroupInfo()
        initializeGeneralLayout()
        InputAccessoryView.createViewAndInitialize(fakeMessageTextView, fakeSendButton, self, nil)
        
        // Get messages
        getMessages(onLoad: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.becomeFirstResponder() // Initialize custom inputAccessoryView
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        NotificationCenter.default.removeObserver(self)
        if observed {
            typingView.messageTextView.removeObserver(self, forKeyPath: "contentSize")
            typingView.messageTextView.inputAccessoryView = nil
            typingView.messageTextView.reloadInputViews()
            observed = false
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Layout Methods
    func initializeGeneralLayout() {
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight, true)
        messageViewHeight.constant = Dimensions.safeAreaHeight - infoViewHeight.constant
        
        // Initialize group info view
        groupInfoViewWidth.constant = self.view.frame.width * groupInfoRatio
        groupInfoViewRightConstraint.constant = -groupInfoViewWidth.constant
        groupInfoTableView.rowHeight = Dimensions.getPoints(60, true) // Height of each row - TODO: Change row height later for better UI
        groupInfoTableViewHeight.constant = groupInfoTableView.rowHeight * CGFloat(groupInfoArray.count)
        groupInfoTableView.isScrollEnabled = false
        groupImageViewWidth.constant = groupInfoViewWidth.constant - Dimensions.getPoints(32, false) // 16 margins on left and right side
        
        self.view.layoutIfNeeded()
    }
    
    /// Initialize anything in the view that is related to the group.
    func initializeGroupInfo() {
        // CHANGE INDICES
        // CHANGE STRING
        let cd = ConvertDate(date: groupInformation.dateCreated)
        
        if groupInformation.creator == UserData.username {
            groupInfoArray[groupInfoArray.count-1] = "Settings"
        } else {
            groupInfoArray[groupInfoArray.count-1] = "View Creator Profile"
        }
        if groupInformation.members.count == 1 {
            groupInfoArray[1] = String(groupInformation.members.count) + " Star"
        } else {
            groupInfoArray[1] = String(groupInformation.members.count) + " Stars"
        }
        groupInfoArray[0] = groupInfoArray[0].replacingOccurrences(of: "#", with: String(groupInformation.numOnline))
        
        creatorLabel.text = "Created by \(groupInformation.creator) on \(cd.convert())"
        titleLabel.text = groupInformation.title
        groupImageView.image = UIImage(named: "noPicture") // TODO: Get group picture
    }
    
    // MARK: Firebase Queries
    
    /// Paginates the messages.
    @objc func getMoreMessages(_ sender: AnyObject) {
        // TODO: Disable listening to messages or no?
        getMessages(onLoad: false)
    }
    
    /**
     Gets messages of a certain group on join or on refresh.
    
     - parameters:
        - onLoad: Determines whether or not the user is getting messages on join (view load) or on refresh.
     */
    func getMessages(onLoad: Bool) {
        let messagesDB = Database.database().reference().child(FirebaseNames.messages)
        
        if onLoad {
            messageArray = [Message]()
            messagesDB.child(groupInformation.title)
                .queryOrdered(byChild: "date_sent") // Ascending order
                .queryLimited(toLast: numMessages)
                .observe(.value) { (snapshot) in
                    guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                        SVProgressHUD.showError(withStatus: "There was a problem getting messages. Please try again.")
                        return
                    }
                    
                    // Store the latest date (first element of children)
                    self.earliestDate = JSON((children.first?.value)!)["date_sent"].doubleValue
                    
                    // Iterate over snapshot's children, skipping dummy message - earliest message first
                    for child in children {
                        if child.key != "dummy" {
                            let value = JSON(child.value!)
                            let messageObj = self.createMessageObj(value["author"].stringValue, value["content"].stringValue, value["date_sent"].doubleValue, value["group"].stringValue, child.key, value["picture"].stringValue)
                            self.messageArray.append(messageObj)
                        }
                    }
                    
                    // Account for empty messages
                    if self.messageArray.count == 0 {
                        self.dateToStartListening = 0.0
                    } else {
                        self.dateToStartListening = self.messageArray[self.messageArray.count-1].dateSent
                    }
                    
                    DispatchQueue.main.async {
                        self.messageTableView.reloadData()
                        self.messageTableView.scrollToBottom(self.messageArray, false)
                        messagesDB.child(self.groupInformation.title).removeAllObservers()
                        self.listenForNewMessages()
                    }
            }
        } else {
            self.pageQuery = messagesDB.child(groupInformation.title)
                .queryOrdered(byChild: "date_sent")
                .queryEnding(atValue: earliestDate) // <=
                .queryLimited(toLast: numMessages + 1) // Adjust for ignoring the = to keep the number of messages the same
                .observe(.value, with: { (snapshot) in
                    guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                        SVProgressHUD.showError(withStatus: "There was a problem getting messages. Please try again.")
                        self.messageTableView.refreshControl?.endRefreshing()
                        return
                    }
                    
//                    var indexPaths = [IndexPath]()
                    
                    // Iterate from end -> beginning of array, and insert backwards to keep order
                    for index in stride(from: children.count-1, through: 0, by: -1) {
                        let child = children[index]
                        if child.key != "dummy" {
                            let value = JSON(child.value!)
                            
                            // Adjust for <=, ignore the =
                            if self.earliestDate != value["date_sent"].doubleValue {
                                let messageObj = self.createMessageObj(value["author"].stringValue, value["content"].stringValue, value["date_sent"].doubleValue, value["group"].stringValue, child.key, value["picture"].stringValue)
                                self.messageArray.insert(messageObj, at: 0)
                                
//                                indexPaths.insert(IndexPath(row: index, section: 0), at: 0)
                            }
                        }
                    }
                    
                    // Store the earliest date (first element of children)
                    self.earliestDate = JSON((children.first?.value)!)["date_sent"].doubleValue
                    
                    DispatchQueue.main.async {
//                        self.insertMessage(indexPaths)
                        self.removePageQuery()
                        self.messageTableView.reloadData()
                        self.messageTableView.refreshControl?.endRefreshing()
                    }
                })
        }
    }

    func removePageQuery() {
        guard let pg = pageQuery else { return }
        let messagesDB = Database.database().reference().child(FirebaseNames.messages)
        messagesDB.child(groupInformation.title).removeObserver(withHandle: pg)
        pageQuery = nil
    }
    
    // MARK: Firebase Observers
    
    /// Initializes the firebase observe data event for the current group's messages. Only runs once **on view load**.
    func listenForNewMessages() {
        let messagesDB = Database.database().reference().child(FirebaseNames.messages)
        
        messagesDB.child(groupInformation.title)
            .queryOrdered(byChild: "date_sent")
            .queryStarting(atValue: dateToStartListening)
            .observe(.childAdded) { (snapshot) in
                // Ignore dummy message
                if snapshot.key != "dummy" {
                    let value = JSON(snapshot.value!)
                    
                    // Since .queryStarting is >=, ignore the =, only take >
                    if value["date_sent"].doubleValue != self.dateToStartListening {
                        let messageObj = self.createMessageObj(value["author"].stringValue, value["content"].stringValue, value["date_sent"].doubleValue, value["group"].stringValue, snapshot.key, value["picture"].stringValue)
                        self.messageArray.append(messageObj)
                        
                        DispatchQueue.main.async {
                            // If at bottom before receiving message, then stay at bottom
                            let atBottom = self.messageTableView.isAtBottom
                            
                            self.insertMessage()
                            
                            // If you're at the bottom or the sender, scroll (stay at bottom)
                            if atBottom || value["author"].stringValue == UserData.username {
                                self.messageTableView.scrollToBottom(self.messageArray, true)
                            }
                        }
                    }
                }
        }
    }
    
    // MARK: IBOutlet Actions
    @IBAction func goBack(_ sender: Any) {
        slideRightTransition()
        typingView.isHidden = true
        
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
    }
    
    @IBAction func showGroupInfo(_ sender: Any) {
        dimView.isUserInteractionEnabled = true
        self.view.bringSubview(toFront: dimView)
        self.view.bringSubview(toFront: groupInfoView)
        
        typingView.messageTextView.resignFirstResponder()
        fakeMessageTextView.text = typingView.messageTextView.text
        fakeMessageTextView.textColor = typingView.messageTextView.textColor
        typingView.isHidden = true
        
        if !UIView.areAnimationsEnabled {
            UIView.setAnimationsEnabled(true)
        }
        UIView.animate(withDuration: Durations.showGroupInfoDuration) {
            self.dimView.alpha = 0.5
            self.groupInfoViewRightConstraint.constant = 0
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func sendPressed(_ sender: Any) {
        if !Validate.isInvalidInput(typingView.messageTextView.text!) && typingView.messageTextView.textColor != UIColor.lightGray {
            isMessageSent = true
            typingView.messageTextView.isEditable = false
            typingView.sendButton.isEnabled = false
            
            // TODO: *** Get picture ***
            
            // Store message into database
            let messagesDB = Database.database().reference().child(FirebaseNames.messages)
            messagesDB.child(groupInformation.title).childByAutoId().setValue([
                "author": UserData.username,
                "group": groupInformation.title,
                "content": typingView.messageTextView.text!,
                "date_sent": Date().timeIntervalSince1970,
                "picture": UserData.picture
                ])
            
            // Reset
            typingView.messageTextView.isEditable = true
            typingView.sendButton.isEnabled = true
            typingView.messageTextView.text = placeholder
            typingView.messageTextView.textColor = UIColor.lightGray
            
            if messageTableView.scrollIndicatorInsets.bottom != 0 {
                isMessageSent = false
                typingView.messageTextView.becomeFirstResponder()
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
//            if groupInfoArray[indexPath.row].contains("Star") || groupInfoArray[indexPath.row].contains("Online") {
//                performSegue(withIdentifier: "goToMembers", sender: self)
//            }
            groupInfoTableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    // MARK: UITextViewDelegate Methods / UITextView
    func textViewDidBeginEditing(_ textView: UITextView) {
        if typingView.messageTextView.textColor == placeholderColor {
            typingView.messageTextView.text = ""
            typingView.messageTextView.textColor = UIColor.black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        // Change spaces and empty text to placeholder
        if Validate.isInvalidInput(typingView.messageTextView.text!) {
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
    
    /*
     TODO: Do this to change height instead? It's cleaner.
     let sizeToFitIn = CGSize(width: textView.bounds.size.width, height: .greatestFiniteMagnitude)
     let newSize = textView.sizeThatFits(sizeToFitIn)
     var newHeight = newSize.height
     
     // That part depends on your approach to placing constraints, it's just my example
     textInputHeightConstraint?.constant = newHeight
    */
    // BUG: Deleting multiple lines shifts strangely?
    // Respond to contentSize change in messageTextView
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        print("observed content size changed")
        
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
                
                UIView.animate(withDuration: Durations.textViewHeightDuration, animations: {
                    // If overflow or messages are hidden, then only move the table view up accordingly
                    if self.messageTableViewHeight.constant < self.messageTableView.contentSize.height {
                        self.messageTableView.contentInset.bottom += changeInHeight
                        self.messageTableView.scrollIndicatorInsets.bottom += changeInHeight
                        self.messageTableView.contentOffset.y += changeInHeight
                    }
                    
                    if self.typingView != nil {
                        print("change height of typing view")
                        self.typingView.changeInHeight = changeInHeight
                        self.typingView.invalidateIntrinsicContentSize()
                        
                        // BUG: This code makes the view jump, but centers text vertically?
                        if let superview = self.typingView.superview {
                            print("superview")
                            superview.setNeedsLayout()
                            superview.layoutIfNeeded()
                        }
                    }
                    
                    self.view.layoutIfNeeded()
                })
                
                lastLines = wholeLines
                lastContentHeight = textView.contentSize.height
            }
        }
    }
    
    // MARK: Keyboard (NotificationCenter) Methods
    @objc func keyboardWillShow(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo, changeTableView {
            // Only show keyboard if it's NOT shown
            if messageTableView.scrollIndicatorInsets.bottom == 0 {
                // Get keyboard animation duration
                let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
                
                // Get keyboard height, includes inputAccessoryView height
                let keyboardHeight: CGFloat = ((userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)! - self.typingView.frame.height
                
                let changeInHeight = getHeightChange()
                
                if !UIView.areAnimationsEnabled {
                    UIView.setAnimationsEnabled(true)
                }
                
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
                    print("change in height relative to one line: ", changeInHeight)
                    
                    // If content isn't overflowing
                    if leftOverSpace > 0 {
                        if leftOverSpace < keyboardHeight + self.heightTypingView + changeInHeight {
                            print("case 3")
                            let diffY = keyboardHeight + changeInHeight - leftOverSpace
                            self.messageTableView.contentInset.bottom += keyboardHeight + changeInHeight
                            self.messageTableView.scrollIndicatorInsets.bottom += keyboardHeight + changeInHeight
                            self.messageTableView.contentOffset.y += diffY
                        } else {
                            print("case 1")
                            self.messageTableView.contentInset.bottom += keyboardHeight + changeInHeight
                            self.messageTableView.scrollIndicatorInsets.bottom += keyboardHeight + changeInHeight
                        }
                    } else {
                        print("case 2")
                        self.messageTableView.contentInset.bottom += keyboardHeight + changeInHeight
                        self.messageTableView.scrollIndicatorInsets.bottom += keyboardHeight + changeInHeight
                        self.messageTableView.contentOffset.y += keyboardHeight + changeInHeight
                    }
                    
                    self.typingView.changeInHeight = changeInHeight
                    self.typingView.invalidateIntrinsicContentSize()
                    self.view.layoutIfNeeded()
                }
                fakeTypingView.isUserInteractionEnabled = false
            }
            isMessageSent = false
            changeTableView = false
            isKeyboardHidden = false
        }
        
        if isKeyboardHidden {
            changeTableView = true
        }
    }
    
    @objc func keyboardWillHide(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo, !isKeyboardHidden {
            // Only move views down if a message is not sent
            if !isMessageSent {
                let keyboardHeight: CGFloat = ((userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)! - self.typingView.frame.height
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
                        self.messageTableView.contentOffset.y -= keyboardHeight + changeInHeight
                    }
                    print("hide keyboard - keyboardWillHide")
                    // Reset to starting values
                    self.messageTableView.contentInset.bottom = 0
                    self.messageTableView.scrollIndicatorInsets.bottom = 0
                    self.typingView.changeInHeight = -changeInHeight
                    self.isKeyboardHidden = true
                    
                    self.typingView.invalidateIntrinsicContentSize()
                    self.view.layoutIfNeeded()
                }
            }
        }
    }
    
    // MARK: UIGestureRecognizer Methods
    
    @objc func tableViewTapped() {
        // If keyboard is showing
        if messageTableView.contentInset.bottom != 0 {
            typingView.messageTextView.endEditing(true)
            typingView.messageTextView.resignFirstResponder()
        }
    }
    
    @objc func closeGroupInfo() {
        UIView.animate(withDuration: Durations.showGroupInfoDuration, animations: {
            self.dimView.alpha = 0
            self.groupInfoViewRightConstraint.constant = -self.groupInfoViewWidth.constant
            self.view.layoutIfNeeded()
        }) { (complete) in
            self.typingView.isHidden = false
            self.dimView.isUserInteractionEnabled = false
        }
    }
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        // Remove all observers - add them back on view load
        // TODO: Maybe change this to implement notifications?
        Database.database().reference().child("\(FirebaseNames.messages)/\(groupInformation.title)").removeAllObservers()
        dateToStartListening = 0.0
        earliestDate = nil
        
        if segue.identifier == "goBackToGroups" {
            let destinationVC = segue.destination as! GroupsViewController
            destinationVC.messageObj = self
        } else if segue.identifier == "goBackToStarredGroups" {
            let destinationVC = segue.destination as! StarredGroupsViewController
            destinationVC.messageObj = self
        } else if segue.identifier == "goToMembers" {
//            let destinationVC = segue.destination as! MembersViewController
            // TODO: Finish this later if needed
        }
    }
    
    // MARK: Miscellaneous Methods
    
    /// Edit UIViewController transition left -> right
    func slideRightTransition() {
        let transition = CATransition()
        transition.duration = Durations.navigationDuration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromLeft
        self.view.window?.layer.add(transition, forKey: nil)
    }
    
    /// Gets the change in height of the text view / typing view relative to one line of text, i.e. if there are 3 lines of text, then this method would return the height of 2 lines of text.
    func getHeightChange() -> CGFloat {
        // Get the number of lines to calculate the height of the typing view
        var numLines = floorf(Float(typingView.messageTextView.contentSize.height / (typingView.messageTextView.font?.lineHeight)!))
        if Int(numLines) >= maxLines { // Don't go over the max number of lines
            numLines = Float(maxLines)
        }
        // Height to change starting from the default 1 line text view height - in case there are multiple lines of text
        let changeInHeight = CGFloat(floorf(Float((typingView.messageTextView.font?.lineHeight)!)) * (numLines - 1))
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
    func createMessageObj(_ author: String, _ content: String, _ dateSent: TimeInterval, _ group: String, _ id: String, _ picture: String) -> Message {
        var messageObj = Message()
        messageObj.author = author
        messageObj.content = content
        messageObj.dateSent = dateSent
        messageObj.group = group
        messageObj.id = id
        messageObj.picture = picture
        return messageObj
    }
    
    /**
     Adds rows to the messageTableView.
     
     - parameters:
        - indexArray: Array of `IndexPath` objects. Determines where to add the rows to the table view. The default value is `[]`.
     */
    func insertMessage(_ indexArray: [IndexPath] = []) {
        let indexPath = IndexPath(row: messageArray.count-1, section: 0)
        UIView.setAnimationsEnabled(false)
        messageTableView.beginUpdates()
        messageTableView.insertRows(at: indexArray.count == 0 ? [indexPath] : indexArray, with: UITableViewRowAnimation.none)
        messageTableView.endUpdates()
        UIView.setAnimationsEnabled(true)
    }
    
    // MARK: PROTOTYPE METHODS FOR FUTURE IMPLEMENTATIONS
    func starClicked() {
        // Clicked vs. unclicked
        let groupsDB = Database.database().reference().child(FirebaseNames.groups)
        groupsDB
            .queryOrderedByKey()
            .queryEqual(toValue: groupInformation.title)
            .observeSingleEvent(of: .value) { (snapshot) in
                // Check if the group still exists
                if snapshot.childrenCount == 0 {
                    SVProgressHUD.showError(withStatus: "The group you want to join does not exist. It has most likely been removed.")
                    self.goBack(true)
                    return
                }
                
                // Add to members
                groupsDB.child("\(self.groupInformation.title)/members/\(UserData.username)").setValue(true)
                
                // Reload data in group info view
                // CHANGE INDICES
                // CHANGE STRING
                self.groupInformation.members[UserData.username] = true
                self.groupInfoArray[1] = String(self.groupInformation.members.count) + " Stars"
                
                DispatchQueue.main.async {
                    self.groupInfoTableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .none)
                }
        }
    }
}
