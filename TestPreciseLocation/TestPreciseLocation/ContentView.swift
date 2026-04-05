//
//  ContentView.swift
//  TestPreciseLocation
//
//  Created by Jeffrey898 on 3/17/26.
//
// 9 8 5 1

import SwiftUI
import RealityKit
import ARKit

import NearbyInteraction
import MultipeerConnectivity

enum P2PRole {
    case None
    case Broadcast
    case Search
}

@Observable
class NearbyManager: NSObject {
    let DATA_COLLECTION_THRESHOLD: Float = 0.5
    
    var position: SIMD3<Float> = .zero
    var distance: Float = -1.0
    var niDirection: SIMD3<Float> = .zero
    var arView: ARView = ARView(frame: .zero)
    var targetPos: SIMD3<Float> = .zero
    var targetCount: Float = 0.0
    var target: SIMD3<Float> = .zero
    
    var positionCollected: [SIMD3<Float>] = []
    var distanceCollected: [Float] = []
    
    var dataCollection: [SIMD4<Float>] = []
    
    var prevTime: UInt64 = 0
    
    // Nearby Interaction
    private var niSession: NISession!

    private var myDiscoveryToken: NIDiscoveryToken?
    
    public var status: String = "App Initialized"

    // Multipeer
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name + UUID().uuidString)

    private var mcSession: MCSession!

    private var advertiser: MCNearbyServiceAdvertiser!

    private var browser: MCNearbyServiceBrowser!
    
    override init() {
        super.init()
//        setupMultipeer()
//        setupNearby()
    }
    
    func submitData() {
        print(dataCollection)
    }
    
    func begin(_ type: P2PRole) {
        print("begin is called")
        if status == "App Initialized" && type != P2PRole.None {
            status = "Searching . . ."
            setupMultipeer(type)
            setupNearby()
        }
    }

    func setupMultipeer(_ type: P2PRole) {
        mcSession = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        
        mcSession.delegate = self

        if type == P2PRole.Broadcast {
            advertiser = MCNearbyServiceAdvertiser(
                peer: myPeerID,
                discoveryInfo: nil,
                serviceType: "dir-demo"
            )
            
            advertiser.delegate = self
            advertiser.startAdvertisingPeer()

        } else if type == P2PRole.Search {
            browser = MCNearbyServiceBrowser(
                peer: myPeerID,
                serviceType: "dir-demo"
            )

            browser.delegate = self
            browser.startBrowsingForPeers()

        } else {
            print("unexpected error")
        }
    }
    
    func setupNearby() {
        niSession = NISession()
        niSession.delegate = self
        myDiscoveryToken = niSession.discoveryToken
        
        status = "Waiting for peer"
    }
    
    private func sendDiscoveryToken() {
        print("sending discovery token")
        guard let token = myDiscoveryToken else { return }
        let data = try! NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: true
        )
        
        try? mcSession.send(
            data,
            toPeers: mcSession.connectedPeers,
            with: .reliable
        )
    }
    
    private func startSession(with peerToken: NIDiscoveryToken) {
        print("starting NI Session")
        let config = NINearbyPeerConfiguration(peerToken: peerToken)
        niSession.run(config)
        
        // start ARView
        let arkit_config = ARWorldTrackingConfiguration()

        arkit_config.planeDetection = [.horizontal, .vertical]
        arkit_config.environmentTexturing = .automatic
        arkit_config.worldAlignment = .gravityAndHeading
        
        arView.session.run(
            arkit_config,
            options: [
                .resetTracking,
                .removeExistingAnchors
            ]
        )

        self.status = "Session running"
    }
}

extension NearbyManager: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        let now: UInt64 = DispatchTime.now().uptimeNanoseconds
        let dt: UInt64 = now - prevTime
        
//        if dt < UInt64(1e7) {
//            return
//        }
        
        prevTime = now
        // on receive update
        guard let obj = nearbyObjects.first else { return }
        
        distance = obj.distance ?? -1.0
        niDirection = obj.direction ?? .zero
        
        guard let frame = arView.session.currentFrame else { return }

        let transform = frame.camera.transform
        
        position.x = transform.columns.3.x
        position.y = transform.columns.3.y
        position.z = transform.columns.3.z
        
