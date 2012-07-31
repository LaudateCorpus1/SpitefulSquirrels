/*
 * Kobold2D™ --- http://www.kobold2d.org
 *
 * Copyright (c) 2010-2011 Steffen Itterheim. 
 * Released under MIT License in Germany (LICENSE-Kobold2D.txt).
 */

#import "GameLayer.h"
#import "SimpleAudioEngine.h"
#import "StartMenuLayer.h"

const float PTM_RATIO = 32.0f;
#define FLOOR_HEIGHT    62.0f

CCSprite *projectile;
CCSprite *block;
CGRect firstrect;
CGRect secondrect;
NSMutableArray *blocks = [[NSMutableArray alloc] init];
NSNumber *acornsFired=[[NSUserDefaults standardUserDefaults] objectForKey:@"acornsFired"];
NSNumber *level= [[NSNumber alloc] init];
BOOL level2Unlocked;


@interface GameLayer (PrivateMethods)
-(void) enableBox2dDebugDrawing;
-(void) addSomeJoinedBodies:(CGPoint)pos;
-(void) addNewSpriteAt:(CGPoint)p;
-(b2Vec2) toMeters:(CGPoint)point;
-(CGPoint) toPixels:(b2Vec2)vec;
@end

@implementation GameLayer

#pragma mark Initialize
-(id) init
{
	if ((self = [super init]))
	{
		CCLOG(@"%@ init", NSStringFromClass([self class]));
        
        
        if (acornsFired==nil) acornsFired=0;
        
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"explo2.wav"];
        
        bullets = [[NSMutableArray alloc] init];
        
        // Construct a world object, which will hold and simulate the rigid bodies.
		b2Vec2 gravity = b2Vec2(0.0f, -10.0f);
		world = new b2World(gravity);
		world->SetAllowSleeping(YES);
		//world->SetContinuousPhysics(YES);
        
        //create an object that will check for collisions
		contactListener = new ContactListener();
		world->SetContactListener(contactListener);
        
		glClearColor(0.1f, 0.0f, 0.2f, 1.0f);
        
        CGSize screenSize = [CCDirector sharedDirector].winSize;

        
        b2Vec2 lowerLeftCorner =b2Vec2(0,FLOOR_HEIGHT/PTM_RATIO);
		b2Vec2 lowerRightCorner = b2Vec2(screenSize.width*2.0f/PTM_RATIO,FLOOR_HEIGHT/PTM_RATIO);
		b2Vec2 upperLeftCorner = b2Vec2(0,screenSize.height/PTM_RATIO);
		b2Vec2 upperRightCorner = b2Vec2(2.0f*screenSize.width/PTM_RATIO,screenSize.height/PTM_RATIO);
		
		// Define the static container body, which will provide the collisions at screen borders.
		b2BodyDef screenBorderDef;
		screenBorderDef.position.Set(0, 0);
        screenBorderBody = world->CreateBody(&screenBorderDef);
		b2EdgeShape screenBorderShape;
        
        screenBorderShape.Set(lowerLeftCorner, lowerRightCorner);
        screenBorderBody->CreateFixture(&screenBorderShape, 0);
        
        screenBorderShape.Set(lowerRightCorner, upperRightCorner);
        screenBorderBody->CreateFixture(&screenBorderShape, 0);
        
        screenBorderShape.Set(upperRightCorner, upperLeftCorner);
        screenBorderBody->CreateFixture(&screenBorderShape, 0);
        
        screenBorderShape.Set(upperLeftCorner, lowerLeftCorner);
        screenBorderBody->CreateFixture(&screenBorderShape, 0);
        
        //Standard level sprites
        CCSprite *sprite = [CCSprite spriteWithFile:@"bg_mainlevel.png"];
        sprite.anchorPoint = CGPointZero;
        [self addChild:sprite z:-1];
        
        sprite = [CCSprite spriteWithFile:@"catapult_base_1.png"];
        sprite.anchorPoint = CGPointZero;
        sprite.position = CGPointMake(135.0f, FLOOR_HEIGHT);
        [self addChild:sprite z:0];
        
        sprite = [CCSprite spriteWithFile:@"squirrel_1.png"];
        sprite.anchorPoint = CGPointZero;
        sprite.position = CGPointMake(11.0f, FLOOR_HEIGHT);
        [self addChild:sprite z:0];
        
        sprite = [CCSprite spriteWithFile:@"catapult_base_2.png"];
        sprite.anchorPoint = CGPointZero;
        sprite.position = CGPointMake(135.0f, FLOOR_HEIGHT - 10.0f);
        [self addChild:sprite z:9];
        
        sprite = [CCSprite spriteWithFile:@"squirrel_2.png"];
        sprite.anchorPoint = CGPointZero;
        sprite.position = CGPointMake(240.0f, FLOOR_HEIGHT);
        [self addChild:sprite z:9];
        
        sprite = [CCSprite spriteWithFile:@"bg_mainlevel_foreground.png"];
        sprite.anchorPoint = CGPointZero;
        [self addChild:sprite z:10];
        
        CCSprite *arm = [CCSprite spriteWithFile:@"catapult_arm.png"];
        
        [self addChild:arm z:8];
        
        // Setting the properties of our definition
        b2BodyDef armBodyDef;
        armBodyDef.type = b2_dynamicBody;
        armBodyDef.linearDamping = 1;
        armBodyDef.angularDamping = 1;
        armBodyDef.position.Set(230.0f/PTM_RATIO,(FLOOR_HEIGHT+91.0f)/PTM_RATIO);
        armBodyDef.userData = (__bridge void*)arm; //this tells Box2D which sprite to update.
        
        //create a body with the definition we just created
        armBody = world->CreateBody(&armBodyDef); //the -> is C++ syntax
        
        //Create a fixture for the arm
        b2PolygonShape armBox;
        b2FixtureDef armBoxDef;
        armBoxDef.shape = &armBox;
        armBoxDef.density = 0.3F;
        armBox.SetAsBox(11.0f/PTM_RATIO, 91.0f/PTM_RATIO);
        armFixture = armBody->CreateFixture(&armBoxDef);
        
        // Create a joint to fix the catapult to the floor.
        b2RevoluteJointDef armJointDef;
        armJointDef.Initialize(screenBorderBody, armBody, b2Vec2(233.0f/PTM_RATIO, FLOOR_HEIGHT/PTM_RATIO));
        
        /*When creating the joint you have to specify 2 bodies and the hinge point. You might be thinking: “shouldn’t the catapult’s arm attach to the base?”. Well, in the real world, yes. But in Box2d not necessarily. You could do this but then you’d have to create another body for the base and add more complexity to the simulation.*/
        
        armJointDef.enableMotor = true; // the motor will fight against our motion, sort of like a spring
        armJointDef.enableLimit = true;
        armJointDef.motorSpeed  = -5; // this sets the motor to move the arm clockwise, so when you pull it back it springs forward
        armJointDef.lowerAngle  = CC_DEGREES_TO_RADIANS(9);
        armJointDef.upperAngle  = CC_DEGREES_TO_RADIANS(75);//these limit the range of motion of the catapult
        armJointDef.maxMotorTorque = 300; //this limits the speed at which the catapult can move
        armJoint = (b2RevoluteJoint*)world->CreateJoint(&armJointDef);
        
        if ([level intValue]==2)
        {
            level2Unlocked=[[[NSUserDefaults standardUserDefaults] 
                             objectForKey: @"level2Unlocked"] 
                            boolValue];
            if (level2Unlocked==true)
            {
                NSDictionary *level2 = [NSDictionary dictionaryWithContentsOfFile:@"level2.plist"];
                NSArray *dictBlocks = [level2 objectForKey:@"blocks"];
                for (NSDictionary *block in dictBlocks)
                {
                    sprite=[CCSprite spriteWithFile:[block objectForKey:@"spriteName"]];
                    sprite.position=CGPointMake([[block objectForKey:@"x"] floatValue], FLOOR_HEIGHT+[[block objectForKey:@"y"] floatValue]);
                    [self addChild:sprite z:7];
                    [blocks addObject:sprite];
                }
            }
            else level=[NSNumber numberWithInt:1];
        }
        if ([level intValue]==1)
        {
            [self createTargets];
            [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:TRUE] forKey:@"level2Unlocked"];
        }
		
		
        //Load the plist which tells Cocos2D how to properly parse your spritesheet
        
        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile: @"acorns.plist"];
        
        //Load in the spritesheet
        
        CCSpriteBatchNode *spriteSheet = [CCSpriteBatchNode batchNodeWithFile:@"acorns.png"];
        
        [self addChild:spriteSheet];
        
        //Define the frames based on the plist - note that for this to work, the original files must be in the format acorn1, acorn2, acorn3 etc...
        
        //When it comes time to get art for your own original game, makegameswith.us will give you spritesheets that follow this convention, <spritename>1 <spritename>2 <spritename>3 etc...
        
        flyingFrames = [NSMutableArray array];
        
        for(int i = 1; i <= 4; ++i)
        {
            [flyingFrames addObject:
             
             [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName: [NSString stringWithFormat:@"acorn%d.png", i]]];
        }
        
        //schedules a call to the update method every frame
		[self scheduleUpdate];
        [self performSelector:@selector(resetGame) withObject:nil afterDelay:0.5f];
	}
    
	return self;
}
#pragma mark-


