//
//  MIOCFilterProcessor.h
//  RhythmNetwork
//
//  Created by John Iversen on 7/20/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MIOCProcessorProtocol.h"

// define opcodes we plan to use
#define kMIOCInputNoteOffFilterProcessorOpcode 0x08
#define kMIOCOutputNoteOffFilterProcessorOpcode 0x09

#define kMIOCInputActiveSenseFilterProcessorOpcode 0x1A
#define kMIOCOutputActiveSenseFilterProcessorOpcode 0x1B

#define kMIOCFilterChannelAll 0x00


@interface MIOCFilterProcessor : NSObject <MIOCProcessor>
{
	Byte		_port;
	Byte		_channel;
	Byte		_IOOpcode;
	NSString	*_type;
}

- (MIOCFilterProcessor *)initWithType:(NSString *)type Port:(Byte)port Channel:(Byte)channel OnInput:(BOOL)isInput;

@end

//
// General Structure:
// Proc.-type, I/O-number, [Channel] [P0..Pn = parameters]
//
// Proc.-type is the type of MIDI data processor (Routing, Filter,
// Keyboard Split etc.). An even number as processor type specifies
// processing parameters for a MIDI-input, an odd number specifies
// a MIDI-output processor.
//
//
// 8/9  filter Note Off messages  length = 3
// Channel:        00=omni, 8N=ch.N
//
// 1A/1B active sensing filter     length = 2
// Removes event (FE)
