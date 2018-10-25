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
let kDefaultsKeyFirstRun                                = "FirstRun"

// MARK: - Local notifications
let kNotificationMPCDisconnetion                        = "receivedMPCDisconnectionNotification"
let kNotificationMPCDataReceived                        = "receivedMPCChatDataNotification"
let kNotificationMPCCoreDataInitialized                 = "coreDataInitializedNotification"

// MARK: - SendReceive Dictionary terms
let kCommunicationsMessageTerm                          = "message"
let kCommunicationsSenderTerm                           = "sender"
let kCommunicationsSelfTerm                             = "self"
let kCommunicationsFromPeerTerm                         = "fromPeer"
let kCommunicationsDataTerm                             = "data"
let kCommunicationsEndConnectionTerm                    = "_end_chat_"
let kCommunicationsLostConnectionTerm                   = "_lost_connection_"

// MARK: - CoreData
let kCoreDataDBModel                                    = "mpc_chat"
let kCoreDataDBName                                     = "mpc_chatDB"

let kCoreDataEntityPeers                                = "Peers"
