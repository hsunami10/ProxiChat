//
//  EditProfileViewController.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/11/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit
import Firebase
import SVProgressHUD

/* TODO / BUGS
 - fix layout for editing bio page
 - check for a change in a profile field (disable update button accordingly)
 */

class EditProfileViewController: UIViewController {
    
    // MARK: Private Access
    private let textFieldHeight: CGFloat = Dimensions.getPoints(30, true)
    private let textViewHeight: CGFloat = Dimensions.getPoints(90, true)
    private var observed = false
    
    // MARK: Public Access
    var row = -1
    var delegate: UpdateProfileDelegate?
    
    // Height of button for calculating field view height constraint. Top & bottom constraints are 16 each
    @IBOutlet var updateButton: UIButton!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var infoViewHeight: NSLayoutConstraint!
    
    // Single field view: bio, email (2,3)
    @IBOutlet var subSingleView: UIView!
    @IBOutlet var subSingleViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var singleFieldTitleLabel: UILabel!
    @IBOutlet var singleTextView: UITextView!
    @IBOutlet var singleTextViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var singleTextField: UITextField!
    @IBOutlet var singleTextFieldHeightConstraint: NSLayoutConstraint!
    @IBOutlet var singleErrorLabel: UILabel!
    
    // Double field view: password (1)
    @IBOutlet var subDoubleView: UIView!
    @IBOutlet var subDoubleViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var doubleFieldTitleLabel: UILabel!
    @IBOutlet var doubleTextFieldOne: UITextField!
    @IBOutlet var doubleTextFieldOneHeightConstraint: NSLayoutConstraint!
    @IBOutlet var doubleTextFieldTwo: UITextField!
    @IBOutlet var doubleTextFieldTwoHeightConstraint: NSLayoutConstraint!
    @IBOutlet var doubleErrorLabel: UILabel!
    
    @IBOutlet var contentView: UIView!
    @IBOutlet var contentViewBottomConstraint: NSLayoutConstraint! // Change according to keyboard
    
    // Change based on: content view height - keyboard height & button distance
    @IBOutlet var fieldViewHeightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.font = Font.getFont(Font.infoViewFontSize)
        doubleFieldTitleLabel.font = Font.getFont(15)
        singleFieldTitleLabel.font = Font.getFont(15)
        
        // Responsive layout
        infoViewHeight.constant = Dimensions.getPoints(Dimensions.infoViewHeight, true)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        observed = true
        
        // Hide everything first
        subSingleView.isHidden = true
        subDoubleView.isHidden = true
        
        // Initialize field view height with respect to keyboard heigth and button
        fieldViewHeightConstraint.constant = contentView.frame.height - (CGFloat(UserDefaults.standard.float(forKey: "proxiChatKeyboardHeight")) + 16 + updateButton.frame.height)
        
        // Change view for the specific row chosen. First set values, then set layout. Set the height constraint for subfield view last.
        switch row {
        case 1:
            titleLabel.text = "Change Password"
            doubleFieldTitleLabel.text = "Password"
            doubleTextFieldOne.placeholder = "Enter a new password"
            doubleTextFieldTwo.placeholder = "Confirm the new password"
            doubleTextFieldOne.isSecureTextEntry = true
            doubleTextFieldTwo.isSecureTextEntry = true
            
            doubleTextFieldOneHeightConstraint.constant = textFieldHeight
            doubleTextFieldTwoHeightConstraint.constant = textFieldHeight
            
            subDoubleViewHeightConstraint.constant = doubleFieldTitleLabel.frame.height + 8 + doubleTextFieldOneHeightConstraint.constant + 8 + doubleTextFieldTwoHeightConstraint.constant + 8 + doubleErrorLabel.frame.height + 8
            updateButton.setTitle("Update Password", for: .normal)
            break
        case 2:
            // TODO: Fix the layout for this
            
            titleLabel.text = "Edit Bio"
            singleFieldTitleLabel.text = "Bio"
            singleTextField.isHidden = true
            singleErrorLabel.isHidden = true
            singleTextView.layer.borderWidth = 1
            singleTextView.layer.borderColor = UIColor.lightGray.cgColor
            singleTextView.text = UserData.bio
            
            singleTextViewHeightConstraint.constant = textViewHeight
            subSingleViewHeightConstraint.constant = singleFieldTitleLabel.frame.height + 8 + singleTextViewHeightConstraint.constant + 8
            updateButton.setTitle("Update Bio", for: .normal)
            break
        case 3:
            titleLabel.text = "Change Email"
            singleFieldTitleLabel.text = "Email"
            singleTextView.isHidden = true
            singleTextField.text = UserData.email
            
            singleTextFieldHeightConstraint.constant = textFieldHeight
            subSingleViewHeightConstraint.constant = singleFieldTitleLabel.frame.height + singleTextFieldHeightConstraint.constant + singleErrorLabel.frame.height + 24
            updateButton.setTitle("Update Email", for: .normal)
            break
        default:
            break
        }
        
