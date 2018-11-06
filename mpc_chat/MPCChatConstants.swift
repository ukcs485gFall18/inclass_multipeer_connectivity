//
//  MPCConstants.swift
//
//
//  Created by Corey Baker on 10/9/18.
//  Copyright © 2018 University of Kentucky - CS 485G. All rights reserved.
//

import Foundation

let kAppName                                            = "mpcchat"
let kPeerID                                             = "uniquePeerIDs"
let kAdvertisingUUID                                    = "uuid"
let kDefaultsKeyFirstRun                                = "FirstRun"

// MARK: - Segues
let kSegueChat                                          = "idSegueChat"

// MARK: - Local notifications
let kNotificationMPCIsInitialized                       = "mpcIsInitializedNotification"
let kNotificationCoreDataInitialized                    = "coreDataInitializedNotification" //CoreData notifies appDelega
let kNotificationCoreDataIsReady                        = "coreDataIsReadyNotification" //After setting CoreData flags, notifies everyone else
let kNotificationBrowserUserTappedCell                  = "browserUserTappedCell"

// MARK: - SendReceive Dictionary terms
let kCommunicationsMessageContentTerm                   = "message"
let kCommunicationsMessageUUIDTerm                      = "uuid"
let kCommunicationsEndConnectionTerm                    = "_end_chat_"
let kCommunicationsLostConnectionTerm                   = "_lost_connection_"

// MARK: - Browser UI Dictionary terms
let kBrowserPeerUUIDTerm                                = "peerUUID"
let kBrowserPeerRoomUUID                                = "roomUUID"
let kBrowserPeerRoomName                                = "roomName"

// MARK: - CoreData
let kCoreDataDBModel                                    = "mpc_chat"
let kCoreDataDBName                                     = "mpc_chatDB"

let kCoreDataEntityPeer                                 = "Peer"
let kCoreDataPeerAttributeCreatedAt                     = "createdAt"
let kCoreDataPeerAttributeModifiedAt                    = "modifiedAt"
let kCoreDataPeerAttributepeerUUID                      = "uuid"
let kCoreDataPeerAttributePeerName                      = "peerName"
let kCoreDataPeerAttributeLastConnected                 = "lastConnected"
let kCoreDataPeerAttributeLastSeen                      = "lastSeen"

let kCoreDataEntityRoom                                 = "Room"
let kCoreDataRoomAttributeCreatedAt                     = "createdAt"
let kCoreDataRoomAttributeModifiedAt                    = "modifiedAt"
let kCoreDataRoomAttributeName                          = "name"
let kCoreDataRoomAttributeUUID                          = "uuid"
let kCoreDataRoomAttributeMessages                      = "messages"
let kCoreDataRoomAttributeOwner                         = "owner"
let kCoreDataRoomAttributePeers                         = "peers"

let kCoreDataEntityMessage                              = "Message"
let kCoreDataMessageAttributeCreatedAt                  = "createdAt"
let kCoreDataMessageAttributeModifiedAt                 = "modifiedAt"
let kCoreDataMessageAttributeContent                    = "content"
let kCoreDataMessageAttributeRoom                       = "room"
let kCoreDataMessageAttributeOwner                      = "owner"
let kCoreDataMessageAttributeUUID                       = "uuid"
