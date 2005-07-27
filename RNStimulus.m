//
//  RNStimulus.m
//  RhythmNetwork
//
//  Created by John Iversen on 1/22/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "RNStimulus.h"

#import "RNTapperNode.h"
#import <CoreAudio/HostTime.h>
#import <CoreMIDI/MIDIServices.h>

#define kNoteDuration_ms 100 
#define kNoteVelocity	100

@implementation RNStimulus

//designated initializer
- (RNStimulus *) initWithStimulusNumber: (Byte) stimChannel MIDIChannel: (Byte) MIDIChannel Note: (Byte) note StartTime: (double) startTime IOI: (double) IOI StartPhase: (double) startPhase Count: (int) nEvents
{
	self = [super init];
	_stimulusChannel = stimChannel;
	_MIDIChannel	 = MIDIChannel;
	_note			 = note;
	_noteDuration_ms = kNoteDuration_ms;
	_relativeStartTime_ms	= startTime; 
	_IOI_ms			 = IOI;
	_startPhase_ms	 = startPhase;
	_nEvents		 = nEvents;
	_jitter_ms		 = 0;
	
	return self;
}

// string format:  stimulus#: MIDIchannel(note), IOI, duration, phase, jitter 
// (e.g. "1: 16(64), IOI=1000.0, events=10, phase=400.0, jitter=50.0")
- (RNStimulus *) initWithString: (NSString *) initString
{
	int		stimChannel, MIDIChannel, note, nEvents;
	double	startTime = 0.0, IOI, startPhase = 0.0, jitter = 0.0;
	NSScanner *theScanner;
	
	theScanner		= [NSScanner scannerWithString:initString];
	if ([theScanner scanInt:&stimChannel] &&
		[theScanner scanString:@":" intoString:NULL] &&
		[theScanner scanInt:&MIDIChannel] &&
		[theScanner scanString:@"(" intoString:NULL] &&
		[theScanner scanInt:&note] &&
		[theScanner scanString:@")" intoString:NULL] &&
		[theScanner scanString:@"," intoString:NULL] &&
		[theScanner scanString:@"IOI=" intoString:NULL] &&
		[theScanner scanDouble:&IOI] &&
		[theScanner scanString:@"," intoString:NULL] &&
		[theScanner scanString:@"events=" intoString:NULL] &&
		[theScanner scanInt:&nEvents]) {
		//successful scan of necessary elements, now check for optional ones
		if ([theScanner isAtEnd] == NO) { //phase is optional
			if ([theScanner scanString:@"," intoString:NULL] &&
				[theScanner scanString:@"phase=" intoString:NULL] &&
				[theScanner scanDouble:&startPhase] == NO) {
				startPhase = 0.0; //didn't find phase, no chance of finding jitter
			} else { //found phase, now look for optional jitter
				if ([theScanner scanString:@"," intoString:NULL] &&
					[theScanner scanString:@"jitter=" intoString:NULL] &&
					[theScanner scanDouble:&jitter] == NO)	jitter = 0.0; //didn't find jitter
			} 
		}
	} else {
		//we've had a scan error if we make it here
		NSAssert1(FALSE, @"Error parsing stimulus string: %@", initString);
		return nil;
	}
	
	self = [self initWithStimulusNumber:stimChannel MIDIChannel:MIDIChannel Note:note StartTime:startTime IOI:IOI StartPhase:startPhase Count:nEvents];
	[self setJitter:jitter];
	return self;
	
}

- (void) setStartTimeSeconds: (NSTimeInterval) startTime_s
{
	_relativeStartTime_ms = startTime_s * 1000.0;
}

- (void) setJitter: (double) jitter_ms
{
	_jitter_ms = jitter_ms;
}

- (Byte) stimulusChannel { return _stimulusChannel; }
- (Byte) MIDIChannel { return _MIDIChannel; }
- (double) startTime_ms { return _relativeStartTime_ms; }
- (double) IOI_ms { return _IOI_ms; }
- (double) jitter_ms { return _jitter_ms; }
- (double) startPhase_ms { return _startPhase_ms; }
- (int) nEvents { return _nEvents; }
- (NSString *) eventTimes { return _eventTimes; }
- (void) setEventTimes: (NSString *) eventStr
{
	[_eventTimes autorelease];
	_eventTimes = nil;
	_eventTimes = [eventStr copy];
}
	
