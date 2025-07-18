//
//  RNTapper.m
//  RhythmNetwork
//
//  Created by John Iversen on 10/10/04.
//  Copyright 2004 John Iversen. All rights reserved.
//

#import "RNTapperNode.h"
#import "MIOCConnection.h"
#import "RNNetworkView.h"
#import "MIOCVelocityProcessor.h"
#import "RNArchitectureDefines.h"

static NSArray *colorArray;

@implementation RNTapperNode

+ (NSArray *) colorArray
{
	if (colorArray == nil) {
		//colorArray = [@[[NSColor greenColor], [NSColor blueColor], [NSColor orangeColor], \
		//	[NSColor purpleColor], [NSColor brownColor], [NSColor blackColor]] retain];
        colorArray = [@[[NSColor systemGreenColor], [NSColor systemBlueColor], [NSColor systemOrangeColor], \
                        [NSColor systemPurpleColor], [NSColor systemBrownColor], [NSColor systemTealColor], \
                        [NSColor systemYellowColor], [NSColor systemPinkColor], [NSColor systemIndigoColor]] retain];
	}
	return colorArray;
}

// create a flash layer for the node (init on first call to drawWithRadius:
+ (CAShapeLayer *)flashLayerForRect:(NSRect)rect
{
	NSRect		insetRect	= NSInsetRect(rect, 1.0, 1.0);
	CGPathRef	path		= CGPathCreateWithEllipseInRect(insetRect, NULL);
	
	CAShapeLayer *layer = [CAShapeLayer layer];
	layer.path			= path;
	layer.bounds			= insetRect;
	layer.position		= CGPointMake(NSMidX(insetRect), NSMidY(insetRect));
	layer.fillColor		= [[NSColor clearColor] CGColor];
	layer.strokeColor		= NULL;
	layer.lineWidth		= 0.0;

	CGPathRelease(path);
	return layer;
}
+ (CAShapeLayer *)ringLayerForRect:(NSRect)rect
{
    CGPathRef path = CGPathCreateWithEllipseInRect(rect, NULL);

	CAShapeLayer *layer = [CAShapeLayer layer];
	layer.path			= path;
	layer.bounds			= rect;
	layer.position		= CGPointMake(NSMidX(rect), NSMidY(rect));
	layer.fillColor		= NULL;
	layer.strokeColor		= [[NSColor clearColor] CGColor];
	layer.lineWidth		= 2.0;
	layer.opacity		= 0.0;

    CGPathRelease(path);
    return layer;
}


//designated initializer
- (RNTapperNode *)initWithNodeNumber: (RNNodeNum_t) nodeNumber
{
	NSAssert( (nodeNumber < kMaxNodes), @"nodeNumber must be < %d (%d passed)", kMaxNodes, nodeNumber);
	
	self = [super init];
	if (!self) return nil;

	_nodeNumber = nodeNumber;
	
	if (nodeNumber==0) { //bigBrother, do nothing--subclass initializer will do the init

		
	} else { // tapper
		//calculate concentrator assignment based on nodeNumber (RNArchitectureDefines.h)
		Byte concentratorNo = portForNode(nodeNumber); //same as MIOC port
		Byte chan = channelForNode(nodeNumber);
		Byte note = noteForNode(nodeNumber);
		NSAssert3( (concentratorNo <= kNumConcentrators), @"nodeNumber exceeds the number of inputs available (%d > %d; %d concentrator(s))", nodeNumber, (kNumConcentrators * kNumInputsPerConcentrator), kNumConcentrators);
		[self setSourcePort: (Byte) concentratorNo 
				 SourceChan: (Byte) chan
				 SourceNote: (Byte) note];
		[self setDestPort: (Byte) concentratorNo
				 DestChan: (Byte) chan
				 DestNote: (Byte) note];
		
		//Remainder of initialization happens in RNNetwork -initFromDictionary:
		// plotting locations, stimulus channels and the like,
		// as only the network object knows connections and how many nodes there are
		
		// UPDATE: July 25 - for greater simplicity use 1:1 mapping between node and channel/note. This limits us to 15 tapper nodes, but practically
		// that is a reasonable compromise--for larger groups I won't be useing MIOC most likely. An alternative is to make channel = port and have the
		// notes uniquely encode the tapper. But MIOC only routes on port/channel
		
	}
	
	return self;
}

- (void) dealloc
{
	[_flashColor release];
	if (_flashTimer != nil) {
		[_flashTimer invalidate];
		[_flashTimer release];
		_flashTimer = nil;
	}
	[_sourceVelocityProcessor release];
	_sourceVelocityProcessor = nil;
	[_destVelocityProcessor release];
	_destVelocityProcessor = nil;
    
    [_flashLayer removeFromSuperlayer];
    [_ringLayer removeFromSuperlayer];
	
	[super dealloc];
}

// *********************************************
//    Accessors
// *********************************************
#pragma mark  Accessors

- (RNNodeNum_t) nodeNumber { return _nodeNumber; }

