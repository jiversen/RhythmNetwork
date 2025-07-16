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
#import "RNArchitectureDefines.h"

@implementation RNBBNode

- (RNBBNode *)initWithNumStimulusChannels:(Byte)numStimulusChannels
{
	self = (RNBBNode *)[super initWithNodeNumber:0];

	[self setNumStimulusChannels:numStimulusChannels];

	// these values are for channel 1
	[self setSourcePort:(Byte)kBigBrotherPort
			 SourceChan:(Byte)kBigBrotherChannel
			 SourceNote:(Byte)kBaseNote];
	[self setDestPort:(Byte)kBigBrotherPort
			 DestChan:(Byte)kMIOCOutChannelSameAsInput
			 DestNote:(Byte)kBaseNote];
	[self setHearsBigBrother:TRUE]; // since is BB
	[self setHearsSelf:FALSE];      // ***might want to monitor self?

	return self;
}

- (void)dealloc
{
	unsigned int i;

	for (i = 1; i <= _numStimulusChannels; i++) {
		[_flashLayerArray[i] removeFromSuperlayer];
		_flashLayerArray[i] = nil;
	}
	[super dealloc];
}

// TODO: this needs rethinking. We currently map stimuli into descending channel from 16--complication is not really needed
// as long as we use NOTE to dismbiguate stimuli from tappers
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

// TODO: what is this used for? Aah, for programming the drum machines--Suggest we make _this_ channel 16 (1-based)
- (Byte) controlMIDIChannel
{
	return kBigBrotherControlChannel;
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
    if (newNumStimulusChannels == _numStimulusChannels)
        return;
    
    // invalidate existing layers
	if (_numStimulusChannels > 0) {
		for (unsigned int i=1; i<= _numStimulusChannels; i++) {
            [_flashLayerArray[i] removeFromSuperlayer];
            _flashLayerArray[i] = nil;
		}
	}
    _numStimulusChannels = newNumStimulusChannels;
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
    
    [[NSColor whiteColor] setFill];
    [aPath fill];
    
	//edge color: according to stimulus channel (use 0 based indexing)
	[[RNTapperNode colorArray][(stimulusChannel-1)]  setStroke];

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
			[NSFont fontWithName:@"Helvetica" size:15], NSFontAttributeName, nil,nil];
		[stimStr drawAtPoint:NSMakePoint( (centerPt.x + 1.5 * kNodeScale) * radius, (centerPt.y - 0.45 * kNodeScale) * radius ) withAttributes:attributes];
	}
    
    // init flash animation layer
    if (_flashLayerArray[stimulusChannel] == nil) {
        _flashLayerArray[stimulusChannel] = [RNTapperNode flashLayerForRect:aRect];
        [[RNNetworkView sharedNetworkView].layer addSublayer: _flashLayerArray[stimulusChannel]];
    }
	
}

- (void) flashStimulusChannel: (Byte) stimulusChannel
{
    if (_flashLayerArray[stimulusChannel] == nil)
        return;
    
    NSColor *flashColor = [RNTapperNode colorArray][MIN(stimulusChannel-1, [[RNTapperNode colorArray] count])];
    
    //set up animation on _flashLayerArray[stimulusChannel]
    _flashLayerArray[stimulusChannel].fillColor = [[NSColor clearColor] CGColor];

    // Create a fade-out animation
	CABasicAnimation *fadeAnimation = [CABasicAnimation animationWithKeyPath:@"fillColor"];
	fadeAnimation.fromValue				= (__bridge id)[flashColor CGColor];		// Start with full color
	fadeAnimation.toValue				= (__bridge id)[[NSColor clearColor] CGColor];// Fade to transparent
	fadeAnimation.duration				= 0.3;
	fadeAnimation.removedOnCompletion		= YES;
	fadeAnimation.fillMode				= kCAFillModeRemoved;
    
    // Add animation to the flash layer
    [_flashLayerArray[stimulusChannel] addAnimation:fadeAnimation forKey:@"flashFade"];
    
}


@end
