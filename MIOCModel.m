#import "MIOCModel.h"

#import "MIOCProcessorProtocol.h"
#import "MIOCConnection.h"
#import "MIOCVelocityProcessor.h"
#import "MIOCFilterProcessor.h"
#import "MIDIIO.h"
#import "MIDICore.h"
#import "NSStringHexStringCategory.h"

//various components of sysex messages
static Byte sysexStart[1] = {0xF0};
static Byte sysexEnd[1] = {0xF7};
static Byte MIDITEMPID[3] = {0x00, 0x20, 0x0d};
static Byte encodedMode[1] = {0x40};	//we'll never send handshaking or multi-packet messages
static Byte notEncodedMode[1] = {0x00}; // so these two suffice
static Byte addRemoveProcessorOpcode[1] = {0x04};
static Byte addProcessorFlag[1] = {0x80};
static Byte removeProcessorFlag[1] = {0x00};


@implementation MIOCModel

// *********************************************
//    INIT
// *********************************************

- (MIOCModel *)init
{
	self = [super init];
	_deviceID		= 0x00; //*** hard coded for now, later add discovery if we have multiple devices
	_deviceType		= kDevicePMM88E;
	_connectionList = [[NSMutableArray arrayWithCapacity:0] retain];
	_velocityProcessorList = [[NSMutableArray arrayWithCapacity:0] retain];
	
	_MIDILink		= [[MIDIIO alloc] init];
	
	[_MIDILink registerSysexListener:self];
	
	//default: use external (MIOC) processor
	_useInternalMIDIProcessor = NO;
	_MIDICore = nil;
	
	//check it mioc is online--if so, initialize it
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(handleMIOCReply:) 
												 name:@"MIOCReplyNotification" 
											   object:nil];
	
	[self checkOnline]; //once online, we'll initizlize in reply handler
	
	return self;
}

- (void) dealloc
{
	[_connectionList release];
	[_velocityProcessorList release];
	[_MIDILink release]; //removes listeners too
	[super dealloc];
}

- (void) initialize
{
	NSLog(@"Initializing MIOC");
	[self queryDeviceName];
	[self addFilterProcessors];
}

- (BOOL) useInternalMIDIProcessor { return _useInternalMIDIProcessor; }

- (void) setUseInternalMIDIProcessor:(BOOL) useInternal
{
	_useInternalMIDIProcessor = useInternal;
	if (useInternal==YES) {
		if (_MIDICore == nil)
			_MIDICore = [[MIDICore alloc] initWithInterface:_MIDILink];
		//initialize midi core with connections/velocities/delays...
	} else if (useInternal == NO) {
		[_MIDICore release]; //restores original readProc
		_MIDICore = nil;
	}
}

//reset MIOC: clear all existing connections, processors
// to force sync, unfortunately must ask user to power cycle MIOC--there's no reset sysex command we can send
// and we can't really know if we've removed everything, as there's no way to query
//  then re-initialize: name, filter processors
- (void) reset
{	
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Don't reset"];
	[alert setMessageText:@"Reset MIDI Matrix..."];
	[alert setInformativeText:@"Please turn the Midi Matrix (PMM 88-E) off, then on. Click OK when done."];
	[alert setAlertStyle:NSWarningAlertStyle];
	
	int returnCode = [alert runModal];

	if (returnCode == NSAlertFirstButtonReturn) { //OK: assume they've powercycled
		//reset our model state
		[_connectionList removeAllObjects];
		[_velocityProcessorList removeAllObjects];
		//initialize the MIOC (after checking it's connected)
		[self checkOnline];
	} else //Cancel: do nothing
		NSLog(@"Reset cancelled");
}


- (void) checkOnline
{
	if (_useInternalMIDIProcessor == NO)
		//we send a test query--if it is replied to, we know we're online
		[self queryPortAddress];
}

- (BOOL) queryPortAddress
{
	//send dump request message
	NSString *sendStr = @"F0 00 20 0D 7F 7F 00 78 F7";
	NSData *data = [sendStr convertHexStringToData];
	NSLog(@"Querying port address\n\tData (%d B): %@", [data length], data);
	return [self sendVerifiedMIOCQuery:data];
}

