//
//  RNTapper.m
//  RhythmNetwork
//
//  Created by John Iversen on 10/10/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "RNTapperNode.h"
#import "MIOCConnection.h"
#import "RNNetworkView.h"

static NSArray *colorArray;

@implementation RNTapperNode

+ (NSArray *) colorArray
{
	if (colorArray == nil) {
		colorArray = [[NSArray arrayWithObjects: [NSColor greenColor], [NSColor blueColor], [NSColor orangeColor], \
			[NSColor purpleColor], [NSColor brownColor], nil] retain];
	}
	return colorArray;
}

//designated initializer
- (RNTapperNode *)initWithNodeNumber: (RNNodeNum_t) nodeNumber
{
	Byte concentratorNo, note;
	NSAssert1( (nodeNumber < 255), @"For now nodeNumber must be < 255 (%d passed)", nodeNumber);
	
	self = [super init];
	_nodeNumber = nodeNumber;
	
	if (nodeNumber==0) { //bigBrother, do nothing

		
	} else { //actual tapper
		//calculate concentrator assignment based on nodeNumber
		concentratorNo = floor( ((double)nodeNumber-1) / kNumInputsPerConcentrator ) + 1;
		//note = (concentratorNo - 1) * kNumInputsPerConcentrator + 
		//	(nodeNumber-1) % kNumInputsPerConcentrator + kBaseNote + 1;
		note = kBaseNote + concentratorNo;
		NSAssert3( (concentratorNo <= kNumConcentrators), @"nodeNumber exceeds the number of inputs available (%d > %d; %d concentrator(s))", 
				   nodeNumber, (kNumConcentrators * kNumInputsPerConcentrator), kNumConcentrators);	
		RNNodeNum_t relativeNodeNumber = nodeNumber - (concentratorNo - 1)*kNumInputsPerConcentrator;
		[self setSourcePort: (Byte) concentratorNo 
				 SourceChan: (Byte) relativeNodeNumber 
				 SourceNote: (Byte) note];
		[self setDestPort: (Byte) concentratorNo
				 DestChan: (Byte) relativeNodeNumber 
				 DestNote: (Byte) note];
		
		//Remainder of initialization happens in RNNetwork -initFromDictionary:
		// plotting locations, stimulus channels and the like,
		// as only the network object knows connections and how many nodes there are
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
	[colorArray release];
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
	
	if (_flashIntensity > 0) {
		NSColor *tempColor = [[NSColor whiteColor] blendedColorWithFraction:_flashIntensity ofColor:_flashColor];
		[tempColor setFill];
	} else {
		[[NSColor whiteColor] setFill];
	}
	
	[aPath fill];
	
	//edge color: red if doesn't hear induction, green if does
	//*** to do: color code according to which channel of BB is heard--defined by # induction sequences...
	if ([self hearsBigBrother]) {
		//[self bigBrotherSubChannel];
		[[[RNTapperNode colorArray] objectAtIndex:([self bigBrotherSubChannel]-1)]  setStroke];
	} else {
		[[NSColor redColor] setStroke];
	}
	[aPath setLineWidth:2.0];
	[aPath stroke];
}

- (void) flashWithColor: (NSColor *) flashColor inView: (NSView *) theView
{
	//set flash color, redraw, and set fadeout timer
	[_flashColor autorelease];
	_flashColor = [flashColor retain];
	_flashIntensity = 1;
	
	if (_flashTimer != nil) {
		[_flashTimer invalidate];
		[_flashTimer release];
		_flashTimer = nil;
	}
	
	_flashTimer = [[NSTimer scheduledTimerWithTimeInterval:0.05
													target:self
												  selector:@selector(fadeFlashColor:)
												  userInfo:theView
												   repeats:YES] retain];
}

- (void) fadeFlashColor: (NSTimer *) theTimer;
{
	RNNetworkView *theView = [_flashTimer userInfo];
	
	[theView lockFocus];
	[self drawWithRadius: [theView drawRadius]];
	[theView unlockFocus];
	[theView setNeedsDisplay:TRUE];
	
	_flashIntensity -= 0.2;
	if (_flashIntensity <= 0) {
		_flashIntensity = 0;
		[_flashTimer invalidate];
		[_flashTimer release];
		_flashTimer = nil;
	}
	
}



@end