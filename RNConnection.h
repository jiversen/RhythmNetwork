//
//  RNConnection.h
//  RhythmNetwork
//
//  Created by John Iversen on 12/28/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "RNTapperNode.h"

@interface RNConnection : NSObject {
	RNNodeNum_t _fromNode;
	RNNodeNum_t _toNode;
	double _weight;
	unsigned int	_fromSubChannel; //node 0 can have several separately addressable outputs
}

// *********************************************
// Init, accessors 

- (RNConnection *) init;
- (RNConnection *) initWithFromNode: (RNNodeNum_t) fromNode ToNode: (RNNodeNum_t) toNode; //designated
- (RNConnection *) initWithString: (NSString *) coordString;

- (NSString *) description;

- (RNNodeNum_t) fromNode;
- (RNNodeNum_t) toNode;
- (void) setFromNode: (RNNodeNum_t) newFromNode ToNode: (RNNodeNum_t) newToNode;

- (double) weight;
- (void) setWeight: (double) newWeight;

- (unsigned int) fromSubChannel;
- (void) setFromSubChannel: (unsigned int) newFromSubChannel;

// *********************************************
//  Display--taken care of in RNNetwork--since needs access to node objects

@end
