#import "MIOCModel.h"

#import "MIOCProcessorProtocol.h"
#import "MIOCConnection.h"
#import "MIOCVelocityProcessor.h"
#import "MIDIIO.h"
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
	
	return self;
}

- (void) dealloc
{
	[_connectionList release];
	[_velocityProcessorList release];
	[_MIDILink release]; //removes listeners too
	[super dealloc];
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
		if ([self sendConnectSysex:aConnection] == kSendSysexSuccess) 
			[_connectionList addObject:aConnection];
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
		if ([self sendDisconnectSysex:aConnection] == kSendSysexSuccess) 
			[_connectionList removeObject:aConnection];
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
//  disconnect all entries in _connectionList
- (void) disconnectAll
{
	MIOCConnection *conn;
	NSEnumerator *enumerator = [_connectionList objectEnumerator];
	while (conn = [enumerator nextObject]) {
		[self disconnectOne: conn];
	}		
	//sanity--
	NSAssert( ([_connectionList count] == 0), @"Non-empty connectionList after disconnectAll");
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
		if ([self sendAddVelocityProcessorSysex:aVelProc] == kSendSysexSuccess) 
			[_velocityProcessorList addObject:aVelProc];
	} else
		NSLog(@"Attempt was made to add velocity processor (%@) multiple times.", aVelProc);	
}

- (void) removeVelocityProcessor:(MIOCVelocityProcessor *) aVelProc
{
	
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
//     UNUSED
- (void)receiveSysexData:(NSData *)data
{
	//NSString *hexStr = [[NSString alloc] initHexStringWithData:data];
	//NSLog(@"MIOCModel Received Sysex (%d bytes): %@\n",[data length], hexStr);
	//add logic here to parse info messages and fill in instance values
	//also potentially to verify connections made
}

// *********************************************
//    MIOC CONNECTION -> MIDI BRIDGE INTERNAL
// *********************************************
#pragma mark MIOC -> MIDI MESSAGING

// *********************************************
//  
- (BOOL) sendConnectSysex:(MIOCConnection *) aConnection
{	
	return [self sendConnectDisconnectSysex: aConnection withFlag:addProcessorFlag];
}

- (BOOL) sendDisconnectSysex:(MIOCConnection *) aConnection
{
	return [self sendConnectDisconnectSysex: aConnection withFlag:removeProcessorFlag];
}

// *********************************************
//  common method for connecting/disconnecting
- (BOOL) sendConnectDisconnectSysex: (MIOCConnection *) aConnection withFlag:(Byte *)flagPtr
{
	
	NSData *message = [self sysexMessageForProcessor: aConnection withFlag: flagPtr];
	//unsigned i = [message retainCount];
	//printf("before sendSysex, message: %x (%d B) retain %d\n",(unsigned) message, [message length], i);
	
	[_MIDILink sendSysex:message];
	
	//i = [message retainCount];
	//printf("after sendSysex, message: %x %d\n",(unsigned) message, i);
	//for now, assume all sysex sends complete correctly--how could we know otherwise?
	return kSendSysexSuccess;
}

// *********************************************
//  compose, encode and send sysex to make a connecion in MIOC
- (NSData *) sysexMessageForConnection: (MIOCConnection *) aConnection withFlag:(Byte *)flagPtr
{
	NSMutableData *message = [NSMutableData dataWithCapacity:0];
	[message appendBytes:sysexStart length:sizeof(sysexStart)];	//sysex start
	[message appendBytes:MIDITEMPID length:sizeof(MIDITEMPID)]; //manufacturer-ID
	[message appendBytes:&_deviceID length:1];					//device ID (address)
	[message appendBytes:&_deviceType length:1];				//device Type
	[message appendBytes:encodedMode length:sizeof(encodedMode)];	//Mode (data are encoded)
	[message appendBytes:addRemoveProcessorOpcode length:sizeof(addRemoveProcessorOpcode)];	//opcode
																							//encoded portion
	NSMutableData *toEncode = [NSMutableData dataWithCapacity:0];
	[toEncode appendBytes:flagPtr length:1];												//*add/remove flag
	NSData *connectionData = [aConnection MIDIBytes];										//processor data
	[toEncode appendData:connectionData];		
	NSData *encodedPortion = [self encode87: toEncode];										//encode it
	[message appendData:encodedPortion];
	message = [self addChecksum:message];
	[message appendBytes:sysexEnd length:sizeof(sysexEnd)];
	
	return message;
}


- (BOOL) sendAddVelocityProcessorSysex:(MIOCVelocityProcessor *) aVelProc
{
	return [self sendAddRemoveVelocityProcessorSysex: aVelProc withFlag:addProcessorFlag];
}

- (BOOL) sendRemoveVelocityProcessorSysex:(MIOCVelocityProcessor *) aVelProc
{
	return [self sendAddRemoveVelocityProcessorSysex: aVelProc withFlag:removeProcessorFlag];
}

- (BOOL) sendAddRemoveVelocityProcessorSysex:(MIOCVelocityProcessor *) aVelProc withFlag:(Byte *)flagPtr
{
	NSData *message = [self sysexMessageForProcessor: aVelProc withFlag: flagPtr];	
	[_MIDILink sendSysex:message];
	return kSendSysexSuccess;
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
			sourceData = nil;
		}
	}
	return sourceData;
}

@end
