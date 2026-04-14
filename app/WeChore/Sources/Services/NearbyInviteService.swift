import Foundation
import MultipeerConnectivity
#if canImport(NearbyInteraction)
import NearbyInteraction
#endif

@MainActor
public protocol NearbyInviteExchanging {
    func startAdvertising(payload: InvitePayload) async
    func startBrowsing() async
    func stop()
}

public enum NearbyInviteConstants {
    public static let serviceType = "wchore-chat"
}

@MainActor
public final class AppleNearbyInviteExchange: NSObject, NearbyInviteExchanging {
    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiserAssistant: MCAdvertiserAssistant?
    #if canImport(NearbyInteraction)
    private var nearbySession: NISession?
    #endif

    public override init() {}

    public func startAdvertising(payload: InvitePayload) async {
        let peerID = MCPeerID(displayName: "WeChore")
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        let assistant = MCAdvertiserAssistant(
            serviceType: NearbyInviteConstants.serviceType,
            discoveryInfo: [
                "code": payload.code,
                "thread": payload.threadID
            ],
            session: session
        )
        self.peerID = peerID
        self.session = session
        advertiserAssistant = assistant
        assistant.start()

        #if canImport(NearbyInteraction)
        if NISession.deviceCapabilities.supportsPreciseDistanceMeasurement {
            nearbySession = NISession()
        }
        #endif
    }

    public func startBrowsing() async {
        let peerID = MCPeerID(displayName: "WeChore")
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        self.peerID = peerID
        self.session = session
        _ = MCBrowserViewController(serviceType: NearbyInviteConstants.serviceType, session: session)
    }

    public func stop() {
        advertiserAssistant?.stop()
        advertiserAssistant = nil
        session?.disconnect()
        session = nil
        peerID = nil
        #if canImport(NearbyInteraction)
        nearbySession?.invalidate()
        nearbySession = nil
        #endif
    }
}

@MainActor
public final class FakeNearbyInviteExchange: NearbyInviteExchanging {
    public private(set) var advertisedPayload: InvitePayload?
    public private(set) var didBrowse = false

    public init() {}

    public func startAdvertising(payload: InvitePayload) async {
        advertisedPayload = payload
    }

    public func startBrowsing() async {
        didBrowse = true
    }

    public func stop() {
        advertisedPayload = nil
        didBrowse = false
    }
}
