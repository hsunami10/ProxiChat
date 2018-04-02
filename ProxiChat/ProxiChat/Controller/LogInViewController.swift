//
//  LogInViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/14/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import SwiftyJSON
import SVProgressHUD
import Firebase

/*
 TODO / BUGS:
 - add sending email if someone forgot username and/or password
 - change status to online in prepareSegue function
 */

class LogInViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet var usernameTextField: UITextField! // Username and Email
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        usernameTextField.placeholder = "Username / Email"
        errorLabel.text = " "
        passwordTextField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
            // Save log in
            UserDefaults.standard.set(true, forKey: "isUserLoggedInProxiChat")
            UserDefaults.standard.set(UserData.username, forKey: "proxiChatUsername")
            UserDefaults.standard.synchronize()
        }
    }
    
    // MARK: IBOutlet Actions
    @IBAction func logIn(_ sender: Any) {
        validateFields(usernameTextField.text!, passwordTextField.text!)
    }
    
    @IBAction func goBack(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Notification Center Methods
    @objc func keyboardWillShow(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo {
            let keyboardHeight: CGFloat = ((userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)!
            UserDefaults.standard.set(keyboardHeight, forKey: "proxiChatKeyboardHeight")
            UserDefaults.standard.synchronize()
        }
    }
    
    // MARK: Miscellaneous Methods
    /// Validates all inputs. If all inputs pass, then signs in the user.
    func validateFields(_ username: String, _ password: String) {
        if !Validate.isOneWord(username) || !Validate.isOneWord(password) {
            errorLabel.text = "Invalid username and/or password."
        } else {
            SVProgressHUD.show()
            
            let usersDB = Database.database().reference().child(FirebaseNames.users)
            
            // If email
            if Validate.isValidEmail(username) {
                usersDB
                    .queryOrdered(byChild: "email")
                    .queryEqual(toValue: username)
                    .observeSingleEvent(of: .value) { (snapshot) in
                        if snapshot.childrenCount != 1 {
                            self.errorLabel.text = "Email / password is incorrect. Please try again."
                            return
                        }
                        
                        guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                            self.errorLabel.text = "Email / password is incorrect. Please try again."
                            return
                        }
                        UserData.username = children.first!.key
                        
                        Auth.auth().signIn(withEmail: username, password: password, completion: { (user, error) in
                            if error != nil {
                                self.errorLabel.text = error?.localizedDescription
                            } else {
                                self.performSegue(withIdentifier: "goToGroups", sender: self)
                            }
                        })
                }
            } else { // If username
                if username.isValidFIRKey() {
                    usersDB.observeSingleEvent(of: .value, with: { (snapshot) in
                        if snapshot.hasChild(username) {
                            UserData.username = username
                            self.performSegue(withIdentifier: "goToGroups", sender: self)
                        } else {
                            self.errorLabel.text = "Username does not exist."
                        }
                    })
                } else {
                    self.errorLabel.text = "Username / email does not exist."
                }
            }
            SVProgressHUD.dismiss()
        }
    }
}
