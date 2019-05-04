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

protocol BoardViewDelegate : class {
    func dismissBoard()
}

class BoardViewController: UIViewController {

    weak var boardViewDelegate0 : BoardViewDelegate?
    
    var gameID = String()
    var color = String()
    var myDice = String()
    var notMyDice = String()
    var isHost = Bool()
    var turn = String()
    var roll = [Int]()
    
    @IBOutlet var sceneView: SCNView!
    
    @IBOutlet var returnButton: UIImageView!
    
    @IBOutlet var debugLabel: UILabel!
    
    
    var mainScene : SCNScene!
    var cameraNode: SCNNode!
    
    var db : Firestore? = nil
    var ref : ListenerRegistration?
    var ref1 : ListenerRegistration?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("you are \(color)")
        
        setupScene()
        
        myDice = color == "white" ? "dice0" : "dice1"
        notMyDice = color != "white" ? "dice0" : "dice1"
        debugLabel.text = myDice + color + " "
        
        db = Firestore.firestore()
        
        initialRoll()
        
        
        
        let returnTap = UITapGestureRecognizer(target: self, action: #selector(returnTapped))
        returnButton.addGestureRecognizer(returnTap)
        returnButton.isUserInteractionEnabled = true
    }
    
    func afterRoll () {
        ref1 = db?.collection("games").document(gameID).addSnapshotListener({ (snapshot, error) in
            if snapshot?.data()?["turn"] == nil || snapshot?.data()?["turn"] as! String != self.color {
                return
            }
            
            
        })
    }
    
    func killInitialRoll() {
        ref?.remove()
    }
    
