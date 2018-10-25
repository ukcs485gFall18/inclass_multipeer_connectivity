//
//  Peers+CoreDataProperties.swift
//  mpc_chat
//
//  Created by Baker, Corey on 10/25/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//
//

import Foundation
import CoreData


extension Peers {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Peers> {
        return NSFetchRequest<Peers>(entityName: "Peers")
    }

    @NSManaged public var lastConnected: Date?
    @NSManaged public var lastSeen: Date?
    @NSManaged public var peerHash: String?

}
