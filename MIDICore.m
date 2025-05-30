//
//  MIDICore.m
//  RhythmNetwork
//
//  Created by John Iversen on 9/13/05.
//  Copyright 2005 John Iversen (iversen@nsi.edu). All rights reserved.
//

#import "MIDICore.h"

#import <CoreMIDI/MIDIServices.h>
#import <CoreAudio/HostTime.h>

#import "MIOCConnection.h"
#import "MIDIIO.h"

// Forward definitions of callback
static void MIDICoreReadProc(const MIDIPacketList *pktlist, void *refCon, void *connRefCon);

@implementation MIDICore

// designated init
- (MIDICore *)initWithInterface:(MIDIIO *)midiIO
{
	self = [super init];

	_MIDILink = midiIO;
	[_MIDILink setReadProc:MIDICoreReadProc refCon:self];
	// insert self into MIDIIO, gather local copy of ports

	_outPortLocalCopy	= [_MIDILink outPort];
	_MIDIDestLocalCopy	= [_MIDILink MIDIDest];

	// register to be notified when destination changes (the only relevant change)
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(newDestinationHandler:)
												name	:@"MIDIIO_newDestinationNotification" object:nil];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_MIDILink setDefaultReadProc];
	[super dealloc];
}

- (void)connect:(MIOCConnection *)aConnection
{
	// add to our list of
}

- (void)disconnect:(MIOCConnection *)aConnection
{}

- (void)addVelocityProcessor:(MIOCVelocityProcessor *)aVelProc
{}

- (void)removeVelocityProcessor:(MIOCVelocityProcessor *)aVelProc
{}

- (void)newDestinationHandler:(NSNotification *)notification
{
	// update local copies
	_MIDIDestLocalCopy = [_MIDILink MIDIDest];
}

static void MIDICoreReadProc(const MIDIPacketList *pktlist, void *refCon, void *connRefCon)
{
	unsigned int	i, pktlistLength;
	MIDICore		*myself = (MIDICore *)refCon;

	NSLog(@"in MIDICoreReadProc");

	// sketch
	// NEW :jri:20050929 We'll use MIDIThruConnections for this first pass
	// X walk packet list, for note on find port (connRefCon) and midi channel
	// X use these to index into _processListPtrArray, walk the processList creating
	// X new packets with new channel and possibly modified velocity. Send this new list marked for
	// X		immediate scheduling
	// X same for next input packet
	//
	// walk input packet list a second time, repeating process on _delayProcessListPtrArray
	//	only difference: schedule for a later time relative to input timestamp
	// AND, need to get data out to listeners registered in MIDIIO--we can store the original readproc
	// when we patch ours in and then call it after we've done our scheduling. That's not time critical, so we'll
	// best move out of the realtime thread to one of our methods
}

@end
