//
//  MIOCVelocityProcessor.h
//  RhythmNetwork
//
//  Created by John Iversen on 4/4/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MIOCProcessorProtocol.h"

#define kMIOCInputVelocityProcessorOpcode 24
#define kMIOCOutputVelocityProcessorOpcode 25

@interface MIOCVelocityProcessor : NSObject <MIOCProcessor> {
	Byte _port;
	Byte _channel;
	Byte _IOOpcode;
	Byte _position;
	Byte _threshold;
	SInt8 _gradientBelowThreshold;
	SInt8 _gradientAboveThreshold;
	SInt8 _offset;
}

- (MIOCVelocityProcessor *) initWithPort:(Byte)port Channel:(Byte)channel OnInput:(BOOL)isInput;
- (void) setVelocityMapThreshold:(Byte)threshold GradientAbove:(double)gradientAbove GradientBelow:(double)gradientBelow Offset:(Byte)offset;
- (void) setWeight:(double)weight;
- (void) setPosition:(Byte)position;

- (NSString *) description;
- (BOOL) isEqual: (id) anObject; //used for uniqueness testing in NSArray

//- (NSData *) MIDIBytes; //convert to MIDI bytestream

@end

/// Specifications
///General
//Proc.-type, I/O-number, [Channel] [P0..Pn = parameters]
//
//Proc.-type is the type of MIDI data processor
//An even number as processor type specifies 
//processing parameters for a MIDI-input, an odd number specifies
//a MIDI-output processor. Routing-parameters are always given as
//input-processing (the connected output is given as parameter).
///Specific
//24/25 Velocity proc.            length = 8       
//Computes a new value for the second MIDI data byte of
//note events. The received value is used as an input-parameter 
//for this function.
//
//Channel:        
//bit 7:          = 0 for omni, bits 0..3 must be 0
//= 1 for channel given by bits 0..3
//
//bits 6..4       = 001 for Note-On velocity,
//= 000 for Note-Off velocity,
//= 010 would result in changing
//of polypressure-data (An).
//(just 001 is used!)
//
//P0:     Position of processor, forces to place multiple
//velocity processors in a defined order. This is
//important, because the output value of one prc.
//may be used as input value of a another one to
//get more complex functions.
//Valid range of this byte is 0..7, processors
//are placed in ascending order.
//P1:     Threshold, cuts the range of input values into
//two parts: values below and values above Thrsh.
//Valid range: 0..127
//P2:     Gradient of the velocity function for input 
//values below the threshold value.
//Range: -128..+127 = -16 ..+15.875
//P3:     Gradient of the velocity function for input 
//values above the threshold value.
//Range: -128..+127 = -16 ..+15.875
//P4:     Offset to add to the output value.
//Range: -128..+127

