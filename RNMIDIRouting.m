//
//  RNMIDIRouting.m
//  RhythmNetwork
//
//  Created by John R. Iversen on 2025-06-26.
//

#import "RNMIDIRouting.h"
#include "stdatomic.h"

// We use an atomic swap double-buffering scheme for realtime weight matrices
// this points to the inactive of the two, which we can render into then set.
#define WEIGHT_INACTIVE_INDEX (1 - _weightMatrixIndex)
#define DELAY_INACTIVE_INDEX (1 - _delayMatrixIndex)

@implementation RNMIDIRouting

- (RNMIDIRouting *) init {
	self = [super init];
	if (self) {
		// explicitly initialize routing to the first one, and set to empty
		_weightMatrixIndex = 0;
		NodeMatrix *active = &_weightMatrix[_weightMatrixIndex];
		memset(active, 0, sizeof(NodeMatrix));
		atomic_store(&_routingTable.weightMatrix, active);
		
		_delayMatrixIndex = 0;
		active = &_delayMatrix[_delayMatrixIndex];
		memset(active, 0, sizeof(NodeMatrix));
		atomic_store(&_routingTable.delayMatrix, active);
	}
	return self;
}

- (RNRealtimeRoutingTable *) routingTable {
	return &_routingTable;
}

// atomically flip to new matrix
- (void)setWeightMatrix:(NodeMatrix *)matrix {
	NodeMatrix *inactive = &_weightMatrix[WEIGHT_INACTIVE_INDEX];
	NSAssert(matrix==inactive,@"illegal input pointer--must a pointer returned by ond of the get___MatrixCopy methods");
	atomic_store(&_routingTable.weightMatrix, matrix);
	_weightMatrixIndex = 1 - _weightMatrixIndex;
}

- (void)setDelayMatrix:(NodeMatrix *)matrix {
	NodeMatrix *inactive = &_delayMatrix[DELAY_INACTIVE_INDEX];
	NSAssert(matrix==inactive,@"illegal input pointer--must a pointer returned by ond of the get___MatrixCopy methods");
	atomic_store(&_routingTable.delayMatrix, matrix);
	_delayMatrixIndex = 1 - _delayMatrixIndex;
}

// grab current matrix and copy into backing buffer
- (NodeMatrix *)getCurrentWeightMatrixCopy {
	NodeMatrix *active = atomic_load(&_routingTable.weightMatrix);
	NodeMatrix *inactive = &_weightMatrix[WEIGHT_INACTIVE_INDEX];
	memcpy(inactive, active, sizeof(NodeMatrix));
	return inactive;
}

- (NodeMatrix *)getCurrentDelayMatrixCopy { 
	NodeMatrix *active = atomic_load(&_routingTable.delayMatrix);
	NodeMatrix *inactive = &_delayMatrix[DELAY_INACTIVE_INDEX];
	memcpy(inactive, active, sizeof(NodeMatrix));
	return inactive;
}

// zero out backing buffer
- (NodeMatrix *)getEmptyWeightMatrix {
	NodeMatrix *inactive = &_weightMatrix[WEIGHT_INACTIVE_INDEX];
	memset(inactive, 0, sizeof(NodeMatrix));
	return inactive;
}

- (NodeMatrix *)getEmptyDelayMatrix { 
	NodeMatrix *inactive = &_delayMatrix[DELAY_INACTIVE_INDEX];
	memset(inactive, 0, sizeof(NodeMatrix));
	return inactive;
}

// strikes me that it'd be very useful to have some convenience methods that modify Node Matrices
//

@end


	
