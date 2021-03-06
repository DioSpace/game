//
//  GameScene1.swift
//  game
//
//  Created by lzd_free on 2019/3/21.
//  Copyright © 2019 Dio. All rights reserved.
//

import SpriteKit

class GameScene1: SKScene {
    
    override func didMove(to view: SKView) {
        self.backgroundColor = SKColor.green
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let scene = TargetScene.init(size: CGSize.init(width: ScreenWIDTH, height: ScreenHEIGHT))
        
        scene.scaleMode = .aspectFill
  
        self.view?.presentScene(scene)
    }
}