//send a verified query: indicate that we're waiting for a response and set up a timer to wait for it
//  if timer fires before we receive the response, we're not connected and try to make that right
- (BOOL) sendVerifiedMIOCQuery:(NSData *)data
{
	NSAssert( (_awaitingReply==NO), @"Trying to send sysex before receiving earlier reply");
	//try to send
	BOOL success = [_MIDILink sendSysex:data];
	
	if (success == YES) {
		//sent it successfully, now wait for reply
		_awaitingReply = YES;
		// two things can happen: 1) get reply and handleMIOCReply is called
		// or 2) don't get reply and handleMIOCReplyTimeout is called when timer counts down
		NSAssert( (_replyTimer==nil), @"doubling up on timers!");
		_replyTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 //expect a reply fast
														target:self
													  selector:@selector(handleMIOCReplyTimeout:)
													  userInfo:nil
													   repeats:NO] retain];
	} else {
		//didn't send successfully, problem with MIDI connections
		// throw up an alert sheet. One problem w/ this is that I'm not sure we can get at drawer while sheet
		// is down (in case we need to change settings there...)
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"OK (I'll do it)"];
		[alert setMessageText:@"Problem with MIDI connection!"];
		[alert setInformativeText:@"Please follow these steps: After clicking OK, make sure the MIDI interface is connected and the proper MIDI Input and Output are selected. Then press the device 'Reset' button."];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		int returnCode = [alert runModal];
		if (returnCode == NSAlertFirstButtonReturn) { //OK: try again
			//[[self MIDILink] handleMIDISetupChange]; //total hack--force this to happen (as it might not happen
			// in time otherwise before we get back in this spot, thus infinite loop)
			//[self checkOnline];
		}
		
	}
	
	return success;
}

//called after sending request used for testing whether MIOC is online
- (void) handleMIOCReply:(NSNotification *)notification
{
	//if we get here, we know we're online
	NSAssert( (_isOnline == YES), @"_isOnline should be YES"); //sanity check
	//zap the timer
	[_replyTimer invalidate];
	[_replyTimer release];
	_replyTimer = nil;
	
	//check if we're correctly hooked up
	if (_correctPort == NO) {
		NSLog(@"MIDI interface must be connected to MIOC I/O port 8");
	}
	
	[self initialize];
}

//if we sent our request, and haven't heard back, this is called
- (void) handleMIOCReplyTimeout:(NSTimer *)timer
{
	//if we get here, we haven't yet received a reply
	NSAssert( (_awaitingReply == YES), @"Should be awaiting a reply!"); //sanity check
	
	//we only give it one chance to reply, if not, assume it's offline
	[_replyTimer invalidate];
	[_replyTimer release];
	_replyTimer = nil;
	_awaitingReply = NO;
	_isOnline = NO;
	
	//now, ask user to get the device online
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Stop trying"];
	[alert setMessageText:@"Problem connecting with MIDI Matrix (PMM 88-E)!"];
	[alert setInformativeText:@"Please make sure it is turned on and then click OK."];
	[alert setAlertStyle:NSWarningAlertStyle];
	int returnCode = [alert runModal];
	if (returnCode == NSAlertFirstButtonReturn) { //OK: try again
		[self checkOnline];
	} //otherwise do nothing more
}


//send an un verified query
- (BOOL) sendMIOCQuery:(NSData *)data
{
	if (_isOnline==NO) {
		NSLog(@"MIOC is not online...connect");
		return NO;
	}
	
	NSAssert( (_awaitingReply==NO), @"Trying to send sysex before receiving earlier reply");
	_awaitingReply = YES;
	//try to send
	return [_MIDILink sendSysex:data];
}

