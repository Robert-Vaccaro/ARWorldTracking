//
//  ViewController.swift
//  ARWorldTracking
//
//  Created by Bobby on 4/8/21.
//


import UIKit
import SceneKit
import ARKit
import SocketIO

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, ARSessionObserver {
    //The URL string must be http://YourNetworkIPAddress:8080
    //Phone and server must be on the same wifi if using localhost test server.
    let manager = SocketManager(socketURL: URL(string: "http://10.0.0.23:8080")!, config: [.log(true), .compress])
    var socket:SocketIOClient!
    var name: String?
    var resetAck: SocketAckEmitter?
    var mutexlock = false;
    
    let defaultConfiguration: ARWorldTrackingConfiguration = {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.isLightEstimationEnabled = false
        configuration.worldAlignment = .gravity
        configuration.environmentTexturing = .none
        return configuration
    }()
    
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var resetBtn: UIButton!
    @IBOutlet weak var eulerAnglesLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationLabel.layer.cornerRadius = 3
        locationLabel.layer.masksToBounds = true
        
        eulerAnglesLabel.layer.cornerRadius = 3
        eulerAnglesLabel.layer.masksToBounds = true
        
        resetBtn.layer.cornerRadius = 3
        
        socket = manager.defaultSocket
        addHandlers()
        socket.connect()
        
        sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        
        sceneView.delegate = self
        sceneView.session.delegate = self
    }
    
    func addHandlers() {
        socket.on("connect") { _, _ in
            print("socket connected")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Run the view's session
        sceneView.autoenablesDefaultLighting = true;
        sceneView.session.run(defaultConfiguration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    @IBAction func resetBtnPress(_ sender: Any) {
        resetWorldCenter()
    }
    
    // Resets the center of the world to current position of the camera.
    func resetWorldCenter(){
        sceneView.session.pause()
        sceneView.session.run(defaultConfiguration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func updateContentNodeCache(targTransforms: Array<SKWorldTransform>, cameraTransform:SCNMatrix4) {
        for transform in targTransforms {
            
            let targTransform = SCNMatrix4Mult(transform.transform, cameraTransform);
            
            if let box = findCube(arucoId: Int(transform.arucoId)) {
                box.setWorldTransform(targTransform);
                
            } else {
                
                let arucoCube = ArucoNode(arucoId: Int(transform.arucoId))
                sceneView.scene.rootNode.addChildNode(arucoCube);
                // Relocalize center of world once an Aruco Box is detected and created.
                resetWorldCenter()
                arucoCube.setWorldTransform(targTransform);
            }
        }
    }
    
    func findCube(arucoId:Int) -> ArucoNode? {
        for node in sceneView.scene.rootNode.childNodes {
            if node is ArucoNode {
                let box = node as! ArucoNode
                if (arucoId == box.id) {
                    return box
                }
            }
        }
        return nil
    }
    
    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        if self.mutexlock {
            return;
        }
        /*
         To calculate the distance from the root node's position to the camera position.
         let distance = simd_distance(sceneView.scene.rootNode.simdTransform.columns.3, (frame.camera.transform.columns.3)!);
         */
        let cameraRotation = frame.camera.eulerAngles
        let cameraLocation = frame.camera.transform.columns.3
        print(cameraLocation.x, cameraLocation.y, cameraLocation.z)
        /*
         Pitch (the x component) is the rotation about the node’s x-axis.
         Yaw (the y component) is the rotation about the node’s y-axis.
         Roll (the z component) is the rotation about the node’s z-axis.
         */
        
        
        self.socket.emit("location", ["x":cameraLocation.x, "y":cameraLocation.y,"z":cameraLocation.z])
        self.socket.emit("rotation", ["x":cameraRotation.x, "y":cameraRotation.y,"z":cameraRotation.z])
        self.socket.emit("image", ["image",sceneView.snapshot().jpegData(compressionQuality: 0.5)])
        
        DispatchQueue.main.async {
            self.locationLabel.text = """
                Camera Location:
                X: \(cameraLocation.x)
                Y: \(cameraLocation.y)
                Z: \(cameraLocation.z)
                """
            self.eulerAnglesLabel.text = """
                Camera Euler Angles:
                X: \(cameraRotation.x)
                Y: \(cameraRotation.y)
                Z: \(cameraRotation.z)
                """
        }
        
        self.mutexlock = true;
        let pixelBuffer = frame.capturedImage
        
        // 1) cv::aruco::detectMarkers
        // 2) cv::aruco::estimatePoseSingleMarkers
        // 3) transform offset and rotation of marker's corners in OpenGL coords
        // 4) return them as an array of matrixes
        let transMatrixArray:Array<SKWorldTransform> = ArucoCV.estimatePose(pixelBuffer, withIntrinsics: frame.camera.intrinsics, andMarkerSize: Float64(ArucoProperty.ArucoMarkerSize)) as! Array<SKWorldTransform>;
        
        
        if(transMatrixArray.count == 0) {
            self.mutexlock = false;
            return;
        }
        
        let cameraMatrix = SCNMatrix4.init(frame.camera.transform);
        
        DispatchQueue.main.async(execute: {
            self.updateContentNodeCache(targTransforms: transMatrixArray, cameraTransform:cameraMatrix)
            
            self.mutexlock = false;
        })
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        //        NSLog("%s", __FUNC__)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        
    }
    
    // MARK: - ARSessionObserver
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    }
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }

}