// set FROM details
- (void) setSourcePort: (Byte) newSourcePort SourceChan: (Byte) newSourceChan SourceNote: (Byte) newSourceNote
{
	[self setSourcePort: newSourcePort];
	[self setSourceChan: newSourceChan];
	[self setSourceNote: newSourceNote];
}

// set TO details
- (void) setDestPort: (Byte) newDestPort DestChan: (Byte) newDestChan DestNote: (Byte) newDestNote
{
	[self setDestPort: newDestPort];
	[self setDestChan: newDestChan];
	[self setDestNote: newDestNote];
}

- (Byte) sourcePort { return _sourcePort; }
- (void) setSourcePort: (Byte) newSourcePort
{
	_sourcePort = newSourcePort;
}


- (Byte) sourceChan { return _sourceChan; }
- (void) setSourceChan: (Byte) newSourceChan
{
	_sourceChan = newSourceChan;
}


- (Byte) sourceNote { return _sourceNote; }
- (void) setSourceNote: (Byte) newSourceNote
{
	_sourceNote = newSourceNote;
}


- (Byte) destPort { return _destPort; }
- (void) setDestPort: (Byte) newDestPort
{
	_destPort = newDestPort;
}


- (Byte) destChan { return _destChan; }
- (void) setDestChan: (Byte) newDestChan
{
	_destChan = newDestChan;
}


- (Byte) destNote { return _destNote; }
- (void) setDestNote: (Byte) newDestNote
{
	_destNote = newDestNote;
}

//where to route things for velocity weighting
- (Byte) otherNodePassthroughPort
{
	return kPatchThruPort; // !!!:jri:20050908 assumes <= 16 tappers, fix if we expand (by adding multiple patch ports)
}

- (Byte) otherNodePassthroughChan
{
	//assign channels sequentially (channel = node num)
	Byte patchChan = [self sourceChan] + kNumInputsPerConcentrator * ([self sourcePort] - 1);
	NSAssert1( (patchChan <= 15), @"patch chan out of range--too many tappers? (%u)", patchChan);
	return patchChan;
}

//processor applied to all performance input by a tapper
- (MIOCVelocityProcessor *) sourceVelocityProcessor { return _sourceVelocityProcessor; }
- (void) setSourceVelocityProcessor: (MIOCVelocityProcessor *) newSourceVelocityProcessor
{
	[_sourceVelocityProcessor autorelease];
	_sourceVelocityProcessor = [newSourceVelocityProcessor copy];
	[_sourceVelocityProcessor setPort:[self sourcePort]];
	[_sourceVelocityProcessor setChannel:[self sourceChan]];
	[_sourceVelocityProcessor setOnInput:YES];
}

//processor applied to all output sent to a tapper's drum machine
- (MIOCVelocityProcessor *) destVelocityProcessor { return _destVelocityProcessor; }
- (void) setDestVelocityProcessor: (MIOCVelocityProcessor *) newDestVelocityProcessor
{
	[_destVelocityProcessor autorelease];
	//patch up the processor so port and channel match ours
	_destVelocityProcessor = [newDestVelocityProcessor copy]; // !!!:jri:20050907 Need to copy, since all nodes maay be passed same init object
	[_destVelocityProcessor setPort:[self destPort]];
	[_destVelocityProcessor setChannel:[self destChan]];
	[_destVelocityProcessor setOnInput:NO];
}

//we split our performance into two paths--one for self feedback, the other is what other tappers hear,
// routed through an auxiliary port where velocity can be manipulated
// this processor is applied to that stream
- (MIOCVelocityProcessor *) otherNodeVelocityProcessor { return _otherNodeVelocityProcessor; }
- (void) setOtherNodeVelocityProcessor: (MIOCVelocityProcessor *) newVelocityProcessor
{
	[_otherNodeVelocityProcessor autorelease];
	//patch up the processor with correct channel in passthru port
	_otherNodeVelocityProcessor = [newVelocityProcessor copy];
	[_otherNodeVelocityProcessor setPort:[self otherNodePassthroughPort] ];
	[_otherNodeVelocityProcessor setChannel:[self otherNodePassthroughChan] ];
	[_otherNodeVelocityProcessor setOnInput:NO];
}

- (Byte) drumsetNumber { return _drumsetNumber; }
- (void) setDrumsetNumber:(Byte) newDrumsetNumber
{
	if (newDrumsetNumber > 49) {
		NSLog(@"Drum set number %d out of range (0 to 49)",newDrumsetNumber);
		newDrumsetNumber = 49; //will make it clear
	}
	_drumsetNumber = newDrumsetNumber;
}

// *********************************************
//    plotting 
// *********************************************
#pragma mark  Plotting

- (NSPoint) plotLocation { return _plotLocation; }
- (void) setPlotLocation: (NSPoint) newPlotLocation
{
	_plotLocation = newPlotLocation;
}
- (void) setPlotLocationX: (double) x Y: (double) y
{
	_plotLocation = NSMakePoint(x,y);
}

- (BOOL) hearsSelf { return _hearsSelf; }
- (void) setHearsSelf: (BOOL) flag
{
	_hearsSelf = flag;
}


