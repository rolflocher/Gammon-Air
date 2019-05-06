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
    var notMyColor = String()
    var myDice = String()
    var notMyDice = String()
    var isHost = Bool()
    var turn = String()
    var roll = [Int]()
    var moves = [[Int]]()
    var canMove = false
    var position = [15.1, 12.6, 10.1, 7.7, 5.25, 2.8, -2.25, -4.7, -7.15, -9.55, -12, -14.35]
    var holdingPiece : Int? = nil
    var holdingNode : SCNNode? = nil
    var holdingName : Int? = nil
    var firstRollOver = false
    var settingRoll = false
    var usedMoves = [[Int]]()
    
    var boardArray = [[Int]]()
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
        for _ in 1..<25 {
            boardArray.append([])
        }
        
        position.append(contentsOf: position.reversed())
        
        setupScene()
        
        myDice = color == "white" ? "dice0" : "dice1"
        notMyDice = color != "white" ? "dice0" : "dice1"
        
        notMyColor = color == "white" ? "black" : "white"
        
        debugLabel.text = myDice + " " + color + " "
        
        db = Firestore.firestore()
        
        initialRoll()
        
        let tap = UILongPressGestureRecognizer(target: self, action: #selector(handleTap(rec:)))
        sceneView.addGestureRecognizer(tap)
        sceneView.isUserInteractionEnabled = true
        
        let returnTap = UITapGestureRecognizer(target: self, action: #selector(returnTapped))
        returnButton.addGestureRecognizer(returnTap)
        returnButton.isUserInteractionEnabled = true
    }
    
    func afterRoll () {
        ref1 = db?.collection("games").document(gameID).addSnapshotListener({ (snapshot, error) in
            if snapshot?.data()?["turn"] == nil {
                return
            }
            
            if self.settingRoll {
                self.settingRoll = false
                return
            }
            
            if snapshot?.data()?["turn"] as! String != self.color && snapshot?.data()?["isFirst"] != nil {
                let vector0 = snapshot?.data()?["dice0"] as! [Float]
                let vector1 = snapshot?.data()?["dice1"] as! [Float]
                self.throwDice(initial: false, spectating: true, dice0Ballistics: [SCNVector3(vector0[0], vector0[1], vector0[2]), SCNVector3(vector0[3], vector0[4], vector0[5])], dice1Ballistics: [SCNVector3(vector1[0], vector1[1], vector1[2]), SCNVector3(vector1[3], vector1[4], vector1[5])])
                return
            }
            else if snapshot?.data()?["turn"] as! String != self.color {
                return
            }
            //let 😤 = [5]
            //print(😤.first(where: {$0 == 4}))
            
            if snapshot?.data()?["isFirst"] != nil {
                let force = SCNVector3(x: self.color == "white" ? 12 : -12, y: 2 , z: Float.random(in: -0.5..<0.5))
                let position = SCNVector3(x: Float.random(in: -0.5..<0.5), y: Float.random(in: -0.5..<0.5), z: Float.random(in: -0.5..<0.5))
                let force0 = SCNVector3(x: self.color == "white" ? 12 : -12, y: 2 , z: Float.random(in: -0.5..<0.5))
                let position0 = SCNVector3(x: Float.random(in: -0.5..<0.5), y: Float.random(in: -0.5..<0.5), z: Float.random(in: -0.5..<0.5))
                self.db?.collection("games").document(self.gameID).setData([
                    "dice0" : [force.x, force.y, force.z, position.x, position.y, position.z],
                    "dice1" : [force0.x, force0.y, force0.z, position0.x, position0.y, position0.z],
                    ], merge: true)
                self.settingRoll = true
                self.throwDice(initial: false, spectating: false, dice0Ballistics: [force, position], dice1Ballistics: [force0, position0])
                DispatchQueue.main.asyncAfter(deadline: .now()+6, execute: {
                    self.roll = self.getDice()
                    self.debugLabel.text = String(self.roll[0]) + String(self.roll[1])
                    self.moves = [[Int]]()
                    self.usedMoves = [[Int]]()
                    if self.color == "white" {
                        for x in 0..<self.boardArray.count {
                            if self.boardArray[x].contains(where: {$0 < 16}){
                                if x+self.roll[0] < self.boardArray.count {
                                    if self.boardArray[x+self.roll[0]].contains(where: {$0 < 16}) || self.boardArray[x+self.roll[0]].count <= 1 {
                                        self.moves.append([x, x+self.roll[0]])
                                    }
                                }
                                if x+self.roll[1] < self.boardArray.count {
                                    if self.boardArray[x+self.roll[1]].contains(where: {$0 < 16}) ||  self.boardArray[x+self.roll[1]].count <= 1{
                                        self.moves.append([x, x+self.roll[1]])
                                    }
                                }
                            }
                        }
                        if self.moves.count == 0 {
//                            if self.usedMoves.count == 0 {
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : self.notMyColor,
                                "isFirst" : false,
                                "move0" : [0],
                                "move1" : [0]
                                ], merge: true)
//                            }
//                            else if self.usedMoves.count == 2 {
//                                self.db?.collection("games").document(self.gameID).setData([
//                                    "turn" : self.notMyColor,
//                                    "isFirst" : false,
//                                    "move0" : self.usedMoves[0],
//                                    "move1" : [0]
//                                    ], merge: true)
//                            }
//                            else {
//                                self.db?.collection("games").document(self.gameID).setData([
//                                    "turn" : self.notMyColor,
//                                    "isFirst" : false,
//                                    "move0" : self.usedMoves[0],
//                                    "move1" : self.usedMoves[1]
//                                    ], merge: true)
//                            }
                            
                        }
                        else {
                            self.canMove = true
                        }
                        print(self.moves)
                    }
                    else {
                        for x in 0..<self.boardArray.count {
                            
                            if self.boardArray[x].contains(where: {$0 > 15}){
                                if x-self.roll[0] >= 0 {
                                    if self.boardArray[x-self.roll[0]].contains(where: {$0 > 15}) || self.boardArray[x-self.roll[0]].count <= 1 {
                                        self.moves.append([x, x-self.roll[0]])
                                    }
                                }
                                if x-self.roll[1] >= 0 {
                                    if self.boardArray[x-self.roll[1]].contains(where: {$0 > 15}) ||  self.boardArray[x-self.roll[1]].count <= 1{
                                        self.moves.append([x, x-self.roll[1]])
                                    }
                                }
                            }
                        }
                        if self.moves.count == 0 {
//                            if self.usedMoves.count == 0 {
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : self.notMyColor,
                                "isFirst" : false,
                                "move0" : [0],
                                "move1" : [0]
                                ], merge: true)
//                            }
//                            else if self.usedMoves.count == 2 {
//                                self.db?.collection("games").document(self.gameID).setData([
//                                    "turn" : self.notMyColor,
//                                    "isFirst" : false,
//                                    "move0" : self.usedMoves[0],
//                                    "move1" : [0]
//                                    ], merge: true)
//                            }
//                            else {
//                                self.db?.collection("games").document(self.gameID).setData([
//                                    "turn" : self.notMyColor,
//                                    "isFirst" : false,
//                                    "move0" : self.usedMoves[0],
//                                    "move1" : self.usedMoves[1]
//                                    ], merge: true)
//                            }
                            
                        }
                        else {
                            self.canMove = true
                        }
                        print(self.moves)
                    }
                })
            }
            else {
                self.moves = [[Int]]()
                if self.color == "white" {
                    for x in 0..<self.boardArray.count {
                        if self.boardArray[x].contains(where: {$0 < 16}){
                            if x+self.roll[0] < self.boardArray.count {
                                if self.boardArray[x+self.roll[0]].contains(where: {$0 < 16}) || self.boardArray[x+self.roll[0]].count <= 1 {
                                    self.moves.append([x, x+self.roll[0]])
                                }
                            }
                            if x+self.roll[1] < self.boardArray.count {
                                if self.boardArray[x+self.roll[1]].contains(where: {$0 < 16}) ||  self.boardArray[x+self.roll[1]].count <= 1{
                                    self.moves.append([x, x+self.roll[1]])
                                }
                            }
                        }
                    }
                    self.canMove = true
                    print(self.moves)
                }
                else {
                    for x in 0..<self.boardArray.count {
                        if self.boardArray[x].contains(where: {$0 > 15}){
                            if x-self.roll[0] >= 0 {
                                if self.boardArray[x-self.roll[0]].contains(where: {$0 > 15}) || self.boardArray[x-self.roll[0]].count <= 1 {
                                    self.moves.append([x, x-self.roll[0]])
                                }
                            }
                            if x-self.roll[1] >= 0 {
                                if self.boardArray[x-self.roll[1]].contains(where: {$0 > 15}) ||  self.boardArray[x-self.roll[1]].count <= 1{
                                    self.moves.append([x, x-self.roll[1]])
                                }
                            }
                        }
                    }
                    self.canMove = true
                    print(self.moves)
                }
            }
            
            
        })
    }
    
    @objc func handleTap ( rec: UITapGestureRecognizer) {
        if !canMove {
            return
        }
        
        let location: CGPoint = rec.location(in: sceneView)
        let hits = self.sceneView.hitTest(location, options: nil)
        
        if holdingPiece != nil {
            let position0 = hits.first!.worldCoordinates
            if rec.state == .ended {
                let index = getBoardIndex(x: position0.x, z: position0.z)
                
                if self.moves.contains(where: {$0[0] == holdingPiece! && $0[1] == index}) {
                    let sep : Double = 1.82
                    var xPos = Double()
                    if index < 12 {
                        xPos = (-9+sep*Double(boardArray[index].count))
                    }
                    else {
                        xPos = (9-sep*Double(boardArray[index].count))
                    }
                    let actionMove = SCNAction.move(to: SCNVector3(xPos, 0.5, self.position[index]), duration: 0.1)
//                    self.mainScene.rootNode.childNodes[1+self.boardArray[holdingPiece!].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                    holdingNode!.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                    holdingNode!.runAction(actionMove)
                    boardArray[index].append(holdingName!)
                    usedMoves.append([holdingPiece!, index])
                    
                    if self.roll.count == 1 {
                        self.canMove = false // tell backend that turn is over ##################
                        self.holdingPiece = nil
                        self.db?.collection("games").document(self.gameID).setData([
                            "turn" : notMyColor,
                            "isFirst" : false,
                            "move0" : usedMoves[0],
                            "move1" : usedMoves[1]
                            ], merge: true)
                        self.firstRollOver = true
                        return
                    }
                    
                    self.roll.removeAll(where: {$0 == abs(holdingPiece! - index)})
                    if self.roll.isEmpty {
                        self.roll.append (abs(holdingPiece!-index))
                    }
                    self.moves = []
                    for x in 0..<self.boardArray.count {
                        
                        if color == "white" {
                            if self.boardArray[x].contains(where: {$0 < 16}){
                                if x+self.roll[0] < self.boardArray.count {
                                    if self.boardArray[x+self.roll[0]].contains(where: {$0 < 16}) || self.boardArray[x+self.roll[0]].count <= 1 {
                                        self.moves.append([x, x+self.roll[0]])
                                    }
                                }
                            }
                        }
                        else {
                            if self.boardArray[x].contains(where: {$0 > 15}){
                                if x-self.roll[0] >= 0 {
                                    if self.boardArray[x-self.roll[0]].contains(where: {$0 > 15}) || self.boardArray[x-self.roll[0]].count <= 1 {
                                        self.moves.append([x, x-self.roll[0]])
                                    }
                                }
                            }
                        }
                        
                    }
                    if self.moves.isEmpty {
                        self.canMove = false // tell backend that turn is over ##################
                        self.holdingPiece = nil
                        if self.usedMoves.count == 1 {
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : notMyColor,
                                "isFirst" : false,
                                "move0" : usedMoves[0],
                                "move1" : [0]
                                ], merge: true)
                        }
//                        else {
//                            self.db?.collection("games").document(self.gameID).setData([
//                                "turn" : notMyColor,
//                                "isFirst" : false,
//                                "move0" : usedMoves[0],
//                                "move1" : usedMoves[1]
//                                ], merge: true)
//                        }
                        
                        self.firstRollOver = true
                        return
                    }
                    self.holdingPiece = nil
                }
                else {
                    let sep : Double = 1.82
                    var xPos = Double()
                    if index < 12 {
                        xPos = (-9+sep*Double(boardArray[holdingPiece!].count))
                    }
                    else {
                        xPos = (9-sep*Double(boardArray[holdingPiece!].count))
                    }
                    let actionMove = SCNAction.move(to: SCNVector3(xPos, 0.5, self.position[holdingPiece!]), duration: 0.1)
//                    self.mainScene.rootNode.childNodes[1+self.boardArray[holdingPiece!].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
//                    self.mainScene.rootNode.childNodes[1+self.boardArray[holdingPiece!].last!].runAction(actionMove)
                    holdingNode!.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                    holdingNode!.runAction(actionMove)
                    boardArray[holdingPiece!].append(holdingName!)
                    self.holdingPiece = nil
                }
                
                
            }
            else {
                let actionMove = SCNAction.move(to: SCNVector3(position0.x, 4, position0.z), duration: 0.1)
//                self.mainScene.rootNode.childNodes[1+self.boardArray[holdingPiece!].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
//                self.mainScene.rootNode.childNodes[1+self.boardArray[holdingPiece!].last!].runAction(actionMove)
                holdingNode!.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                holdingNode!.runAction(actionMove)
            }
            
            return
        }
        
        if !hits.isEmpty{
            if let tappedNode = hits.first?.node {
                let zPos = tappedNode.position.z
                let xPos = tappedNode.position.x
                
                let index = getBoardIndex(x: xPos, z: zPos)
                if self.boardArray[index].count == 0 {
                    return
                }
                if color == "white" {
                    if self.boardArray[index][0] > 15 {
                        return
                    }
                }
                else {
                    if self.boardArray[index][0] < 16 {
                        return
                    }
                }
                
                //print(index)
                let poss = self.moves.filter({$0[0] == index})
                if poss.count == 0 {
                    // tell backend turn is over ####
                    print("no possible moves")
                    print(index)
                    print(moves)
                    return
                }
                let position0 = hits.first!.worldCoordinates
                let actionMove = SCNAction.move(to: SCNVector3(position0.x, 4, position0.z), duration: 0.1)
                if rec.state == .began {
                    self.mainScene.rootNode.childNodes[1+self.boardArray[index].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                    self.mainScene.rootNode.childNodes[1+self.boardArray[index].last!].runAction(actionMove)
                    self.holdingPiece = index
                    self.holdingNode = self.mainScene.rootNode.childNodes[1+self.boardArray[index].last!]
                    self.holdingName = self.boardArray[index].last!
                    self.boardArray[index].removeLast()
                }
                else if rec.state == .ended {
                    holdingNode!.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                    self.holdingPiece = nil
                }
                else {
                    holdingNode!.runAction(actionMove)
                }
                
                
            }
            else {
                return
            }
            
        }
    }
    
    func getBoardIndex (x: Float, z: Float) -> Int {
        let zPos = z
        let xPos = x
        
        print("x: \(xPos) z: \(zPos)")
        var index = Int()
        if zPos > 14 {
            index = xPos > 0 ? 23 : 0
        }
        else if zPos > 11 {
            index = xPos > 0 ? 22 : 1
        }
        else if zPos > 9 {
            index = xPos > 0 ? 21 : 2
        }
        else if zPos > 6 {
            index = xPos > 0 ? 20 : 3
        }
        else if zPos > 4 {
            index = xPos > 0 ? 19 : 4
        }
        else if zPos > 0 {
            index = xPos > 0 ? 18 : 5
        }
        else if zPos > -3 {
            index = xPos > 0 ? 17 : 6
        }
        else if zPos > -6 {
            index = xPos > 0 ? 16 : 7
        }
        else if zPos > -8 {
            index = xPos > 0 ? 15 : 8
        }
        else if zPos > -11 {
            index = xPos > 0 ? 14 : 9
        }
        else if zPos > -13 {
            index = xPos > 0 ? 13 : 10
        }
        else {
            index = xPos > 0 ? 12 : 11
        }
        return index
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
                return
            }
            else if (snapshot?.data()?[self.notMyDice] as! [Float]).count == 1 ||  (snapshot?.data()?[self.myDice] as! [Float]).count == 1{
                return
            }
            
            if snapshot?.data()?["turn"] == nil {
                let vector0 = snapshot?.data()?["dice0"] as! [Float]
                let vector1 = snapshot?.data()?["dice1"] as! [Float]
                self.throwDice(initial: true, spectating: false, dice0Ballistics: [SCNVector3(vector0[0], vector0[1], vector0[2]), SCNVector3(vector0[3], vector0[4], vector0[5])], dice1Ballistics: [SCNVector3(vector1[0], vector1[1], vector1[2]), SCNVector3(vector1[3], vector1[4], vector1[5])])
                DispatchQueue.main.asyncAfter(deadline: .now()+6, execute: {
                    self.roll = self.getDice()
                    self.debugLabel.text = String(self.roll[0]) + String(self.roll[1])
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
                            self.firstRollOver = true
                        }
                        else {
                            print("u are black and you go after w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : "white"], merge: true)
                            self.debugLabel.text = self.debugLabel.text! + "white turn, not u"
                            self.killInitialRoll()
                            self.afterRoll()
                            self.firstRollOver = true
                        }
                        
                    }
                    else {
                        self.db?.collection("games").document(self.gameID).setData([
                            self.myDice : [1]], merge: true)
                    }
                    
                })
            }
        })
    }
    
    func throwDice(initial : Bool, spectating: Bool, dice0Ballistics : [SCNVector3], dice1Ballistics : [SCNVector3]) {
        print("throwDice called, make sure not double")
        var dice0Position = SCNVector3()
        var dice1Position = SCNVector3()
        if initial {
            dice0Position = SCNVector3(-8, 7, 8)
            dice1Position = SCNVector3(8, 7, -8)
        }
        else if spectating {
            dice0Position = self.color != "white" ? SCNVector3(-7, 7, 8) : SCNVector3(7, 7, -8)
            dice1Position = self.color != "white" ? SCNVector3(-9, 7, 8) : SCNVector3(7, 7, -8)
        }
        else {
            dice0Position = self.color == "white" ? SCNVector3(-7, 7, 8) : SCNVector3(7, 7, -8)
            dice1Position = self.color == "white" ? SCNVector3(-9, 7, 8) : SCNVector3(7, 7, -8)
        }
        let force = dice0Ballistics[0]
        let position = dice0Ballistics[1]
        
        if mainScene.rootNode.childNodes.count == 34 {
            mainScene.rootNode.childNodes[32].removeFromParentNode()
            mainScene.rootNode.childNodes[32].removeFromParentNode()
        }
        
//        if mainScene.rootNode.childNodes.count == 32 {
        var geometry:SCNGeometry
        geometry = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.1)
        geometry.materials.first?.diffuse.contents = UIColor.cyan
        geometry.firstMaterial?.diffuse.contents = UIColor.cyan
        let geometryNode0 = SCNScene(named: "scnModels.scnassets/die.scn")!
        let geometryNode = geometryNode0.rootNode.childNodes.first!
        geometryNode.scale = SCNVector3(0.5, 0.5, 0.5)
        geometryNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        geometryNode.position = dice0Position
        geometryNode.physicsBody?.applyForce(force, at: position, asImpulse: true)
        mainScene.rootNode.addChildNode(geometryNode)
