//
//  MessageViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/18/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO

class MessageViewController: UIViewController {
    
    var groupInformation: Group!
    var socket: SocketIOClient!
    
    @IBOutlet var groupTitle: UILabel!
    @IBOutlet var messageTableView: UITableView!
    @IBOutlet var typingViewHeight: NSLayoutConstraint!
    @IBOutlet var messageTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        groupTitle.text = groupInformation.title
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        
    }
    
    // MARK: IBOutlet Actions
    @IBAction func goBackToGroups(_ sender: Any) {
        self.dismiss(animated: true) {
            print("leave room")
        }
    }
    @IBAction func showGroupInfo(_ sender: Any) {
        print("show group info")
    }
    @IBAction func sendMessage(_ sender: Any) {
        
    }
}