//        let intrinsic = frame.camera.intrinsics
//        let fx = intrinsic[0][0]
//        let fy = intrinsic[1][1]
//        
//        let imageResolution = frame.camera.imageResolution
//        let width = Float(imageResolution.width)
//        let height = Float(imageResolution.height)
//        
//        let fovX = 2 * atan(width / (2 * fx)) * (180 / .pi)
//        let fovY = 2 * atan(height / (2 * fy)) * (180 / .pi)
//
//        let right: SIMD3<Float> = SIMD3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)
//        let up: SIMD3<Float> = SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z)
//        let cosX = cos(fovX / 2)
//        let cosY = cos(fovY / 2)
//        
//        let up_dot = simd_dot(up, position)
        
        if position.x > 0.0001 || position.y > 0.0001 || position.z < 0.0001 {
            dataCollection.append(SIMD4<Float>(position.x, position.y, position.z, distance))
        } else {
            return
        }
        
        if positionCollected.count < 5 {
            // make sure the positions are not too close
            var valid = true
            for point in positionCollected {
                if position.x < 0.0001 && position.y < 0.0001 && position.z < 0.0001 {
                    valid = false
                }
                let length = simd_length(position - point)
                if length < DATA_COLLECTION_THRESHOLD {
                    valid = false
                }
                if positionCollected.count == 3 {
                    let ab = simd_normalize(position - positionCollected[1])
                    let ac = simd_normalize(position - positionCollected[2])
                    let abs_dot_prod = abs(simd_dot(ab, ac))
                    print(abs_dot_prod)
                    if abs_dot_prod > 0.85 {
                        valid = false
                    }
                } else if positionCollected.count == 4 {
                    let ab = simd_normalize(positionCollected[2] - positionCollected[1])
                    let ac = simd_normalize(positionCollected[3] - positionCollected[1])
                    let ad = simd_normalize(position - positionCollected[1])
                    let ref = simd_cross(ab, ac)
                    let abs_dot_prod = abs(simd_dot(ref, ad))
                    print(abs_dot_prod)
                    if abs_dot_prod < 0.15 {
                        valid = false
                    }
                }
            }
            
            if valid && (position.x > 0.0001 || position.y > 0.0001 || position.z > 0.0001) {
                positionCollected.append(position)
                distanceCollected.append(distance)
            } else {
                return
            }
        }
        
        print(positionCollected.count)
        if positionCollected.count >= 5 {
            let r = positionCollected[0]
            let p0 = positionCollected[1]
            let p1 = positionCollected[2]
            let p2 = positionCollected[3]
            let p3 = positionCollected[4]
            let dr = distanceCollected[0]
            let d0 = distanceCollected[1]
            let d1 = distanceCollected[2]
            let d2 = distanceCollected[3]
            let d3 = distanceCollected[4]
            let A = simd_float3x4(rows: [
                SIMD3<Float>(p0.x - r.x, p0.y - r.y, p0.z - r.z),
                SIMD3<Float>(p1.x - r.x, p1.y - r.y, p1.z - r.z),
                SIMD3<Float>(p2.x - r.x, p2.y - r.y, p2.z - r.z),
                SIMD3<Float>(p3.x - r.x, p3.y - r.y, p3.z - r.z)
            ])
            let y0 = dr * dr - d0 * d0 + p0.x * p0.x - r.x * r.x + p0.y * p0.y - r.y * r.y + p0.z * p0.z - r.z * r.z
            let y1 = dr * dr - d1 * d1 + p1.x * p1.x - r.x * r.x + p1.y * p1.y - r.y * r.y + p1.z * p1.z - r.z * r.z
            let y2 = dr * dr - d2 * d2 + p2.x * p2.x - r.x * r.x + p2.y * p2.y - r.y * r.y + p2.z * p2.z - r.z * r.z
            let y3 = dr * dr - d3 * d3 + p3.x * p3.x - r.x * r.x + p3.y * p3.y - r.y * r.y + p3.z * p3.z - r.z * r.z
            let y = SIMD4<Float>(0.5 * y0, 0.5 * y1, 0.5 * y2, 0.5 * y3)
            
            let AT = simd_transpose(A)
            
            print(positionCollected)
            print(distanceCollected)
            positionCollected.removeFirst()
            positionCollected.removeFirst()
            distanceCollected.removeFirst()
            distanceCollected.removeFirst()
            targetPos += simd_inverse(AT * A) * AT * y
            targetCount += 1
            target = targetPos / targetCount
        }
    }

     
}

