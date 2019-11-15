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
let kSegueChat                                          = "goToChat"
let kSegueGotoConnectedUsers                            = "goToConnectedUsers"

// MARK: - Local notifications
let kNotificationMPCIsInitialized                       = "mpcIsInitializedNotification"
let kNotificationCoreDataInitialized                    = "coreDataInitializedNotification" //Notify everyone waiting for CoreData to be initialized that it's ready
let kNotificationBrowserUserTappedCell                  = "browserUserTappedCell"
let kNotificationBrowserHasAddedUserToRoom              = "browserHasAddedUserToRoom"
//let kNotificationBrowserReceivedInvite                  = "browserReceivedInvite"
//let kNotificationBrowserReceivedInviteWhileConnected    = "browserReceivedInviteWhileConnected"
let kNotificationBrowserScreenNeedsToBeRefreshed        = "browserScreenNeedsToBeRefreshed"
let kNotificationChatRefreshRoom                        = "chatRefreshRoom"
let kNotificationChatPeerWasLost                        = "chatPeerWasLost"
let kNotificationChatNewMessagePosted                   = "chatNewMessagePosted"


// MARK: - Local notification keys
let kNotificationBrowserPeerDisplayName                 = "browserPeerDisplayNameKey"
let kNotificationBrowserRoomName                        = "browserRoomNameKey"
let kNotificationChatPeerHashKey                        = "chatPeerHashKey"
let kNotificationChatPeerUUIDKey                        = "chatPeerUUIDKey"
let kNotificationChatPeerNameKey                        = "chatPeerNameKey"
let kNotificationChatPeerMessageKey                     = "chatPeerMessageKey"


// MARK: - SendReceive Dictionary terms
let kCommunicationsMessageContentTerm                   = "communicationsMessage"
let kCommunicationsMessageUUIDTerm                      = "communicationsUUID"
let kCommunicationsRoomUUID                             = "communicationsRoomUUID"
let kCommunicationsRoomName                             = "communicationsRoomName"
let kCommunicationsRoomOwnerUUID                        = "communicationsRoomOwnerUUID"
let kCommunicationsEndConnectionTerm                    = "_end_chat_"
let kCommunicationsLostConnectionTerm                   = "_lost_connection_"

// MARK: - Browser UI Dictionary terms
let kBrowserCellPeerUUIDTerm                                = "peerUUID"


// MARK: - CoreData
let kCoreDataDBModel                                    = "mpc_chat"
let kCoreDataDBName                                     = "mpc_chatDB"

let kCoreDataEntityPeer                                 = "Peer"
let kCoreDataPeerAttributeCreatedAt                     = "createdAt"
let kCoreDataPeerAttributeModifiedAt                    = "modifiedAt"
let kCoreDataPeerAttributePeerUUID                      = "uuid"
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