    func initialRoll () {
        let force = SCNVector3(x: color == "white" ? 12 : -12, y: 2 , z: Float.random(in: -0.5..<0.5))
        let position = SCNVector3(x: Float.random(in: -0.5..<0.5), y: Float.random(in: -0.5..<0.5), z: Float.random(in: -0.5..<0.5))
        db?.collection("games").document(gameID).setData([
            myDice : [force.x, force.y, force.z, position.x, position.y, position.z],
            ], merge: true)
        
        ref = db?.collection("games").document(gameID).addSnapshotListener({ (snapshot, error) in
            if snapshot?.data()?[self.notMyDice] == nil || snapshot?.data()?[self.myDice] == nil{
                return
            }
            if (snapshot?.data()?[self.notMyDice] as! [Float]).count == 1 && (snapshot?.data()?[self.myDice] as! [Float]).count == 1 {
                self.killInitialRoll()
                self.initialRoll()
            }
            else if (snapshot?.data()?[self.notMyDice] as! [Float]).count == 1 ||  (snapshot?.data()?[self.myDice] as! [Float]).count == 1{
                return
            }
            
            if snapshot?.data()?["turn"] == nil {
                let vector0 = snapshot?.data()?["dice0"] as! [Float]
                let vector1 = snapshot?.data()?["dice1"] as! [Float]
                self.throwDice(initial: true, dice0Ballistics: [SCNVector3(vector0[0], vector0[1], vector0[2]), SCNVector3(vector0[3], vector0[4], vector0[5])], dice1Ballistics: [SCNVector3(vector1[0], vector1[1], vector1[2]), SCNVector3(vector1[3], vector1[4], vector1[5])])
                DispatchQueue.main.asyncAfter(deadline: .now()+6, execute: {
                    self.roll = self.getDice()
                    if self.roll[self.color == "white" ? 0 : 1] > self.roll[self.color != "white" ? 0 : 1] {
                        if self.color == "white" {
                            print("u are white and you go first w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : "white"], merge: true)
                            self.debugLabel.text = self.debugLabel.text! + "white turn, u go"
                            self.killInitialRoll()
                            self.afterRoll()
                        }
                        else {
                            print("u are black and you go first w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : "black"], merge: true)
                            self.debugLabel.text = self.debugLabel.text! + "black turn, u go"
                            self.killInitialRoll()
                            self.afterRoll()
                        }
                    }
                    else if self.roll[self.color == "white" ? 0 : 1] < self.roll[self.color != "white" ? 0 : 1] {
                        if self.color == "white" {
                            print("u are white and you go after w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : "black"], merge: true)
                            self.debugLabel.text = self.debugLabel.text! + "black turn, not u"
                            self.killInitialRoll()
                            self.afterRoll()
                        }
                        else {
                            print("u are black and you go after w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : "white"], merge: true)
                            self.debugLabel.text = self.debugLabel.text! + "white turn, not u"
                            self.killInitialRoll()
                            self.afterRoll()
                        }
                        
                    }
                    else {
                        self.db?.collection("games").document(self.gameID).setData([
                            self.myDice : [1]])
                    }
                })
            }
        })
    }
    
    func throwDice(initial : Bool, dice0Ballistics : [SCNVector3], dice1Ballistics : [SCNVector3]) {
        var dice0Position = SCNVector3()
        var dice1Position = SCNVector3()
        if initial {
            dice0Position = SCNVector3(-8, 7, 8)
            dice1Position = SCNVector3(8, 7, -8)
        }
        else {
            dice0Position = SCNVector3(-7, 7, 8)
            dice1Position = SCNVector3(-9, 7, 8)
        }
        var geometry:SCNGeometry
        geometry = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.1)
        geometry.materials.first?.diffuse.contents = UIColor.cyan
        geometry.firstMaterial?.diffuse.contents = UIColor.cyan
        let geometryNode0 = SCNScene(named: "scnModels.scnassets/die.scn")!
        let geometryNode = geometryNode0.rootNode.childNodes.first!
        
        geometryNode.scale = SCNVector3(0.5, 0.5, 0.5)
        geometryNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        geometryNode.position = dice0Position
        let force = dice0Ballistics[0]//SCNVector3(x: 12, y: 2 , z: Float.random(in: -0.5..<0.5))
        let position = dice0Ballistics[1]//SCNVector3(x: Float.random(in: -0.5..<0.5), y: Float.random(in: -0.5..<0.5), z: Float.random(in: -0.5..<0.5))
        geometryNode.physicsBody?.applyForce(force, at: position, asImpulse: true)
        mainScene.rootNode.addChildNode(geometryNode)
        
        var geometry1:SCNGeometry
        geometry1 = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.1)
        geometry1.materials.first?.diffuse.contents = UIColor.cyan
        let geometryNode10 = SCNScene(named: "scnModels.scnassets/die.scn")!
        let geometryNode1 = geometryNode10.rootNode.childNodes.first!
        geometryNode1.scale = SCNVector3(0.5, 0.5, 0.5)
        geometryNode1.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        geometryNode1.position = dice1Position
        let force1 = dice1Ballistics[0]//SCNVector3(x: -12, y: 2 , z: Float.random(in: -0.5..<0.5))
        let position1 = dice1Ballistics[1]//SCNVector3(x: Float.random(in: -0.5..<0.5), y: Float.random(in: -0.5..<0.5), z: Float.random(in: -0.5..<0.5))
        geometryNode1.physicsBody?.applyForce(force1, at: position1, asImpulse: true)
        mainScene.rootNode.addChildNode(geometryNode1)
    }
    
    func setupScene() {
        mainScene = SCNScene()
        sceneView.scene = mainScene
        
        mainScene.physicsWorld.gravity.y = Float(-95.0)
        
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 37.7, 0)
        cameraNode.rotation = SCNVector4(1, 0, 0, -1.57)
        mainScene.rootNode.addChildNode(cameraNode)
        
        var board:SCNGeometry
        board = SCNBox(width: 22.0, height: 0.5, length: 32.0, chamferRadius: 0.05)
        board.materials.first?.diffuse.contents = UIImage(named: "board.jpg")
        let boardNode = SCNNode(geometry: board)
        
        boardNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        boardNode.physicsBody?.friction = 0.9
        boardNode.position = SCNVector3(0, 0, 0.3)
        mainScene.rootNode.addChildNode(boardNode)
        
        let pieceHeight : CGFloat = 0.5
        let pieceRadius : CGFloat = 0.90
        let sep = 1.82
        for x in 1..<31 {
            var p0:SCNGeometry
            p0 = SCNCylinder(radius: pieceRadius, height: pieceHeight)
            p0.materials.first?.diffuse.contents = UIColor.red
            let p0n = SCNNode(geometry: p0)
            p0n.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
            if x > 15 {
                p0.materials.first?.diffuse.contents = UIColor.darkGray
            }
            else {
                p0.materials.first?.diffuse.contents = UIColor.white
            }
            switch x {
            case 1:
                p0n.position = SCNVector3(-9, 0.5, 15.1)
            case 2:
                p0n.position = SCNVector3(-9+sep, 0.5, 15.1)
            case 3:
                p0n.position = SCNVector3(-9, 0.5, -14.3)
            case 4:
                p0n.position = SCNVector3(-9+sep, 0.5, -14.3)
            case 5:
                p0n.position = SCNVector3(-9+sep*2, 0.5, -14.3)
            case 6:
                p0n.position = SCNVector3(-9+sep*3, 0.5, -14.3)
            case 7:
                p0n.position = SCNVector3(-9+sep*4, 0.5, -14.3)
            case 8:
                p0n.position = SCNVector3(9, 0.5, 2.3)
            case 9:
                p0n.position = SCNVector3(9-sep, 0.5, 2.3)
            case 10:
                p0n.position = SCNVector3(9-sep*2, 0.5, 2.3)
            case 11:
                p0n.position = SCNVector3(9-sep*3, 0.5, 2.3)
            case 12:
                p0n.position = SCNVector3(9-sep*4, 0.5, 2.3)
            case 13:
                p0n.position = SCNVector3(9, 0.5, -2.3)
            case 14:
                p0n.position = SCNVector3(9-sep, 0.5, -2.3)
            case 15:
                p0n.position = SCNVector3(9-sep*2, 0.5, -2.3)
            case 16:
                p0n.position = SCNVector3(9, 0.5, 15.1)
            case 17:
                p0n.position = SCNVector3(9-sep, 0.5, 15.1)
            case 18:
                p0n.position = SCNVector3(-9, 0.5, 2.3)
            case 19:
                p0n.position = SCNVector3(-9+sep, 0.5, 2.3)
            case 20:
                p0n.position = SCNVector3(-9+sep*2, 0.5, 2.3)
            case 21:
                p0n.position = SCNVector3(-9+sep*3, 0.5, 2.3)
            case 22:
                p0n.position = SCNVector3(-9+sep*4, 0.5, 2.3)
            case 23:
                p0n.position = SCNVector3(-9, 0.5, -2.3)
            case 24:
                p0n.position = SCNVector3(-9+sep, 0.5, -2.3)
            case 25:
                p0n.position = SCNVector3(-9+sep*2, 0.5, -2.3)
            case 26:
                p0n.position = SCNVector3(9, 0.5, -14.3)
            case 27:
                p0n.position = SCNVector3(9-sep, 0.5, -14.3)
            case 28:
                p0n.position = SCNVector3(9-sep*2, 0.5, -14.3)
            case 29:
                p0n.position = SCNVector3(9-sep*3, 0.5, -14.3)
            case 30:
                p0n.position = SCNVector3(9-sep*4, 0.5, -14.3)
            default:
                p0n.position = SCNVector3(-9, 0.5, 15.1)
            }
            if x <= 2 {
                
            }
            mainScene.rootNode.addChildNode(p0n)
            
            
        }
        
    }
    
    func getDice() -> [Int] {
        var diceList = [Int]()
        for x in 2..<4 {
            let angles = self.mainScene.rootNode.childNodes[x].presentation.eulerAngles
            print(angles)
            
            if (angles.x > 3 || angles.x < -3) && (angles.z < -3 || angles.z > 3) {
                diceList.append(1)
            }
            else if (angles.z > -0.2 && angles.z < 0.2) && (angles.x > -0.2 && angles.x < 0.2) {
                diceList.append(1)
            }
                
                
            else if (angles.y > 2.4 || angles.y < -2.6) && (angles.z < -1.35 && angles.z > -1.75) {
                diceList.append(2)
            }
            else if (angles.y > -0.8 && angles.y < 0.9) && (angles.z > 1.35 && angles.z < 2.2) {
                diceList.append(2)
            }
                //        else if (angles.x > 2.5 && angles.x < -2.5) && (angles.z > 1.35 && angles.z < 2.2)  {
                //            self.colorLabel.text = "Two"
                //        }
                //        else if (angles.x > 1.35 && angles.x < 1.75) && (angles.y < -1.35 && angles.y > -1.75) {
                //            self.colorLabel.text = "Two"
                //        }
                //        else if (angles.x < -1.35 && angles.x > -1.75) && (angles.y > 1.35 && angles.y < 1.75) {
                //            self.colorLabel.text = "Two"
                //        }
                
                
                
            else if (angles.z > -0.2 && angles.z < 0.2) && (angles.x > 1.35 && angles.x < 1.75) {
                diceList.append(3)
            }
            else if (angles.z > 3 || angles.z < -3) && (angles.x < -1.35 && angles.x > -1.75) {
                diceList.append(3)
            }
                
                
            else if (angles.z > -0.2 && angles.z < 0.2) && (angles.x < -1.35 && angles.x > -1.75) {
                diceList.append(4)
            }
            else if (angles.z > 2.6 || angles.z < -2.6) && (angles.x > 1.35 && angles.x < 1.75) {
                diceList.append(4)
            }
                
                
                //        else if (angles.x > -1.2 && angles.x < 1.2) && (angles.z < -1.35 && angles.z > -1.75) {
                //            self.colorLabel.text = "Five"
                //            print("other classic five")
                //        }
                //        else if (angles.x > 3 || angles.x < -3) && (angles.x > 1.35 && angles.x < 1.75) {
                //            self.colorLabel.text = "Five"
                //        }
                //        else if (angles.x < -1.35 && angles.x > -2.25) && (angles.z < -1.35 && angles.z > -1.75) {
                //            self.colorLabel.text = "Five"
                //        }
                //        else if (angles.x > 2.6 && angles.x < -2.6) && (angles.z < -1.35 && angles.z > -1.75) {
                //            self.colorLabel.text = "Five"
                //            print("classic five")
                //        }
            else if (angles.y > -0.8 && angles.y < 0.9) && (angles.z < -1.35 && angles.z > -1.75) {
                diceList.append(5)
            }
            else if (angles.y > 2.4 || angles.y < -2.6) && (angles.z > 1.35 && angles.z < 2.2) {
                diceList.append(5)
            }
                
                
            else if (angles.x < -3 || angles.x > 3) && angles.z > -0.2 && angles.z < 0.2 {
                diceList.append(6)
            }
            else if (angles.z < -3 || angles.z > 3) && (angles.x > -0.2 && angles.x < 0.2) {
                diceList.append(6)
            }
                
            else {
                diceList.append(4)
            }
        }
        return diceList
    }
    
    @objc func returnTapped () {
        presentingViewController?.dismiss(animated: true, completion: {
            
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

//extension SCNNode {
//
//    convenience init(named name: String) {
//        self.init()
//
//        guard let scene = SCNScene(named: name) else {
//            return
//        }
//
//        for childNode in scene.rootNode.childNodes {
//            addChildNode(childNode)
//        }
//    }
//
//}
