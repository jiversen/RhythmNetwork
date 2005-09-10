//
//  RNBBNode.m
//  RhythmNetwork
//
//  Created by John Iversen on 2/19/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

#import "RNBBNode.h"
#import "RNTapperNode.h"
#import "MIOCConnection.h"
#import "RNNetworkView.h"
#import "RNStimulus.h"

@implementation RNBBNode

- (RNBBNode *) initWithNumStimulusChannels: (Byte) numStimulusChannels
{
	self = (RNBBNode *) [super initWithNodeNumber:0];
		
	[self setNumStimulusChannels:numStimulusChannels];
	
	//these values are for channel 1
	[self setSourcePort: (Byte) kBigBrotherPort 
			 SourceChan: (Byte) kBigBrotherChannel 
			 SourceNote: (Byte) kBaseNote];
	[self setDestPort: (Byte) kBigBrotherPort
			 DestChan: (Byte) kMIOCOutChannelSameAsInput 
			 DestNote: (Byte) kBaseNote];
	[self setHearsBigBrother:TRUE]; //since is BB
	[self setHearsSelf:FALSE];	// ***might want to monitor self?
		
	return self;
		
}

- (void) dealloc
{
	unsigned int i;
	
	for (i=1; i<= _numStimulusChannels; i++) {
		_flashIntensityArray[i] = 0.0;
		if (_flashTimerArray[i] != nil) {			//test isn't really necessary
			[_flashTimerArray[i] invalidate];
			[_flashTimerArray[i] release];
			_flashTimerArray[i] = nil;
		}
	}
	[super dealloc];
}

- (Byte) stimulusNumberForMIDIChannel: (Byte) midiChannel
{
	Byte stimulusChannel;
	
	stimulusChannel = kBigBrotherChannel - midiChannel + 1; //both are 1 based
	return stimulusChannel;
}
- (Byte) MIDIChannelForStimulusNumber: (Byte) stimulusChannel
{
	Byte channel;
	
	channel = kBigBrotherChannel - stimulusChannel + 1;
	return channel;	
}

//**in future, could have different notes for each pacing stimulus
- (Byte) MIDINoteForStimulusNumber: (Byte) stimulusChannel
{
//#pragma unused stimulusChannel	
	Byte note;
	note = [self sourceNote];
	return note;
}

- (Byte) numStimulusChannels { return _numStimulusChannels; }
- (void) setNumStimulusChannels: (Byte) newNumStimulusChannels
{
	unsigned int i;
	
    _numStimulusChannels = newNumStimulusChannels;
	if (_numStimulusChannels > 0) {
		for (i=1; i<= _numStimulusChannels; i++) {
			_flashIntensityArray[i] = 0.0;
			_flashTimerArray[i] = nil;
			_stimulusArray[i] = nil;
		}
	}
}

- (RNStimulus *) stimulusForChannel: (Byte) stimulusChannel
{
	NSAssert( (stimulusChannel <= [self numStimulusChannels]), @"stimulus channel out of range");
	return _stimulusArray[stimulusChannel];
}
- (void) setStimulus: (RNStimulus*) stim ForChannel: (Byte) stimulusChannel
{
	NSAssert( (stimulusChannel <= [self numStimulusChannels]), @"stimulus channel out of range");
//	NSAssert( (_stimulusArray[stimulusChannel] != nil), @"assigning a stimulus to a non-empty channel");
	_stimulusArray[stimulusChannel] = stim;
}

// *********************************************
//    Display
// *********************************************
#pragma mark  Display

- (void) drawWithRadius: (double) radius 
{
	unsigned int i;
	
	for (i=1; i<= [self numStimulusChannels]; i++) {
		[self drawStimulusChannel:i WithRadius:radius];
	}
}

