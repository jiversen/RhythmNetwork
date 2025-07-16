//
//  RNNetwork.h
//  RhythmNetwork
//
//  Created by John Iversen on 10/10/04.
//  Copyright 2004 John Iversen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "RNTapperNode.h"
#import "RNArchitectureDefines.h"
#import "RNMIDIRouting.h"

@class	RNStimulus;
@class	RNGlobalConnectionStrength;

@interface RNNetwork : NSObject
{
	NSMutableArray	*_nodeList;			// will contain RNTapperNode s
	NSMutableArray	*_connectionList;	// will contain RNConnection s
	NSMutableArray	*_MIOCConnectionList; // translation of RNConnections to MIOCConnections
	NSString			*_description;
	RNMIDIRouting  *_MIDIRouting;         // real-time routing table; TODO: how to inform MIDIIO?
	unsigned int		_numTapperNodes;
	unsigned int		_numStimulusChannels;	// max number of independent Big Brother stimulus channels needed
	BOOL				_isWeighted;
    BOOL                _isDelay;
}

- (RNNetwork *)initFromDictionary:(NSDictionary *)theDict;

- (NSArray *)nodeList;
- (NSArray *)MIOCConnectionList;
- (NSArray *)MIOCVelocityProcessorList;
- (RNMIDIRouting *)MIDIRouting;

- (NSString *)description;

- (unsigned int)numStimulusChannels;
- (RNStimulus *)stimulusForChannel:(Byte)stimulusChannel;
- (void)setStimulus:(RNStimulus *)stim ForChannel:(Byte)stimulusChannel;
- (void)setStimulusArray:(RNStimulus **)stimulusArray;
- (void)setGlobalConnectionStrength:(RNGlobalConnectionStrength *)connectionStrength;
- (void)setDrumsetNumber:(Byte)drumsetNumber;

// - (void) addConnection: (RNConnection *) aConnection;
// - (void) removeConnection: (RNConnection *) aConnection;
- (void)drawWithRadius:(double)radius;

@end
