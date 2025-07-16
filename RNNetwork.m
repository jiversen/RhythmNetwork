//
//  RNNetwork.m
//  RhythmNetwork
//
//  Created by John Iversen on 10/10/04.
//  Copyright 2004 John Iversen. All rights reserved.
//

#import "RNNetwork.h"

#import "RNTapperNode.h"
#import "RNBBNode.h"
#import "RNConnection.h"
#import "RNStimulus.h"
#import "MIOCConnection.h"
#import "RNGlobalConnectionStrength.h"
#import "RNArchitectureDefines.h"

@implementation RNNetwork

// designated initializer
- (RNNetwork *)initFromDictionary:(NSDictionary *)theDict
{
	self = [super init];

	// extract fields

	// Number of Nodes
	NSNumber *nodesNum = [theDict valueForKey:@"nodes"];
	NSAssert1((nodesNum != nil), @"Network definition is missing number of Nodes: %@", theDict);
	RNNodeNum_t nNodes = (RNNodeNum_t)[nodesNum intValue];
	NSAssert1((nNodes > 0), @"Invalid Nodes value (%@) in file.", nodesNum);
	_numTapperNodes = nNodes;

	// connections
	NSArray *connectionsArray = [theDict valueForKey:@"connections"];
	NSAssert((connectionsArray != nil), @"File is missing connection list");

	// network description
	_description = [theDict valueForKey:@"description"];

	// number of stimulus channels for BigBrother
	NSNumber *stimulusChannelNum = [theDict valueForKey:@"stimulusChannels"];

	if (stimulusChannelNum == nil) {
		_numStimulusChannels = 1;
	} else {
		_numStimulusChannels = [stimulusChannelNum intValue];
	}

	NSAssert1((_numStimulusChannels < 16), @"Too many stimulus channels (%@).", stimulusChannelNum);

	// Is network weighted? (therefore we need to route output to others thru a third port)
	//	See specifications.txt for rationale 9/8/05
	_isWeighted = NO;	// default
	NSNumber *isWeightedNum = [theDict valueForKey:@"isWeighted"];
	if (isWeightedNum != nil)
		_isWeighted = (BOOL) [isWeightedNum boolValue];
	
	//Does network contain delays? If so, we need some additional special routing and the use of a second MIDIIO.
	_isDelay = NO; //default
	NSNumber *isDelayNum = [theDict valueForKey:@"isDelay"];
	if (isDelayNum != nil)
		_isDelay = (BOOL) [isDelayNum boolValue];
	
	// *********************************************
	//  Construct nodeList (creating the nodes), include as 0 'bigBrother' node, this computer
	//
	_nodeList = [[NSMutableArray arrayWithCapacity:nNodes + 1] retain];
	RNNodeNum_t		iNode;
	RNTapperNode	*tempNode;

	// bigBrother node--first in array (index 0)
	tempNode = [[RNBBNode alloc] initWithNumStimulusChannels:_numStimulusChannels];
	[tempNode setPlotLocationX:-1.15 Y:1.15];	// upper left corner
	[_nodeList addObject:[tempNode autorelease]];
	// we need to associate stimuli with each channel--done while constructing connection list

	// tapper nodes--arrange in a circle
	double x, y, dAngle, angle, pi;
	pi		= acos(-1.0);
	angle	= pi / 2.0;
	dAngle	= 2.0 * pi / nNodes;

	for (iNode = 1; iNode <= nNodes; iNode++) {
		tempNode	= [[RNTapperNode alloc] initWithNodeNumber:iNode];
		x			= cos(angle);
		y			= sin(angle);
		[tempNode setPlotLocationX:x Y:y];
		[_nodeList addObject:[tempNode autorelease]];
		angle -= dAngle;
	}

	// *********************************************
	//  Construct connectionList -- logical connections, doesn't reflect physical path, which might go via another node
	//
	NSUInteger iConn, nConnections = [connectionsArray count];
	_connectionList = [[NSMutableArray arrayWithCapacity:nConnections] retain];
	RNConnection	*tempConn;
	NSString		*connString;

	for (iConn = 0; iConn < nConnections; iConn++) {
		connString	= connectionsArray[iConn];
		tempConn	= [[[RNConnection alloc] initWithString:connString] autorelease];
		[_connectionList addObject:tempConn];
		
		// now, test to see if this connection is from bb or self
		// update to node's properties accordingly
		RNNodeNum_t from	= [tempConn fromNode];
		RNNodeNum_t to		= [tempConn toNode];

		if (from == 0) {
			[_nodeList[to] setHearsBigBrother:TRUE];
			[_nodeList[to] setBigBrotherSubChannel:[tempConn fromSubChannel]];
		}

		if (from == to) {
			[_nodeList[to] setHearsSelf:TRUE];
		}
	}

	// *********************************************
	//  prebuild array of MIOCConnections to use for programming the MIOC
	//
	// 1) big brother must be listening to all inputs (defined here), including BB
	// 2) the rest are defined in the input file, viz
	//		a) bb -> some or all tappers (for pacing stimuli)
	//		b) tapper to self
	//		c) tapper to other tapper
	//			**new 20050908: if isWeighted = YES, route via a patchthru node and apply velocity processing
	//  grab port/channel from nodes
	//		    **new 20250704: if isDelay = YES, construct RNMIDIRouting tables and associated MIOC Connections
	//			And, if timing is performant enough, could do all weighting internally rather than in MIOC
	//			TODO: compare MIOC route to MIDIIO internal route timing

	_MIOCConnectionList = [[NSMutableArray arrayWithCapacity:(nConnections + nNodes)] retain];
	MIOCConnection	*newMIOCConn;
	Byte			sourcePort, sourceChan, destPort, destChan;
	unsigned int	iStim;

	// 1a) all BB output back to self (so computer can monitor everything it outputs)
	for (iStim = 1; iStim <= _numStimulusChannels; iStim++) {
		sourcePort	= [_nodeList[0] sourcePort];
		sourceChan	= [_nodeList[0] MIDIChannelForStimulusNumber:iStim];
		destPort	= [_nodeList[0] destPort];	// big brother
		destChan	= [_nodeList[0] destChan];	// keep it on same chan as output
		newMIOCConn = [MIOCConnection connectionWithInPort:sourcePort InChannel:sourceChan OutPort:destPort OutChannel:destChan];
		[_MIOCConnectionList addObject:newMIOCConn];
	}

	// 1b) all tapper nodes to BB (so computer records all taps)
	for (iNode = 1; iNode <= nNodes; iNode++) {
		sourcePort	= [_nodeList[iNode] sourcePort];
		sourceChan	= [_nodeList[iNode] sourceChan];
		destPort	= [_nodeList[0] destPort];	// big brother
		destChan	= [_nodeList[0] destChan];
		newMIOCConn = [MIOCConnection connectionWithInPort:sourcePort InChannel:sourceChan OutPort:destPort OutChannel:destChan];
		[_MIOCConnectionList addObject:newMIOCConn];
	}

	// 2) network
	NSEnumerator	*theEnumerator = [_connectionList objectEnumerator];
	RNConnection	*thisConn;
	
	NodeMatrix *weightMatrix = NULL;
	NodeMatrix *delayMatrix  = NULL;
	// for delay, we have to instantiate _MIDIRouting and then grab copies of the routing matrices
	if (_isDelay) {
		_MIDIRouting = [[RNMIDIRouting alloc] init];
		weightMatrix = [_MIDIRouting getEmptyWeightMatrix];
		delayMatrix  = [_MIDIRouting getEmptyDelayMatrix];
	}

	while (thisConn = [theEnumerator nextObject]) {

		if ([thisConn fromNode] == 0) { // 2a) source is BB, take into account stimulus channels
			sourcePort = [_nodeList[[thisConn fromNode]] sourcePort];
			sourceChan = [_nodeList[[thisConn fromNode]] MIDIChannelForStimulusNumber:[thisConn fromSubChannel]];
			destPort   = [_nodeList[[thisConn toNode]] destPort];
			destChan   = [_nodeList[[thisConn toNode]] destChan]; // always kMIOCOutChannelSameAsInput

		} else { // source is a tapper node

			// destination depends on if network is weighted
			//  TODO: this needs to be revised to only treat specific connections with weight != 1.0 as weighted.
			// I don't quite get this, however, as where are the velocity processors made?
			if (_isDelay == NO) { // not delayed, within MIOC direct to destination
				sourcePort = [_nodeList[[thisConn fromNode]] sourcePort];
				sourceChan = [_nodeList[[thisConn fromNode]] sourceChan];

				// destination depends on if network is weighted
				if (_isWeighted == NO) { // not weighted, direct to destination
					destPort = [_nodeList[[thisConn toNode]] destPort];
					destChan = [_nodeList[[thisConn toNode]] destChan];
				} else {  // weighted, direct to destination if source is same node as dest, otherwise route through other port
					if ([thisConn fromNode] == [thisConn toNode]) { // to self
						destPort = [_nodeList[[thisConn toNode]] destPort];
						destChan = [_nodeList[[thisConn toNode]] destChan];
					} else { // via other port, source to thru port and from thru to our destination
						// make connection from thru to destination first, then set up for other connection
						newMIOCConn = [MIOCConnection connectionWithInPort:[_nodeList[[thisConn fromNode]] otherNodePassthroughPort]
																 InChannel:[_nodeList[[thisConn fromNode]] otherNodePassthroughChan]
																   OutPort:[_nodeList[[thisConn toNode]] destPort]
																OutChannel:[_nodeList[[thisConn toNode]] destChan]];
						[_MIOCConnectionList addObject:newMIOCConn];

						// next set dest for instantiation below (source is already source node)
						destPort = [_nodeList[[thisConn fromNode]] otherNodePassthroughPort];
						destChan = [_nodeList[[thisConn fromNode]] otherNodePassthroughChan];
					}
				}
				newMIOCConn = [MIOCConnection connectionWithInPort:sourcePort InChannel:sourceChan OutPort:destPort OutChannel:destChan];
				[_MIOCConnectionList addObject:newMIOCConn];
				
			} else { // Delay
				// input is already set up in 1b) above
				// output is generated by computer, sent into MIOC kDelayPort and must route out to standard destination
				sourcePort = kDelayPort;
				sourceChan = [_nodeList[[thisConn fromNode]] sourceChan];
				destPort = [_nodeList[[thisConn toNode]] destPort];
				destChan = [_nodeList[[thisConn toNode]] destChan];
				newMIOCConn = [MIOCConnection connectionWithInPort:sourcePort InChannel:sourceChan OutPort:destPort OutChannel:destChan];
				[_MIOCConnectionList addObject:newMIOCConn];
				
				//Also add this connection to RNMIDIRouting table
				double weight = [thisConn weight];
				double delay = [thisConn delay];
				(*weightMatrix)[sourceChan][destChan] = weight;
				(*delayMatrix)[sourceChan][destChan] = delay;
			}

			
		}
	} // while enumerate over connection list
	
	// Oh, crap. We can't commit the routing matrices yet as we've only just created the network, not made it 'live'. No,
	// wait, we own the RNMIDIRouting, so yes we absolutely can and then when we go live we just pass OUR routing
	// table pointer to MIDIIO for use. Phew. This can be done on RNController's programMIOCWithNetwork!
	if (_isDelay) {
		[_MIDIRouting setWeightMatrix:weightMatrix];
		[_MIDIRouting setDelayMatrix:delayMatrix];
	}

	return self;
}

