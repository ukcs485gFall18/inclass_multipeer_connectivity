# inclass_multipeer_connectivity

![Swift Version 4.2](https://img.shields.io/badge/Swift-v4.2-yellow.svg)

This is a based off an original turorial by (http://www.appcoda.com/chat-app-swift-tutorial/) that was written in Swift 2.0. The code has been updated to Swift 4.2 and has many additions:
- Unique MCPeerID saved to UserDefaults per Apple's recommendations. This mitigates the issue of phantoms when MultipeerConnectivity is reinitialized
- MPCManger is completely seperated from the rest of the code
- Allows max connections for an individual session
- Much more...
