//
//  GameScene.swift
//  MyGame
//
//  Created by hello on 2019/2/26.
//  Copyright © 2019 game. All rights reserved.
//

//https://www.jianshu.com/p/304e84a12b91
/*
 PS:这里稍微多介绍一点SKLabelNode这个类，如果做过iOS应用开发的朋友应该都知道UILabel这个控件，跟UILabel类似SKLabelNode就是SpriteKit中显示一段文字的空间，首先他是继承自SKNode，所以它可以被添加到场景里面，它也可以执行各种Action动作。另外可能还有一个你不适应的地方就是他的位置布局问题，在做iOS应用时候UILabel有大小，UILabel的原点在它自己左上角，你自然知道怎么放置它了。但是SKLabelNode是没有size这个属性的，他的frame属性也只是readonly的，这怎么办？SKLabelNode有两个新的属性叫做verticalAlignmentMode和horizontalAlignmentMode，表示这个label在水平和垂直方向上如何布局，他们是枚举类型。比如你把的SKLabelNode的postion位置设置在(50,100)这个点，然后把他的verticalAlignmentMode 设置为.top，则表示这段文字的顶部是position所在位置的y的水平高度上，如果设置为.bottom，则这段文字的底部水平线高度就是position的y的水平高度。所以
 **/
import SpriteKit

enum GameStatus {
    case idle    //初始化
    case running    //游戏运行中
    case over    //游戏结束
}

class GameScene: SKScene {
    
    // 布置地面
    var floor1:SKSpriteNode!
    var floor2:SKSpriteNode!
    
    var bird: SKSpriteNode!//鸟
    
    var gameStatus: GameStatus = .idle  //表示当前游戏状态的变量，初始值为初始化状态
    
    //设置三个常量来表示小鸟、水管和地面物理体
    let birdCategory: UInt32 = 0x1 << 0
    let pipeCategory: UInt32 = 0x1 << 1
    let floorCategory: UInt32 = 0x1 << 2
    
    //但是这个游戏结束有点突兀，最好能给个提示告诉玩家游戏结束了。
    lazy var gameOverLabel: SKLabelNode = {
        let label = SKLabelNode(fontNamed: "Chalkduster")
        label.text = "Game Over"
        return label
    }()
    
    //用来展示用户走了多远的距离
    lazy var metersLabel: SKLabelNode = {
        let label = SKLabelNode(text: "meters:0")
        label.verticalAlignmentMode = .top
        label.horizontalAlignmentMode = .right
        return label
    }()
    
    //记录飞行米数的变量
    var meters = 0 {
        didSet  {
            metersLabel.text = "meters:\(meters)"
        }
    }
    
