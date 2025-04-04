//
//  MIOCConnection.h
//  RhythmNetwork
//
//  Created by John Iversen on 9/17/04.
//  Copyright 2004 John Iversen. All rights reserved.
//

// representation of a MIOC connection between an input port/channel to output port/channel
// :jri:20050917 expanded on the formalism: weight, delay not directly found in MIOC, but
// would be in the ideal processor.

#import <Cocoa/Cocoa.h>
#import "MIOCProcessorProtocol.h"

@class MIOCVelocityProcessor;

#define kMIOCInChannelAll			0x80
#define kMIOCOutChannelSameAsInput	0x80
#define kMIOCRoutingProcessorOpcode 0x00

@interface MIOCConnection : NSObject <MIOCProcessor>
{
	Byte					_inPort;
	Byte					_inChannel;
	Byte					_outPort;
	Byte					_outChannel;
	double				_weight;
	double				_delay_ms;
	MIOCVelocityProcessor	*_velocityProcessor;
}

+ (MIOCConnection *)connectionWithInPort:(int)anInPort InChannel:(int)anInChannel OutPort:(int)anOutPort OutChannel:(int)anOutChannel;
- (MIOCConnection *)initWithInPort:(int)anInPort InChannel:(int)anInChannel OutPort:(int)anOutPort OutChannel:(int)anOutChannel;

- (double)weight;
- (void)setWeight:(double)newWeight;

- (double)delay;
- (void)setDelay:(double)newDelay;

- (NSString *)description;

- (BOOL)isEqual:(id)anObject;	// used for uniqueness testing in NSArray
- (unsigned)hash;

// - (NSData *) MIDIBytes; //convert to MIDI bytestream

@end
