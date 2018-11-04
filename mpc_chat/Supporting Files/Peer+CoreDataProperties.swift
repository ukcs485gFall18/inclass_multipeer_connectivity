//
//  Peer+CoreDataProperties.swift
//  mpc_chat
//
//  Created by Corey Baker on 11/1/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//
//

import Foundation
import CoreData


extension Peer {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Peer> {
        return NSFetchRequest<Peer>(entityName: "Peer")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var lastConnected: Date?
    @NSManaged public var lastSeen: Date
    @NSManaged public var modifiedAt: Date
    @NSManaged public var peerHash: Int
    @NSManaged public var peerName: String
    @NSManaged public var messages: Set<Message>?
    @NSManaged public var rooms: Set<Room>?
    @NSManaged public var peersInRooms: Set<Peer>?

}

// MARK: Generated accessors for messages
extension Peer {

    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: Message)

    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: Message)

    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: Set<Message>)

    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: Set<Message>)

}

// MARK: Generated accessors for rooms
extension Peer {

    @objc(addRoomsObject:)
    @NSManaged public func addToRooms(_ value: Room)

    @objc(removeRoomsObject:)
    @NSManaged public func removeFromRooms(_ value: Room)

    @objc(addRooms:)
    @NSManaged public func addToRooms(_ values: Set<Room>)

    @objc(removeRooms:)
    @NSManaged public func removeFromRooms(_ values: Set<Room>)

}

// MARK: Generated accessors for peersInRooms
extension Peer {

    @objc(addPeersInRoomsObject:)
    @NSManaged public func addToPeersInRooms(_ value: Room)

    @objc(removePeersInRoomsObject:)
    @NSManaged public func removeFromPeersInRooms(_ value: Room)

    @objc(addPeersInRooms:)
    @NSManaged public func addToPeersInRooms(_ values: Set<Room>)

    @objc(removePeersInRooms:)
    @NSManaged public func removeFromPeersInRooms(_ values: Set<Room>)

}
