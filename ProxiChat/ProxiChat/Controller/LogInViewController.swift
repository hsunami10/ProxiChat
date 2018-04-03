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
    
    private var canSignIn = false
    
    @IBOutlet var usernameTextField: UITextField! // Username and Email
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        usernameTextField.placeholder = "Username / Email"
        errorLabel.text = " "
        passwordTextField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        UserData.connected = false
        
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { (user, error) in
                if error != nil {
                    print(error!.localizedDescription)
                    SVProgressHUD.showError(withStatus: AlertMessages.authError)
                } else {
                    print("successfully signed in anon")
                    self.canSignIn = true
                }
            }
        } else {
            if (Auth.auth().currentUser?.isAnonymous)! {
                print("existing anon")
                self.canSignIn = true
            } else {
                SVProgressHUD.showError(withStatus: AlertMessages.authError)
            }
        }
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
            UserData.signInGroups = false
            
            // Save log in
            UserDefaults.standard.set(true, forKey: "isUserLoggedInProxiChat")
            UserDefaults.standard.set(UserData.username, forKey: "proxiChatUsername")
            UserDefaults.standard.set(UserData.password, forKey: "proxiChatPassword")
            UserDefaults.standard.set(UserData.email, forKey: "proxiChatEmail")
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
        if !canSignIn {
            SVProgressHUD.showError(withStatus: AlertMessages.authError)
            return
        }
        
        if !Validate.isOneWord(username) || !Validate.isOneWord(password) {
            errorLabel.text = "Invalid username and/or password."
        } else {
            SVProgressHUD.show()
            let usersDB = Database.database().reference().child(FirebaseNames.users)
            
            // Cache anonymous user to delete when sign in is successful
            guard let anonUser = Auth.auth().currentUser else {
                SVProgressHUD.dismiss()
                SVProgressHUD.showError(withStatus: AlertMessages.authError)
                return
            }
            
            // If email
            if Validate.isValidEmail(username) {
                usersDB
                    .queryOrdered(byChild: "email")
                    .queryEqual(toValue: username)
                    .observeSingleEvent(of: .value) { (snapshot) in
                        // Should give back one result - unique email
                        if snapshot.childrenCount != 1 {
                            SVProgressHUD.dismiss()
                            self.errorLabel.text = "Email / password is incorrect. Please try again."
                            return
                        }
                        
                        guard let children = snapshot.children.allObjects as? [DataSnapshot] else {
                            SVProgressHUD.dismiss()
                            self.errorLabel.text = "Email / password is incorrect. Please try again."
                            return
                        }
                        UserData.username = children.first!.key
                        
                        Auth.auth().signIn(withEmail: username, password: password, completion: { (user, error) in
                            self.handleSignIn(user, error, anonUser, password)
                        })
                }
            } else { // If username
                if username.isValidFIRKey() {
                    usersDB.observeSingleEvent(of: .value, with: { (snapshot) in
                        if snapshot.hasChild(username) {
                            UserData.username = username
                            let val = JSON(snapshot.value!)
                            
                            Auth.auth().signIn(withEmail: val[username]["email"].stringValue, password: password, completion: { (user, error) in
                                self.handleSignIn(user, error, anonUser, password)
                            })
                        } else {
                            SVProgressHUD.dismiss()
                            self.errorLabel.text = "Username does not exist."
                        }
                    })
                } else {
                    SVProgressHUD.dismiss()
                    self.errorLabel.text = "Username / email does not exist."
                }
            }
        }
    }
    
    /**
     Handles all errors for signing in, updating auth profile _displayName_ field, and deleting the anonymous user.
     
     - parameters:
         - user: The user object returned from the sign in query.
         - error: The error returned from the sign in query.
         - anonUser: The anonymous user needed to deleted after everything succeeds.
         - password: The password of the user.
     */
    func handleSignIn(_ user: User?, _ error: Error?, _ anonUser: User, _ password: String) {
        if error != nil {
            print(error!.localizedDescription)
            self.errorLabel.text = error?.localizedDescription
            SVProgressHUD.dismiss()
            SVProgressHUD.showError(withStatus: error!.localizedDescription)
        } else {
            Auth.auth().currentUser?.createProfileChangeRequest().displayName = UserData.username
            Auth.auth().currentUser?.createProfileChangeRequest().commitChanges(completion: { (error) in
                if error != nil {
                    SVProgressHUD.dismiss()
                    SVProgressHUD.showError(withStatus: error!.localizedDescription)
                } else {
                    anonUser.delete(completion: { (error) in
                        if error != nil {
                            SVProgressHUD.dismiss()
                            SVProgressHUD.showError(withStatus: error!.localizedDescription)
                        } else {
                            SVProgressHUD.dismiss()
                            UserData.email = (user?.email)!
                            UserData.password = password
                            
                            self.performSegue(withIdentifier: "goToGroups", sender: self)
                        }
                    })
                }
            })
        }
    }
    
}
