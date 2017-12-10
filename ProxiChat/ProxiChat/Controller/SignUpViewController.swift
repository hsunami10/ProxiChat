//
//  RegisterVIewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/14/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SocketIO
import SwiftyJSON
import SVProgressHUD

class SignUpViewController: UIViewController, UITextFieldDelegate {
    
    var socket: SocketIOClient?
    
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var repeatPasswordTextField: UITextField!
    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        errorLabel.text = " "
        eventHandlers()
        emailTextField.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: SocketIO Event Handlers
    func eventHandlers() {
        socket?.on("sign_up_response", callback: { (data, ack) in
            let success = JSON(data[0])["success"].boolValue
            let error_msg = JSON(data[0])["error_msg"].stringValue
            
            // Successfully signed in?
            if success {
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
        signUp(usernameTextField.text!, passwordTextField.text!, repeatPasswordTextField.text!, emailTextField.text!)
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
    /// Checks for valid inputs, then sends accordingly.
    @IBAction func submitSignUp(_ sender: Any) {
        signUp(usernameTextField.text!, passwordTextField.text!, repeatPasswordTextField.text!, emailTextField.text!)
    }
    
    @IBAction func goBack(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Miscellaneous Methods
    /// Checks whether the email is valid or not using regex.
    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"+"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"+"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"+"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"+"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"+"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"+"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])"
        let emailTest = NSPredicate(format: "SELF MATCHES[c] %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }
    
    /// Validates all inputs. If all pass, then registers the user.
    func signUp(_ username: String, _ password: String, _ passwordRetype: String, _ email: String) {
        // TODO: Optional: Add requirements to password?
        if username.split(separator: " ").count != 1 || password.split(separator: " ").count != 1 || passwordRetype.split(separator: " ").count != 1 {
            errorLabel.text = "Invalid username and/or password."
        } else if password != passwordRetype {
            errorLabel.text = "Passwords do not match."
        } else if !isValidEmail(email) {
            errorLabel.text = "Email address not valid."
        } else {
            SVProgressHUD.show()
            socket?.emit("sign_up", username, password)
        }
    }
}
