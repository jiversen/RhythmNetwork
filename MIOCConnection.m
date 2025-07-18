//
//  MIOCConnection.m
//  RhythmNetwork
//
//  Created by John Iversen on 9/17/04.
//  Copyright 2004 John Iversen. All rights reserved.
//

#import "MIOCConnection.h"
#import "MIOCVelocityProcessor.h"

// note--arguments to methods use 1 as basis (e.g. ports 1-8), as does internal representation
// Conversion to 0 based happens in MIDIBytes method

@implementation MIOCConnection

+ (MIOCConnection *)connectionWithInPort:(int)anInPort InChannel:(int)anInChannel OutPort:(int)anOutPort OutChannel:(int)anOutChannel
{
	MIOCConnection *con = [[MIOCConnection alloc] initWithInPort:anInPort InChannel:anInChannel OutPort:anOutPort OutChannel:anOutChannel];

	return [con autorelease];
}

// designated initializer
- (MIOCConnection *)initWithInPort:(int)anInPort InChannel:(int)anInChannel OutPort:(int)anOutPort OutChannel:(int)anOutChannel
{
	self = [super init];
	if (!self) return nil;

	_inPort			= (Byte)anInPort;
	_inChannel		= (Byte)anInChannel;
	_outPort		= (Byte)anOutPort;
	_outChannel 	= (Byte)anOutChannel;
	[self setWeight:1.0];
	
	return self;
}

- (void)dealloc
{
	[_velocityProcessor release];
	_velocityProcessor = nil;
	[super dealloc];
}

- (double)weight {
	return _weight;
}

- (void)setWeight:(double)newWeight
{
	if (_weight != newWeight) {
		_weight = newWeight;
		[_velocityProcessor release];
		_velocityProcessor = nil;

		if (_weight != 1.0) {
			_velocityProcessor = [[MIOCVelocityProcessor alloc] initWithPort:_outPort Channel:_outChannel OnInput:NO];
			[_velocityProcessor setWeight:newWeight];
		}
	}
}

- (double)delay {
	return _delay_ms;
}

- (void)setDelay:(double)newDelay
{
	NSAssert((newDelay >= 0), @"can't have negative delays!");
	_delay_ms = newDelay;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%u,%u -> %u,%u", _inPort, _inChannel, _outPort, _outChannel];	// ***temp
}

- (BOOL)isEqual:(MIOCConnection *)anObject
{
	BOOL			equal;
	MIOCConnection	*other = (id)anObject;	// by casting we avoid warnings

	// surprisingly we can statically type anObject above with no errors? And  interface declaration and implementation type can vary

	if (![other isMemberOfClass:[MIOCConnection class]]) {
		return FALSE;
	}

	equal = ((_inPort == other->_inPort)
		&& (_inChannel == other->_inChannel)
		&& (_outPort == other->_outPort)
		&& (_outChannel == other->_outChannel)
		&& (_weight == other->_weight)
		&& (_delay_ms == other->_delay_ms));

	return equal;
}

// only includes port info, not weight & delay
- (unsigned)hash
{
	unsigned hashval;

	hashval = (_inPort * 1 << 24) + (_inChannel * 1 << 16) + (_outPort * 1 << 8) + _outChannel;
	return hashval;
}

- (NSData *)MIDIBytes	// convert to MIDI bytestream (NB converts to 0-based channel indexing)
{
	Byte buf[5];

	buf[0]	= kMIOCRoutingProcessorOpcode;
	buf[1]	= _inPort - 1;
	buf[2]	= (_inChannel == kMIOCInChannelAll)?kMIOCInChannelAll:(_inChannel - 1);
	buf[3]	= _outPort - 1;
	buf[4]	= (_outChannel == kMIOCOutChannelSameAsInput)?kMIOCOutChannelSameAsInput:(_outChannel - 1);
	return [NSData dataWithBytes:buf length:5];
}

@end
