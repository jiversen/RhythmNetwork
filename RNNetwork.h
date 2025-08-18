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

@interface RNNetwork : NSObject {
	unsigned int    _numTapperNodes;
	unsigned int    _numStimulusChannels; // max number of independent Big Brother stimulus channels needed
	NSMutableArray *_nodeList;            // will contain RNTapperNode s
	NSMutableArray *_connectionList;      // will contain RNConnection s
	NSMutableArray *_MIOCConnectionList;  // translation of RNConnections to MIOCConnections
	RNMIDIRouting  *_MIDIRouting;         // real-time routing table; pushed to MIDIIO by RNController (programMIDIRoutingWithNetwork)
	NSString       *_description;
	BOOL            _isWeighted;
	BOOL            _isDelay;
}

//TODO: move stimuli out of BB node0 subchannels to first class nodes in the node list. Right now we're stuck with this
//once clever 'node 0 for everything else' paradigm. Why not have separate lists: nodeList, stimulusNodeList?
//Also, it looks like this can only be created once, from a definition dictionary, in one go and there is no facility
// for modifying it on the fly...think this through...except for adding new stimuli and global connection strength,
// which I no longer really understand--what this in addition to individual weights?

- (RNNetwork *)initFromDictionary:(NSDictionary *)theDict;

- (NSArray *)nodeList;
- (NSArray *)MIOCConnectionList;
- (NSArray *)MIOCVelocityProcessorList;
- (RNMIDIRouting *)MIDIRouting;
//- (RNNodeNum_t)nodeIndexForChannel:(Byte)channel Note:(Byte)note;

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
