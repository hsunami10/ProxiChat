//
//  ProfileCell.swift
//  ProxiChat
//
//  Created by Michael Hsu on 12/10/17.
//  Copyright © 2017 Michael Hsu. All rights reserved.
//

import UIKit

/*
 Get the height of each label and add the spacing between the two, subtract that from the cell height, divide by 2, and that number is the top and bottom padding of the title and content labels. They should equal.
 */
class ProfileCell: UITableViewCell {

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var contentLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