// *********************************************
//    Accessors
// *********************************************
#pragma mark  Accessors

- (NSArray *)nodeList
{
	return [NSArray arrayWithArray:_nodeList];
}

- (NSArray *)MIOCConnectionList
{
	return [NSArray arrayWithArray:_MIOCConnectionList];// return non-mutable form, necessary?
}

// Dynamically harvest any processors from nodes
- (NSArray *)MIOCVelocityProcessorList
{

	RNNodeNum_t nNodes = [[self nodeList] count] - 1;	// number of tappers (exclude BB)
	NSMutableArray			*processorList = [NSMutableArray arrayWithCapacity:nNodes];
	MIOCVelocityProcessor	*processor;

	for (RNNodeNum_t iNode = 1; iNode <= nNodes; iNode++) {
		processor = [_nodeList[iNode] sourceVelocityProcessor];
		if (processor != nil) {
			[processorList addObject:processor];
		}

		processor = [_nodeList[iNode] destVelocityProcessor];
		if (processor != nil) {
			[processorList addObject:processor];
		}

		processor = [_nodeList[iNode] otherNodeVelocityProcessor];
		if (processor != nil) {
			[processorList addObject:processor];
		}
	}

	return [NSArray arrayWithArray:processorList];
}

- (RNMIDIRouting *)MIDIRouting {
	return _MIDIRouting;
}

