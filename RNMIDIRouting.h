//
//  RNMIDIRouting.h
//  RhythmNetwork
//
//  Created by John R. Iversen on 2025-06-26.
//

#import <Foundation/Foundation.h>
#import <stdatomic.h>
#import "RNArchitectureDefines.h"

typedef double NodeMatrix[kMaxNodes + 1][kMaxNodes + 1]; // we use 1-based index, with 0 as BB node

typedef struct {
	// Swappable transformation matrices (atomic for thread safety)
	_Atomic(NodeMatrix *) weightMatrix; // 0 = no route, +/- = velocity scale
	_Atomic(NodeMatrix *) delayMatrix;  // in ms, 0=immediate
} RNRealtimeRoutingTable;

@interface RNMIDIRouting : NSObject {
	RNRealtimeRoutingTable _routingTable;
	NodeMatrix             _weightMatrix[2];
	NodeMatrix             _delayMatrix[2];
	int                    _weightMatrixIndex; // index of the 'live' matrix
	int                    _delayMatrixIndex;
}

- (RNMIDIRouting *)init;
- (RNRealtimeRoutingTable *)routingTable;

// Atomic setters
- (void)setWeightMatrix:(NodeMatrix *)_weightMatrix;
- (void)setDelayMatrix:(NodeMatrix *)_delayMatrix;

// get an editable copy, update then set
- (NodeMatrix *)getCurrentWeightMatrixCopy;
- (NodeMatrix *)getCurrentDelayMatrixCopy;
- (NodeMatrix *)getEmptyWeightMatrix;
- (NodeMatrix *)getEmptyDelayMatrix;

@end
