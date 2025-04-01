//
//  MIOCProcessorProtocol.h
//  RhythmNetwork
//
//  Created by John Iversen on 7/5/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol MIOCProcessor

- (NSData *)MIDIBytes;		// convert to MIDI bytestream

@end
