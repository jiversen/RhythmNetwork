//
//  RNBBNode.h
//  RhythmNetwork
//
//  Created by John Iversen on 2/19/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

// this adds functionality for multiple stimulus channels

#import <Cocoa/Cocoa.h>

#import "RNTapperNode.h"

#define kBigBrotherPort 8
#define kBigBrotherChannel 16

@class RNStimulus;

@interface RNBBNode : RNTapperNode {
	Byte			_numStimulusChannels;
	RNStimulus *	_stimulusArray[17];	//1-based arrays, max possible stimulus channels: 16
	double			_flashIntensityArray[17];  //1 then fades to 0
	NSTimer	*		_flashTimerArray[17];
}

- (RNBBNode *) initWithNumStimulusChannels: (Byte) numStimulusChannels;
- (void) dealloc;

- (Byte) stimulusNumberForMIDIChannel: (Byte) midiChannel;
- (Byte) MIDIChannelForStimulusNumber: (Byte) stimulusChannel;

- (Byte) MIDINoteForStimulusNumber: (Byte) stimulusChannel;

- (Byte) numStimulusChannels;
- (void) setNumStimulusChannels: (Byte) numChannels;

- (RNStimulus *) stimulusForChannel: (Byte) stimulusChannel;
- (void) setStimulus: (RNStimulus *) stim ForChannel: (Byte) stimulusChannel;

- (void) drawWithRadius: (double) radius;
- (void) drawStimulusChannel: (Byte) stimulusChannel WithRadius: (double) radius;
- (void) flashStimulusChannel: (Byte) stimulusChannel WithColor: (NSColor *) flashColor inView: (NSView *) theView;
- (void) fadeFlashColor: (NSTimer *)theTimer;
@end
