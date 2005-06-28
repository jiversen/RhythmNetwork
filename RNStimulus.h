//
//  RNStimulus.h
//  RhythmNetwork
//
//  Created by John Iversen on 1/22/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface RNStimulus : NSObject {
	Byte	_stimulusChannel;
	Byte	_MIDIChannel;
	Byte	_note;
	double  _noteDuration_ms;
	double	_relativeStartTime_ms; //time relative to experiment start (in ms)
	UInt64	_experimentStartTime_ns;
	double	_IOI_ms;
	double	_jitter_ms; //if non-zero, jitter:pick ioi uniformly between ioi-jitter & ioi+jitter
	double	_startPhase_ms;
	int		_nEvents;
	NSString *_eventTimes;	// \n sep list of requested stimulus times (rel to experiment start), String easier for matlab
}

- (RNStimulus *) initWithStimulusNumber: (Byte) stimChannel MIDIChannel: (Byte) channel Note: (Byte) note StartTime: (double) startTime IOI: (double) IOI StartPhase: (double) startPhase Count: (int) nEvents;
- (RNStimulus *) initWithString: (NSString *) initString;

- (void) setStartTimeSeconds: (NSTimeInterval) startTime_s;
- (void) setJitter: (double) jitter_ms;

- (Byte) stimulusChannel;
- (Byte) MIDIChannel;
- (double) startTime_ms;
- (double) IOI_ms;
- (double) jitter_ms;
- (double) startPhase_ms;
- (int) nEvents;
- (NSString *) eventTimes;
- (void) setEventTimes: (NSString *) eventStr;

- (double) asynchronyForNanoseconds: (UInt64) time_ns;

- (NSData *) MIDIPacketListForExperimentStartTime: (UInt64) experimentStartTime_ns;

@end
