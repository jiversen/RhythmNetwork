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

static NSArray *colorArray;

@implementation RNTapperNode

+ (NSArray *) colorArray
{
	if (colorArray == nil) {
		colorArray = [@[[NSColor greenColor], [NSColor blueColor], [NSColor orangeColor], \
			[NSColor purpleColor], [NSColor brownColor], [NSColor blackColor]] retain];
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
		//two alternatives: notes w/in concentrator increase sequentially (as does channel)
		// or constant note w/in concentrator
		RNNodeNum_t relativeNodeNumber = nodeNumber - (concentratorNo - 1)*kNumInputsPerConcentrator;
		note = kBaseNote + relativeNodeNumber;
		//old way:
		//note = (concentratorNo - 1) * kNumInputsPerConcentrator + 
		//	(nodeNumber-1) % kNumInputsPerConcentrator + kBaseNote + 1;
		//note = kBaseNote + concentratorNo;
		NSAssert3( (concentratorNo <= kNumConcentrators), @"nodeNumber exceeds the number of inputs available (%d > %d; %d concentrator(s))", 
				   nodeNumber, (kNumConcentrators * kNumInputsPerConcentrator), kNumConcentrators);	
		[self setSourcePort: (Byte) concentratorNo 
				 SourceChan: (Byte) relativeNodeNumber 
				 SourceNote: (Byte) note];
		[self setDestPort: (Byte) concentratorNo
				 DestChan: (Byte) relativeNodeNumber 
				 DestNote: (Byte) note];
		
		//Remainder of initialization happens in RNNetwork -initFromDictionary:
		// plotting locations, stimulus channels and the like,
		// as only the network object knows connections and how many nodes there are
		
		//details of addressing (input, output are same): tappers 1 to kNumInputsPerConcentrator are
		//	  port: 1
		// channel: tapper#
		//    note: constant per concentrator (why?)
		// does destNote make any sense?
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
	
	//[colorArray release];  // !!!:jri:20050628 This is a class-wide value, not per instance. AND didn't set to nil, so was going to have multiple releases
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
	NSAssert1( (patchChan <= 16), @"patch chan out of range--too many tappers? (%u)", patchChan);
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
	
	if (_flashIntensity > 0) {
		NSColor *tempColor = [[NSColor whiteColor] blendedColorWithFraction:_flashIntensity ofColor:_flashColor];
		[tempColor setFill];
	} else {
		[[NSColor whiteColor] setFill];
	}
	
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
}

- (void) flashWithColor: (NSColor *) flashColor inView: (NSView *) theView
{
	//set flash color, redraw, and set fadeout timer
	[_flashColor autorelease];		// !!!:jri:20050819 TODO: create separate setter for color
	_flashColor = [flashColor retain];
	_flashIntensity = 1;
	
	// !!!:jri:20050819 TODO: use single class-wide timer, start it up if it's paused
	
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

// !!!:jri:20050819 TODO: replace w/ method operating on class-wide timer, loop thru all
//	members...uh, that won't work, need to do this at the network level (who calls the flashes anyway...net view)
//	since we need all the nodes. Sounds like a job for network view? How inefficient is it to dig into nodes each
//  iteration thru the timer. Would maintaning a simple array of flashIntensities in the view, rather than tapper
//  nodes themselves be better? We'll still call on each node to draw itself


- (void) fadeFlashColor: (NSTimer *) theTimer;
{
	RNNetworkView *theView = [_flashTimer userInfo];
	
	[theView lockFocus];
	[self drawWithRadius: [theView drawRadius]];
	[theView unlockFocus];
	[theView setNeedsDisplay:TRUE];
	
	_flashIntensity -= 0.25;
	if (_flashIntensity <= 0) {
		_flashIntensity = 0;
		[_flashTimer invalidate];
		[_flashTimer release];
		_flashTimer = nil;
	}
	
}



@end