//        }
//        else {
//            mainScene.rootNode.childNodes[32].eulerAngles = SCNVector3(0, 0, 0)
//            mainScene.rootNode.childNodes[32].position = dice0Position
//            mainScene.rootNode.childNodes[32].physicsBody?.applyForce(force, at: position, asImpulse: true)
//        }
    
        let force1 = dice1Ballistics[0]
        let position1 = dice1Ballistics[1]
//        if mainScene.rootNode.childNodes.count == 33 {
        var geometry1:SCNGeometry
        geometry1 = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.1)
        geometry1.materials.first?.diffuse.contents = UIColor.cyan
        let geometryNode10 = SCNScene(named: "scnModels.scnassets/die.scn")!
        let geometryNode1 = geometryNode10.rootNode.childNodes.first!
        geometryNode1.scale = SCNVector3(0.5, 0.5, 0.5)
        geometryNode1.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        geometryNode1.position = dice1Position
        geometryNode1.physicsBody?.applyForce(force1, at: position1, asImpulse: true)
        mainScene.rootNode.addChildNode(geometryNode1)
//        }
//        else {
//            print("dice1 sees \(mainScene.rootNode.childNodes.count)")
//            mainScene.rootNode.childNodes[33].eulerAngles = SCNVector3(0, 0, 0)
//            mainScene.rootNode.childNodes[33].position = dice1Position
//            mainScene.rootNode.childNodes[33].physicsBody?.applyForce(force1, at: position1, asImpulse: true)
//        }
        
        
        
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
        let zSep = 2.35
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
                boardArray[0].append(x)
            case 2:
                p0n.position = SCNVector3(-9+sep, 0.5, 15.1)
                boardArray[0].append(x)
            case 3:
                p0n.position = SCNVector3(-9, 0.5, -14.3)
                boardArray[11].append(x)
            case 4:
                p0n.position = SCNVector3(-9+sep, 0.5, -14.3)
                boardArray[11].append(x)
            case 5:
                p0n.position = SCNVector3(-9+sep*2, 0.5, -14.3)
                boardArray[11].append(x)
            case 6:
                p0n.position = SCNVector3(-9+sep*3, 0.5, -14.3)
                boardArray[11].append(x)
            case 7:
                p0n.position = SCNVector3(-9+sep*4, 0.5, -14.3)
                boardArray[11].append(x)
            case 8:
                p0n.position = SCNVector3(9, 0.5, 2.8)
                boardArray[18].append(x)
            case 9:
                p0n.position = SCNVector3(9-sep, 0.5, 2.8)
                boardArray[18].append(x)
            case 10:
                p0n.position = SCNVector3(9-sep*2, 0.5, 2.8)
                boardArray[18].append(x)
            case 11:
                p0n.position = SCNVector3(9-sep*3, 0.5, 2.8)
                boardArray[18].append(x)
            case 12:
                p0n.position = SCNVector3(9-sep*4, 0.5, 2.8)
                boardArray[18].append(x)
            case 13:
                p0n.position = SCNVector3(9, 0.5, -4.7)
                boardArray[16].append(x)
            case 14:
                p0n.position = SCNVector3(9-sep, 0.5, -4.7)
                boardArray[16].append(x)
            case 15:
                p0n.position = SCNVector3(9-sep*2, 0.5, -4.7)
                boardArray[16].append(x)
            case 16:
                p0n.position = SCNVector3(9, 0.5, 15.1)
                boardArray[23].append(x)
            case 17:
                p0n.position = SCNVector3(9-sep, 0.5, 15.1)
                boardArray[23].append(x)
            case 18:
                p0n.position = SCNVector3(-9, 0.5, 2.8)
                boardArray[5].append(x)
            case 19:
                p0n.position = SCNVector3(-9+sep, 0.5, 2.8)
                boardArray[5].append(x)
            case 20:
                p0n.position = SCNVector3(-9+sep*2, 0.5, 2.8)
                boardArray[5].append(x)
            case 21:
                p0n.position = SCNVector3(-9+sep*3, 0.5, 2.8)
                boardArray[5].append(x)
            case 22:
                p0n.position = SCNVector3(-9+sep*4, 0.5, 2.8)
                boardArray[5].append(x)
            case 23:
                p0n.position = SCNVector3(-9, 0.5, -4.7)
                boardArray[7].append(x)
            case 24:
                p0n.position = SCNVector3(-9+sep, 0.5, -4.7)
                boardArray[7].append(x)
            case 25:
                p0n.position = SCNVector3(-9+sep*2, 0.5, -4.7)
                boardArray[7].append(x)
            case 26:
                p0n.position = SCNVector3(9, 0.5, -14.3)
                boardArray[12].append(x)
            case 27:
                p0n.position = SCNVector3(9-sep, 0.5, -14.3)
                boardArray[12].append(x)
            case 28:
                p0n.position = SCNVector3(9-sep*2, 0.5, -14.3)
                boardArray[12].append(x)
            case 29:
                p0n.position = SCNVector3(9-sep*3, 0.5, -14.3)
                boardArray[12].append(x)
            case 30:
                p0n.position = SCNVector3(9-sep*4, 0.5, -14.3) // debug 2.35
                boardArray[12].append(x)
            default:
                p0n.position = SCNVector3(-9, 0.5, 15.1)
            }
            mainScene.rootNode.addChildNode(p0n)
        }
        print(boardArray)
        
        //print(self.mainScene.rootNode.childNodes.count)
    }
    
    func getDice() -> [Int] {
        var diceList = [Int]()
        
        for x in self.mainScene.rootNode.childNodes.count-2..<self.mainScene.rootNode.childNodes.count {
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