// reminder: channel is 1-based
//- (RNNodeNum_t)nodeIndexForChannel:(Byte)channel Note:(Byte)note
//{
//	return _nodeLookup[channel][note];
//}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@%@%@", _description, _isWeighted?@"ⓦ":@"", _isDelay?@"🅓":@""];
}

- (unsigned int)numStimulusChannels
{
	return _numStimulusChannels;
}

// these are convenience methods reaching into the big brother node
// they associate the correct stimuli with iW
- (RNStimulus *)stimulusForChannel:(Byte)stimulusChannel
{
	RNBBNode *bbNode = [self nodeList][0];

	return [bbNode stimulusForChannel:stimulusChannel];
}

- (void)setStimulus:(RNStimulus *)stim ForChannel:(Byte)stimulusChannel
{
	RNBBNode *bbNode = [self nodeList][0];

	[bbNode setStimulus:stim ForChannel:stimulusChannel];
}

// grab stimuli from the array
- (void)setStimulusArray:(RNStimulus **)stimulusArray
{
	unsigned int	i;
	RNStimulus		*stim;

	if (_numStimulusChannels > 0) {
		for (i = 1; i <= _numStimulusChannels; i++) {
			stim = stimulusArray[i];
			NSAssert((stim == nil || [[stim className] isEqualToString:@"RNStimulus"]), @"non-stimulus");
			[self setStimulus:stim ForChannel:i];
		}
	}
}