- (BOOL) queryDeviceName
{
	//send dump request message
	NSString *sendStr = @"f0 00 20 0d 00 20 00 45 f7";
	NSData *data = [sendStr convertHexStringToData];
	NSLog(@"Querying device name\n\tData (%d B): %@", [data length], data);
	//clear earlier name, in case return fails
	[_deviceName autorelease];
	_deviceName = nil;
	
	return [self sendMIOCQuery:data];
}

- (NSString *) deviceName
{
	if (_deviceName != nil)
		return _deviceName;
	else
		return [NSString stringWithString:@"<Not Connected>"];
}

//stub for setting MIOC device name. Not needed at present, so fails
- (BOOL) setDeviceName:(NSString *) name
{
	return NO;
}

// *********************************************
//    MANAGE MIOC CONNECTIONS
// *********************************************
#pragma mark MANAGE MIOC CONNECTIONS

// *********************************************
//  Make one connection--if connection not already in our state array, send sysex to MIOC to make it
//  --otherwise, do nothing (MIOC does no checking for multiple identical channels)
- (void) connectOne:(MIOCConnection *) aConnection
{
	if (![_connectionList containsObject:aConnection]) {
		if ([self sendConnect:aConnection] == kSendSysexSuccess) {
			[_connectionList addObject:aConnection];
			NSLog(@"Connected:    %@",aConnection);
		} else
			NSLog(@"\n\tFailed to add connection processor (%@).",aConnection);
	} else
		NSLog(@"Attempt was made to add connection (%@) multiple times.", aConnection);
}

// *********************************************
//  iterate through an array of MIOCConnections, connecting each one
- (void) connectMany:(NSArray *) aConnectionList;
{
	NSAssert( (aConnectionList != nil), @"nil connection List");
	MIOCConnection *conn;
	NSEnumerator *enumerator = [aConnectionList objectEnumerator];
	while (conn = [enumerator nextObject]) {
		[self connectOne: conn];
	}
}

// *********************************************
//  convenience method to make one connection by explicitly passing arguments
//	--creates an MIOCConnection object and calls connectOne
- (void) connectInPort: (int) anInPort InChannel: (int) anInChannel OutPort: (int) anOutPort OutChannel: (int) anOutChannel
{
	MIOCConnection *conn = [MIOCConnection connectionWithInPort:anInPort InChannel:anInChannel 
														OutPort:anOutPort OutChannel:anOutChannel];
	[self connectOne:conn];
}

// *********************************************
//  
- (void) disconnectOne:(MIOCConnection *) aConnection
{
	if ([_connectionList containsObject:aConnection]) {
		if ([self sendDisconnect:aConnection] == kSendSysexSuccess) {
			[_connectionList removeObject:aConnection];
			NSLog(@"Disconnected: %@",aConnection);
		} else
			NSLog(@"\n\tFailed to remove connection processor (%@).",aConnection);
	} else
		NSLog(@"Attempt was made to remove non-existent connection (%@).", aConnection);
}

- (void) disconnectMany:(NSArray *) aConnectionList
{
	NSAssert( (aConnectionList != nil), @"nil connection List");
	MIOCConnection *conn;
	NSEnumerator *enumerator = [aConnectionList objectEnumerator];
	while (conn = [enumerator nextObject]) {
		[self disconnectOne: conn];
	}	
}

- (void) disconnectInPort: (int) anInPort InChannel: (int) anInChannel OutPort: (int) anOutPort OutChannel: (int) anOutChannel
{
	MIOCConnection *conn = [MIOCConnection connectionWithInPort:anInPort InChannel:anInChannel 
														OutPort:anOutPort OutChannel:anOutChannel];
	[self disconnectOne:conn];
}

// *********************************************
//  disconnect all entries in _connectionList & all velocity processors
- (void) disconnectAll
{
	[self setConnectionList:[NSArray array]];
	//sanity--
	NSAssert( ([_connectionList count] == 0), @"Non-empty connectionList after disconnectAll");
	
	[self setVelocityProcessorList:[NSArray array]];
	//sanity--
	NSAssert( ([_velocityProcessorList count] == 0), @"Non-empty velocityProcessorList after disconnectAll");
}

