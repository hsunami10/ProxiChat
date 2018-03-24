//
//  MessageCell.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/18/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit

class MessageCell: UITableViewCell {
    // TODO: Add date
    @IBOutlet var userPicture: UIImageView!
    @IBOutlet var username: UILabel!
    @IBOutlet var content: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        username.font = Font.getFont(15)
        content.font = Font.getFont(16)
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
