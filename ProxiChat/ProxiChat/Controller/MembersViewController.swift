//
//  MembersViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/25/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO

class MembersViewController: UIViewController {
    
    var socket: SocketIOClient?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