// *********************************************
//  accessors for _connectionList NSMutableArray
// we don't want anyone else to modify our connectionList, so return a copy & make it non-mutable so if they try
//	they'll get an error. Since using class method, it's already autoreleased
- (NSArray *) connectionList
{
	return [NSArray arrayWithArray:_connectionList];
}

//do an incremental change: determine connections that need to be lost and those needing to be added
- (void) setConnectionList: (NSArray *) newConnectionList
{
	NSMutableArray *connectionsToRemove = [NSMutableArray arrayWithCapacity:10];
	NSMutableArray *connectionsToAdd = [NSMutableArray arrayWithCapacity:10];

	//find current connections NOT in new list (to remove)
	MIOCConnection *conn;
	NSEnumerator   *currentEnumerator = [[self connectionList] objectEnumerator];
	while (conn = [currentEnumerator nextObject]) {
		if ([newConnectionList containsObject:conn] == NO)
			[connectionsToRemove addObject:conn];
	}
	
	//find new connections not already in current list (to add)
	NSEnumerator   *newEnumerator = [newConnectionList objectEnumerator];
	while (conn = [newEnumerator nextObject]) {
		if ([[self connectionList] containsObject:conn] == NO)
			[connectionsToAdd addObject:conn];
	}
	
	[self disconnectMany:connectionsToRemove];
	[self connectMany:connectionsToAdd];
	NSLog(@"Update connections: Remove %d; Add %d\n", [connectionsToRemove count], [connectionsToAdd count]);
}

// *********************************************
//    Velocity Processors
// *********************************************
#pragma mark VELOCITY PROCESSORS

- (void) addVelocityProcessor:(MIOCVelocityProcessor *) aVelProc
{
	if (![_velocityProcessorList containsObject:aVelProc]) {
		if ([self sendAddVelocityProcessor:aVelProc] == kSendSysexSuccess) {
			[_velocityProcessorList addObject:aVelProc];
			NSLog(@"Added vel proc: %@",aVelProc);
		} else
			NSLog(@"\n\tFailed to add velocity processor (%@).",aVelProc);
	} else
		NSLog(@"Attempt was made to add velocity processor (%@) multiple times.", aVelProc);	
}

- (void) removeVelocityProcessor:(MIOCVelocityProcessor *) aVelProc
{
	if ([_velocityProcessorList containsObject:aVelProc]) {
		if ([self sendRemoveVelocityProcessor:aVelProc] == kSendSysexSuccess) {
			[_velocityProcessorList removeObject:aVelProc];
			NSLog(@"Removed vel proc: %@",aVelProc);
		} else
			NSLog(@"\n\tFailed to remove velocity processor (%@).",aVelProc);
	} else
		NSLog(@"Attempt was made to remove non-existent velocity processor (%@).", aVelProc);
}

// *********************************************
//  iterate through an array of MIOCVelocityProcessors, adding each one
- (void) addVelocityProcessorsInArray:(NSArray *) aProcessorList
{
	NSAssert( (aProcessorList != nil), @"nil processor List");
	MIOCVelocityProcessor *processor;
	NSEnumerator *enumerator = [aProcessorList objectEnumerator];
	while (processor = [enumerator nextObject]) {
		[self addVelocityProcessor:processor];
	}
}

// *********************************************
//  iterate through an array of MIOCVelocityProcessors, removing each one
- (void) removeVelocityProcessorsInArray:(NSArray *) aProcessorList
{
	NSAssert( (aProcessorList != nil), @"nil processor List");
	MIOCVelocityProcessor *processor;
	NSEnumerator *enumerator = [aProcessorList objectEnumerator];
	while (processor = [enumerator nextObject]) {
		[self removeVelocityProcessor:processor];
	}
}

// *********************************************
//  accessors for _velocityProcessorList NSMutableArray
- (NSArray *) velocityProcessorList
{
	return [NSArray arrayWithArray:_velocityProcessorList];
}

