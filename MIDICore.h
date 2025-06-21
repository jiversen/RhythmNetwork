//
//  MIDICore.h
//  RhythmNetwork
//
//  Created by John Iversen on 9/13/05.
//  Copyright 2005 John Iversen (iversen@nsi.edu). All rights reserved.
//

//  a class encapsulating an efficient MIDI processor for matrix, velocity and delay (for now)

#import <Cocoa/Cocoa.h>

#import <CoreMIDI/MIDIServices.h>
#import <CoreAudio/HostTime.h>

#define kMaxChannel 16
#define kMaxPort	1

// minimal structure that describes how notes on a given channel will be routed and transformed
typedef struct _MIDICoreProcess {
	Byte				outPort;			// MIOC port
	Byte				outChannel;
	NSTimeInterval	delay_s;			// desired delay in sec
	MIDITimeStamp		timestamp_delta;	// calc # of ticks to be added to incoming timestamp
	Byte				velocityConstant;	// ???:jri:20050929 replace w/ more general velocity map?
	double			velocityScale;
} MIDICoreProcess;

@class MIDIIO, MIOCConnection, MIOCVelocityProcessor;

// TODO: seems this would make more sense as a subclass of MIDIIO--it would swap in a new handleMIDI (and could even pass it along to [super handleMIDI..]? But why bother for now...!
@interface MIDICore : NSObject
{
	MIDIIO			*_MIDILink;				// our bridge to MIDI
	MIDIPortRef		_outPortLocalCopy;		// local copies of IO port references
	MIDIEndpointRef 	_MIDIDestLocalCopy;
	// higher-level model of connections that's transformed into efficient lower-level representation when it changes

	// stub low-level data structures containing info how to map incoming MIDI data
	// array (port x channel) of pointers to arrays of process struct (null terminated)
	// split into 'immediate' thru and delay--process all of former first for lowest latency
	MIDICoreProcess *_processListPtrArray[kMaxPort][kMaxChannel];
	MIDICoreProcess *_delayProcessListPtrArray[kMaxPort][kMaxChannel];
}

// init: attach to existing MIDIIO, patch in own readProc
- (MIDICore *)initWithInterface:(MIDIIO *)midiIO;

- (void)dealloc;

// functions to set routing, velocity processing and delays
- (void)connect:(MIOCConnection *)aConnection;
- (void)disconnect:(MIOCConnection *)aConnection;

- (void)addVelocityProcessor:(MIOCVelocityProcessor *)aVelProc;
- (void)removeVelocityProcessor:(MIOCVelocityProcessor *)aVelProc;

// something to translate our higher level rep into the efficient data structures--but state is kept in
// MIOCModel, so that would require some changes--right now I've linked into this AFTER that model's been
// updated. We don't want to translate the whole list each time we add/remove a connection, so we'll have
// do do some more low-level bitshuffling work.

// also,need to ensure it doesn't change during processing--perhaps a double-buffer scheme would work,
// only at end of readProc can the swap happen--but that rests on re-rendering the buffers after each change.
// instead, we want to prevent ourselves from making changes while read-proc is running. Can we guarantee
// we'll never preempt the read proc, or does the readproc need to lock down the data and we need to wait until
// unlocked. Don't ever want the chance the read_proc will have to wait.

// we also need a way to know when ports/sources have changed, though! Don't want to have to look it up
// each time! use notifications
- (void)newDestinationHandler:(NSNotification *)notification;

@end
