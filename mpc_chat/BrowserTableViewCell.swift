//
//  BrowserTableViewCell.swift
//  mpc_chat
//
//  Created by Corey Baker on 10/25/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//

import UIKit

class BrowserTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    @IBOutlet weak var peerNameLabel: UILabel!
    @IBOutlet weak var isPeerLabel: UILabel!
    
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