- (void) drawStimulusChannel: (Byte) stimulusChannel WithRadius: (double) radius
{
	NSPoint centerPt = [self plotLocation]; 
	
	double nodeRadius = radius*kNodeScale;
	
	//offset the point according to # channels (this is in normalized coordinates)
	centerPt.y -= (stimulusChannel-1) * 0.25;
	
	NSRect aRect = NSMakeRect( centerPt.x * radius - nodeRadius, centerPt.y * radius - nodeRadius, nodeRadius*2.0, nodeRadius*2.0);
	NSBezierPath *aPath = [NSBezierPath bezierPathWithOvalInRect:aRect];
	
	if (_flashIntensityArray[stimulusChannel] > 0) {
		NSColor *tempColor = [[NSColor whiteColor] blendedColorWithFraction:_flashIntensityArray[stimulusChannel]
																	ofColor:_flashColor];
		[tempColor setFill];
	} else {
		[[NSColor whiteColor] setFill];
	}
	
	[aPath fill];
	
	//edge color: according to stimulus channel (use 0 based indexing)
	[[[RNTapperNode colorArray] objectAtIndex:(stimulusChannel-1)]  setStroke];

	[aPath setLineWidth:2.0];
	[aPath stroke];
	
	//descriptive text regarding stimulus
	RNStimulus *stim = [self stimulusForChannel:stimulusChannel];
	NSString *stimStr;
	if (stim != nil) {
		if ([stim jitter_ms] == 0.0)
			stimStr = [NSString stringWithFormat:@"%.0f\nx %d", [stim IOI_ms], [stim nEvents] ];
		else
			stimStr = [NSString stringWithFormat:@"%.0f±%.0f\nx %d", [stim IOI_ms], [stim jitter_ms], [stim nEvents] ];
		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor redColor], NSForegroundColorAttributeName, \
			[NSFont fontWithName:@"Helvetica" size:7], NSFontAttributeName, nil,nil];
		[stimStr drawAtPoint:NSMakePoint( (centerPt.x + 1.5 * kNodeScale) * radius, (centerPt.y - 0.45 * kNodeScale) * radius ) withAttributes:attributes];
	}
	
}

- (void) flashStimulusChannel: (Byte) stimulusChannel WithColor: (NSColor *) flashColor inView: (NSView *) theView
{
	//set flash color, redraw, and set fadeout timer
	[_flashColor autorelease];
	_flashColor = [flashColor retain];
	_flashIntensityArray[stimulusChannel] = 1;
	
	if (_flashTimerArray[stimulusChannel] != nil) {
		[_flashTimerArray[stimulusChannel] invalidate];
		[_flashTimerArray[stimulusChannel] release];
		_flashTimerArray[stimulusChannel] = nil;
	}
	
	_flashTimerArray[stimulusChannel] = [[NSTimer scheduledTimerWithTimeInterval:0.05
													target:self
												  selector:@selector(fadeFlashColor:)
												  userInfo:theView
												   repeats:YES] retain];
}

//the only twist is we need to recover stimulusChannel from timer by looking up in array
// alternative would be to make use a dictionary for userInfo
- (void) fadeFlashColor: (NSTimer *) theTimer;
{
	RNNetworkView *theView = [theTimer userInfo];
	
	Byte stimulusChannel;
	unsigned int i;
	
	i = 1;
	while (i<=[self numStimulusChannels]) {
		if (theTimer == _flashTimerArray[i])
			break;
		i++;
	}
	//catch the case where we've checked all i, with no match
	NSAssert( (i <= [self numStimulusChannels]), @"Did not find stimulus channel matching this timer");
	stimulusChannel = i;
	
	[theView lockFocus];
	[self drawStimulusChannel:stimulusChannel WithRadius: [theView drawRadius]];
	[theView unlockFocus];
	[theView setNeedsDisplay:TRUE];
	
	_flashIntensityArray[stimulusChannel] -= 0.2;
	if (_flashIntensityArray[stimulusChannel] <= 0.0) {
		_flashIntensityArray[stimulusChannel] = 0.0;
		[_flashTimerArray[stimulusChannel] invalidate];
		[_flashTimerArray[stimulusChannel] release];
		_flashTimerArray[stimulusChannel] = nil;
	}
	
}

@end
