//
//  MIOCVelocityProcessor.m
//  RhythmNetwork
//
//  Created by John Iversen on 4/4/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

#import "MIOCVelocityProcessor.h"
#import "MIOCConnection.h"


@implementation MIOCVelocityProcessor

- (MIOCVelocityProcessor *) initWithPort:(Byte)port Channel:(Byte)channel OnInput:(BOOL)isInput
{
	self = [super init];
	
	[self setPort:port];
	[self setChannel:channel];
	[self setOnInput:isInput];
	
	[self setPosition:0]; //unnecessary, but explicit
	//set to default: no modification of velocity
	[self setVelocityMapThreshold:64 GradientAbove:1.0 GradientBelow:1.0 Offset:0];
	return self;
}

- (void) setPort:(Byte)port
{
	NSAssert( (port >= 1 && port <= 8), @"port out of range"); // !!!:jri:20050908 hard wired, assumes one MIOC
	_port = port;
}

- (void) setChannel:(Byte)channel
{
	NSAssert( (channel >= 1 && channel <= 16), @"channel out of range");
	_channel = channel;
}

- (void) setOnInput:(BOOL)isInput
{
	if (isInput == YES)
		_IOOpcode = kMIOCInputVelocityProcessorOpcode;
	else
		_IOOpcode = kMIOCOutputVelocityProcessorOpcode;
}

//massed setter, will need per-variable if we do bindings UI
// note, here gradients are true gradients: -16...+15.875, not integers as in midi stream
- (void) setVelocityMapThreshold:(Byte)threshold GradientAbove:(double)gradientAbove GradientBelow:(double)gradientBelow Offset:(Byte)offset
{
	NSAssert( (threshold <= 127), @"threshold out of range");
	_threshold = threshold;
	
	NSAssert( (gradientAbove >= -16.0 && gradientAbove <= 15.875), @"above gradient out of range");
	_gradientAboveThreshold = (SInt8) round(gradientAbove * 8);
	
	NSAssert( (gradientBelow >= -16.0 && gradientBelow <= 15.875), @"below gradient out of range");
	_gradientBelowThreshold = (SInt8) round(gradientBelow * 8);
		
	//offset can't be out of range--all SInt8 vals are permitted
	_offset = offset;
}

//set a simple velocity weighting
- (void) setWeight:(double)weight
{
	NSAssert( (weight >= -16.0 && weight <=15.875), @"Weight out of range"); //redundant, but more informative
	[self setVelocityMapThreshold:0 GradientAbove:weight GradientBelow:1.0 Offset:0];
}

- (void) setConstantVelocity:(Byte)velocity;
{
	NSAssert( (velocity <= 127), @"Velocity out of range");
	[self setVelocityMapThreshold:velocity GradientAbove:0.0 GradientBelow:0.0 Offset:0]; // !!!:jri:20050907 midi matrix manual p. 96
}

- (void) setPosition:(Byte)position
{
	NSAssert( (position <= 7), @"position out of range");
	_position = position;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%c port %d, channel %d: %.2f (%u) %.2f +%u", \
		(_IOOpcode == kMIOCInputVelocityProcessorOpcode)?'I':'O', _port, _channel, \
		(float) _gradientBelowThreshold / 8.0, \
		_threshold, (float) _gradientAboveThreshold / 8.0, _offset];
}

- (BOOL) isEqual: (MIOCVelocityProcessor *) anObject
{
	BOOL equal;
	MIOCVelocityProcessor *other = (id)anObject;	
	
	if (![other isMemberOfClass: [MIOCVelocityProcessor class] ])
		return FALSE;
	equal = ((_port	== other->_port) 
			 && (_channel	== other->_channel) 
			 && (_IOOpcode	== other->_IOOpcode)
			 && (_position	== other->_position)
			 && (_threshold	== other->_threshold)
			 && (_gradientBelowThreshold	== other->_gradientBelowThreshold)
			 && (_gradientAboveThreshold	== other->_gradientAboveThreshold)
			 && (_offset    == other->_offset));
	return equal;
}

//impossible to uniquely hash this

 //convert to MIDI bytestream
- (NSData *) MIDIBytes
{
	Byte buf[8];
	NSAssert( (_IOOpcode == kMIOCInputVelocityProcessorOpcode || _IOOpcode == kMIOCOutputVelocityProcessorOpcode), @"Opcode incorrect");
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

- (id)copyWithZone:(NSZone *)zone
{
	BOOL isInput = (_IOOpcode == kMIOCInputVelocityProcessorOpcode)?YES:NO;
	//NB we descend directly from NSObject, so no need to call super's allocWithZone (see NSObject, copy)
	MIOCVelocityProcessor *newProcessor = [[MIOCVelocityProcessor allocWithZone:zone] initWithPort:_port
																						   Channel:_channel
																						   OnInput:isInput];
	//transfer remainder of parameters
	newProcessor->_threshold = _threshold;
	newProcessor->_gradientBelowThreshold = _gradientBelowThreshold;
	newProcessor->_gradientAboveThreshold = _gradientAboveThreshold;
	newProcessor->_offset = _offset;

	return newProcessor; //sender 'owns' us, must release on own
}

@end