    //didMove()方法会在当前场景被显示到一个view上的时候调用，你可以在里面做一些初始化的工作
    override func didMove(to view: SKView) {
        self.backgroundColor = SKColor(red: 80.0/255.0, green: 192.0/255.0, blue: 203.0/255.0, alpha: 1.0)
        
        /*
         可以看到为什么我弄了两个floor？因为我们一会要让floor向左移动，使得看起来小鸟在向右飞，所以我弄了两个floor头尾两连地放着，等会我们就让两个floor一起往左边移动，当左边的floor完全超出屏幕的时候，就马上把左边的floor移动凭借到右边的floor后面然后继续向左移动，如此循环下去。
         **/
        floor1 = SKSpriteNode.init(imageNamed: "floor")
        floor1.anchorPoint = CGPoint.init(x: 0, y: 0)
        floor1.position = CGPoint.init(x: 0, y: 0)
        self.addChild(floor1)
        
        floor2 = SKSpriteNode.init(imageNamed: "floor")
        floor2.anchorPoint = CGPoint.init(x: 0, y: 0)
        floor2.position = CGPoint.init(x: floor1.size.width, y: 0)
        self.addChild(floor2)
        
        
        //配置 鸟
        bird = SKSpriteNode(imageNamed: "player1")
        addChild(bird)
        
        //首先在场景初始化完成的时候，肯定要先调用一下shuffle()初始化
        shuffle()
        
        //配置场景的物理体 Set Scene physics
        self.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)//给场景添加一个物理体，这个物理体就是一条沿着场景四周的边，限制了游戏范围，其他物理体就不会跑出这个场景
        self.physicsWorld.gravity = CGVector(dx: 0.0, dy: -2.9)
        print(self.physicsWorld.gravity)//打印一下当前物理世界的重力加速度
        self.physicsWorld.contactDelegate = self //物理世界的碰撞检测代理为场景自己，这样如果这个物理世界里面有两个可以碰撞接触的物理体碰到一起了就会通知他的代理 (SKPhysicsContactDelegate)
        
        
        /*
         categoryBitMask，这个用来表示当前物理体是哪一个物理体，我们用我们刚刚准备好的floorCategory来表示他，等会碰撞检测的时候需要通过这个来判断。categoryBitMask 这个用来表示当前物理体是哪一个物理体
        **/
        //配置地面1的物理体
        floor1.physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: 0, y: 0, width: floor1.size.width, height: floor1.size.height))
        floor1.physicsBody?.categoryBitMask = floorCategory
        //配置地面2的物理体
        floor2.physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(x: 0, y: 0, width: floor2.size.width, height: floor2.size.height))
        floor2.physicsBody?.categoryBitMask = floorCategory
        
        /*
         contactTestBitMask是来设置可以与小鸟碰撞检测的物理体，我们设置了地面和水管，所以通常物理体的categoryBitMask用二进制移位方式来表示，这样在设置contactTestBitMask的时候就可以直接多个移位的标识做按位取或的运算即可
         **/
        //配置小鸟物理体
        bird.physicsBody = SKPhysicsBody(texture: bird.texture!, size: bird.size)
        bird.physicsBody?.allowsRotation = false    //禁止旋转
        bird.physicsBody?.categoryBitMask = birdCategory //设置小鸟物理体标示
        bird.physicsBody?.contactTestBitMask = floorCategory | pipeCategory //设置可以小鸟碰撞检测的物理体
        
        
        // Set Meter Label
        metersLabel.position = CGPoint(x: self.size.width * 0.5, y: self.size.height)
        metersLabel.zPosition = 100
        addChild(metersLabel)
    }

    //update()方法为SKScene自带的系统方法，在画面每一帧刷新的时候就会调用一次
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        if gameStatus != .over {
            moveScene()
        }
        if gameStatus == .running {
            meters += 1//累加飞行距离
        }
    }
    
    
    //现在我们知道了整个游戏会有三个进程状态，那么我们就给GameScene增加三个对应的方法，分别来处理这个三个状态。
    func shuffle()  {
        //游戏初始化处理方法
        gameStatus = .idle
        removeAllPipesNode()
        bird.position = CGPoint(x: self.size.width * 0.5, y: self.size.height * 0.5)
        /*
         isDynamic的作用是设置这个物理体当前是否会受到物理环境的影响，默认是true，我们在游戏初始化的时候设置小鸟不受物理环境影响，但是在游戏开始的时候才会受到物理环境的影响
         **/
        bird.physicsBody?.isDynamic = false//防止游戏一开始在初始化状态小鸟就受到重力的影响而掉到地面上了
        birdStartFly()
        
        /*
         不过要记住在游戏回到初始化状态下的时候，要把gameOverLabel从场景里移除掉，所以找到shuffle()方法，然后在removeAllPipesNode()方法后面加上下面这一句
         **/
        gameOverLabel.removeFromParent()
        
        meters = 0//重置飞行距离
    }
    func startGame()  {
        //游戏开始处理方法
        gameStatus = .running
        bird.physicsBody?.isDynamic = true //小岛开始受到重力作用
        startCreateRandomPipesAction()  //开始循环创建随机水管
    }
    func gameOver()  {
        //游戏结束处理方法
        gameStatus = .over
        birdStopFly()
        stopCreateRandomPipesAction()
        
        /*
         接下来找到gameOver()方法，在此方法的最后加上下面的代码，这样在gameOver的时候就会有一个提示语从天而降了
         **/
        //禁止用户点击屏幕
        isUserInteractionEnabled = false
        //添加gameOverLabel到场景里
        addChild(gameOverLabel)
        //设置gameOverLabel其实位置在屏幕顶部
        gameOverLabel.position = CGPoint(x: self.size.width * 0.5, y: self.size.height)
        //让gameOverLabel通过一个动画action移动到屏幕中间
        gameOverLabel.run(SKAction.move(by: CGVector(dx:0, dy:-self.size.height * 0.5), duration: 0.5), completion: {
            //动画结束才重新允许用户点击屏幕
            self.isUserInteractionEnabled = true
        })
    }
    
    
    /*
     touchesBegan()是SKScene自带的系统方法，当玩家手指点击到屏幕上的时候会调用，可以看到我们用switch语句来处理了三种不同的游戏状态下，玩家点击屏幕后做出的不同响应
     **/
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch gameStatus {
        case .idle:
            startGame()//如果在初始化状态下，玩家点击屏幕则开始游戏
        case .running:
            /*
             这个句代码可以给小鸟的物理体施加一个向上的冲量，让小鸟获得一定的向上速度，但是由于小鸟还受重力影响，所以你得经常点击屏幕才能保持小鸟不掉下去。
             applyImpulse是什么？IapplyImpulse在物理上就是冲量的意思，冲量=质量 * (结束速度 - 初始速度)，即I = m * (v2 - v1)，如果物体的质量为1，那么冲量i = v2 - v1。当一个质量为1的物理体applyImpulse(CGVector(dx: 0, dy: 20))的意思就是让他在y的方向上叠加20m/s的速度。当然如果物理体质量m不为1，那叠加的速度就不是刚好等于冲量的字面量了，而是要除以m了。如一个质量为2的物理体同样applyImpulse(CGVector(dx: 0, dy: 20))，结果就是它在y的方向上叠加了10m/s的一个速度
             **/
            bird.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 20))
            print("给小鸟一个向上的力")//如果在游戏进行中状态下，玩家点击屏幕则给小鸟一个向上的力(暂时用print一句话代替)
        case .over:
            shuffle() //如果在游戏结束状态下，玩家点击屏幕则进入初始化状态
        }
    }

    
    //移动地面
    func moveScene() {
        /*
         我们在这个方法里先让两个floor向左移动1的位置，然后检查两个floor是否已经完全超出屏幕的左边，超出的floor则移动到另一个floor的右边。
         **/
        //make floor move
        floor1.position = CGPoint(x: floor1.position.x - 1, y: floor1.position.y)
        floor2.position = CGPoint(x: floor2.position.x - 1, y: floor2.position.y)
        //check floor position
        if floor1.position.x < -floor1.size.width {
            floor1.position = CGPoint(x: floor2.position.x + floor2.size.width, y: floor1.position.y)
        }
        if floor2.position.x < -floor2.size.width {
            floor2.position = CGPoint(x: floor1.position.x + floor1.size.width, y: floor2.position.y)
        }
        
        //循环检查场景的子节点，同时这个子节点的名字要为pipe
        for pipeNode in self.children where pipeNode.name == "pipe" {
            //因为我们要用到水管的size，但是SKNode没有size属性，所以我们要把它转成SKSpriteNode
            if let pipeSprite = pipeNode as? SKSpriteNode {
                //将水管左移1
                pipeSprite.position = CGPoint(x: pipeSprite.position.x - 1, y: pipeSprite.position.y)
                //检查水管是否完全超出屏幕左侧了，如果是则将它从场景里移除掉
                if pipeSprite.position.x < -pipeSprite.size.width * 0.5 {
                    pipeSprite.removeFromParent()
                }
            }
        }
    }
    
    
    /*
     先给GameScene添加两个新的方法，一个是让小鸟开始飞，一个是让小鸟停止飞(游戏结束，小鸟坠地了就要停止飞)
     **/
    //开始飞
    func birdStartFly() {
        /*
         我们用了准备的3张小鸟的图片生成了四个SKTexture纹理对象，他们四个连起来就是小鸟的翅膀从上->中->下->中这样一个循环过程然后用这一组纹理创建了一个飞的动作(flyAction)，同时设置纹理的变化时间为0.15秒然后让小鸟重复循环执行这个飞的动作，同时给这个动作使用了一个叫"fly"的key来标识在birdStopFly()方法里只有一句代码，就是把fly这个动作从小鸟身上移除掉
         **/
        let flyAction = SKAction.animate(with: [SKTexture(imageNamed: "player1"), SKTexture(imageNamed: "player2"),SKTexture(imageNamed: "player3"),SKTexture(imageNamed: "player2")],timePerFrame: 0.15)
        bird.run(SKAction.repeatForever(flyAction), withKey: "fly")
    }
    //停止飞
    func birdStopFly() {
        bird.removeAction(forKey: "fly")
    }
 
    
    //添加一对水管到场景里，这个方法有两个参数分别是上水管和下水管的大小，在此方法里仅仅做的是创建两个SKSpriteNode对象，然后将他们加到场景里
    func addPipes(topSize: CGSize, bottomSize: CGSize) {
        //创建上水管
        let topTexture = SKTexture(imageNamed: "topPipe")      //利用上水管图片创建一个上水管纹理对象
        let topPipe = SKSpriteNode(texture: topTexture, size: topSize)  //利用上水管纹理对象和传入的上水管大小参数创建一个上水管对象
        topPipe.name = "pipe"   //给这个水管取个名字叫pipe
        topPipe.position = CGPoint(x: self.size.width + topPipe.size.width * 0.5, y: self.size.height - topPipe.size.height * 0.5) //设置上水管的垂直位置为顶部贴着屏幕顶部，水平位置在屏幕右侧之外
        
        //创建下水管，每一句方法都与上面创建上水管的相同意义
        let bottomTexture = SKTexture(imageNamed: "bottomPipe")
        let bottomPipe = SKSpriteNode(texture: bottomTexture, size: bottomSize)
        bottomPipe.name = "pipe"
        bottomPipe.position = CGPoint(x: self.size.width + bottomPipe.size.width * 0.5, y: self.floor1.size.height + bottomPipe.size.height * 0.5)  //设置下水管的垂直位置为底部贴着地面的顶部，水平位置在屏幕右侧之外
        
        
        //配置上水管物理体
        topPipe.physicsBody = SKPhysicsBody(texture: topTexture, size: topSize)
        topPipe.physicsBody?.isDynamic = false
        topPipe.physicsBody?.categoryBitMask = pipeCategory
        //配置下水管物理体
        bottomPipe.physicsBody = SKPhysicsBody(texture: bottomTexture, size: bottomSize)
        bottomPipe.physicsBody?.isDynamic = false
        bottomPipe.physicsBody?.categoryBitMask = pipeCategory

        
        //将上下水管添加到场景里
        addChild(topPipe)
        addChild(bottomPipe)
    }
 
    //具体某一次创建一对水管方法，在此方法里计算上下水管大小随机数
    func createRandomPipes() {
        //先计算地板顶部到屏幕顶部的总可用高度
        let height = self.size.height - self.floor1.size.height
        //计算上下管道中间的空档的随机高度，最小为空档高度为2.5倍的小鸟的高度，最大高度为3.5倍的小鸟高度
        let pipeGap = CGFloat(arc4random_uniform(UInt32(bird.size.height))) + bird.size.height * 2.5
        //管道宽度在60
        let pipeWidth = CGFloat(60.0)
        //随机计算顶部pipe的随机高度，这个高度肯定要小于(总的可用高度减去空档的高度)
        let topPipeHeight = CGFloat(arc4random_uniform(UInt32(height - pipeGap)))
        //总可用高度减去空档gap高度减去顶部水管topPipe高度剩下就为底部的bottomPipe高度
        let bottomPipeHeight = height - pipeGap - topPipeHeight
        //调用添加水管到场景方法
        addPipes(topSize: CGSize(width: pipeWidth, height: topPipeHeight), bottomSize: CGSize(width: pipeWidth, height: bottomPipeHeight))
    }
    
    // 开始重复创建水管的动作方法
    func startCreateRandomPipesAction() {
        //创建一个等待的action,等待时间的平均值为3.5秒，变化范围为1秒
        let waitAct = SKAction.wait(forDuration: 3.5, withRange: 1.0)
        //创建一个产生随机水管的action，这个action实际上就是调用一下我们上面新添加的那个createRandomPipes()方法
        let generatePipeAct = SKAction.run {
            self.createRandomPipes()
        }
        //让场景开始重复循环执行"等待" -> "创建" -> "等待" -> "创建"。。。。。
        //并且给这个循环的动作设置了一个叫做"createPipe"的key来标识它
        run(SKAction.repeatForever(SKAction.sequence([waitAct, generatePipeAct])), withKey: "createPipe")
    }
    
    // 停止创建水管的动作方法
    func stopCreateRandomPipesAction() {
        self.removeAction(forKey: "createPipe")
    }
    
    // 移除掉场景里的所有水管
    func removeAllPipesNode() {
        for pipe in self.children where pipe.name == "pipe" {  //循环检查场景的子节点，同时这个子节点的名字要为pipe
            pipe.removeFromParent()  //将水管这个节点从场景里移除掉
        }
    }
    
}