//do an incremental change: determine connections that need to be lost and those needing to be added
- (void) setVelocityProcessorList: (NSArray *) newVelocityProcessorList
{
	NSMutableArray *processorsToRemove = [NSMutableArray arrayWithCapacity:10];
	NSMutableArray *processorsToAdd = [NSMutableArray arrayWithCapacity:10];
	
	//find current velocity processors NOT in new list (to remove)
	MIOCVelocityProcessor *processor;
	NSEnumerator   *currentEnumerator = [[self velocityProcessorList] objectEnumerator];
	while (processor = [currentEnumerator nextObject]) {
		if ([newVelocityProcessorList containsObject:processor] == NO)
			[processorsToRemove addObject:processor];
	}
	
	//find new connections not already in current list (to add)
	NSEnumerator   *newEnumerator = [newVelocityProcessorList objectEnumerator];
	while (processor = [newEnumerator nextObject]) {
		if ([[self velocityProcessorList] containsObject:processor] == NO)
			[processorsToAdd addObject:processor];
	}
	
	[self addVelocityProcessorsInArray:processorsToAdd]; //add before remove seems to work, prevents gap when there's no processor
	[self removeVelocityProcessorsInArray:processorsToRemove];
	
	NSLog(@"Update velocity processors: Remove %d; Add %d\n", [processorsToRemove count], [processorsToAdd count]);
}


//filter out active sense and note-offs from all inputs (1-7) that are connected to
//  trigger to midi converters
//  error handling: on first sysex failure, bail out. Weakness: could leave things in indeterminate state
- (void) addFilterProcessors
{
	Byte iPort;
	MIOCFilterProcessor *aProc;
	BOOL result;
	
	_filtersInitialized = YES;

	for (iPort=1; iPort<=7; iPort++) {
		//remove note off
		aProc = [[MIOCFilterProcessor alloc] initWithType:@"noteoff" 
													 Port:iPort 
												  Channel:kMIOCFilterChannelAll 
												  OnInput:YES];
		result = [self sendAddProcessor:aProc];
		if (result == kSendSysexFailure) {
			_filtersInitialized = NO;
			break;
		}
		//remove active sense
		aProc = [[MIOCFilterProcessor alloc] initWithType:@"activesense" 
													 Port:iPort 
												  Channel:kMIOCFilterChannelAll 
												  OnInput:YES];
		result = [self sendAddProcessor:aProc];
		if (result == kSendSysexFailure) {
			_filtersInitialized = NO;
			break;
		}
	}
	
	if (_filtersInitialized == NO)
		NSLog(@"\n\tFailed to initialize MIOC filters.");
	
}


// *********************************************
//    MIDI
// *********************************************
#pragma mark MIDI

// *********************************************
//  Reference to our MIDIIO object
- (MIDIIO *) MIDILink
{
	return _MIDILink;
}

// *********************************************
//     Process incoming sysex data (if we're expecting it)
- (void)receiveSysexData:(NSData *)data
{
	MIOCMessage *reply;
	
	if (_awaitingReply == YES) {
		NSString *hexStr = [[NSString alloc] initHexStringWithData:data];
		NSLog(@"MIOCModel Received Expected Sysex (%d bytes): %@\n",[data length], hexStr);
		reply = (MIOCMessage *)[data bytes];
		//add logic here to parse info messages and fill in instance values
		//also potentially to verify connections made
		if (reply->opcode==0x05) {
			_awaitingReply = NO;
			[_deviceName autorelease];
			_deviceName = [[NSString stringWithCString:(&reply->data[1]) length:8] retain];
			//post notification for UI to resync
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MIOCModelChangeNotification"
																object:self];
		// we use this reply as a means to check MIOC is online--
		} else if (reply->opcode==0x38) { //what ports are we connected to?
			_awaitingReply = NO;
			_isOnline = YES;
			//check we're connected to correct port
			Byte outport = reply->data[0]; 
			Byte inport = reply->data[1];
			if (outport==0x07 && inport==0x07) //should be connected to port #8
				_correctPort = YES;
			else
				_correctPort = NO;
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MIOCReplyNotification"
																object:self];
		} else
			NSLog(@"Unhandled Sysex Message, opcode = %x",reply->opcode);
	}

}

