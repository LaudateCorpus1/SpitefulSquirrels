//
//  StartMenuLayer.m
//  SpitefulSquirrels
//
//  Created by Matt on 7/30/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "StartMenuLayer.h"
#import "GameLayer.h"

@implementation StartMenuLayer

-(id) init
{
    if ((self = [super init]))
    {
        CCMenuItemFont* level1Button=
        [CCMenuItemFont itemFromString:@"Level 1" 
                                target:self
                              selector:@selector(startGame:)
                                   ];
        [level1Button setTag:1];
            
        CCMenuItemFont* level2Button=
        [CCMenuItemFont itemFromString:@"Level 2" 
                                target:self
                              selector:@selector(startGame:)];
        [level2Button setTag:2];
                                            
        CCMenu *myMenu = [CCMenu menuWithItems: level1Button, level2Button, nil];
        
        [myMenu setPosition:ccp([[CCDirector sharedDirector] winSize].width/2,
                                [[CCDirector sharedDirector] winSize].height/2)];
        [myMenu alignItemsHorizontallyWithPadding:30];
        [self addChild:myMenu z:1];
        
    }
    return self;
}

-(void) startGame: (CCMenuItem *)caller
{
    [[CCDirector sharedDirector] replaceScene: [GameLayer scene:[NSNumber numberWithInteger:[caller tag]]]];
}

+(id) scene
{
    CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	GameLayer *layer = [StartMenuLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
    
	// return the scene
	return scene;
}

@end
