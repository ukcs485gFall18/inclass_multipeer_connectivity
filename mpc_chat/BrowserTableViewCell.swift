//
//  BrowserTableViewCell.swift
//  mpc_chat
//
//  Created by Corey Baker on 10/25/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//

import UIKit

class BrowserTableViewCell: UITableViewCell {

    @IBOutlet weak var peerNameLabel: UILabel!
    @IBOutlet weak var isPeerLabel: UILabel!
    @IBOutlet weak var lastConnectedLabel: UILabel!
    @IBOutlet weak var lastSeenLabel: UILabel!
    
    var peerUUID = ""
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code

    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if isSelected{
            // Configure the view for the selected state
            let info: [String:Any] = [kBrowserpeerUUIDTerm: peerUUID]
            let notification = Notification(name: .init(kNotificationBrowserUserTappedCell), object: info, userInfo: nil)
            
            NotificationCenter.default.post(notification)
        }
    }

}
