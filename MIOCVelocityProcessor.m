//
//  MIOCVelocityProcessor.m
//  RhythmNetwork
//
//  Created by John Iversen on 4/4/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "MIOCVelocityProcessor.h"


@implementation MIOCVelocityProcessor

- (MIOCVelocityProcessor *) initWithPort:(Byte)port Channel:(Byte)channel OnInput:(BOOL)isInput
{
	self = [super init];
	_port = port;
	NSAssert( (channel >= 1 && channel <= 16), @"channel out of range");
	_channel = channel;
	if (isInput == YES)
		_IOOpcode = kMIOCInputVelocityProcessorOpcode;
	else
		_IOOpcode = kMIOCOutputVelocityProcessorOpcode;
	//initialize the rest to a no-change processor
	[self setPosition:0]; //unnecessary, but explicit
	[self setVelocityMapThreshold:0 GradientAbove:1.0 GradientBelow:1.0 Offset:0];
	return self;
}
//massed setter, will need per-variable if we do bindings UI
// note, here gradients are true gradients: -16...+15.875
- (void) setVelocityMapThreshold:(Byte)threshold GradientAbove:(double)gradientAbove GradientBelow:(double)gradientBelow Offset:(Byte)offset
{
	NSAssert( (threshold >= 0 && threshold <= 127), @"threshold out of range");
	_threshold = threshold;
	
	NSAssert( (gradientAbove >= -16.0 && gradientAbove <=15.875), @"above gradient out of range");
	_gradientAboveThreshold = (SInt8) round(gradientAbove * 8);
	
	NSAssert( (gradientBelow >= -16.0 && gradientBelow <=15.875), @"below gradient out of range");
	_gradientBelowThreshold = (SInt8) round(gradientBelow * 8);
		
	//offset can't be out of range--all SInt8 vals are permitted
	_offset = offset;
}

//set a simple velocity weighting
- (void) setWeight:(double)weight
{
	NSAssert( (weight >= 0.0 && weight <=1.0), @"Weight out of range")
	[self setVelocityMapThreshold:0 GradientAbove:weight GradientBelow:1.0 Offset:0];
}
- (void) setPosition:(Byte)position
{
	NSAssert( (position >= 0 && position <= 7), @"position out of range")
	_position = position;
}

 //convert to MIDI bytestream
- (NSData *) MIDIBytes
{
	Byte buf[8], chan;
	NSAsert( (_IOOpcode == kMIOCInputVelocityProcessorOpcode || _IOOpcode == kMIOCOutputVelocityProcessorOpcode), @"Opcode incorrect");
	buf[0] = _IOOpcode;
	buf[1] = _port - 1;
	buf[2] = (_channel==kMIOCInChannelAll)?0x10:(0x90 + _channel - 1);
	buf[3] = _position;
	buf[4] = _threshold;
	buf[5] = _gradientBelowThreshold;
	buf[6] = _gradientAboveThreshold;
	buf[7] = _offset;
	
	return [NSData dataWithBytes:buf length:8];
}


@end