        if row == 1 {
            doubleErrorLabel.text = " "
            subDoubleView.isHidden = false
        } else if row == 2 || row == 3 {
            singleErrorLabel.text = " "
            subSingleView.isHidden = false
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !observed {
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if observed {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: IBOutlet Actions
    @IBAction func submitUpdateField(_ sender: UIButton) {
        let usersDB = Database.database().reference().child(FirebaseNames.users)
        SVProgressHUD.show()
        
        switch row {
        case 1:
            if doubleTextFieldOne.text! == doubleTextFieldTwo.text! {
                if Validate.isOneWord(doubleTextFieldOne.text!) {
                    
                    Auth.auth().currentUser?.updatePassword(to: doubleTextFieldOne.text!, completion: { (error) in
                        if error != nil {
                            print(error!.localizedDescription)
                            SVProgressHUD.dismiss()
                            SVProgressHUD.showError(withStatus: error?.localizedDescription)
                        } else {
                            usersDB.child(UserData.username).updateChildValues(["password" : self.doubleTextFieldOne.text!], withCompletionBlock: { (error, ref) in
                                if error != nil {
                                    print(error!.localizedDescription)
                                    SVProgressHUD.dismiss()
                                    SVProgressHUD.showError(withStatus: error?.localizedDescription)
                                } else {
                                    self.delegate?.updateProfile(EditProfile.password, self.doubleTextFieldOne.text!)
                                    self.slideRightTransition()
                                    SVProgressHUD.dismiss()
                                    self.dismiss(animated: false, completion: nil)
                                }
                            })
                        }
                    })
                } else {
                    SVProgressHUD.dismiss()
                    doubleErrorLabel.text = "Invalid password."
                }
            } else {
                SVProgressHUD.dismiss()
                doubleErrorLabel.text = "Passwords do not match."
            }
            break
        case 2:
            usersDB.child(UserData.username).updateChildValues(["bio" : singleTextView.text!]) { (error, ref) in
                if error != nil {
                    print(error!.localizedDescription)
                    SVProgressHUD.dismiss()
                    SVProgressHUD.showError(withStatus: error?.localizedDescription)
                } else {
                    SVProgressHUD.dismiss()
                    self.delegate?.updateProfile(EditProfile.bio, self.singleTextView.text!)
                    self.slideRightTransition()
                    SVProgressHUD.dismiss()
                    self.dismiss(animated: false, completion: nil)
                }
            }
            break
        case 3:
            if Validate.isValidEmail(singleTextField.text!) {
                Auth.auth().currentUser?.updateEmail(to: singleTextField.text!, completion: { (error) in
                    if error != nil {
                        print(error!.localizedDescription)
                        SVProgressHUD.dismiss()
                        SVProgressHUD.showError(withStatus: error?.localizedDescription)
                    } else {
                        usersDB.child(UserData.username).updateChildValues(["email" : self.singleTextField.text!], withCompletionBlock: { (error, ref) in
                            if error != nil {
                                print(error!.localizedDescription)
                                SVProgressHUD.dismiss()
                                SVProgressHUD.showError(withStatus: error?.localizedDescription)
                            } else {
                                SVProgressHUD.dismiss()
                                self.delegate?.updateProfile(EditProfile.email, self.singleTextField.text!)
                                self.slideRightTransition()
                                self.dismiss(animated: false, completion: nil)
                            }
                        })
                    }
                })
            } else {
                SVProgressHUD.dismiss()
                singleErrorLabel.text = "Invalid email."
            }
            break
        default:
            break
        }
    }
    
    @IBAction func close(_ sender: UIButton) {
        slideRightTransition()
        self.dismiss(animated: false, completion: nil)
    }
    
    // MARK: Notification Center Methods
    @objc func keyboardWillShow(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo {
            let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            let keyboardHeight: CGFloat = ((userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)!
            
            UIView.animate(withDuration: duration) {
                self.contentViewBottomConstraint.constant = -keyboardHeight
                self.view.layoutIfNeeded()
            }
        }
    }
    @objc func keyboardWillHide(_ aNotification: NSNotification) {
        if let userInfo = aNotification.userInfo {
            let duration: TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            
            UIView.animate(withDuration: duration) {
                self.contentViewBottomConstraint.constant = 0
                self.view.layoutIfNeeded()
            }
        }
    }
    
    // MARK: Miscellaneous Methods
    func slideRightTransition() {
        let transition = CATransition()
        transition.duration = Durations.navigationDuration
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromLeft
        self.view.window?.layer.add(transition, forKey: nil)
    }
}