// TO DO: calculate relative to actual eventTimes
// time_ns is realtime
- (double) asynchronyForNanoseconds: (UInt64) time_ns
{
	UInt64 stimStartTime_ns;
	double timeSinceStimStart_ms, asynchrony_ms, junk;
	
	stimStartTime_ns = (UInt64) roundf( 1000000.0 * ([self startTime_ms] + [self startPhase_ms]) ) \
		+ _experimentStartTime_ns;
	timeSinceStimStart_ms = (time_ns - stimStartTime_ns) / 1000000.0;
	asynchrony_ms = [self IOI_ms] * (modf( (timeSinceStimStart_ms / [self IOI_ms]) + 0.5 , &junk) - 0.5);
	
	return asynchrony_ms;
}

- (UInt64) experimentStartTime
{
	return _experimentStartTime_ns;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"@T+%.1fs: #%d: %d(%d):IOI=%.1f, events=%d, phase=%.1f, jitter=%.1f", \
		_relativeStartTime_ms / 1000.0, _stimulusChannel, _MIDIChannel, _note, _IOI_ms, _nEvents, _startPhase_ms, _jitter_ms];
}

- (NSData *) MIDIPacketListForExperimentStartTime: (UInt64) experimentStartTime_ns
{
	MIDIPacket	*curPkt;
	Byte onMessage[3], offMessage[3];
	size_t packetListLength = 8192; //big enough for ~500 events
	MIDIPacketList *packetList = malloc(packetListLength);
	NSMutableString *eventStr = [NSMutableString stringWithCapacity:1024];
	
	UInt64 eventOnTime_ns, eventOffTime_ns, stimStartTime_ns, IOI_ns, noteDuration_ns, previousEventTime_ns;
	MIDITimeStamp eventTimeStamp;
	
	_experimentStartTime_ns = experimentStartTime_ns; //keep it around
	
	//internal time calculations are in ns, convert to hosttime only at end
	stimStartTime_ns = (UInt64) roundf( 1000000.0 * (_relativeStartTime_ms + _startPhase_ms) ) + experimentStartTime_ns;
	IOI_ns = (UInt64) roundf( 1000000.0 * _IOI_ms );
	noteDuration_ns = (UInt64) roundf (1000000.0 * _noteDuration_ms );
	
	//note on and off MIDI messages
	onMessage[0] = 0x90 + (_MIDIChannel - 1); //NB convert to MIDI 0-based index
	onMessage[1] = _note;
	onMessage[2] = kNoteVelocity;
	
	offMessage[0] = onMessage[0];
	offMessage[1] = onMessage[1];
	offMessage[2] = 0;
	
	//random seed
	srand( (unsigned) time(NULL) );
	double urand;
	SInt64 jitter;
	
	//assemble packet list of all stimulus events
	curPkt = MIDIPacketListInit(packetList);

	previousEventTime_ns = stimStartTime_ns - IOI_ns; //one event prior to start
	
	unsigned int iEvent;
	for (iEvent = 0; iEvent < _nEvents; iEvent++) {
		
		//calculate jitter (in ns)--first event: no jitter
		if (iEvent == 0 || _jitter_ms == 0.0)  
			jitter = 0.0;
		else {
			urand = (double) rand() / RAND_MAX; //unit random
			urand = 2.0 * (urand - 0.5);
			jitter = (SInt64) roundf( _jitter_ms * 1000000.0 * urand );
		}

		//noteOn
		//eventTime_ns = stimStartTime_ns + (iEvent * IOI_ns) + jitter; //old way, actually is jittered asynchrony, not IOI
		eventOnTime_ns = previousEventTime_ns + (IOI_ns + jitter);
		previousEventTime_ns = eventOnTime_ns;
		eventTimeStamp = AudioConvertNanosToHostTime(eventOnTime_ns);
		curPkt = MIDIPacketListAdd(packetList,packetListLength,curPkt,eventTimeStamp,3,onMessage);
		
		//noteOff
		eventOffTime_ns = eventOnTime_ns + noteDuration_ns;
		eventTimeStamp = AudioConvertNanosToHostTime(eventOffTime_ns);
		curPkt = MIDIPacketListAdd(packetList,packetListLength,curPkt,eventTimeStamp,3,offMessage);
		
		NSAssert2( (curPkt != NULL), @"Packet List overflow (after %d events of %d)", iEvent, _nEvents);
		
		//stuff event time into eventTimes string
		[eventStr appendFormat:@"%qi\n", (eventOnTime_ns - experimentStartTime_ns)];
	}
	
	// stash eventStr
	[self setEventTimes:eventStr];
	
	//calculate actual packetListLength
	//	curPkt points to the last one added, so add the length of the last packet
	packetListLength = (size_t) curPkt - (size_t) packetList + 
		sizeof(MIDITimeStamp) + sizeof(UInt16) + 3;
	
	//wrap
	NSData *wrappedPacketList = [NSData dataWithBytes:packetList length:packetListLength];
	free(packetList);
	return wrappedPacketList;
}

@end
