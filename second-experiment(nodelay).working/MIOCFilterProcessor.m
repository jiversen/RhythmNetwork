//
//  MIOCFilterProcessor.m
//  RhythmNetwork
//
//  Created by John Iversen on 7/20/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

#import "MIOCFilterProcessor.h"


@implementation MIOCFilterProcessor


- (MIOCFilterProcessor *) initWithType:(NSString *)type Port:(Byte)port Channel:(Byte)channel OnInput:(BOOL)isInput
{
	self = [super init];
	_port = port;
	_channel = kMIOCFilterChannelAll;
	_type = [type copy];
	
	if ([type isEqualToString:@"noteoff"]) {
		_IOOpcode = kMIOCInputNoteOffFilterProcessorOpcode;
	} else if ([type isEqualToString:@"activesense"]) {
		_IOOpcode = kMIOCInputActiveSenseFilterProcessorOpcode;
	} else
		NSAssert1( 0, @"Unknown filter processor type: %@", type);
	
	if (isInput == NO) //output processor is input + 1
		_IOOpcode += 1;
	
	return self;
}

//convert to MIDI bytestream
- (NSData *) MIDIBytes
{
	Byte buf[3];
	buf[0] = _IOOpcode;
	buf[1] = _port - 1;
	buf[2] = _channel;

	if ([_type isEqualToString:@"noteoff"]) {
		return [NSData dataWithBytes:buf length:3];
	} else if ([_type isEqualToString:@"activesense"]) {
		return [NSData dataWithBytes:buf length:2];		//doesn't care about channel param
	} else {
		return nil;
	}
}



@end