// add processor for each node--this applies only to connections to OTHER nodes
// self feedback and pacing stimuli are untouched
// !!! this name is no longer accurate now that it handles global strength & input strength...
- (void)setGlobalConnectionStrength:(RNGlobalConnectionStrength *)connectionStrength
{
	MIOCVelocityProcessor	*processor = [connectionStrength processor];

	RNNodeNum_t nNodes = [[self nodeList] count] - 1;	// number of tappers (exclude BB)

	for (RNNodeNum_t iNode = 1; iNode <= nNodes; iNode++) {
		if ([[connectionStrength type] isEqual:@"constantInput"]) {	// apply to input
			[_nodeList[iNode] setSourceVelocityProcessor:processor];
		} else {
			NSAssert((_isWeighted == YES), @"Network must be weighted: add isWeighted key to definition dictionary.");
			[_nodeList[iNode] setOtherNodeVelocityProcessor:processor];	// otherwise apply to other
		}
	}
}

- (void)setDrumsetNumber:(Byte)drumsetNumber
{
	RNNodeNum_t nNodes = [[self nodeList] count] - 1;	// number of tappers (exclude BB)

	for (RNNodeNum_t iNode = 1; iNode <= nNodes; iNode++) {
		[_nodeList[iNode] setDrumsetNumber:drumsetNumber];
	}
}

// *********************************************
//    Display
// *********************************************
#pragma mark  Display