// *********************************************
//    MIOC CONNECTION -> MIDI BRIDGE INTERNAL
// *********************************************
#pragma mark MIOC -> MIDI MESSAGING

// *********************************************
//  
- (BOOL) sendConnect:(MIOCConnection *) aConnection
{	
	if (_useInternalMIDIProcessor == NO)
		return [self sendConnectDisconnectSysex: aConnection withFlag:addProcessorFlag];
	else {
		[_MIDICore connect:aConnection];
		return kSendSysexSuccess;  //cannot fail
	}
}

- (BOOL) sendDisconnect:(MIOCConnection *) aConnection
{
	if (_useInternalMIDIProcessor == NO)
		return [self sendConnectDisconnectSysex: aConnection withFlag:removeProcessorFlag];
	else {
		[_MIDICore disconnect:aConnection];
		return kSendSysexSuccess;  //cannot fail
	}
}

// *********************************************
//  common method for connecting/disconnecting
- (BOOL) sendConnectDisconnectSysex: (MIOCConnection *) aConnection withFlag:(Byte *)flagPtr
{
	
	NSData *message = [self sysexMessageForProcessor: aConnection withFlag: flagPtr];
	//unsigned i = [message retainCount];
	//printf("before sendSysex, message: %x (%d B) retain %d\n",(unsigned) message, [message length], i);
	
	return [_MIDILink sendSysex:message];
	
	//i = [message retainCount];
	//printf("after sendSysex, message: %x %d\n",(unsigned) message, i);
	//for now, assume all sysex sends complete correctly--how could we know otherwise?
	// NEW: we add some checks that send completed correctly--destionation exists, etc.
}

- (BOOL) sendAddVelocityProcessor:(MIOCVelocityProcessor *) aVelProc
{
	if (_useInternalMIDIProcessor == NO)
		return [self sendAddRemoveVelocityProcessorSysex: aVelProc withFlag:addProcessorFlag];
	else {
		[_MIDICore addVelocityProcessor:aVelProc];
		return kSendSysexSuccess;  //cannot fail
	}
}

- (BOOL) sendRemoveVelocityProcessor:(MIOCVelocityProcessor *) aVelProc
{
	if (_useInternalMIDIProcessor == NO)
		return [self sendAddRemoveVelocityProcessorSysex: aVelProc withFlag:removeProcessorFlag];
	else {
		[_MIDICore removeVelocityProcessor:aVelProc];
		return kSendSysexSuccess;  //cannot fail
	}
}

- (BOOL) sendAddRemoveVelocityProcessorSysex:(MIOCVelocityProcessor *) aVelProc withFlag:(Byte *)flagPtr
{
	NSData *message = [self sysexMessageForProcessor: aVelProc withFlag: flagPtr];	
	return [_MIDILink sendSysex:message];
}

// *********************************************
//  general method to send sysex messages
- (BOOL) sendAddProcessor:(id <MIOCProcessor>) aProc
{
	if (_useInternalMIDIProcessor == NO)
		return [self sendAddRemoveProcessorSysex: aProc withFlag:addProcessorFlag];
	else
		return kSendSysexSuccess;
}

- (BOOL) sendRemoveProcessor:(id <MIOCProcessor>) aProc
{
	if (_useInternalMIDIProcessor == NO)
		return [self sendAddRemoveProcessorSysex: aProc withFlag:removeProcessorFlag];
	else
		return kSendSysexSuccess;
}

- (BOOL) sendAddRemoveProcessorSysex:(id <MIOCProcessor>) aProc withFlag:(Byte *)flagPtr
{
	NSData *message = [self sysexMessageForProcessor: aProc withFlag: flagPtr];	
	return [_MIDILink sendSysex:message];
}

