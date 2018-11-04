//
//  Message+CoreDataProperties.swift
//  mpc_chat
//
//  Created by Corey Baker on 11/1/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//
//

import Foundation
import CoreData


extension Message {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Message> {
        return NSFetchRequest<Message>(entityName: "Message")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var uuid: String
    @NSManaged public var modifiedAt: Date
    @NSManaged public var content: String
    @NSManaged public var room: Room
    @NSManaged public var owner: Peer

}
