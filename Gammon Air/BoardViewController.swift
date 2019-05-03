//
//  BoardViewController.swift
//  Gammon Air
//
//  Created by Rolf Locher on 4/30/19.
//  Copyright © 2019 Rolf Locher. All rights reserved.
//

import UIKit
import Firebase
import SceneKit

class BoardViewController: UIViewController {

    var gameID = String()
    var color = String()
    
    @IBOutlet var idLabel: UILabel!
    
    @IBOutlet var colorLabel: UILabel!
    
    @IBOutlet var turnLabel: UILabel!
    
    @IBOutlet var sceneView: SCNView!
    
    
    var mainScene : SCNScene!
    var cameraNode: SCNNode!
    
    var db : Firestore? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        idLabel.text = gameID
        colorLabel.text = color
        
        mainScene = SCNScene()
        sceneView.scene = mainScene
        
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 37.7, 0)
        cameraNode.rotation = SCNVector4(1, 0, 0, -1.57)
        mainScene.rootNode.addChildNode(cameraNode)
        
        var board:SCNGeometry
        board = SCNBox(width: 20.0, height: 0.5, length: 44.0, chamferRadius: 0.05)
        board.materials.first?.diffuse.contents = UIColor.red
        let boardNode = SCNNode(geometry: board)
        boardNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        boardNode.position = SCNVector3(0, 0, 0)
        mainScene.rootNode.addChildNode(boardNode)
        
        var geometry:SCNGeometry
        geometry = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.1)
        geometry.materials.first?.diffuse.contents = UIColor.cyan
        let geometryNode = SCNNode(geometry: geometry)
        geometryNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        geometryNode.position = SCNVector3(-8, 7, 8)
        let force = SCNVector3(x: 12, y: 2 , z: 0)
        let position = SCNVector3(x: 0.5, y: -0.5, z: 0.5)
        geometryNode.physicsBody?.applyForce(force, at: position, asImpulse: true)
        mainScene.rootNode.addChildNode(geometryNode)
        
        var geometry1:SCNGeometry
        geometry1 = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.1)
        geometry1.materials.first?.diffuse.contents = UIColor.cyan
        let geometryNode1 = SCNNode(geometry: geometry1)
        geometryNode1.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        geometryNode1.position = SCNVector3(8, 7, -8)
        let force1 = SCNVector3(x: -12, y: 2 , z: 0)
        let position1 = SCNVector3(x: 0.3, y: 0.5, z: -0.5)
        geometryNode1.physicsBody?.applyForce(force1, at: position1, asImpulse: true)
        mainScene.rootNode.addChildNode(geometryNode1)
        
        
        mainScene.physicsWorld.gravity.y = Float(-70.0)
        
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        
        
        
        db = Firestore.firestore()
        
        db?.collection("games").document(gameID).addSnapshotListener({ (snapshot, error) in
            self.turnLabel.text = snapshot?.data()?["turn"] as? String
        })
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