extension NearbyManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // on state change
        print("sending token?")
        print(state)
        if state == .connected {
            // SEND DISCOVERY TOKEN
            print("yup, sending token")
            sendDiscoveryToken()
        } else if state == .notConnected {
            print("not connected")
        } else if state == .connecting {
            print("connecting?")
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("receiving data")
        // on receive data
        if let token = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self,
            from: data
        ) {
            // START SESSION
            startSession(with: token)
        }
    }
    
    func session(_ session: MCSession, didReceive certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        // on certificate sent
        certificateHandler(true)
    }
    
    func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {
        // on receive stream
        print("received stream")
    }
    
    func session(_: MCSession, didStartReceivingResourceWithName _: String, fromPeer _: MCPeerID, with _: Progress) {
        //start receiving resources
        print("received resources")
    }
    
    func session(_: MCSession, didFinishReceivingResourceWithName _: String, fromPeer _: MCPeerID, at _: URL?, withError _: Error?) {
        // finish receiving resources
        print("finished receiving resources")
    }
}

extension NearbyManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // on receive invitation
        
        print("invitation accepted")
        invitationHandler(true, mcSession)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
        // on error
        print("advertiser error")
    }
}

extension NearbyManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        // browser found a peer
        browser.invitePeer(peerID, to: mcSession, withContext: nil, timeout: 10)
        print("inviting peer")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // browser lost a peer
        print("browser lost peer")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
        // browsing error
        print("browser error")
    }
}

struct ContentView: View {

    @State private var arView = ARView(frame: .zero)
    @State private var positionText = "Position: (0,0,0)"
    
    @State private var locations: [String] = []
    
    @State private var preciseLocator: NearbyManager = NearbyManager();

    var body: some View {
        Circle()              // Circle shape
                    .fill(Color.red)  // Dot color
                    .frame(width: 20, height: 20) // Dot size
                    .position(x: 100, y: 100)     // Dot position
        ZStack {

            VStack {

                Text("Position: \(preciseLocator.position.x), \(preciseLocator.position.y), \(preciseLocator.position.z)")
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 60)
                
                Text("Distance: " + String(preciseLocator.distance))
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                
                Text("NIDir \(preciseLocator.niDirection.x), \(preciseLocator.niDirection.y), \(preciseLocator.niDirection.z)")
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                
                Text("Target: \(preciseLocator.target.x), \(preciseLocator.target.y), \(preciseLocator.target.z)")
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                Text("Target - self: \(preciseLocator.target.x - preciseLocator.position.x), \(preciseLocator.target.y - preciseLocator.position.y), \(preciseLocator.target.z - preciseLocator.position.z)")
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                
                Text("Status: " + preciseLocator.status)
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 60)
                
                Text("Count: \(preciseLocator.positionCollected.count)")
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 60)

                Spacer()
                
                Button(action: {
                    preciseLocator.submitData()
                }) {
                    Text("SubmitData")
                        .font(.headline)
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                }
                
                Button(action: {
                    beginNI(P2PRole.Broadcast)
                }) {
                    Text("Broadcast Device")
                        .font(.headline)
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                }
                
                Button(action: {
                    beginNI(P2PRole.Search)
                }) {
                    Text("Search Device")
                        .font(.headline)
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                }

//                Button(action: {
//                    resetTracking()
//                }) {
//                    Text("Start / Reset Tracking")
//                        .font(.headline)
//                        .padding()
//                        .background(Color.white.opacity(0.9))
//                        .cornerRadius(12)
//                }
//                .padding(.bottom, 40)
            }
        }
//        .onAppear {
//            startPositionUpdates()
//        }
    }
    
    func beginNI(_ type: P2PRole) {
        preciseLocator.begin(type)
    }

    func startPositionUpdates() {

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in

            guard let frame = arView.session.currentFrame else { return }

            let transform = frame.camera.transform

            let x = transform.columns.3.x
            let y = transform.columns.3.y
            let z = transform.columns.3.z

            positionText = String(format: "Position: (%.3f, %.3f, %.3f)", x, y, z)
            
            locations.append(positionText)
            while (locations.count > 5) {
                locations.remove(at: 0)
            }
            print(locations)
        }
    }

    func resetTracking() {

        let config = ARWorldTrackingConfiguration()

        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        config.worldAlignment = .gravityAndHeading

        arView.session.run(
            config,
            options: [
                .resetTracking,
                .removeExistingAnchors
            ]
        )

    }
}

#Preview {
    ContentView()
}
