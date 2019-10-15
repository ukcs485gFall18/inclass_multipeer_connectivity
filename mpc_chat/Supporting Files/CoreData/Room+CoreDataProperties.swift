//
//  Room+CoreDataProperties.swift
//  mpc_chat
//
//  Created by Corey Baker on 11/1/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//
//

import Foundation
import CoreData


extension Room {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Room> {
        return NSFetchRequest<Room>(entityName: "Room")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date
    @NSManaged public var name: String
    @NSManaged public var uuid: String
    @NSManaged public var messages: Set<Message>?
    @NSManaged public var owner: Peer
    @NSManaged public var peers: Set<Peer>

}

// MARK: Generated accessors for messages
extension Room {

    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: Message)

    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: Message)

    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: Set<Message>)

    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: Set<Message>)

}

// MARK: Generated accessors for peers
extension Room {

    @objc(addPeersObject:)
    @NSManaged public func addToPeers(_ value: Peer)

    @objc(removePeersObject:)
    @NSManaged public func removeFromPeers(_ value: Peer)

    @objc(addPeers:)
    @NSManaged public func addToPeers(_ values: Set<Peer>)

    @objc(removePeers:)
    @NSManaged public func removeFromPeers(_ values: Set<Peer>)

}