// *********************************************
//  general method to compose sysex message
- (NSData *) sysexMessageForProcessor: (id <MIOCProcessor>) aProc withFlag:(Byte *)flagPtr
{
	NSMutableData *message = [NSMutableData dataWithCapacity:0];
	
	//preamble
	[message appendBytes:sysexStart length:sizeof(sysexStart)];	//sysex start
	[message appendBytes:MIDITEMPID length:sizeof(MIDITEMPID)]; //manufacturer-ID
	[message appendBytes:&_deviceID length:1];					//device ID (address)
	[message appendBytes:&_deviceType length:1];				//device Type
	[message appendBytes:encodedMode length:sizeof(encodedMode)];	//Mode (data are encoded)
	[message appendBytes:addRemoveProcessorOpcode length:sizeof(addRemoveProcessorOpcode)];	//opcode
	
	//encoded portion of message
	NSMutableData *toEncode = [NSMutableData dataWithCapacity:0];
	[toEncode appendBytes:flagPtr length:1];												//*add/remove flag
	NSData *processorData = [aProc MIDIBytes];										        //processor data
	[toEncode appendData:processorData];		
	NSData *encodedPortion = [self encode87: toEncode];										//encode it
	[message appendData:encodedPortion];
	
	//checksum and termination
	message = [self addChecksum:message];
	[message appendBytes:sysexEnd length:sizeof(sysexEnd)];
	
	return message;
}

// *********************************************
//  calculate the checksum
// From email from Thomas Elger, engineer of Miditemp: checksum is "Sum of all bytes 
// [e.g.] (00,20,...,01,01) = 0xD9, 2th-complement (negated value) is 0x27. 
//	0xD9 + 0x27 = 0x100 (lower 7 bits have to be 0)"
// [query in regards to: f0 00 20 0d 00 20 40 04 06 40 00 00 00 00 01 01 ?? F7

- (NSMutableData *) addChecksum:(NSMutableData *)message
{
	Byte *p, *end, checksumByte;
	unsigned checksum = 0;
	
	p = (Byte *)[message bytes];
	end = p + [message length] - 1; //***don't forget the -1 (took me 10mins to figure out why checksum was variable)
	//printf("length = %d\n", [message length]);
	p++; //skip the initial F0
	while (p<=end) {
		//printf("%x -> ", *p);
		checksum += *p++;
		//printf("%x\n", checksum);
	}
	checksum = 0x100 - checksum; //2's complement negation
	checksumByte = (Byte) (checksum & 0x7f); //msb must be zero
	[message appendBytes:&checksumByte length:1];
	//NSLog(@"\n\tmessage: %@\n\tchecksum %x @ %p (%x)", message, checksumByte, &checksumByte, checksum);
	return message;
}

// *********************************************
//    verify checksum
//		we receive an encoded message, with checksum and F7 at the end
- (BOOL) verifyChecksum:(NSData *) message
{
	Byte *p, *end, actualChecksumByte, calcChecksumByte;
	unsigned checksum = 0;
	
	p = (Byte *)[message bytes];
	end = p + [message length] - 1; //***don't forget the -1 (took me 10mins to figure out why checksum was variable)
	end = end - 2; //***don't include the actual checksum, or the ending F7
	p++; //skip the initial F0
	while (p<=end) {
		//printf("%x -> ", *p);
		checksum += *p++;
		//printf("%x\n", checksum);
	}
	checksum = 0x100 - checksum; //2's complement negation
	calcChecksumByte = (Byte) (checksum & 0x7f); //msb must be zero
	actualChecksumByte = *p;
	
	BOOL isChecksumOK = (calcChecksumByte == actualChecksumByte);
	NSAssert3( (isChecksumOK == YES), @"Checksum error: calc=%d, actual = %d, message = %@", 
			   calcChecksumByte, actualChecksumByte, message);

	return isChecksumOK;
}