extension GameScene:SKPhysicsContactDelegate{
    
    //检测碰撞
    /*
     在GameScene里添加下面这个方法代码，didBegin()会在当前物理世界有两个物理体碰撞接触了则回调用，这两个碰撞了的物理体的信息都在contact这个参数里面，分别是bodyA和bodyB
     **/
    func didBegin(_ contact: SKPhysicsContact) {
        //先检查游戏状态是否在运行中，如果不在运行中则不做操作，直接return
        if gameStatus != .running { return }
        //为了方便我们判断碰撞的bodyA和bodyB的categoryBitMask哪个小，小的则将它保存到新建的变量bodyA里的，大的则保存到新建变量bodyB里
        var bodyA : SKPhysicsBody
        var bodyB : SKPhysicsBody
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            bodyA = contact.bodyA
            bodyB = contact.bodyB
        }else {
            bodyA = contact.bodyB
            bodyB = contact.bodyA
        }
        //接下来判断bodyA是否为小鸟，bodyB是否为水管或者地面，如果是则游戏结束，直接调用gameOver()方法
        if (bodyA.categoryBitMask == birdCategory && bodyB.categoryBitMask == pipeCategory) ||
            (bodyA.categoryBitMask == birdCategory && bodyB.categoryBitMask == floorCategory) {
            gameOver()
        }
    }
}