- (void)drawWithRadius:(double)radius
{
	NSEnumerator		*theEnumerator = [_connectionList objectEnumerator];
	RNConnection		*thisConn;
	NSPoint				fromPt, toPt, arrowPt, larrowPt, rarrowPt, textPt;
	NSBezierPath		*tempPath = [NSBezierPath bezierPath];
	NSAffineTransform	*arrowRotation, *arrowTranslation, *arrowTransform;
	double				angle;

	[[NSColor labelColor] setFill];
	[[NSColor labelColor] setStroke];

	while (thisConn = [theEnumerator nextObject]) {
		if (([thisConn fromNode] > 0) && ([thisConn fromNode] != [thisConn toNode])) {
			fromPt		= [_nodeList[[thisConn fromNode]] plotLocation];
			toPt		= [_nodeList[[thisConn toNode]] plotLocation];
			fromPt.x	*= radius;
			fromPt.y	*= radius;
			toPt.x		*= radius;
			toPt.y		*= radius;
			// but we want to point to be at edge of node's circle (radius = radius * kNodeScale)
			angle	= atan2((fromPt.y - toPt.y), (fromPt.x - toPt.x));
			toPt.x	+= radius * kNodeScale * cos(angle);
			toPt.y	+= radius * kNodeScale * sin(angle);
			[tempPath removeAllPoints];
			[tempPath moveToPoint:fromPt];
			[tempPath lineToPoint:toPt];
			[tempPath stroke];

			// draw an arrowhead
			arrowPt.x			= toPt.x + 0.75 * (radius * kNodeScale * cos(angle));	// arrowhead length is proportion of node radius
			arrowPt.y			= toPt.y + 0.75 * (radius * kNodeScale * sin(angle));
			arrowTranslation	= [NSAffineTransform transform];
			[arrowTranslation translateXBy:-toPt.x yBy:-toPt.y];
			arrowRotation = [NSAffineTransform transform];
			[arrowRotation rotateByDegrees:15];	// arrowhead's breadth controlled by this angle

			arrowTransform = [NSAffineTransform transform];
			[arrowTransform appendTransform:arrowTranslation];
			[arrowTransform appendTransform:arrowRotation];
			[arrowTranslation invert];
			[arrowTransform appendTransform:arrowTranslation];
			[arrowTranslation invert];
			rarrowPt = [arrowTransform transformPoint:arrowPt];

			arrowTransform = [NSAffineTransform transform];
			[arrowTransform appendTransform:arrowTranslation];
			[arrowRotation invert];
			[arrowTransform appendTransform:arrowRotation];
			[arrowTranslation invert];
			[arrowTransform appendTransform:arrowTranslation];
			larrowPt = [arrowTransform transformPoint:arrowPt];

			[tempPath removeAllPoints];
			[tempPath moveToPoint:rarrowPt];
			[tempPath lineToPoint:toPt];
			[tempPath lineToPoint:larrowPt];

			if (TRUE) {	// to fill the arrows
				[tempPath closePath];
				[tempPath fill];
			}

			[tempPath stroke];
			
			//TODO: Add text with weight/delay
			NSString *connStr = [NSString stringWithFormat:@"%.1f ms", [thisConn delay]];
			textPt.x = fromPt.x += 1.2 * radius * kNodeScale * cos(-angle);
			textPt.y = fromPt.y += 1.2 * radius * kNodeScale * sin(-angle);
			[self drawRotatedText:connStr atPoint:textPt angle:angle];

			
		}	// if node-to-node connection
	}		// enumerate over connections

	// draw nodes
	RNTapperNode *thisNode;
	theEnumerator = [_nodeList objectEnumerator];

	while (thisNode = [theEnumerator nextObject]) {
		[thisNode drawWithRadius:radius];
	}
}

- (void)drawRotatedText:(NSString *)text atPoint:(NSPoint)textPt angle:(CGFloat)angle
{
	// Save graphics state
	[[NSGraphicsContext currentContext] saveGraphicsState];

	// Move the origin to textPt
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform translateXBy:textPt.x yBy:textPt.y];
	[transform rotateByRadians:angle]; // positive angle = counter-clockwise
	[transform concat];

	// Attributes
	NSDictionary *attributes = @{
		NSFontAttributeName: [NSFont systemFontOfSize:10],
		NSForegroundColorAttributeName: [NSColor redColor],
		NSBackgroundColorAttributeName: [NSColor whiteColor]  // to "erase" what's underneath
	};

	// Measure text size
	NSSize textSize = [text sizeWithAttributes:attributes];

	// Draw the text centered at (0, 0), because the transform moved the origin to textPt
	NSPoint drawPoint = NSMakePoint(-textSize.width / 2.0, -textSize.height / 2.0);
	[text drawAtPoint:drawPoint withAttributes:attributes];

	// Restore graphics state
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

@end
