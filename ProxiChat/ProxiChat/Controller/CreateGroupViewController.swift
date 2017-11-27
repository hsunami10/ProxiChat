//
//  CreateGroupViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/21/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit

/*
 - only update location when they submit the form - write a SQL function
 */

class CreateGroupViewController: UIViewController {
    
    

    override func viewDidLoad() {
        super.viewDidLoad()

        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func cancel(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
