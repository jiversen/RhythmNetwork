//
//  MIOCConnection.h
//  RhythmNetwork
//
//  Created by John Iversen on 9/17/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

//representation of a MIOC connection between an input port/channel to output port/channel

#import <Cocoa/Cocoa.h>

@class MIOCVelocityProcessor;

#define	kMIOCInChannelAll			0x80
#define kMIOCOutChannelSameAsInput  0x80
#define kMIOCRoutingProcessorOpcode 0x00

@interface MIOCConnection : NSObject {
	Byte _inPort;
	Byte _inChannel;
	Byte _outPort;
	Byte _outChannel;
	double _weight;
	MIOCVelocityProcessor *_velocityProcessor;
}

+ (MIOCConnection *) connectionWithInPort:(int) anInPort InChannel:(int) anInChannel OutPort:(int) anOutPort OutChannel:(int) anOutChannel;
- (MIOCConnection *) initWithInPort:(int) anInPort InChannel:(int) anInChannel OutPort:(int) anOutPort OutChannel:(int) anOutChannel;

- (void) setWeight:(double)weight;

- (NSString *) description;

- (BOOL) isEqual: (id) anObject; //used for uniqueness testing in NSArray
- (unsigned) hash;

- (NSData *) MIDIBytes; //convert to MIDI bytestream

@end
