//
//  RNConnection.m
//  RhythmNetwork
//
//  Created by John Iversen on 12/28/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "RNConnection.h"

@implementation RNConnection

// *********************************************
//    Init, accessors
// *********************************************

- (RNConnection *) init
{
	return [self initWithFromNode:0 ToNode:0];
}

- (RNConnection *) initWithFromNode: (UInt16) fromNode ToNode: (UInt16) toNode
{
	self = [super init];
	[self setFromNode: fromNode ToNode: toNode];
	[self setWeight:1.0]; //for now, no weighting
	return self;
}

//init from string of format {from, to} or {from, to} weight
//  e.g. "{2, 2}1.0"  (connection from node 2 to self, weight 1)
// if from node is 0, can optionally  have two digit decimal to indicate which subchannel
//	e.g. "{0.01, 2}1.0" refers to subchannel 1 (range: 1 to 16, i.e. 0.01 to 0.16)

- (RNConnection *) initWithString: (NSString *) coordString
{
	RNNodeNum_t	from, to;
	Byte subChannel;
	NSPoint	tempPoint;
	NSScanner *theScanner;
	NSCharacterSet *closeBraceSet;
	double	weight;
	
	tempPoint = NSPointFromString(coordString);
	from = (RNNodeNum_t) floor(tempPoint.x);
	//output subchannels of big brother node 0
	if (from == 0) {
		subChannel = (tempPoint.x - from) * 100;
		if (subChannel == 0) //if it's unspecified, default to 1
			subChannel = 1;
		NSAssert( (subChannel >= 1 && subChannel <= 16 ), @"subchannel out of range");
	}
	to = (RNNodeNum_t) floor(tempPoint.y);
	
	//extract weight, if any
	closeBraceSet	= [NSCharacterSet characterSetWithCharactersInString:@"}"];
	theScanner		= [NSScanner scannerWithString:coordString];
	if ([theScanner scanUpToCharactersFromSet:closeBraceSet intoString:NULL] &&
		[theScanner scanString:@"}" intoString:NULL]) {
		if ([theScanner isAtEnd] == NO) 
			if ([theScanner scanDouble:&weight] == NO) weight = 1.0;
	}
	
	self = [self initWithFromNode:from ToNode:to];
	[self setWeight:weight];
	
	if (from == 0)
		[self setFromSubChannel:subChannel]; //non-zero only in case of BB
	
	return self;
}

// *********************************************
//    Accessors
// *********************************************
#pragma mark  Accessors

- (NSString *) description
{
	return [NSString stringWithFormat:@"{%u.%u, %u} %.2f", _fromNode, _fromSubChannel/100, _toNode, _weight];
}

- (UInt16) fromNode { return _fromNode; }
- (UInt16) toNode { return _toNode; }

- (void) setFromNode: (UInt16) newFromNode ToNode: (UInt16) newToNode
{
	_fromNode = newFromNode;
	_toNode = newToNode;
}

- (double) weight { return _weight; }
- (void) setWeight: (double) newWeight
{
	_weight = newWeight;
}

- (unsigned int) fromSubChannel
{
	return _fromSubChannel;
}
- (void) setFromSubChannel: (unsigned int) newFromSubChannel
{
	NSAssert( (_fromNode == 0), @"Only node 0 may have subChannels");
	_fromSubChannel = newFromSubChannel;
	NSAssert( (_fromSubChannel >= 1 && _fromSubChannel <= 16), @"fromSubChannel out of range");
}

@end
