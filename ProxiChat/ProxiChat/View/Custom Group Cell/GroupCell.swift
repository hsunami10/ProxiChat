//
//  GroupCell.swift
//  ProxiChat
//
//  Created by Michael Hsu on 11/15/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit

class GroupCell: UITableViewCell {

    @IBOutlet var groupName: UILabel! // TODO: Limit based on label width - use extensions in String
    @IBOutlet var numberOfMembers: UILabel! // Max: 9999
    @IBOutlet var lockIcon: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}
