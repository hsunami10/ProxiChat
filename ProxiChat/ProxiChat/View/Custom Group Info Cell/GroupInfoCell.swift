//
//  GroupInfoCell.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/23/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit

class GroupInfoCell: UITableViewCell {

    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var descriptionImage: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
