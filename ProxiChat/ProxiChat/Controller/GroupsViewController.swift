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

class GroupsViewController: UIViewController {
    
    var socket: SocketIOClient?
    var username: String = ""
    let domain = "http://localhost:3000"

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if socket == nil {
            socket = SocketIOClient(socketURL: URL(string: domain)!)
        }
        eventHandlers()
        
        socket?.connect(timeoutAfter: 5.0, withHandler: {
            SVProgressHUD.showError(withStatus: "Connection Failed.")
        })
        socket?.joinNamespace("/proxichat_namespace")
        socket?.emit("go_online", username)
    }
    
    func eventHandlers() {
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