// *********************************************
//  
- (NSData *) encode87:(NSData *) sourceData
{
	Byte msbByte, thisByte, encodedLength = 0;
	Byte *source, *end, *blockEnd, *sp;
	unsigned inputLength, blockIdx;
	//unsigned checksum;
	NSRange firstByte = NSMakeRange(0,1);
	
	inputLength = [sourceData length];
	source = (Byte *)[sourceData bytes];
	
	NSMutableData *encodedData = [NSMutableData dataWithCapacity:0];
	[encodedData appendBytes:&encodedLength length:1]; //placeholder for length, overwritten later
	
	end = source + inputLength - 1; //points to last byte of source
	while (source <= end) {
		blockEnd = source + 6; //grab 7 byte chunks
		if (blockEnd > end) blockEnd = end; //handle short final block
		blockIdx = 1;
		msbByte = 0;
		sp = source;
		//collect the msbits from bytes in this block
		while (sp <= blockEnd) {
			msbByte += (*sp & 0x80) >> blockIdx; //shift msb according to byte position
			sp++;
			blockIdx++;
		}
		//save msbByte and truncated data bytes
		[encodedData appendBytes:&msbByte length:1];
		//checksum += msbByte;
		while (source <= blockEnd) {
			thisByte = *source++ & 0x7F; //mask msb
			[encodedData appendBytes:&thisByte length:1];
			//checksum += thisByte;
		}
	}
	
	//fill in the length (first byte) and checksum (at end)
	encodedLength = [encodedData length] - 2; //length should be length of encoded -1, and another -1 for the length byte itself
	[encodedData replaceBytesInRange:firstByte withBytes:&encodedLength];
	//checksum += encodedLength;
	//checksumByte = (Byte) (checksum & 0x7F); //keep only lsbyte (??? BROKEN?)
	//[encodedData appendBytes:&checksumByte length:1];
	
	return [NSData dataWithData:encodedData]; //return unmutable
}

// *********************************************
//  sourceData must start w/ count of encoded bytes to decode
//  thus, it'll ignore checksum and sysexterminator which may be present
- (NSData *) decode87:(NSData *) sourceData
{
	Byte count, msbByte, thisByte;
	Byte *source, *end, *blockEnd;
	NSMutableData *decodedData = [NSMutableData dataWithCapacity:0];

	source = (Byte *)[sourceData bytes];
	count = (*source++);
		
		end = source + count;   //last byte to be decoded
								//decode blocks of 8 bytes. Final block may be shorter
								//idea, keep first byte, shift left, and w/ 0x80 and add to next
								// repeat 7 times, then get next 'first byte'
		while (source <= end) {
			msbByte = *source;
			blockEnd = source + 7;				//last byte in block
			if (blockEnd > end) blockEnd = end; //handle short final block
			while (++source <= blockEnd) {
				msbByte = msbByte << 1; 
				thisByte = *source + (msbByte & 0x80);
				[decodedData appendBytes:&thisByte length:1];
			}
		}	
	return [NSData dataWithData:decodedData];
}

// *********************************************
//  expand a message's encoded portion (if present)
//  basic format: F0 00 20 0d <ID> 20 <mode> opcode <data> f7
//  data may or may not be encoded, depending on bit 6 of mode
//		40 -> encoded, 00 -> not

- (NSData *) decodeMessage:(NSData *) sourceData
{
	MIOCMessage *message;
	size_t	dataLength;
	NSRange dataRange, preambleRange;
	message = (MIOCMessage *) [sourceData bytes]; //***consider removing the initial F0
	//check if data are encoded
	if (message->mode & kModeEncodedMask)
	{
		BOOL isChecksumOK = [self verifyChecksum:sourceData];
		if (isChecksumOK == YES) {
			dataLength = [sourceData length] - kPreambleLength;
			dataRange.location = kPreambleLength;
			dataRange.length = dataLength;
			NSData *encodedData = [sourceData subdataWithRange:dataRange];
			NSData *decodedData = [self decode87:encodedData];
			preambleRange.location = 0;
			preambleRange.length =  kPreambleLength;
			NSData *preambleData = [sourceData subdataWithRange:preambleRange];
			//reassemble
			NSMutableData *temp = [NSMutableData dataWithData:preambleData];
			[temp appendData:decodedData];
			sourceData = [NSData dataWithData:temp];
		} else {
			NSLog(@"Bad checksum!");
			sourceData = nil;
		}
	}
	return sourceData;
}

@end
