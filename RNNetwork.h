//
//  RNNetwork.h
//  RhythmNetwork
//
//  Created by John Iversen on 10/10/04.
//  Copyright 2004 John Iversen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "RNTapperNode.h"

#define kNumMIDIChans 16
#define kNumMIDINotes 128

@class RNStimulus;
@class RNGlobalConnectionStrength;

@interface RNNetwork : NSObject {
	NSMutableArray	*_nodeList;			//will contain RNTapperNode s
	NSMutableArray	*_connectionList;	//will contain RNConnection s
	NSMutableArray	*_MIOCConnectionList;
	NSString		*_description;
	RNNodeNum_t		_nodeLookup[kNumMIDIChans][kNumMIDINotes]; //takes channel,note to node (0-based indexing)
	unsigned int	_numTapperNodes;
	unsigned int	_numStimulusChannels; //max number of independent Big Brother stimulus channels needed
	BOOL			_isWeighted;
}

- (RNNetwork *) initFromDictionary: (NSDictionary *) theDict;

- (NSArray *) nodeList;
- (NSArray *) MIOCConnectionList;
- (NSArray *) MIOCVelocityProcessorList;
- (RNNodeNum_t) nodeIndexForChannel:(Byte) channel Note: (Byte) note;

- (NSString *) description;

- (unsigned int) numStimulusChannels;
- (RNStimulus *) stimulusForChannel: (Byte) stimulusChannel;
- (void) setStimulus: (RNStimulus *) stim ForChannel: (Byte) stimulusChannel;
- (void) setStimulusArray: (RNStimulus **) stimulusArray;
- (void) setGlobalConnectionStrength: (RNGlobalConnectionStrength *) connectionStrength;
- (void) setDrumsetNumber: (Byte) drumsetNumber;

//- (void) addConnection: (RNConnection *) aConnection;
//- (void) removeConnection: (RNConnection *) aConnection;

- (void) drawWithRadius: (double) radius;

@end
