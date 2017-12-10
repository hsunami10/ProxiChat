//
//  LogInViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/14/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO
import SwiftyJSON
import SVProgressHUD

/*
 TODO / BUGS:
 - add sending email if someone forgot username and/or password
 */

class LogInViewController: UIViewController, UITextFieldDelegate {
    
    var socket: SocketIOClient?

    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        errorLabel.text = " "
        eventHandlers()
        passwordTextField.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        socket?.on("sign_in_response", callback: { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            
            if success {
                // Save log in
                UserDefaults.standard.set(true, forKey: "isUserLoggedInProxiChat")
                UserDefaults.standard.set(self.usernameTextField.text!, forKey: "proxiChatUsername")
                UserDefaults.standard.synchronize()
                
                SVProgressHUD.dismiss()
                self.performSegue(withIdentifier: "goToGroups", sender: self)
            } else {
                SVProgressHUD.dismiss()
                self.errorLabel.text = error_msg
            }
        })
    }
    
    // MARK: UITextField Delegate Methods
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        validateFields(usernameTextField.text!, passwordTextField.text!)
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Navigation Methods
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToGroups" {
            let destinationVC = segue.destination as! GroupsViewController
            destinationVC.socket = socket
            destinationVC.username = usernameTextField.text!
        }
    }
    
    // MARK: IBOutlet Actions
    @IBAction func logIn(_ sender: Any) {
        validateFields(usernameTextField.text!, passwordTextField.text!)
    }
    
    @IBAction func goBack(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Miscellaneous Methods
    /// Validates all inputs. If all inputs pass, then signs in the user.
    func validateFields(_ username: String, _ password: String) {
        if username.split(separator: " ").count != 1 || password.split(separator: " ").count != 1 {
            errorLabel.text = "Invalid username and/or password."
        } else {
            SVProgressHUD.show()
            socket?.emit("sign_in", username, password)
        }
    }
}