- (BOOL) hearsBigBrother { return _hearsBigBrother; }
- (void) setHearsBigBrother: (BOOL) flag
{
	_hearsBigBrother = flag;
}

- (Byte) bigBrotherSubChannel {
	return _bigBrotherSubChannel;
}
- (void) setBigBrotherSubChannel: (Byte) newSubChannel
{
	_bigBrotherSubChannel = newSubChannel;
}


// *********************************************
//    Display
// *********************************************
#pragma mark  Display

- (void) drawWithRadius: (double) radius
{
	NSPoint centerPt = [self plotLocation]; 
	
	double nodeRadius = radius*kNodeScale;
	NSRect aRect = NSMakeRect( centerPt.x * radius - nodeRadius, centerPt.y * radius - nodeRadius, nodeRadius*2.0, nodeRadius*2.0);
	NSBezierPath *aPath = [NSBezierPath bezierPathWithOvalInRect:aRect];
		
	//make a feedback loop
	if ([self hearsSelf]) {
		NSPoint loopCenterPt;
		loopCenterPt.x = centerPt.x * radius * (1 + 1.2*kNodeScale);
		loopCenterPt.y = centerPt.y * radius * (1 + 1.2*kNodeScale);
		double loopRadius = nodeRadius / 1.8;
		NSRect loopRect = NSMakeRect( loopCenterPt.x - loopRadius, loopCenterPt.y - loopRadius, 2.0*loopRadius, 2.0*loopRadius );
		NSBezierPath *loopPath = [NSBezierPath bezierPathWithOvalInRect:loopRect];
		[[NSColor blackColor] setStroke];
		[loopPath stroke];
	}
	
    [[NSColor whiteColor] setFill];
    [aPath fill];
    
	//red: hears no stimulus
	//color code according to which channel of BB is heard--defined by # induction sequences...
	if ([self hearsBigBrother]) {
		[[RNTapperNode colorArray][([self bigBrotherSubChannel]-1)]  setStroke];
	} else {
		[[NSColor redColor] setStroke];
	}

	[aPath setLineWidth:2.0];
	[aPath stroke];
    
    // init flash animation layer
    if (_flashLayer == nil) {
        _flashLayer = [RNTapperNode flashLayerForRect:aRect];
        [[RNNetworkView sharedNetworkView].layer addSublayer: _flashLayer];
    }
    
    if (_ringLayer == nil) {
        _ringLayer = [RNTapperNode ringLayerForRect:aRect];
        [[RNNetworkView sharedNetworkView].layer addSublayer: _ringLayer];
    }
    
}

- (void) flashWithColor: (NSColor *) flashColor
{
    if (_flashLayer == nil)
        return;
    
    if (![NSThread isMainThread]) {
        NSLog(@"⚠️ Not on main thread!");
    }
    
    //_flashLayer.fillColor = [[NSColor clearColor] CGColor];
    
    // Create a Flash animation
	CABasicAnimation *fadeAnimation = [CABasicAnimation animationWithKeyPath:@"fillColor"];
	fadeAnimation.fromValue 	= (__bridge id)[flashColor CGColor];		// Start with full color
	fadeAnimation.toValue	= (__bridge id)[[NSColor whiteColor] CGColor];// Fade to transparent

	CAKeyframeAnimation *scale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
	scale.values				= @[@1.0, @1.5, @1.0];
	scale.keyTimes			= @[@0.0, @0.2, @1.0];
	scale.timingFunction		= [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];

	CAAnimationGroup *flashGroup = [CAAnimationGroup animation];
	flashGroup.animations			= @[fadeAnimation, scale];
	flashGroup.duration				= 0.3;
	flashGroup.fillMode				= kCAFillModeRemoved;
	flashGroup.timingFunction			= [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
	flashGroup.removedOnCompletion	= YES;

	[_flashLayer addAnimation:flashGroup forKey:@"flashEffect"];

	// Create a smoke ring animation
	CABasicAnimation *scaleRing = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
	scaleRing.fromValue			= @1.0;
	scaleRing.toValue			= @2.0;
	scaleRing.duration			= 0.5;
	scaleRing.timingFunction		= [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];

	// Fade (opacity)
	CABasicAnimation *fadeRing = [CABasicAnimation animationWithKeyPath:@"opacity"];
	fadeRing.fromValue	= @1.0;
	fadeRing.toValue		= @0.0;
	fadeRing.duration	= 0.5;

	CAAnimationGroup *ringGroup = [CAAnimationGroup animation];
	ringGroup.animations			= @[scaleRing, fadeRing];
	ringGroup.duration			= 0.5;
	ringGroup.timingFunction		= [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
	ringGroup.fillMode			= kCAFillModeRemoved;
	ringGroup.removedOnCompletion	= YES;
    [_ringLayer addAnimation:ringGroup forKey:@"ringEffect"];
    
    _ringLayer.strokeColor = [flashColor CGColor];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _ringLayer.opacity 	= 0.0;
        _ringLayer.transform 	= CATransform3DIdentity;
    });
}

@end