#pragma mark TargetCreation
- (void)createTargets
{
    targets = [[NSMutableSet alloc] init];
    enemies = [[NSMutableSet alloc] init];
    
    // First block
    [self createTarget:@"brick_2.png" atPosition:CGPointMake(675.0, FLOOR_HEIGHT) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"brick_1.png" atPosition:CGPointMake(741.0, FLOOR_HEIGHT) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"brick_1.png" atPosition:CGPointMake(741.0, FLOOR_HEIGHT+23.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"brick_3.png" atPosition:CGPointMake(672.0, FLOOR_HEIGHT+46.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"brick_1.png" atPosition:CGPointMake(707.0, FLOOR_HEIGHT+58.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"brick_1.png" atPosition:CGPointMake(707.0, FLOOR_HEIGHT+81.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    
    [self createTarget:@"head_dog.png" atPosition:CGPointMake(702.0, FLOOR_HEIGHT) rotation:0.0f isCircle:YES isStatic:NO isEnemy:YES];
    [self createTarget:@"head_cat.png" atPosition:CGPointMake(680.0, FLOOR_HEIGHT+58.0f) rotation:0.0f isCircle:YES isStatic:NO isEnemy:YES];
    [self createTarget:@"head_dog.png" atPosition:CGPointMake(740.0, FLOOR_HEIGHT+58.0f) rotation:0.0f isCircle:YES isStatic:NO isEnemy:YES];
    
    // 2 bricks at the right of the first block
    [self createTarget:@"brick_2.png" atPosition:CGPointMake(770.0, FLOOR_HEIGHT) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"brick_2.png" atPosition:CGPointMake(770.0, FLOOR_HEIGHT+46.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    
    // The dog between the blocks
    [self createTarget:@"head_dog.png" atPosition:CGPointMake(830.0, FLOOR_HEIGHT) rotation:0.0f isCircle:YES isStatic:NO isEnemy:YES];
    
    // Second block
    [self createTarget:@"brick_platform.png" atPosition:CGPointMake(839.0, FLOOR_HEIGHT) rotation:0.0f isCircle:NO isStatic:YES isEnemy:NO];
    [self createTarget:@"brick_2.png"  atPosition:CGPointMake(854.0, FLOOR_HEIGHT+28.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"brick_2.png"  atPosition:CGPointMake(854.0, FLOOR_HEIGHT+28.0f+46.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"head_cat.png" atPosition:CGPointMake(881.0, FLOOR_HEIGHT+28.0f) rotation:0.0f isCircle:YES isStatic:NO isEnemy:YES];
    [self createTarget:@"brick_2.png"  atPosition:CGPointMake(909.0, FLOOR_HEIGHT+28.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"brick_1.png"  atPosition:CGPointMake(909.0, FLOOR_HEIGHT+28.0f+46.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"brick_1.png"  atPosition:CGPointMake(909.0, FLOOR_HEIGHT+28.0f+46.0f+23.0f) rotation:0.0f isCircle:NO isStatic:NO isEnemy:NO];
    [self createTarget:@"brick_2.png"  atPosition:CGPointMake(882.0, FLOOR_HEIGHT+108.0f) rotation:90.0f isCircle:NO isStatic:NO isEnemy:NO];
}

- (void)createTarget:(NSString*)imageName atPosition:(CGPoint)position rotation:(CGFloat)rotation isCircle:(BOOL)isCircle isStatic:(BOOL)isStatic isEnemy:(BOOL)isEnemy
{
    
    CCSprite *sprite = [CCSprite spriteWithFile:imageName];
    [self addChild:sprite z:1];
    
    
    b2BodyDef bodyDef;
    bodyDef.type = isStatic?b2_staticBody:b2_dynamicBody;
    bodyDef.position.Set((position.x+sprite.contentSize.width/2.0f)/PTM_RATIO,(position.y+sprite.contentSize.height/2.0f)/PTM_RATIO);
    bodyDef.angle = CC_DEGREES_TO_RADIANS(rotation);
    bodyDef.userData = (__bridge void*) sprite;
    b2Body *body = world->CreateBody(&bodyDef);
    
    b2FixtureDef boxDef;
    
    if (isCircle)
    {
        b2CircleShape circle;
        circle.m_radius = sprite.contentSize.width/2.0f/PTM_RATIO;
        boxDef.shape = &circle;
    }
    else
    {
        
        b2PolygonShape box;
        box.SetAsBox(sprite.contentSize.width/2.0f/PTM_RATIO,
                     sprite.contentSize.height/2.0f/PTM_RATIO);
        boxDef.shape = &box;
        
    }
    if (isEnemy)
        
    {
        boxDef.userData = (void*)1;
        [enemies addObject:[NSValue valueWithPointer:body]];
    }
    
    boxDef.density = 0.5f;
    body->CreateFixture(&boxDef);
    [targets addObject:[NSValue valueWithPointer:body]];
}
#pragma mark-

+(id) scene: (NSNumber *) lvl
{
    level=lvl;
    CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	GameLayer *layer = [GameLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
    
	// return the scene
	return scene;
}

-(void)goToStart
{
    [[CCDirector sharedDirector] replaceScene:[StartMenuLayer scene]];
}
#pragma mark-

#pragma mark BulletHandling
//Create the bullets, add them to the list of bullets so they can be referred to later
- (void)createBullets: (int) count
{
    currentBullet = 0;
    CGFloat pos = 62.0f;
    
    if (count > 0)
    {
        // delta is the spacing between corns
        // 62 is the position o the screen where we want the acorns to start appearing
        // 165 is the position on the screen where we want the acorns to stop appearing
        // 30 is the size of the acorn
        CGFloat delta = (count > 1)?((165.0f - 62.0f - 30.0f) / (count - 1)):0.0f;
        
        bullets = [[NSMutableArray alloc] initWithCapacity:count];
        for (int i=0; i<count; i++, pos+=delta)
        {
            // Create the bullet
            
            CCSprite *sprite = [CCSprite spriteWithFile:@"acorn.png"];
            [self addChild:sprite z:1];
            
            b2BodyDef bulletBodyDef;
            bulletBodyDef.type = b2_dynamicBody;
            bulletBodyDef.bullet = true; //this tells Box2D to check for collisions more often
            bulletBodyDef.position.Set(pos/PTM_RATIO,(FLOOR_HEIGHT+15.0f)/PTM_RATIO);
            bulletBodyDef.userData = (__bridge void*)sprite;
            b2Body *bullet = world->CreateBody(&bulletBodyDef);
            bullet->SetActive(false);
            
            b2CircleShape circle;
            circle.m_radius = 15.0/PTM_RATIO; //you can figure the dimensions out by looking at acorn.png in image editing software
            
            b2FixtureDef ballShapeDef;
            ballShapeDef.shape = &circle;
            ballShapeDef.density = 0.8f;
            ballShapeDef.restitution = 0.2f;
            ballShapeDef.friction = 0.99f;
            //try changing these and see what happens!
            bullet->CreateFixture(&ballShapeDef);
            
            [bullets addObject:[NSValue valueWithPointer:bullet]];
            acornsFired=[NSNumber numberWithInt:[acornsFired intValue]+1];
            [[NSUserDefaults standardUserDefaults] setObject:acornsFired forKey:@"acornsFired"];
            CCLOG(@"%i", [acornsFired intValue]);
        }
    }
}

- (BOOL)attachBullet
{
    if (currentBullet < [bullets count])
    {
        bulletBody = (b2Body*)[[bullets objectAtIndex:currentBullet++] pointerValue];
        bulletBody->SetTransform(b2Vec2(230.0f/PTM_RATIO, (155.0f+FLOOR_HEIGHT)/PTM_RATIO), 0.0f);
        bulletBody->SetActive(true);
        
        b2WeldJointDef weldJointDef;
        weldJointDef.Initialize(bulletBody, armBody, b2Vec2(230.0f/PTM_RATIO,(155.0f+FLOOR_HEIGHT)/PTM_RATIO));
        weldJointDef.collideConnected = false;
        
        bulletJoint = (b2WeldJoint*)world->CreateJoint(&weldJointDef);
        return YES;
    }
    
    return NO;
}

- (void)resetBullet
{
    if ([enemies count] == 0)
    {
        // game over
        // We'll do something here later
    }
    else if ([self attachBullet])
    {
        [self runAction:[CCMoveTo actionWithDuration:2.0f position:CGPointZero]];
    }
    else
    {
        [self goToStart];
    }
}

#pragma mark-

//Check through all the bullets and blocks and see if they intersect
-(void) detectCollisions
{
    for(int i = 0; i < [bullets count]; i++)
    {
        for(int j = 0; j < [blocks count]; j++)
        {
            if([bullets count]>0)
            {
                NSInteger first = i;
                NSInteger second = j;
                block = [blocks objectAtIndex:second];
                projectile = [bullets objectAtIndex:first];
                
                firstrect = [projectile textureRect];
                secondrect = [block textureRect];
                //check if their x coordinates match
                if(projectile.position.x == block.position.x)
                {
                    //check if their y coordinates are within the height of the block
                    if(projectile.position.y < (block.position.y + 23.0f) && projectile.position.y > block.position.y - 23.0f)
                    {
                        [self removeChild:block cleanup:YES];
                        [self removeChild:projectile cleanup:YES];
                        [blocks removeObjectAtIndex:second];
                        [bullets removeObjectAtIndex:first];
                        [[SimpleAudioEngine sharedEngine] playEffect:@"explo2.wav"];
                        
                    }
                }
            }
            
        }
        
    }
}

- (void)resetGame
{
    [self createBullets:4];
    [self attachBullet];
    [self createTargets];
}

-(void) dealloc
{
	delete world;
    
#ifndef KK_ARC_ENABLED
	[super dealloc];
#endif
}



-(void) update:(ccTime)delta
{
    //get all the bodies in the world
    for (b2Body* body = world->GetBodyList(); body != nil; body = body->GetNext())
    {
        //get the sprite associated with the body
        CCSprite* sprite = (__bridge CCSprite*)body->GetUserData();
        if (sprite != NULL)
        {
            // update the sprite's position to where their physics bodies are
            sprite.position = [self toPixels:body->GetPosition()];
            float angle = body->GetAngle();
            sprite.rotation = CC_RADIANS_TO_DEGREES(angle) * -1;
        }
    }
    //Check for inputs and create a bullet if there is a tap
    KKInput* input = [KKInput sharedInput];
    
    
    if(input.anyTouchBeganThisFrame) //this is when someone's finger first hits the screen
    {
        CGPoint location = input.anyTouchLocation;
        b2Vec2 locationWorld = b2Vec2(location.x/PTM_RATIO, location.y/PTM_RATIO);
        
        if (locationWorld.x < armBody->GetWorldCenter().x + 50.0/PTM_RATIO) //if we're touching the catapult area
        {
            b2MouseJointDef md;
            md.bodyA = screenBorderBody;
            md.bodyB = armBody;
            md.target = locationWorld;
            md.maxForce = 2000;
            //we create a mouse joint that can pull the catapult
            mouseJoint = (b2MouseJoint *)world->CreateJoint(&md);
        }
        
    }
    
    else if(input.anyTouchEndedThisFrame) // if they let go
    {
        if (mouseJoint != nil)
        {
            //destroying the mouse joint lets the catapult motor rotate it back to its original prosition
            world->DestroyJoint(mouseJoint);
            [self performSelector:@selector(resetBullet) withObject:nil afterDelay:5.0f];
            mouseJoint = nil;
        }
    }
    
    if (armJoint->GetJointAngle() >= CC_DEGREES_TO_RADIANS(20))
    {
        releasingArm = YES;
    }
    
    else if(input.touchesAvailable) //if they are dragging the catapult
    {
        if (mouseJoint == nil) return;
        CGPoint location = input.anyTouchLocation;
        location = [[CCDirector sharedDirector] convertToGL:location];
        b2Vec2 locationWorld = b2Vec2(location.x/PTM_RATIO, location.y/PTM_RATIO);
        
        mouseJoint->SetTarget(locationWorld);
    }
    // Arm is being released.
    if (releasingArm && bulletJoint)
    {
        // Check if the arm reached the end so we can return the limits
        if (armJoint->GetJointAngle() <= CC_DEGREES_TO_RADIANS(10))
        {
            releasingArm = NO;
            
            // Destroy joint so the bullet will be free
            world->DestroyJoint(bulletJoint);
            bulletJoint = nil;
            
        }
    }
    
    float timeStep = 0.03f;
    int32 velocityIterations = 8;
    int32 positionIterations = 1;
    world->Step(timeStep, velocityIterations, positionIterations);
    
    //Bullet is moving.
    if (bulletBody && bulletJoint == nil)
    {
        b2Vec2 position = bulletBody->GetPosition();
        CGPoint myPosition = self.position;
        CGSize screenSize = [CCDirector sharedDirector].winSize;
        
        // Move the camera.
        if (position.x > screenSize.width / 2.0f / PTM_RATIO)
        {
            myPosition.x = -MIN(screenSize.width * 2.0f - screenSize.width, position.x * PTM_RATIO - screenSize.width / 2.0f);
            self.position = myPosition;
        }
    }
    
}



// convenience method to convert a b2Vec2 to a CGPoint
-(CGPoint) toPixels:(b2Vec2)vec
{
	return ccpMult(CGPointMake(vec.x, vec.y), PTM_RATIO);
}


@end
