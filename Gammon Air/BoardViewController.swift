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
    let railPosition = 17.5
    var holdingPiece : Int? = nil
    var holdingNode : SCNNode? = nil
    var holdingName : Int? = nil
    var firstRollOver = false
    var settingRoll = false
    var usedMoves = [[Int]]()
    
    var whiteRail = [Int]()
    var blackRail = [Int]()
    var whiteBench = [Int]()
    var blackBench = [Int]()
    
    var boardArray = [[Int]]()
    @IBOutlet var sceneView: SCNView!
    
    @IBOutlet var returnButton: UIImageView!
    
    @IBOutlet var debugLabel: UILabel!
    
    @IBOutlet var rematchButton: UIImageView!
    
    @IBOutlet var gameOverView: UIView!
    
    @IBOutlet var winnerLabel: UILabel!
    
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
        tap.minimumPressDuration = 0.1
        sceneView.addGestureRecognizer(tap)
        sceneView.isUserInteractionEnabled = true
        
        let returnTap = UITapGestureRecognizer(target: self, action: #selector(returnTapped))
        returnButton.addGestureRecognizer(returnTap)
        returnButton.isUserInteractionEnabled = true
    }
    
    
    @IBAction func debugButton(_ sender: Any) {
        //debug
        self.boardArray = [[0],[0],[0],[0],[0],[0],[0],[0],[0],[0],[0],[0],[0],[0],[0],[0],[0],[0],[0],[11],[0],[0],[0],[10,9,8]]
    }
    
    
    func addToRail (node : SCNNode, index : Int, color : String) {
        
        var wSep = Double()
        var position = SCNVector3()
        if color == "white" {
            self.whiteRail.append(self.boardArray[index].removeLast())
            wSep = 2.0
            position = SCNVector3(wSep*Double(self.whiteRail.count), 0.5, 0.3)
        }
        else {
            self.blackRail.append(self.boardArray[index].removeLast())
            wSep = -2.0
            position = SCNVector3(wSep*Double(self.blackRail.count), 0.5, 0.3)
        }
        print("addToRail position: \(position)")
        let actionMove1 = SCNAction.move(to: position, duration: 0.3)
        node.runAction(actionMove1)
    }
    
    func afterRoll () {
        
        ref1 = db?.collection("games").document(gameID).addSnapshotListener({ (snapshot, error) in
            if snapshot?.data()?["turn"] == nil {
                return
            }
            print("is still observing")
            if self.settingRoll {
                self.settingRoll = false
                return
            }
            
            if let winner = snapshot?.data()?["winner"] as? String {
                if winner == self.color {
                    self.winnerLabel.text = "You Won!"
                }
                else {
                    self.winnerLabel.text = "You Lost!"
                }
                UIView.animate(withDuration: 1, animations: {
                    self.gameOverView.alpha = 1
                })
                return
            }
            
            let dice0or = snapshot?.data()?["dice0or"] as! [Double]
            let dice1or = snapshot?.data()?["dice1or"] as! [Double]
            if snapshot?.data()?["turn"] as! String != self.color && dice0or.count != 1 {
                self.mainScene.rootNode.childNodes[33].position = self.mainScene.rootNode.childNodes[33].presentation.position
                self.mainScene.rootNode.childNodes[34].position = self.mainScene.rootNode.childNodes[34].presentation.position
                self.mainScene.rootNode.childNodes[33].eulerAngles = SCNVector3(dice0or[0], dice0or[1], dice0or[2])
                self.mainScene.rootNode.childNodes[34].eulerAngles = SCNVector3(dice1or[0], dice1or[1], dice1or[2])
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
            
            if snapshot?.data()?["isFirst"] != nil {
                let move0 = snapshot?.data()?["move0"] as! [Int]
                let move1 = snapshot?.data()?["move1"] as! [Int]
                let move2 = snapshot?.data()?["move2"] as! [Int]
                let move3 = snapshot?.data()?["move3"] as! [Int]
                var delay = 0.0
                
                let sep : Double = 1.82
                
                if move0.count != 1 {
                    delay += 1.5
                    var position00 = SCNVector3()
                    if move0[0] == -1 {
                        position00 = self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].presentation.position
                        let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                        self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                        self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionMove)
                        let name = self.whiteRail.last!
                        var xPos = Double()
                        var height = Double()
                        if move0[1] < 12 {
                            if self.boardArray[move0[1]].count >= 10 {
                                xPos = (-9+sep*Double(self.boardArray[move0[1]].count-10))
                                height = 1.5
                            }
                            else if self.boardArray[move0[1]].count >= 5 {
                                xPos = (-9+sep*Double(self.boardArray[move0[1]].count-5))
                                height = 1.0
                            }
                            else {
                                xPos = (-9+sep*Double(self.boardArray[move0[1]].count))
                                height = 0.5
                            }
                            
                        }
                        else {
                            if self.boardArray[move0[1]].count >= 10 {
                                xPos = (9-sep*Double(self.boardArray[move0[1]].count-10))
                                height = 1.5
                            }
                            else if self.boardArray[move0[1]].count >= 5 {
                                xPos = (9-sep*Double(self.boardArray[move0[1]].count-5))
                                height = 1.0
                            }
                            else {
                                xPos = (9-sep*Double(self.boardArray[move0[1]].count))
                                height = 0.5
                            }
                        }
//                        if move0[1] < 12 {
//                            xPos = (-9+sep*Double(self.boardArray[move0[1]].count))
//                        }
//                        else {
//                            xPos = (9-sep*Double(self.boardArray[move0[1]].count))
                        
                        if self.color == "white" {
                            if self.boardArray[move0[1]].contains(where: {$0 < 16}) {
                                if move0[1] < 12 {
                                    xPos = (-9+sep*Double(self.boardArray[move0[1]].count-1))
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move0[1]].count-1))
                                }
                            }
                        }
                        else {
                            if self.boardArray[move0[1]].contains(where: {$0 > 15}) {
                                if move0[1] < 12 {
                                    xPos = (-9+sep*Double(self.boardArray[move0[1]].count-1))
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move0[1]].count-1))
                                }
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                            //print("dice0 new pos: \(SCNVector3(xPos, 4, self.position[move0[1]]))")
                            let actionMove0 = SCNAction.move(to: SCNVector3(xPos, 4, self.position[move0[1]]), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionMove0)
                            
                        })
                        DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                            //self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                            
                            if self.color == "white" {
                                if self.boardArray[move0[1]].contains(where: {$0 < 16}) {
                                    self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move0[1]].last!], index: move0[1], color: "white")
                                }
                            }
                            else {
                                if self.boardArray[move0[1]].contains(where: {$0 > 15}) {
                                    self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move0[1]].last!], index: move0[1], color: "black")
                                }
                            }
                            
                            let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.position[move0[1]]), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionMove1)
                            self.boardArray[move0[1]].append(name)
                            self.whiteRail.removeLast()
                        })
                    }
                    else if move0[0] == 24 {
                        position00 = self.mainScene.rootNode.childNodes[1+self.blackRail.last!].presentation.position
                        let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                        self.mainScene.rootNode.childNodes[1+self.blackRail.last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                        self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionMove)
                        let name = self.blackRail.last!
                        var xPos = Double()
                        var height = Double()
                        if move0[1] < 12 {
                            if self.boardArray[move0[1]].count >= 10 {
                                xPos = (-9+sep*Double(self.boardArray[move0[1]].count-10))
                                height = 1.5
                            }
                            else if self.boardArray[move0[1]].count >= 5 {
                                xPos = (-9+sep*Double(self.boardArray[move0[1]].count-5))
                                height = 1.0
                            }
                            else {
                                xPos = (-9+sep*Double(self.boardArray[move0[1]].count))
                                height = 0.5
                            }
                            
                        }
                        else {
                            if self.boardArray[move0[1]].count >= 10 {
                                xPos = (9-sep*Double(self.boardArray[move0[1]].count-10))
                                height = 1.5
                            }
                            else if self.boardArray[move0[1]].count >= 5 {
                                xPos = (9-sep*Double(self.boardArray[move0[1]].count-5))
                                height = 1.0
                            }
                            else {
                                xPos = (9-sep*Double(self.boardArray[move0[1]].count))
                                height = 0.5
                            }
                        }
                        if self.color == "white" {
                            if self.boardArray[move0[1]].contains(where: {$0 < 16}) {
                                if move0[1] < 12 {
                                    xPos = (-9+sep*Double(self.boardArray[move0[1]].count-1))
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move0[1]].count-1))
                                }
                            }
                        }
                        else {
                            if self.boardArray[move0[1]].contains(where: {$0 > 15}) {
                                if move0[1] < 12 {
                                    xPos = (-9+sep*Double(self.boardArray[move0[1]].count-1))
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move0[1]].count-1))
                                }
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                            //print("dice0 new pos: \(SCNVector3(xPos, 4, self.position[move0[1]]))")
                            let actionMove0 = SCNAction.move(to: SCNVector3(xPos, 4, self.position[move0[1]]), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionMove0)
                            
                        })
                        DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                            //self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                            
                            if self.color == "white" {
                                if self.boardArray[move0[1]].contains(where: {$0 < 16}) {
                                    self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move0[1]].last!], index: move0[1], color: "white")
                                }
                            }
                            else {
                                if self.boardArray[move0[1]].contains(where: {$0 > 15}) {
                                    self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move0[1]].last!], index: move0[1], color: "black")
                                }
                            }
                            
                            let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.position[move0[1]]), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionMove1)
                            self.boardArray[move0[1]].append(name)
                            self.blackRail.removeLast()
                        })
                    }
                    else if move0[1] == -2 {
                        position00 = self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].presentation.position
                        let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                        self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                        self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].runAction(actionMove)
                        let name = self.boardArray[move0[0]].last!
                        var xPos = Double()
                        var height = Double()
                        if self.whiteBench.count >= 10 {
                            xPos = (-9+sep*Double(self.whiteBench.count-10))
                            height = 1.5
                        }
                        else if self.whiteBench.count >= 5 {
                            xPos = (-9+sep*Double(self.whiteBench.count-5))
                            height = 1.0
                        }
                        else {
                            xPos = (-9+sep*Double(self.whiteBench.count))
                            height = 0.5
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                            let actionMove0 = SCNAction.move(to: SCNVector3(xPos, 4, self.railPosition), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].runAction(actionMove0)
                            
                        })
                        DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                            let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.railPosition), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].runAction(actionMove1)
                            self.whiteBench.append(name)
                            self.boardArray[move0[0]].removeLast()
                        })
                    }
                    else if move0[1] == 25 {
                        position00 = self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].presentation.position
                        let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                        self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                        self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].runAction(actionMove)
                        let name = self.boardArray[move0[0]].last!
                        var xPos = Double()
                        var height = Double()
                        if self.blackBench.count >= 10 {
                            xPos = (9-sep*Double(self.blackBench.count-10))
                            height = 1.5
                        }
                        else if self.blackBench.count >= 5 {
                            xPos = (9-sep*Double(self.blackBench.count-5))
                            height = 1.0
                        }
                        else {
                            xPos = (9-sep*Double(self.blackBench.count))
                            height = 0.5
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                            let actionMove0 = SCNAction.move(to: SCNVector3(xPos, 4, self.railPosition), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].runAction(actionMove0)
                            
                        })
                        DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                            let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.railPosition), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].runAction(actionMove1)
                            self.blackBench.append(name)
                            self.boardArray[move0[0]].removeLast()
                        })
                    }
                    else {
                        position00 = self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].presentation.position
                        let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                        self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                        self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].runAction(actionMove)
                        let name = self.boardArray[move0[0]].last!
                        var xPos = Double()
                        var height = Double()
                        if move0[1] < 12 {
                            if self.boardArray[move0[1]].count >= 10 {
                                xPos = (-9+sep*Double(self.boardArray[move0[1]].count-10))
                                height = 1.5
                            }
                            else if self.boardArray[move0[1]].count >= 5 {
                                xPos = (-9+sep*Double(self.boardArray[move0[1]].count-5))
                                height = 1.0
                            }
                            else {
                                xPos = (-9+sep*Double(self.boardArray[move0[1]].count))
                                height = 0.5
                            }
                            
                        }
                        else {
                            if self.boardArray[move0[1]].count >= 10 {
                                xPos = (9-sep*Double(self.boardArray[move0[1]].count-10))
                                height = 1.5
                            }
                            else if self.boardArray[move0[1]].count >= 5 {
                                xPos = (9-sep*Double(self.boardArray[move0[1]].count-5))
                                height = 1.0
                            }
                            else {
                                xPos = (9-sep*Double(self.boardArray[move0[1]].count))
                                height = 0.5
                            }
                        }
                        if self.color == "white" {
                            if self.boardArray[move0[1]].contains(where: {$0 < 16}) {
                                if move0[1] < 12 {
                                    xPos = (-9+sep*Double(self.boardArray[move0[1]].count-1))
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move0[1]].count-1))
                                }
                            }
                        }
                        else {
                            if self.boardArray[move0[1]].contains(where: {$0 > 15}) {
                                if move0[1] < 12 {
                                    xPos = (-9+sep*Double(self.boardArray[move0[1]].count-1))
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move0[1]].count-1))
                                }
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                            //print("dice0 new pos: \(SCNVector3(xPos, 4, self.position[move0[1]]))")
                            let actionMove0 = SCNAction.move(to: SCNVector3(xPos, 4, self.position[move0[1]]), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].runAction(actionMove0)
                            
                        })
                        DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                            //self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                            
                            if self.color == "white" {
                                if self.boardArray[move0[1]].contains(where: {$0 < 16}) {
                                    self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move0[1]].last!], index: move0[1], color: "white")
                                }
                            }
                            else {
                                if self.boardArray[move0[1]].contains(where: {$0 > 15}) {
                                    self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move0[1]].last!], index: move0[1], color: "black")
                                }
                            }
                            
                            let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.position[move0[1]]), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move0[0]].last!].runAction(actionMove1)
                            self.boardArray[move0[1]].append(name)
                            self.boardArray[move0[0]].removeLast()
                        })
                    }
                    
                    //print("dice0 old pos: \(position00)")
                    
                    
                }
                if move1.count != 1 {
                    delay += 1.5
                    DispatchQueue.main.asyncAfter(deadline: .now()+1.5, execute: {
                        if move1[0] == -1 {
                            let position00 = self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionMove)
                            let name = self.whiteRail.last!
                            var xPos = Double()
                            var height = Double()
                            if move1[1] < 12 {
                                if self.boardArray[move1[1]].count >= 10 {
                                    xPos = (-9+sep*Double(self.boardArray[move1[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move1[1]].count >= 5 {
                                    xPos = (-9+sep*Double(self.boardArray[move1[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (-9+sep*Double(self.boardArray[move1[1]].count))
                                    height = 0.5
                                }
                                
                            }
                            else {
                                if self.boardArray[move1[1]].count >= 10 {
                                    xPos = (9-sep*Double(self.boardArray[move1[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move1[1]].count >= 5 {
                                    xPos = (9-sep*Double(self.boardArray[move1[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move1[1]].count))
                                    height = 0.5
                                }
                            }
                            if self.color == "white" {
                                if self.boardArray[move1[1]].contains(where: {$0 < 16}) {
                                    if move1[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move1[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move1[1]].count-1))
                                    }
                                }
                            }
                            else {
                                if self.boardArray[move1[1]].contains(where: {$0 > 15}) {
                                    if move1[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move1[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move1[1]].count-1))
                                    }
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                //print("dice0 new pos: \(SCNVector3(xPos, 4, self.position[move1[1]]))")
                                let actionmove1 = SCNAction.move(to: SCNVector3(xPos, 4, self.position[move1[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionmove1)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                //self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                                
                                if self.color == "white" {
                                    if self.boardArray[move1[1]].contains(where: {$0 < 16}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move1[1]].last!], index: move1[1], color: "white")
                                    }
                                }
                                else {
                                    if self.boardArray[move1[1]].contains(where: {$0 > 15}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move1[1]].last!], index: move1[1], color: "black")
                                    }
                                }
                                
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.position[move1[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionMove1)
                                self.boardArray[move1[1]].append(name)
                                self.whiteRail.removeLast()
                            })
                        }
                        else if move1[0] == 24 {
                            let position00 = self.mainScene.rootNode.childNodes[1+self.blackRail.last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.blackRail.last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionMove)
                            let name = self.blackRail.last!
                            var xPos = Double()
                            var height = Double()
                            if move1[1] < 12 {
                                if self.boardArray[move1[1]].count >= 10 {
                                    xPos = (-9+sep*Double(self.boardArray[move1[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move1[1]].count >= 5 {
                                    xPos = (-9+sep*Double(self.boardArray[move1[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (-9+sep*Double(self.boardArray[move1[1]].count))
                                    height = 0.5
                                }
                                
                            }
                            else {
                                if self.boardArray[move1[1]].count >= 10 {
                                    xPos = (9-sep*Double(self.boardArray[move1[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move1[1]].count >= 5 {
                                    xPos = (9-sep*Double(self.boardArray[move1[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move1[1]].count))
                                    height = 0.5
                                }
                            }
                            if self.color == "white" {
                                if self.boardArray[move1[1]].contains(where: {$0 < 16}) {
                                    if move1[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move1[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move1[1]].count-1))
                                    }
                                }
                            }
                            else {
                                if self.boardArray[move1[1]].contains(where: {$0 > 15}) {
                                    if move1[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move1[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move1[1]].count-1))
                                    }
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                //print("dice0 new pos: \(SCNVector3(xPos, 4, self.position[move1[1]]))")
                                let actionmove1 = SCNAction.move(to: SCNVector3(xPos, 4, self.position[move1[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionmove1)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                //self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                                
                                if self.color == "white" {
                                    if self.boardArray[move1[1]].contains(where: {$0 < 16}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move1[1]].last!], index: move1[1], color: "white")
                                    }
                                }
                                else {
                                    if self.boardArray[move1[1]].contains(where: {$0 > 15}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move1[1]].last!], index: move1[1], color: "black")
                                    }
                                }
                                
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.position[move1[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionMove1)
                                self.boardArray[move1[1]].append(name)
                                self.blackRail.removeLast()
                            })
                        }
                        else if move1[1] == -2 {
                            let position00 = self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].runAction(actionMove)
                            let name = self.boardArray[move1[0]].last!
                            var xPos = Double()
                            var height = Double()
                            if self.whiteBench.count >= 10 {
                                xPos = (-9+sep*Double(self.whiteBench.count-10))
                                height = 1.5
                            }
                            else if self.whiteBench.count >= 5 {
                                xPos = (-9+sep*Double(self.whiteBench.count-5))
                                height = 1.0
                            }
                            else {
                                xPos = (-9+sep*Double(self.whiteBench.count))
                                height = 0.5
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                let actionmove1 = SCNAction.move(to: SCNVector3(xPos, 4, self.railPosition), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].runAction(actionmove1)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.railPosition), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].runAction(actionMove1)
                                self.whiteBench.append(name)
                                self.boardArray[move1[0]].removeLast()
                            })
                        }
                        else if move1[1] == 25 {
                            let position00 = self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].runAction(actionMove)
                            let name = self.boardArray[move1[0]].last!
                            var xPos = Double()
                            var height = Double()
                            if self.blackBench.count >= 10 {
                                xPos = (9-sep*Double(self.blackBench.count-10))
                                height = 1.5
                            }
                            else if self.blackBench.count >= 5 {
                                xPos = (9-sep*Double(self.blackBench.count-5))
                                height = 1.0
                            }
                            else {
                                xPos = (9-sep*Double(self.blackBench.count))
                                height = 0.5
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                let actionmove1 = SCNAction.move(to: SCNVector3(xPos, 4, self.railPosition), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].runAction(actionmove1)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.railPosition), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].runAction(actionMove1)
                                self.blackBench.append(name)
                                self.boardArray[move1[0]].removeLast()
                            })
                        }
                        else {
                            let position11 = self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position11.x, 4, position11.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].runAction(actionMove)
                            let name = self.boardArray[move1[0]].last!
                            var xPos = Double()
                            var height = Double()
                            if move1[1] < 12 {
                                if self.boardArray[move1[1]].count >= 10 {
                                    xPos = (-9+sep*Double(self.boardArray[move1[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move1[1]].count >= 5 {
                                    xPos = (-9+sep*Double(self.boardArray[move1[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (-9+sep*Double(self.boardArray[move1[1]].count))
                                    height = 0.5
                                }
                                
                            }
                            else {
                                if self.boardArray[move1[1]].count >= 10 {
                                    xPos = (9-sep*Double(self.boardArray[move1[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move1[1]].count >= 5 {
                                    xPos = (9-sep*Double(self.boardArray[move1[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move1[1]].count))
                                    height = 0.5
                                }
                            }
                            if self.color == "white" {
                                if self.boardArray[move1[1]].contains(where: {$0 < 16}) {
                                    if move1[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move1[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move1[1]].count-1))
                                    }
                                }
                            }
                            else {
                                if self.boardArray[move1[1]].contains(where: {$0 > 15}) {
                                    if move1[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move1[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move1[1]].count-1))
                                    }
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                //print("dice1 new pos: \(SCNVector3(xPos, 4, self.position[move1[1]]))")
                                let actionMove0 = SCNAction.move(to: SCNVector3(xPos, 4, self.position[move1[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].runAction(actionMove0)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                //self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                                if self.color == "white" {
                                    if self.boardArray[move1[1]].contains(where: {$0 < 16}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move1[1]].last!], index: move1[1], color: "white")
                                    }
                                }
                                else {
                                    if self.boardArray[move1[1]].contains(where: {$0 > 15}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move1[1]].last!], index: move1[1], color: "black")
                                    }
                                }
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.position[move1[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move1[0]].last!].runAction(actionMove1)
                                self.boardArray[move1[1]].append(name)
                                self.boardArray[move1[0]].removeLast()
                            })
                        }
                        
                        
                    })
                }
                if move2.count != 1 {
                    delay += 1.5
                    DispatchQueue.main.asyncAfter(deadline: .now()+3, execute: {
                        if move2[0] == -1 {
                            let position00 = self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionMove)
                            let name = self.whiteRail.last!
                            var xPos = Double()
                            var height = Double()
                            if move2[1] < 12 {
                                if self.boardArray[move2[1]].count >= 10 {
                                    xPos = (-9+sep*Double(self.boardArray[move2[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move2[1]].count >= 5 {
                                    xPos = (-9+sep*Double(self.boardArray[move2[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (-9+sep*Double(self.boardArray[move2[1]].count))
                                    height = 0.5
                                }
                                
                            }
                            else {
                                if self.boardArray[move2[1]].count >= 10 {
                                    xPos = (9-sep*Double(self.boardArray[move2[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move2[1]].count >= 5 {
                                    xPos = (9-sep*Double(self.boardArray[move2[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move2[1]].count))
                                    height = 0.5
                                }
                            }
                            if self.color == "white" {
                                if self.boardArray[move2[1]].contains(where: {$0 < 16}) {
                                    if move2[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move2[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move2[1]].count-1))
                                    }
                                }
                            }
                            else {
                                if self.boardArray[move2[1]].contains(where: {$0 > 15}) {
                                    if move2[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move2[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move2[1]].count-1))
                                    }
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                //print("dice0 new pos: \(SCNVector3(xPos, 4, self.position[move2[1]]))")
                                let actionmove2 = SCNAction.move(to: SCNVector3(xPos, 4, self.position[move2[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionmove2)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                //self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                                
                                if self.color == "white" {
                                    if self.boardArray[move2[1]].contains(where: {$0 < 16}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move2[1]].last!], index: move2[1], color: "white")
                                    }
                                }
                                else {
                                    if self.boardArray[move2[1]].contains(where: {$0 > 15}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move2[1]].last!], index: move2[1], color: "black")
                                    }
                                }
                                
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.position[move2[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionMove1)
                                self.boardArray[move2[1]].append(name)
                                self.whiteRail.removeLast()
                            })
                        }
                        else if move1[0] == 24 {
                            let position00 = self.mainScene.rootNode.childNodes[1+self.blackRail.last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.blackRail.last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionMove)
                            let name = self.blackRail.last!
                            var xPos = Double()
                            var height = Double()
                            if move2[1] < 12 {
                                if self.boardArray[move2[1]].count >= 10 {
                                    xPos = (-9+sep*Double(self.boardArray[move2[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move2[1]].count >= 5 {
                                    xPos = (-9+sep*Double(self.boardArray[move2[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (-9+sep*Double(self.boardArray[move2[1]].count))
                                    height = 0.5
                                }
                                
                            }
                            else {
                                if self.boardArray[move2[1]].count >= 10 {
                                    xPos = (9-sep*Double(self.boardArray[move2[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move2[1]].count >= 5 {
                                    xPos = (9-sep*Double(self.boardArray[move2[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move2[1]].count))
                                    height = 0.5
                                }
                            }
                            if self.color == "white" {
                                if self.boardArray[move2[1]].contains(where: {$0 < 16}) {
                                    if move2[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move2[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move2[1]].count-1))
                                    }
                                }
                            }
                            else {
                                if self.boardArray[move2[1]].contains(where: {$0 > 15}) {
                                    if move2[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move2[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move2[1]].count-1))
                                    }
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                //print("dice0 new pos: \(SCNVector3(xPos, 4, self.position[move2[1]]))")
                                let actionmove2 = SCNAction.move(to: SCNVector3(xPos, 4, self.position[move2[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionmove2)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                //self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                                
                                if self.color == "white" {
                                    if self.boardArray[move2[1]].contains(where: {$0 < 16}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move2[1]].last!], index: move2[1], color: "white")
                                    }
                                }
                                else {
                                    if self.boardArray[move2[1]].contains(where: {$0 > 15}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move2[1]].last!], index: move2[1], color: "black")
                                    }
                                }
                                
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.position[move2[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionMove1)
                                self.boardArray[move2[1]].append(name)
                                self.blackRail.removeLast()
                            })
                        }
                        else if move2[1] == -2 {
                            let position00 = self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].runAction(actionMove)
                            let name = self.boardArray[move2[0]].last!
                            var xPos = Double()
                            var height = Double()
                            if self.whiteBench.count >= 10 {
                                xPos = (-9+sep*Double(self.whiteBench.count-10))
                                height = 1.5
                            }
                            else if self.whiteBench.count >= 5 {
                                xPos = (-9+sep*Double(self.whiteBench.count-5))
                                height = 1.0
                            }
                            else {
                                xPos = (-9+sep*Double(self.whiteBench.count))
                                height = 0.5
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                let actionmove2 = SCNAction.move(to: SCNVector3(xPos, 4, self.railPosition), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].runAction(actionmove2)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.railPosition), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].runAction(actionMove1)
                                self.whiteBench.append(name)
                                self.boardArray[move2[0]].removeLast()
                            })
                        }
                        else if move2[1] == 25 {
                            let position00 = self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].runAction(actionMove)
                            let name = self.boardArray[move2[0]].last!
                            var xPos = Double()
                            var height = Double()
                            if self.blackBench.count >= 10 {
                                xPos = (9-sep*Double(self.blackBench.count-10))
                                height = 1.5
                            }
                            else if self.blackBench.count >= 5 {
                                xPos = (9-sep*Double(self.blackBench.count-5))
                                height = 1.0
                            }
                            else {
                                xPos = (9-sep*Double(self.blackBench.count))
                                height = 0.5
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                let actionmove2 = SCNAction.move(to: SCNVector3(xPos, 4, self.railPosition), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].runAction(actionmove2)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.railPosition), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].runAction(actionMove1)
                                self.blackBench.append(name)
                                self.boardArray[move2[0]].removeLast()
                            })
                        }
                        else {
                            let position11 = self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].presentation.position
                            //print("dice1 old pos: \(position11)")
                            let actionMove = SCNAction.move(to: SCNVector3(position11.x, 4, position11.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].runAction(actionMove)
                            let name = self.boardArray[move2[0]].last!
                            var xPos = Double()
                            var height = Double()
                            if move2[1] < 12 {
                                if self.boardArray[move2[1]].count >= 10 {
                                    xPos = (-9+sep*Double(self.boardArray[move2[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move2[1]].count >= 5 {
                                    xPos = (-9+sep*Double(self.boardArray[move2[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (-9+sep*Double(self.boardArray[move2[1]].count))
                                    height = 0.5
                                }
                                
                            }
                            else {
                                if self.boardArray[move2[1]].count >= 10 {
                                    xPos = (9-sep*Double(self.boardArray[move2[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move2[1]].count >= 5 {
                                    xPos = (9-sep*Double(self.boardArray[move2[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move2[1]].count))
                                    height = 0.5
                                }
                            }
                            if self.color == "white" {
                                if self.boardArray[move2[1]].contains(where: {$0 < 16}) {
                                    if move2[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move2[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move2[1]].count-1))
                                    }
                                }
                            }
                            else {
                                if self.boardArray[move2[1]].contains(where: {$0 > 15}) {
                                    if move2[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move2[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move2[1]].count-1))
                                    }
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                //print("dice1 new pos: \(SCNVector3(xPos, 4, self.position[move2[1]]))")
                                let actionMove0 = SCNAction.move(to: SCNVector3(xPos, 4, self.position[move2[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].runAction(actionMove0)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                //self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                                if self.color == "white" {
                                    if self.boardArray[move2[1]].contains(where: {$0 < 16}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move2[1]].last!], index: move2[1], color: "white")
                                    }
                                }
                                else {
                                    if self.boardArray[move2[1]].contains(where: {$0 > 15}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move2[1]].last!], index: move2[1], color: "black")
                                    }
                                }
                                let actionmove2 = SCNAction.move(to: SCNVector3(xPos, height, self.position[move2[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move2[0]].last!].runAction(actionmove2)
                                self.boardArray[move2[1]].append(name)
                                self.boardArray[move2[0]].removeLast()
                            })
                        }
                    })
                }
                if move3.count != 1 {
                    delay += 1.5
                    DispatchQueue.main.asyncAfter(deadline: .now()+4.5, execute: {
                        if move3[0] == -1 {
                            let position00 = self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionMove)
                            let name = self.whiteRail.last!
                            var xPos = Double()
                            var height = Double()
                            if move3[1] < 12 {
                                if self.boardArray[move3[1]].count >= 10 {
                                    xPos = (-9+sep*Double(self.boardArray[move3[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move3[1]].count >= 5 {
                                    xPos = (-9+sep*Double(self.boardArray[move3[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (-9+sep*Double(self.boardArray[move3[1]].count))
                                    height = 0.5
                                }
                                
                            }
                            else {
                                if self.boardArray[move3[1]].count >= 10 {
                                    xPos = (9-sep*Double(self.boardArray[move3[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move3[1]].count >= 5 {
                                    xPos = (9-sep*Double(self.boardArray[move3[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move3[1]].count))
                                    height = 0.5
                                }
                            }
                            if self.color == "white" {
                                if self.boardArray[move3[1]].contains(where: {$0 < 16}) {
                                    if move3[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move3[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move3[1]].count-1))
                                    }
                                }
                            }
                            else {
                                if self.boardArray[move3[1]].contains(where: {$0 > 15}) {
                                    if move3[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move3[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move3[1]].count-1))
                                    }
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                //print("dice0 new pos: \(SCNVector3(xPos, 4, self.position[move3[1]]))")
                                let actionmove3 = SCNAction.move(to: SCNVector3(xPos, 4, self.position[move3[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionmove3)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                //self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                                
                                if self.color == "white" {
                                    if self.boardArray[move3[1]].contains(where: {$0 < 16}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move3[1]].last!], index: move3[1], color: "white")
                                    }
                                }
                                else {
                                    if self.boardArray[move3[1]].contains(where: {$0 > 15}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move3[1]].last!], index: move3[1], color: "black")
                                    }
                                }
                                
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.position[move3[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionMove1)
                                self.boardArray[move3[1]].append(name)
                                self.whiteRail.removeLast()
                            })
                        }
                        else if move3[0] == 24 {
                            let position00 = self.mainScene.rootNode.childNodes[1+self.blackRail.last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.blackRail.last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionMove)
                            let name = self.blackRail.last!
                            var xPos = Double()
                            var height = Double()
                            if move3[1] < 12 {
                                if self.boardArray[move3[1]].count >= 10 {
                                    xPos = (-9+sep*Double(self.boardArray[move3[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move3[1]].count >= 5 {
                                    xPos = (-9+sep*Double(self.boardArray[move3[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (-9+sep*Double(self.boardArray[move3[1]].count))
                                    height = 0.5
                                }
                                
                            }
                            else {
                                if self.boardArray[move3[1]].count >= 10 {
                                    xPos = (9-sep*Double(self.boardArray[move3[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move3[1]].count >= 5 {
                                    xPos = (9-sep*Double(self.boardArray[move3[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move3[1]].count))
                                    height = 0.5
                                }
                            }
                            if self.color == "white" {
                                if self.boardArray[move3[1]].contains(where: {$0 < 16}) {
                                    if move3[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move3[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move3[1]].count-1))
                                    }
                                }
                            }
                            else {
                                if self.boardArray[move3[1]].contains(where: {$0 > 15}) {
                                    if move3[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move3[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move3[1]].count-1))
                                    }
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                //print("dice0 new pos: \(SCNVector3(xPos, 4, self.position[move3[1]]))")
                                let actionmove3 = SCNAction.move(to: SCNVector3(xPos, 4, self.position[move3[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionmove3)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                //self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                                
                                if self.color == "white" {
                                    if self.boardArray[move3[1]].contains(where: {$0 < 16}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move3[1]].last!], index: move3[1], color: "white")
                                    }
                                }
                                else {
                                    if self.boardArray[move3[1]].contains(where: {$0 > 15}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move3[1]].last!], index: move3[1], color: "black")
                                    }
                                }
                                
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.position[move3[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionMove1)
                                self.boardArray[move3[1]].append(name)
                                self.blackRail.removeLast()
                            })
                        }
                        else if move3[1] == -2 {
                            let position00 = self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].runAction(actionMove)
                            let name = self.boardArray[move3[0]].last!
                            var xPos = Double()
                            var height = Double()
                            if self.whiteBench.count >= 10 {
                                xPos = (-9+sep*Double(self.whiteBench.count-10))
                                height = 1.5
                            }
                            else if self.whiteBench.count >= 5 {
                                xPos = (-9+sep*Double(self.whiteBench.count-5))
                                height = 1.0
                            }
                            else {
                                xPos = (-9+sep*Double(self.whiteBench.count))
                                height = 0.5
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                let actionmove3 = SCNAction.move(to: SCNVector3(xPos, 4, self.railPosition), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].runAction(actionmove3)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.railPosition), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].runAction(actionMove1)
                                self.whiteBench.append(name)
                                self.boardArray[move3[0]].removeLast()
                            })
                        }
                        else if move3[1] == 25 {
                            let position00 = self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].presentation.position
                            let actionMove = SCNAction.move(to: SCNVector3(position00.x, 4, position00.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].runAction(actionMove)
                            let name = self.boardArray[move3[0]].last!
                            var xPos = Double()
                            var height = Double()
                            if self.blackBench.count >= 10 {
                                xPos = (9-sep*Double(self.blackBench.count-10))
                                height = 1.5
                            }
                            else if self.blackBench.count >= 5 {
                                xPos = (9-sep*Double(self.blackBench.count-5))
                                height = 1.0
                            }
                            else {
                                xPos = (9-sep*Double(self.blackBench.count))
                                height = 0.5
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                let actionmove3 = SCNAction.move(to: SCNVector3(xPos, 4, self.railPosition), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].runAction(actionmove3)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                let actionMove1 = SCNAction.move(to: SCNVector3(xPos, height, self.railPosition), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].runAction(actionMove1)
                                self.blackBench.append(name)
                                self.boardArray[move3[0]].removeLast()
                            })
                        }
                        else {
                            let position11 = self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].presentation.position
                            //print("dice1 old pos: \(position11)")
                            let actionMove = SCNAction.move(to: SCNVector3(position11.x, 4, position11.z), duration: 0.3)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                            self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].runAction(actionMove)
                            let name = self.boardArray[move3[0]].last!
                            var xPos = Double()
                            var height = Double()
                            if move3[1] < 12 {
                                if self.boardArray[move3[1]].count >= 10 {
                                    xPos = (-9+sep*Double(self.boardArray[move3[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move3[1]].count >= 5 {
                                    xPos = (-9+sep*Double(self.boardArray[move3[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (-9+sep*Double(self.boardArray[move3[1]].count))
                                    height = 0.5
                                }
                                
                            }
                            else {
                                if self.boardArray[move3[1]].count >= 10 {
                                    xPos = (9-sep*Double(self.boardArray[move3[1]].count-10))
                                    height = 1.5
                                }
                                else if self.boardArray[move3[1]].count >= 5 {
                                    xPos = (9-sep*Double(self.boardArray[move3[1]].count-5))
                                    height = 1.0
                                }
                                else {
                                    xPos = (9-sep*Double(self.boardArray[move3[1]].count))
                                    height = 0.5
                                }
                            }
                            if self.color == "white" {
                                if self.boardArray[move3[1]].contains(where: {$0 < 16}) {
                                    if move3[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move3[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move3[1]].count-1))
                                    }
                                }
                            }
                            else {
                                if self.boardArray[move3[1]].contains(where: {$0 > 15}) {
                                    if move3[1] < 12 {
                                        xPos = (-9+sep*Double(self.boardArray[move3[1]].count-1))
                                    }
                                    else {
                                        xPos = (9-sep*Double(self.boardArray[move3[1]].count-1))
                                    }
                                }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now()+0.5, execute: {
                                //print("dice1 new pos: \(SCNVector3(xPos, 4, self.position[move3[1]]))")
                                let actionMove0 = SCNAction.move(to: SCNVector3(xPos, 4, self.position[move3[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].runAction(actionMove0)
                                
                            })
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute: {
                                //self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
                                if self.color == "white" {
                                    if self.boardArray[move3[1]].contains(where: {$0 < 16}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move3[1]].last!], index: move3[1], color: "white")
                                    }
                                }
                                else {
                                    if self.boardArray[move3[1]].contains(where: {$0 > 15}) {
                                        self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[move3[1]].last!], index: move3[1], color: "black")
                                    }
                                }
                                let actionmove3 = SCNAction.move(to: SCNVector3(xPos, height, self.position[move3[1]]), duration: 0.3)
                                self.mainScene.rootNode.childNodes[1+self.boardArray[move3[0]].last!].runAction(actionmove3)
                                self.boardArray[move3[1]].append(name)
                                self.boardArray[move3[0]].removeLast()
                            })
                        }
                        
                        
                    })
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now()+delay, execute: {
                    let force = SCNVector3(x: self.color == "white" ? 12 : -12, y: 2 , z: Float.random(in: -0.5..<0))
                    let position = SCNVector3(x: Float.random(in: -0.5..<0.5), y: Float.random(in: -0.5..<0.5), z: Float.random(in: -0.5..<0.5))
                    let force0 = SCNVector3(x: self.color == "white" ? 12 : -12, y: 2 , z: Float.random(in: 0..<0.5))
                    let position0 = SCNVector3(x: Float.random(in: -0.5..<0.5), y: Float.random(in: -0.5..<0.5), z: Float.random(in: -0.5..<0.5))
                    self.db?.collection("games").document(self.gameID).setData([
                        "dice0" : [force.x, force.y, force.z, position.x, position.y, position.z],
                        "dice1" : [force0.x, force0.y, force0.z, position0.x, position0.y, position0.z],
                        ], merge: true)
                    self.settingRoll = true
                    self.throwDice(initial: false, spectating: false, dice0Ballistics: [force, position], dice1Ballistics: [force0, position0])
                    self.settleDice {
                        //let roll0 = self.getDice()
                        //print("settleDice says roll is : \(roll0[0]), \(roll0[1])")
                        self.roll = self.getDice()
                        let angles = self.mainScene.rootNode.childNodes[33].presentation.eulerAngles
                        let angles0 = self.mainScene.rootNode.childNodes[34].presentation.eulerAngles
                        
                        self.settingRoll = true
                        self.db?.collection("games").document(self.gameID).setData([
                            "dice0or" : [angles.x, angles.y, angles.z],
                            "dice1or" : [angles0.x, angles0.y, angles0.z],
                            ], merge: true)
                        self.debugLabel.text = String(self.roll[0]) + String(self.roll[1])
                        self.moves = [[Int]]()
                        self.usedMoves = [[Int]]()
                        let whiteBack = self.boardArray[0..<18]
                        //let whiteBack0 = self.boardArray[18..<24]
                        let blackBack = self.boardArray[6..<24]
                        //let blackBack0 = self.boardArray[0..<7]
                        if self.color == "white" {
                            for x in 0..<self.boardArray.count {
                                if self.boardArray[x].contains(where: {$0 < 16}){
                                    if x+self.roll[0] < self.boardArray.count {
                                        if self.boardArray[x+self.roll[0]].contains(where: {$0 < 16}) || self.boardArray[x+self.roll[0]].count <= 1 {
                                            self.moves.append([x, x+self.roll[0]])
                                        }
                                    }
                                    // roll[0] adds to go off board
                                    else if (!whiteBack.contains(where: {$0.contains(where: {$0 <= 15})})) { // all in backboard
                                        if !self.boardArray[24-self.roll[0]].contains(where: {$0 <= 15}) { // roll space is empty
                                            if self.boardArray[18..<24-self.roll[0]].contains(where: {$0.contains(where: {$0 <= 15})}) {
                                                
                                            }
                                            else {
                                                self.moves.append([x, -2])
                                            }
                                        }
                                        else if x+self.roll[0] == 24 {
                                            self.moves.append([x, -2])
                                        }
                                        
                                        
                                    }
                                    if x+self.roll[1] < self.boardArray.count {
                                        if self.boardArray[x+self.roll[1]].contains(where: {$0 < 16}) ||  self.boardArray[x+self.roll[1]].count <= 1{
                                            self.moves.append([x, x+self.roll[1]])
                                        }
                                    }
                                    else if (!whiteBack.contains(where: {$0.contains(where: {$0 <= 15})})) {
                                        if !self.boardArray[24-self.roll[1]].contains(where: {$0 <= 15}) {
                                            if self.boardArray[18..<24-self.roll[1]].contains(where: {$0.contains(where: {$0 <= 15})}) {
                                                
                                            }
                                            else {
                                                self.moves.append([x, -2])
                                            }
                                        }
                                        else if x+self.roll[1] == 24 {
                                            self.moves.append([x, -2])
                                        }
                                    }
                                }
                            }
                            
                            
                            
                            if self.whiteRail.count != 0 {
                                self.moves.removeAll()
                                if self.boardArray[self.roll[0]-1].contains(where: {$0 < 16}) || self.boardArray[self.roll[0]-1].count <= 1 {
                                    self.moves.append([-1, self.roll[0]-1])
                                }
                                if self.boardArray[self.roll[1]-1].contains(where: {$0 < 16}) ||  self.boardArray[self.roll[1]-1].count <= 1{
                                    self.moves.append([-1, self.roll[1]-1])
                                }
                            }
                            if self.moves.count == 0 {
                                //                            if self.usedMoves.count == 0 {
                                self.settingRoll = true
                                self.db?.collection("games").document(self.gameID).setData([
                                    "turn" : self.notMyColor,
                                    "isFirst" : false,
                                    "move0" : [0],
                                    "move1" : [0],
                                    "move2" : [0],
                                    "move3" : [0],
                                    "dice0or" : [0],
                                    "dice1or" : [0],
                                    ], merge: true)
                            }
                            else {
                                self.canMove = true
                            }
                            print("moves : \(self.moves)")
                        }
                        else {
                            for x in 0..<self.boardArray.count {
                                
                                if self.boardArray[x].contains(where: {$0 > 15}){
                                    if x-self.roll[0] >= 0 {
                                        if self.boardArray[x-self.roll[0]].contains(where: {$0 > 15}) || self.boardArray[x-self.roll[0]].count <= 1 {
                                            self.moves.append([x, x-self.roll[0]])
                                        }
                                    }
//                                    else if !blackBack.contains(where: {$0.contains(where: {$0 >= 16})}) {
//                                        self.moves.append([x, 25])
//                                    }
                                    else if (!blackBack.contains(where: {$0.contains(where: {$0 >= 16})})) {
                                        if !self.boardArray[-1+self.roll[0]].contains(where: {$0 >= 16}) {
                                            if self.boardArray[self.roll[0]..<7].contains(where: {$0.contains(where: {$0 >= 16})}) {
                                                
                                            }
                                            else {
                                                self.moves.append([x, 25])
                                            }
                                        }
                                        else if x-self.roll[0] == -1 {
                                            self.moves.append([x, 25])
                                        }
                                    }
                                    if x-self.roll[1] >= 0 {
                                        if self.boardArray[x-self.roll[1]].contains(where: {$0 >= 16}) ||  self.boardArray[x-self.roll[1]].count <= 1{
                                            self.moves.append([x, x-self.roll[1]])
                                        }
                                    }
                                    else if (!blackBack.contains(where: {$0.contains(where: {$0 >= 16})})) {
                                        if !self.boardArray[-1+self.roll[1]].contains(where: {$0 >= 16}) {
                                            if self.boardArray[self.roll[1]..<7].contains(where: {$0.contains(where: {$0 >= 16})}) {
                                                
                                            }
                                            else {
                                                self.moves.append([x, 25])
                                            }
                                        }
                                        else if x-self.roll[1] == -1 {
                                            self.moves.append([x, 25])
                                        }
                                    }
                                }
                            }
                            if self.blackRail.count != 0 {
                                self.moves.removeAll()
                                if self.boardArray[24-self.roll[0]].contains(where: {$0 > 15}) || self.boardArray[24-self.roll[0]].count <= 1 {
                                    self.moves.append([24, 24-self.roll[0]])
                                }
                                if self.boardArray[24-self.roll[1]].contains(where: {$0 > 15}) ||  self.boardArray[24-self.roll[1]].count <= 1{
                                    self.moves.append([24, 24-self.roll[1]])
                                }
                            }
                            if self.moves.count == 0 {
                                //                            if self.usedMoves.count == 0 {
                                self.settingRoll = true
                                self.db?.collection("games").document(self.gameID).setData([
                                    "turn" : self.notMyColor,
                                    "isFirst" : false,
                                    "move0" : [0],
                                    "move1" : [0],
                                    "move2" : [0],
                                    "move3" : [0],
                                    "dice0or" : [0],
                                    "dice1or" : [0],
                                    ], merge: true)
                                
                            }
                            else {
                                self.canMove = true
                            }
                            print(self.moves)
                        }
                    }
//                    DispatchQueue.main.asyncAfter(deadline: .now()+6, execute: {
//                        self.roll = self.getDice()
//                        let angles = self.mainScene.rootNode.childNodes[33].presentation.eulerAngles
//                        let angles0 = self.mainScene.rootNode.childNodes[34].presentation.eulerAngles
//
//                        self.settingRoll = true
//                        self.db?.collection("games").document(self.gameID).setData([
//                            "dice0or" : [angles.x, angles.y, angles.z],
//                            "dice1or" : [angles0.x, angles0.y, angles0.z],
//                            ], merge: true)
//                        self.debugLabel.text = String(self.roll[0]) + String(self.roll[1])
//                        self.moves = [[Int]]()
//                        self.usedMoves = [[Int]]()
//                        if self.color == "white" {
//                            for x in 0..<self.boardArray.count {
//                                if self.boardArray[x].contains(where: {$0 < 16}){
//                                    if x+self.roll[0] < self.boardArray.count {
//                                        if self.boardArray[x+self.roll[0]].contains(where: {$0 < 16}) || self.boardArray[x+self.roll[0]].count <= 1 {
//                                            self.moves.append([x, x+self.roll[0]])
//                                        }
//                                    }
//                                    if x+self.roll[1] < self.boardArray.count {
//                                        if self.boardArray[x+self.roll[1]].contains(where: {$0 < 16}) ||  self.boardArray[x+self.roll[1]].count <= 1{
//                                            self.moves.append([x, x+self.roll[1]])
//                                        }
//                                    }
//                                }
//                            }
//                            if self.whiteRail.count != 0 {
//                                self.moves.removeAll()
//                                if self.boardArray[self.roll[0]-1].contains(where: {$0 < 16}) || self.boardArray[self.roll[0]-1].count <= 1 {
//                                    self.moves.append([-1, self.roll[0]-1])
//                                }
//                                if self.boardArray[self.roll[1]-1].contains(where: {$0 < 16}) ||  self.boardArray[self.roll[1]-1].count <= 1{
//                                    self.moves.append([-1, self.roll[1]-1])
//                                }
//                            }
//                            if self.moves.count == 0 {
//                                //                            if self.usedMoves.count == 0 {
//                                self.settingRoll = true
//                                self.db?.collection("games").document(self.gameID).setData([
//                                    "turn" : self.notMyColor,
//                                    "isFirst" : false,
//                                    "move0" : [0],
//                                    "move1" : [0],
//                                    "move2" : [0],
//                                    "move3" : [0],
//                                    "dice0or" : [0],
//                                    "dice1or" : [0],
//                                    ], merge: true)
//                            }
//                            else {
//                                self.canMove = true
//                            }
//                            print("moves : \(self.moves)")
//                        }
//                        else {
//                            for x in 0..<self.boardArray.count {
//
//                                if self.boardArray[x].contains(where: {$0 > 15}){
//                                    if x-self.roll[0] >= 0 {
//                                        if self.boardArray[x-self.roll[0]].contains(where: {$0 > 15}) || self.boardArray[x-self.roll[0]].count <= 1 {
//                                            self.moves.append([x, x-self.roll[0]])
//                                        }
//                                    }
//                                    if x-self.roll[1] >= 0 {
//                                        if self.boardArray[x-self.roll[1]].contains(where: {$0 > 15}) ||  self.boardArray[x-self.roll[1]].count <= 1{
//                                            self.moves.append([x, x-self.roll[1]])
//                                        }
//                                    }
//                                }
//                            }
//                            if self.blackRail.count != 0 {
//                                self.moves.removeAll()
//                                if self.boardArray[24-self.roll[0]].contains(where: {$0 > 15}) || self.boardArray[24-self.roll[0]].count <= 1 {
//                                    self.moves.append([24, 24-self.roll[0]])
//                                }
//                                if self.boardArray[24-self.roll[1]].contains(where: {$0 > 15}) ||  self.boardArray[24-self.roll[1]].count <= 1{
//                                    self.moves.append([24, 24-self.roll[1]])
//                                }
//                            }
//                            if self.moves.count == 0 {
//                                //                            if self.usedMoves.count == 0 {
//                                self.settingRoll = true
//                                self.db?.collection("games").document(self.gameID).setData([
//                                    "turn" : self.notMyColor,
//                                    "isFirst" : false,
//                                    "move0" : [0],
//                                    "move1" : [0],
//                                    "move2" : [0],
//                                    "move3" : [0],
//                                    "dice0or" : [0],
//                                    "dice1or" : [0],
//                                    ], merge: true)
//
//                            }
//                            else {
//                                self.canMove = true
//                            }
//                            print(self.moves)
//                        }
//                    })
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
                }
                print(self.moves)
            }
            
            
        })
    }
    
    @objc func handleTap ( rec: UITapGestureRecognizer) {
        
        if !canMove {
            return
        }
        
        let location: CGPoint = rec.location(in: sceneView)
        let hits = self.sceneView.hitTest(location, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
        if hits.count == 0 {
            return
        }
        if holdingPiece != nil {
            let position0 = hits.last!.worldCoordinates
            //print(hits)
            //print("hold thinks pos is: \(position0.z)")
            if rec.state == .ended {
                let index = getBoardIndex(x: position0.x, z: position0.z)
                //print("tried to drop at \(index) according to gesture objc")
                
                if self.moves.contains(where: {$0[0] == holdingPiece! && $0[1] == index}) {
                    let sep : Double = 1.82
                    var xPos = Double()
                    var height = Double()
                    
                    if index != -2 && index != 25 {
                        if self.color == "white" {
                            if self.boardArray[index].contains(where: {$0 > 15}) {
                                self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[index].last!], index: index, color: "black")
                                //                            if index < 12 {
                                //                                xPos = (-9+sep*Double(boardArray[index].count))
                                //                            }
                                //                            else {
                                //                                xPos = (9-sep*Double(boardArray[index].count))
                                //                            }
                            }
                        }
                        else {
                            if self.boardArray[index].contains(where: {$0 < 16}) {
                                self.addToRail(node: self.mainScene.rootNode.childNodes[1+self.boardArray[index].last!], index: index, color: "white")
                                //                            if index < 12 {
                                //                                xPos = (-9+sep*Double(boardArray[index].count))
                                //                            }
                                //                            else {
                                //                                xPos = (9-sep*Double(boardArray[index].count))
                                //                            }
                            }
                        }
                    }
                    
                    var zPos = Double()
                    if index == -2 {
                        if self.whiteBench.count >= 10 {
                            xPos = (-9+sep*Double(self.whiteBench.count-10))
                            height = 1.5
                        }
                        else if self.whiteBench.count >= 5 {
                            xPos = (-9+sep*Double(self.whiteBench.count-5))
                            height = 1.0
                        }
                        else {
                            xPos = (-9+sep*Double(self.whiteBench.count))
                            height = 0.5
                        }
                        zPos = self.railPosition
                        self.whiteBench.append(holdingName!)
                    }
                    else if index == 25 {
                        if self.blackBench.count >= 10 {
                            xPos = (9-sep*Double(self.blackBench.count-10))
                            height = 1.5
                        }
                        else if self.blackBench.count >= 5 {
                            xPos = (9-sep*Double(self.blackBench.count-5))
                            height = 1.0
                        }
                        else {
                            xPos = (9-sep*Double(self.blackBench.count))
                            height = 0.5
                        }
                        zPos = self.railPosition
                        self.blackBench.append(holdingName!)
                    }
                    else if index < 12 {
                        if boardArray[index].count >= 10 {
                            xPos = (-9+sep*Double(boardArray[index].count-10))
                            height = 1.5
                        }
                        else if boardArray[index].count >= 5 {
                            xPos = (-9+sep*Double(boardArray[index].count-5))
                            height = 1.0
                        }
                        else {
                            xPos = (-9+sep*Double(boardArray[index].count))
                            height = 0.5
                        }
                        zPos = self.position[index]
                        boardArray[index].append(holdingName!)
                    }
                    else {
                        
                        if boardArray[index].count >= 10 {
                            xPos = (9-sep*Double(boardArray[index].count-10))
                            height = 1.5
                        }
                        else if boardArray[index].count >= 5 {
                            xPos = (9-sep*Double(boardArray[index].count-5))
                            height = 1.0
                        }
                        else {
                            xPos = (9-sep*Double(boardArray[index].count))
                            height = 0.5
                        }
                        zPos = self.position[index]
                        boardArray[index].append(holdingName!)
                    }
                    
                    let actionMove = SCNAction.move(to: SCNVector3(xPos, height, zPos), duration: 0.2)
                    holdingNode!.runAction(actionMove)
                    
                    usedMoves.append([holdingPiece!, index])
                    
                    if index == -2 || index == 25 { // move was off the board, check for end
                        if self.color == "white" {
                            if !self.boardArray.contains(where: {$0.contains(where: {$0 <= 15})}) {
                                self.db?.collection("games").document(self.gameID).setData([
                                    "winner" : "white",
                                    ], merge: true)
                                return
                            }
                        }
                        else {
                            if !self.boardArray.contains(where: {$0.contains(where: {$0 >= 16})}) {
                                self.db?.collection("games").document(self.gameID).setData([
                                    "winner" : "black",
                                    ], merge: true)
                                return
                            }
                        }
                    }
                    
                    if self.roll.count == 1 {
                        self.canMove = false // tell backend that turn is over ##################
                        self.holdingPiece = nil
                        self.settingRoll = true
                        if self.usedMoves.count == 2 {
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : notMyColor,
                                "isFirst" : false,
                                "move0" : usedMoves[0],
                                "move1" : usedMoves[1],
                                "move2" : [0],
                                "move3" : [0],
                                "dice0or" : [0],
                                "dice1or" : [0],
                                ], merge: true)
                        }
                        else {
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : notMyColor,
                                "isFirst" : false,
                                "move0" : usedMoves[0],
                                "move1" : usedMoves[1],
                                "move2" : usedMoves[2],
                                "move3" : usedMoves[3],
                                "dice0or" : [0],
                                "dice1or" : [0],
                                ], merge: true)
                        }
                        
                        self.firstRollOver = true
                        return
                    }
                    if index == 25 {
                        self.roll.remove(at: self.roll.firstIndex(where: {$0 == abs(-1-holdingPiece!)}) ?? self.roll.firstIndex(where: {$0 == self.roll.max()!})! )
                    }
                    else if index == -2 {
                        self.roll.remove(at: self.roll.firstIndex(where: {$0 == abs(24-holdingPiece!)}) ?? self.roll.firstIndex(where: {$0 == self.roll.max()!})!)
                    }
                    else {
                        self.roll.remove(at: self.roll.firstIndex(where: {$0 == abs(holdingPiece! - index)})!)
                    }
                    
                    //self.roll.removeFirst(where: {$0 == abs(holdingPiece! - index)})
                    //if self.roll.isEmpty {
                    //    self.roll.append (abs(holdingPiece!-index))
                    //}
                    self.moves = []
                    let whiteBack = self.boardArray[0..<18]
                    let blackBack = self.boardArray[6..<24]
                    for x in 0..<self.boardArray.count {
                        
                        if color == "white" {
                            if self.boardArray[x].contains(where: {$0 < 16}){
                                if x+self.roll[0] < self.boardArray.count {
                                    if self.boardArray[x+self.roll[0]].contains(where: {$0 < 16}) || self.boardArray[x+self.roll[0]].count <= 1 {
                                        self.moves.append([x, x+self.roll[0]])
                                    }
                                }
//                                else if !whiteBack.contains(where: {$0.contains(where: {$0 <= 15})}) {
//                                    self.moves.append([x, -2])
//                                }
                                else if (!whiteBack.contains(where: {$0.contains(where: {$0 <= 15})})) {
                                    if !self.boardArray[24-roll[0]].contains(where: {$0 <= 15}) {
                                        if self.boardArray[18..<24-roll[0]].contains(where: {$0.contains(where: {$0 <= 15})}) {
                                            
                                        }
                                        else {
                                            self.moves.append([x, -2])
                                        }
                                    }
                                    else if x+self.roll[0] == 24 {
                                        self.moves.append([x, -2])
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
//                                else if !blackBack.contains(where: {$0.contains(where: {$0 >= 16})}) {
//                                    self.moves.append([x, 25])
//                                }
                                else if (!blackBack.contains(where: {$0.contains(where: {$0 >= 16})})) {
                                    if !self.boardArray[-1+roll[0]].contains(where: {$0 >= 16}) {
                                        if self.boardArray[roll[0]..<7].contains(where: {$0.contains(where: {$0 >= 16})}) {
                                            
                                        }
                                        else {
                                            self.moves.append([x, 25])
                                        }
                                    }
                                    else if x-self.roll[0] == -1 {
                                        self.moves.append([x, 25])
                                    }
                                }
                            }
                        }
                        
                    }
                    if color == "white" && self.whiteRail.count != 0 {
                        self.moves.removeAll()
                        if self.boardArray[self.roll[0]-1].contains(where: {$0 < 16}) || self.boardArray[self.roll[0]-1].count <= 1 {
                            self.moves.append([-1, self.roll[0]-1])
                        }
                    }
                    else if color == "black" && self.blackRail.count != 0 {
                        self.moves.removeAll()
                        if self.boardArray[24-self.roll[0]].contains(where: {$0 > 15}) || self.boardArray[24-self.roll[0]].count <= 1 {
                            self.moves.append([24, 24-self.roll[0]])
                        }
                        
                    }
                    
                    if self.moves.isEmpty {
                        self.canMove = false // tell backend that turn is over ##################
                        self.holdingPiece = nil
                        if self.usedMoves.count == 1 {
                            self.settingRoll = true
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : notMyColor,
                                "isFirst" : false,
                                "move0" : usedMoves[0],
                                "move1" : [0],
                                "move2" : [0],
                                "move3" : [0],
                                "dice0or" : [0],
                                "dice1or" : [0],
                                ], merge: true)
                        }
                        else if self.usedMoves.count == 2 {
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : notMyColor,
                                "isFirst" : false,
                                "move0" : usedMoves[0],
                                "move1" : usedMoves[1],
                                "move2" : [0],
                                "move3" : [0],
                                "dice0or" : [0],
                                "dice1or" : [0],
                                ], merge: true)
                        }
                        else if self.usedMoves.count == 3 {
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : notMyColor,
                                "isFirst" : false,
                                "move0" : usedMoves[0],
                                "move1" : usedMoves[1],
                                "move2" : usedMoves[2],
                                "move3" : [0],
                                "dice0or" : [0],
                                "dice1or" : [0],
                                ], merge: true)
                        }
                        else if self.usedMoves.count == 4 {
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : notMyColor,
                                "isFirst" : false,
                                "move0" : usedMoves[0],
                                "move1" : usedMoves[1],
                                "move2" : usedMoves[2],
                                "move3" : usedMoves[3],
                                "dice0or" : [0],
                                "dice1or" : [0],
                                ], merge: true)
                        }
                        
                        self.firstRollOver = true
                        return
                    }
                    self.holdingPiece = nil
                }
                else {
                    let sep : Double = 1.82
                    var xPos = Double()
                    let wSep = 2.0
                    var newPosition = SCNVector3()
                    if holdingPiece! == -1 {
                        self.whiteRail.append(holdingName!)
                        newPosition = SCNVector3(wSep*Double(self.whiteRail.count), 0.5, 0.3)
                    }
                    else if holdingPiece! == 24 {
                        self.blackRail.append(holdingName!)
                        newPosition = SCNVector3(wSep*Double(-self.blackRail.count), 0.5, 0.3)
                    }
                    else if holdingPiece! < 12 {
                        //xPos = (-9+sep*Double(boardArray[holdingPiece!].count))
                        var height = Double()
                        if boardArray[holdingPiece!].count >= 10 {
                            xPos = (-9+sep*Double(boardArray[holdingPiece!].count-10))
                            height = 1.5
                        }
                        else if boardArray[holdingPiece!].count >= 5 {
                            xPos = (-9+sep*Double(boardArray[holdingPiece!].count-5))
                            height = 1.0
                        }
                        else {
                            xPos = (-9+sep*Double(boardArray[holdingPiece!].count))
                            height = 0.5
                        }
                        newPosition = SCNVector3(xPos, height, self.position[holdingPiece!])
                        boardArray[holdingPiece!].append(holdingName!)
                    }
                    else {
                        //xPos = (9-sep*Double(boardArray[holdingPiece!].count))
                        var height = Double()
                        if boardArray[holdingPiece!].count >= 10 {
                            xPos = (9-sep*Double(boardArray[holdingPiece!].count-10))
                            height = 1.5
                        }
                        else if boardArray[holdingPiece!].count >= 5 {
                            xPos = (9-sep*Double(boardArray[holdingPiece!].count-5))
                            height = 1.0
                        }
                        else {
                            xPos = (9-sep*Double(boardArray[holdingPiece!].count))
                            height = 0.5
                        }
                        newPosition = SCNVector3(xPos, height, self.position[holdingPiece!])
                        boardArray[holdingPiece!].append(holdingName!)
                    }
                    let actionMove = SCNAction.move(to: newPosition, duration: 0.3)
                    holdingNode!.runAction(actionMove)
                    self.holdingPiece = nil
                }
                
                
            }
            else if rec.state == .ended {
                print("debug: special case in long press")
                self.debugLabel.text = "debug: this is a special case"
                let sep : Double = 1.82
                var xPos = Double()
                let wSep = 2.0
                var newPosition = SCNVector3()
                if holdingPiece! == -1 {
                    self.whiteRail.append(holdingName!)
                    newPosition = SCNVector3(wSep*Double(self.whiteRail.count), 0.5, 0.3)
                }
                else if holdingPiece! == 24 {
                    self.blackRail.append(holdingName!)
                    newPosition = SCNVector3(wSep*Double(-self.blackRail.count), 0.5, 0.3)
                }
                else if holdingPiece! < 12 {
                    //xPos = (-9+sep*Double(boardArray[holdingPiece!].count))
                    var height = Double()
                    if boardArray[holdingPiece!].count >= 10 {
                        xPos = (-9+sep*Double(boardArray[holdingPiece!].count-10))
                        height = 1.5
                    }
                    else if boardArray[holdingPiece!].count >= 5 {
                        xPos = (-9+sep*Double(boardArray[holdingPiece!].count-5))
                        height = 1.0
                    }
                    else {
                        xPos = (-9+sep*Double(boardArray[holdingPiece!].count))
                        height = 0.5
                    }
                    newPosition = SCNVector3(xPos, height, self.position[holdingPiece!])
                    boardArray[holdingPiece!].append(holdingName!)
                }
                else {
                    //xPos = (9-sep*Double(boardArray[holdingPiece!].count))
                    var height = Double()
                    if boardArray[holdingPiece!].count >= 10 {
                        xPos = (9-sep*Double(boardArray[holdingPiece!].count-10))
                        height = 1.5
                    }
                    else if boardArray[holdingPiece!].count >= 5 {
                        xPos = (9-sep*Double(boardArray[holdingPiece!].count-5))
                        height = 1.0
                    }
                    else {
                        xPos = (9-sep*Double(boardArray[holdingPiece!].count))
                        height = 0.5
                    }
                    newPosition = SCNVector3(xPos, height, self.position[holdingPiece!])
                    boardArray[holdingPiece!].append(holdingName!)
                }
                let actionMove = SCNAction.move(to: newPosition, duration: 0.3)
                holdingNode!.runAction(actionMove)
                self.holdingPiece = nil
            }
            else {
//                let actionMove = SCNAction.move(to: SCNVector3(position0.x, 4, position0.z), duration: 0.05)
//                holdingNode!.runAction(actionMove)
//                self.mainScene.rootNode.childNodes[1+self.boardArray[holdingPiece!].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
//                self.mainScene.rootNode.childNodes[1+self.boardArray[holdingPiece!].last!].runAction(actionMove)
                //holdingNode!.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                
                holdingNode!.position = SCNVector3(position0.x, 4, position0.z)
            }
            
            return
        }
        
        else if !hits.isEmpty{
            if let tappedNode = hits.first?.node {
                let zPos = hits.last!.worldCoordinates.z//tappedNode.position.z
                let xPos = hits.last!.worldCoordinates.x//tappedNode.position.x
                
                let index = getBoardIndex(x: xPos, z: zPos)
                print("first grab thinks pos is: \(zPos)")
                
                if index == -5 { // getBoardIndex returning null
                    return
                }
                else if index == -1 { // white rail
                    
                }
                else if index == 24 { // black rail
                    
                }
                else if index == 25 { // black bench
                    
                }
                else if index == -2 { // white bench
                    
                }
                else {
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
                }
                
                
                
                let poss = self.moves.filter({$0[0] == index})
                if poss.count == 0 {
                    print("no possible moves")
                    return
                }
                let position0 = hits.last!.worldCoordinates
                let actionMove = SCNAction.move(to: SCNVector3(position0.x, 4, position0.z), duration: 0.1)
                if rec.state == .began {
                    if index == -1 { // white rail
                        self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                        self.mainScene.rootNode.childNodes[1+self.whiteRail.last!].runAction(actionMove)
                        self.holdingPiece = index
                        self.holdingNode = self.mainScene.rootNode.childNodes[1+self.whiteRail.last!]
                        self.holdingName = self.whiteRail.last!
                        self.whiteRail.removeLast()
                        print("grab at white rail")
                    }
                    else if index == 24 { // black rail
                        self.mainScene.rootNode.childNodes[1+self.blackRail.last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                        self.mainScene.rootNode.childNodes[1+self.blackRail.last!].runAction(actionMove)
                        self.holdingPiece = index
                        self.holdingNode = self.mainScene.rootNode.childNodes[1+self.blackRail.last!]
                        self.holdingName = self.blackRail.last!
                        self.blackRail.removeLast()
                        print("grab at black rail")
                    }
                    else {
                        self.mainScene.rootNode.childNodes[1+self.boardArray[index].last!].physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                        self.mainScene.rootNode.childNodes[1+self.boardArray[index].last!].runAction(actionMove)
                        self.holdingPiece = index
                        self.holdingNode = self.mainScene.rootNode.childNodes[1+self.boardArray[index].last!]
                        self.holdingName = self.boardArray[index].last!
                        self.boardArray[index].removeLast()
                        print("grab at \(index)")
                    }
                    
                }
                else if rec.state == .ended {
                    print("debug: this should never be called")
                    self.debugLabel.text = "debug: this should never be called"
                }
//                else if rec.state == .ended {
//                    //holdingNode!.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
//                    self.holdingPiece = nil
//                }
                else {
                    //print("this also should never be called. rec state")
                    if holdingNode != nil {
                        holdingNode!.runAction(actionMove)
                    }
                    
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
        
        //print("x: \(xPos) z: \(zPos)")
        // put high priority rail touch condition here with return
        
        var index = Int()
        if zPos > 16.4 {
            index = xPos > 0 ? 25 : -2
        }
        else if zPos > 13.84 {
            index = xPos > 0 ? 23 : 0
        }
        else if zPos > 11.47 {
            index = xPos > 0 ? 22 : 1
        }
        else if zPos > 9.05 {
            index = xPos > 0 ? 21 : 2
        }
        else if zPos > 6.55 {
            index = xPos > 0 ? 20 : 3
        }
        else if zPos > 4.10 {
            index = xPos > 0 ? 19 : 4
        }
        else if zPos > 1.56 {
            index = xPos > 0 ? 18 : 5
        }
        else if zPos > -0.98 {
            index = xPos > 0 ? -1 : 24
        }
        else if zPos > -3.40 {
            index = xPos > 0 ? 17 : 6
        }
        else if zPos > -5.76 {
            index = xPos > 0 ? 16 : 7
        }
        else if zPos > -8.35 {
            index = xPos > 0 ? 15 : 8
        }
        else if zPos > -10.75 {
            index = xPos > 0 ? 14 : 9
        }
        else if zPos > -13.2 {
            index = xPos > 0 ? 13 : 10
        }
        else if zPos > -16{
            index = xPos > 0 ? 12 : 11
        }
        else {
            index = -5
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
                self.settleDice(completion: {
                    self.roll = self.getDice()
                    self.debugLabel.text = String(self.roll[0]) + String(self.roll[1])
                    if self.roll[self.color == "white" ? 0 : 1] > self.roll[self.color != "white" ? 0 : 1] {
                        if self.color == "white" {
                            print("u are white and you go first w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : "white",
                                "dice0or" : [0],
                                "dice1or" : [0],], merge: true)
                            self.debugLabel.text = self.debugLabel.text! + "white turn, u go"
                            self.killInitialRoll()
                            self.afterRoll()
                        }
                        else {
                            print("u are black and you go first w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : "black",
                                "dice0or" : [0],
                                "dice1or" : [0],], merge: true)
                            self.debugLabel.text = self.debugLabel.text! + "black turn, u go"
                            self.killInitialRoll()
                            self.afterRoll()
                        }
                    }
                    else if self.roll[self.color == "white" ? 0 : 1] < self.roll[self.color != "white" ? 0 : 1] {
                        if self.color == "white" {
                            print("u are white and you go after w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : "black",
                                "dice0or" : [0],
                                "dice1or" : [0],], merge: true)
                            self.debugLabel.text = self.debugLabel.text! + "black turn, not u"
                            self.killInitialRoll()
                            self.afterRoll()
                            self.firstRollOver = true
                        }
                        else {
                            print("u are black and you go after w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
                            self.db?.collection("games").document(self.gameID).setData([
                                "turn" : "white",
                                "dice0or" : [0],
                                "dice1or" : [0],], merge: true)
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
//                DispatchQueue.main.asyncAfter(deadline: .now()+6, execute: {
//                    self.roll = self.getDice()
//                    self.debugLabel.text = String(self.roll[0]) + String(self.roll[1])
//                    if self.roll[self.color == "white" ? 0 : 1] > self.roll[self.color != "white" ? 0 : 1] {
//                        if self.color == "white" {
//                            print("u are white and you go first w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
//                            self.db?.collection("games").document(self.gameID).setData([
//                                "turn" : "white",
//                                "dice0or" : [0],
//                                "dice1or" : [0],], merge: true)
//                            self.debugLabel.text = self.debugLabel.text! + "white turn, u go"
//                            self.killInitialRoll()
//                            self.afterRoll()
//                        }
//                        else {
//                            print("u are black and you go first w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
//                            self.db?.collection("games").document(self.gameID).setData([
//                                "turn" : "black",
//                                "dice0or" : [0],
//                                "dice1or" : [0],], merge: true)
//                            self.debugLabel.text = self.debugLabel.text! + "black turn, u go"
//                            self.killInitialRoll()
//                            self.afterRoll()
//                        }
//                    }
//                    else if self.roll[self.color == "white" ? 0 : 1] < self.roll[self.color != "white" ? 0 : 1] {
//                        if self.color == "white" {
//                            print("u are white and you go after w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
//                            self.db?.collection("games").document(self.gameID).setData([
//                                "turn" : "black",
//                                "dice0or" : [0],
//                                "dice1or" : [0],], merge: true)
//                            self.debugLabel.text = self.debugLabel.text! + "black turn, not u"
//                            self.killInitialRoll()
//                            self.afterRoll()
//                            self.firstRollOver = true
//                        }
//                        else {
//                            print("u are black and you go after w/ roll \(self.roll[self.color == "white" ? 0 : 1])")
//                            self.db?.collection("games").document(self.gameID).setData([
//                                "turn" : "white",
//                                "dice0or" : [0],
//                                "dice1or" : [0],], merge: true)
//                            self.debugLabel.text = self.debugLabel.text! + "white turn, not u"
//                            self.killInitialRoll()
//                            self.afterRoll()
//                            self.firstRollOver = true
//                        }
//
//                    }
//                    else {
//                        self.db?.collection("games").document(self.gameID).setData([
//                            self.myDice : [1]], merge: true)
//                    }
//
//                })
            }
        })
    }
    
    func throwDice(initial : Bool, spectating: Bool, dice0Ballistics : [SCNVector3], dice1Ballistics : [SCNVector3]) {
        //print("throwDice called, make sure not double")
        var dice0Position = SCNVector3()
        var dice1Position = SCNVector3()
        if initial {
            dice0Position = SCNVector3(-8, 7, 8)
            dice1Position = SCNVector3(8, 7, -8)
        }
        else if spectating {
            dice0Position = self.color != "white" ? SCNVector3(-9, 7, 7) : SCNVector3(9, 7, -7)
            dice1Position = self.color != "white" ? SCNVector3(-9, 7, 9) : SCNVector3(9, 7, -9)
        }
        else {
            dice0Position = self.color == "white" ? SCNVector3(-9, 7, 7) : SCNVector3(9, 7, -7)
            dice1Position = self.color == "white" ? SCNVector3(-9, 7, 9) : SCNVector3(9, 7, -9)
        }
        let force = dice0Ballistics[0]
        let position = dice0Ballistics[1]
        
        if mainScene.rootNode.childNodes.count == 35 {
            mainScene.rootNode.childNodes[33].removeFromParentNode()
            mainScene.rootNode.childNodes[33].removeFromParentNode()
        }
        
//        if mainScene.rootNode.childNodes.count == 32 {
//        var geometry:SCNGeometry
//        geometry = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.1)
//        geometry.materials.first?.diffuse.contents = UIColor.cyan
//        geometry.firstMaterial?.diffuse.contents = UIColor.cyan
        let geometryNode0 = SCNScene(named: "scnModels.scnassets/die.scn")!
        let geometryNode = geometryNode0.rootNode.childNodes.first!
        geometryNode.scale = SCNVector3(0.5, 0.5, 0.5)
        geometryNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        geometryNode.position = dice0Position
        geometryNode.physicsBody?.applyForce(force, at: position, asImpulse: true)
        mainScene.rootNode.addChildNode(geometryNode)
//        }
//        else {
//            mainScene.rootNode.childNodes[33].eulerAngles = SCNVector3(0, 0, 0)
//            mainScene.rootNode.childNodes[33].position = dice0Position
//            mainScene.rootNode.childNodes[33].physicsBody?.applyForce(force, at: position, asImpulse: true)
//        }
    
        let force1 = dice1Ballistics[0]
        let position1 = dice1Ballistics[1]
//        if mainScene.rootNode.childNodes.count == 33 {
//        var geometry1:SCNGeometry
//        geometry1 = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.1)
//        geometry1.materials.first?.diffuse.contents = UIColor.cyan
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
//            mainScene.rootNode.childNodes[34].eulerAngles = SCNVector3(0, 0, 0)
//            mainScene.rootNode.childNodes[34].position = dice1Position
//            mainScene.rootNode.childNodes[34].physicsBody?.applyForce(force1, at: position1, asImpulse: true)
//        }
        
        
        
    }
    
    func setupScene() {
        mainScene = SCNScene()
        sceneView.scene = mainScene
        
        mainScene.physicsWorld.gravity.y = Float(-95.0)
        
        sceneView.allowsCameraControl = false
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
        //let zSep = 2.35
        let sep = 1.82
        
        for x in 1..<31 {
            var p0:SCNGeometry
            p0 = SCNCylinder(radius: pieceRadius, height: pieceHeight)
            p0.materials.first?.diffuse.contents = UIColor.red
            let p0n = SCNNode(geometry: p0)
            p0n.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
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
        var box0:SCNGeometry
        box0 = SCNBox(width: 22.0, height: 0.5, length: 40.0, chamferRadius: 0.05)
        box0.materials.first?.diffuse.contents = UIColor.clear
        let box0Node = SCNNode(geometry: box0)
        
        box0Node.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        box0Node.position = SCNVector3(0, -1, 0) //22 32 0.05
        mainScene.rootNode.addChildNode(box0Node)
        print(self.mainScene.rootNode.childNodes.count)
    }
    
    func getDice() -> [Int] {
        var diceList = [Int]()
        
        for x in 33..<35 {//self.mainScene.rootNode.childNodes.count-2..<self.mainScene.rootNode.childNodes.count {
            let angles = self.mainScene.rootNode.childNodes[x].presentation.eulerAngles
            print(x)
            
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
                
            else if (angles.z > -0.2 && angles.z < 0.2) && (angles.x > 1.35 && angles.x < 1.75) { // 3s as 4
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
                
            else if (angles.y > -0.8 && angles.y < 0.9) && (angles.z < -1.35 && angles.z > -1.75) {
                diceList.append(5)
            }
            else if (angles.y > 2.4 || angles.y < -2.6) && (angles.z > 1.35 && angles.z < 2.2) {
                diceList.append(5)
            }
                
            else if (angles.x < -3 || angles.x > 3) && angles.z > -0.2 && angles.z < 0.2 { // 3s have been 6s
                diceList.append(6)
            }
            else if (angles.z < -3 || angles.z > 3) && (angles.x > -0.2 && angles.x < 0.2) {
                diceList.append(6)
            }
                
            else {
                diceList.append(4)
            }
        }
        if diceList[0] == diceList[1] {
            diceList.append(contentsOf: [diceList[0], diceList[1]])
        }
        return diceList
    }
    
    
    func settleDice (completion: @escaping () -> Void) {
        let oldPos0 = self.mainScene.rootNode.childNodes[33].presentation.eulerAngles
        let oldPos1 = self.mainScene.rootNode.childNodes[34].presentation.eulerAngles
        DispatchQueue.main.asyncAfter(deadline: .now()+1) {
            let newPos0 = self.mainScene.rootNode.childNodes[33].presentation.eulerAngles
            let newPos1 = self.mainScene.rootNode.childNodes[34].presentation.eulerAngles
            let minInt : Float = 0.5
            print("\n")
            print(self.mainScene.rootNode.childNodes.count)
            print("\(oldPos0) - \(newPos0)")
            print("\(oldPos1) - \(newPos1)")
            print(self.mainScene.rootNode.childNodes[33])
            print("\n")
            print(self.mainScene.rootNode.childNodes[34])
            print("\n")
            if (abs(oldPos0.x-newPos0.x) < minInt) && (abs(oldPos0.y-newPos0.y) < minInt) && (abs(oldPos0.z-newPos0.z) < minInt) {
                if  (abs(oldPos1.x-newPos1.x) < minInt) && (abs(oldPos1.y-newPos1.y) < minInt) && (abs(oldPos1.z-newPos1.z) < minInt) {
                    print("sent completion")
                    completion()
                }
                else {
                    print("trying again")
                    self.settleDice {
                        completion()
                    }
                }
            }
            else {
                print("trying again")
                self.settleDice {
                    completion()
                }
            }
        }
    }
    
    @objc func returnTapped () {
        if self.isHost {
            let db = Firestore.firestore()
            db.collection("games").document(gameID).delete()
        }
        if let vc = presentingViewController as? ViewController {
            vc.isReturning = true
        }
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
