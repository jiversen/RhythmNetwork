#import "MIDIIO.h"

#import <CoreMIDI/MIDIServices.h>
#import <CoreAudio/HostTime.h>
#include <assert.h>
#import "NSStringHexStringCategory.h"
#import "RNArchitectureDefines.h"

#define kDelayPacketListLength 8192 //big enough for ~500 events

// wrapper for simple midi io

// Forward definitions of callbacks
static void myReadProc(const MIDIPacketList *pktlist, void *refCon, void *connRefCon);
static void mySysexCompletionProc(MIDISysexSendRequest *request);
static void myMIDINotifyProc(const MIDINotification *message, void * refCon);

#pragma mark CoreMIDI Error Handling
// Error Handling (CGPT)
#define CHECK_OSSTATUS_OR_BAIL(s, msg) do { \
	if ((s) != noErr) { \
		NSLog(@"%s failed: %@ (%d)", msg, (NSString *)CMIDIErrorDescription(s), (int)(s)); \
		goto bail; \
	} \
} while (0)

#define CHECK_OSSTATUS(s, msg) do { \
if ((s) != noErr) { \
	   NSLog(@"%s failed: %@ (%d)", msg, (NSString *)CMIDIErrorDescription(s), (int)(s)); \
   } \
} while (0)

static NSString *CMIDIErrorDescription(OSStatus status) {
	switch (status) {
		case kMIDIInvalidClient: return @"Invalid MIDI client";
		case kMIDIInvalidPort: return @"Invalid MIDI port";
		case kMIDIWrongEndpointType: return @"Wrong endpoint type";
		case kMIDINoConnection: return @"No connection";
		case kMIDIUnknownEndpoint: return @"Unknown endpoint";
		case kMIDIUnknownProperty: return @"Unknown property";
		case kMIDIWrongPropertyType: return @"Wrong property type";
		case kMIDINoCurrentSetup: return @"No current setup";
		case kMIDIMessageSendErr: return @"Error sending message";
		case kMIDIServerStartErr: return @"Could not start MIDI server";
		case kMIDISetupFormatErr: return @"Bad setup format";
		case kMIDIWrongThread: return @"Wrong thread";
		case kMIDIObjectNotFound: return @"Object not found";
		case kMIDIIDNotUnique: return @"ID not unique";
		default: return [NSString stringWithFormat:@"Unknown error (%d)", (int)status];
	}
}

@implementation MIDIIO

// *********************************************
//    INITIALIZATION
// *********************************************
#pragma mark INIT

- (MIDIIO *)init
{
	self                = [super init];
	_MIDIClient         = kMIDIInvalidRef;
	_inPort             = kMIDIInvalidRef;
	_outPort            = kMIDIInvalidRef;
	_MIDISource         = kMIDIInvalidRef;
	_MIDIDest           = kMIDIInvalidRef;
	_sysexListenerArray = [[NSMutableArray arrayWithCapacity:0] retain];
	_MIDIListenerArray  = [[NSMutableArray arrayWithCapacity:0] retain];


	_sysexData        = [[NSMutableData alloc] initWithCapacity:16 * 1024];
	_isReceivingSysex = NO;

	// setup sidecar MIDIIO for sending delayed messages
	if (MIDIGetNumberOfDestinations() >= 2) {
		_delayMIDIIO = [[MIDIIO alloc] initFollower];

		// pre-allocate MIDIPacketList
		_delayPacketList = malloc(kDelayPacketListLength);
	} else {
		NSLog(@"Warning: Only one MIDI output available. Delayed output functionality will be disabled.");
		_delayMIDIIO = nil;
	}

	_isLeader = YES;

	[self setupMIDI];
	
	[self startMIDIProcessingThread];


	return self;
}

// *********************************************
// Simplified init for follower MIDIIO
- (MIDIIO *)initFollower
{
	self        = [super init];
	_MIDIClient = kMIDIInvalidRef; //
	_inPort     = kMIDIInvalidRef;
	_outPort    = kMIDIInvalidRef;
	_MIDISource = kMIDIInvalidRef;
	_MIDIDest   = kMIDIInvalidRef;
	_isLeader   = NO;
	// remaining ivars are initialized to null by default

	return self;
}

// *********************************************
- (void)dealloc
{
	MIDIClientDispose(_MIDIClient);	// automatically disposes of ports
	[_sysexListenerArray release];
	[_MIDIListenerArray  release];
	[_sysexData release];
	[_delayMIDIIO release];
	[super dealloc];
}

// *********************************************
//Setup a midi client, create its input and output ports, connect ports to outside world
- (void)setupMIDI
{
	OSStatus status;
	
	atomic_init(&_MIDIConsumerReady, false);
	NSAssert(TPCircularBufferInit(&_packetBuffer, 4096*8),@"Unable to init TPCircularBuffer");
	_dataAvailableSemaphore = dispatch_semaphore_create(0);
    
	// set up main MIDI
    //create this client
    status = MIDIClientCreate(CFSTR("MIDIIO"), myMIDINotifyProc, (void*)self, &_MIDIClient);
	CHECK_OSSTATUS_OR_BAIL(status, "MIDIClientCreate");

	//create an input port
    status = MIDIInputPortCreate(_MIDIClient, CFSTR("MIDIIO Input Port"), myReadProc, (void*)self, &_inPort);
	CHECK_OSSTATUS_OR_BAIL(status, "MIDIInputPortCreate");

	//create an output port
	status = MIDIOutputPortCreate(_MIDIClient, CFSTR("MIDIIO Output Port"), &_outPort);
	CHECK_OSSTATUS_OR_BAIL(status, "MIDIOutputPortCreate");
	
	// setup a secondary (follower) transmit-only client on the next port from the leader client.
	// this totally requires that the MIDI interface has at least two ports, which we checked in init
	if (_isLeader && _delayMIDIIO) {
		status = MIDIClientCreate(CFSTR("MIDIIO_Delay"), NULL, (void*)self, &_delayMIDIIO->_MIDIClient); //config notifications will come from leader MIDIIO
		CHECK_OSSTATUS_OR_BAIL(status, "MIDIClientCreate_Follower");
		
		//delay MIDI doesn't have an input port
		_delayMIDIIO->_inPort = kMIDIInvalidRef;
		
		//create an output port
		status = MIDIOutputPortCreate(_MIDIClient, CFSTR("MIDIIO_Delay Output Port"), &_delayMIDIIO->_outPort);
		CHECK_OSSTATUS_OR_BAIL(status, "MIDIOutputPortCreate_Follower");
	}
	
	//set source and destination (take user default, otherwise first--after initial entry, which will be "(not connected)")
	NSArray *sourceList = [self getSourceList];
	//try to use default
	if ([self useSourceNamed:[self defaultSourceName]] == NO) {
		//set to no connection
		[self useSourceNamed:sourceList[0]]; //during init, list will always have (not connected) as first
	}
	
	NSArray *destinationList = [self getDestinationList];
	if ([self useDestinationNamed:[self defaultDestinationName]] == NO) { //this will update _delayMIDIIO as well
		//set to no connection
		[self useDestinationNamed:destinationList[0]];
	}
	
	_isRunning = TRUE;
	return;
	
	// Required by CHECK_OSSTATUS_OR_BAIL
bail:
	_isRunning = FALSE;
	NSLog(@"MIDI Setup Failed");
	
}

// add MIDIRouting table. default null value means 'no routing'
- (void)setMIDIRoutingTable:(RNRealtimeRoutingTable *)routingTable {
	_routingTable = routingTable;
}


// *********************************************
// create high-priority processing thread for MIDI packetlist
- (void) startMIDIProcessingThread {
	
	_processingQueue 	= dispatch_queue_create("org.johniversen.midiProcessing", DISPATCH_QUEUE_CONCURRENT);
	dispatch_set_target_queue(_processingQueue, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0));
	
	_listenerQueue = dispatch_queue_create("org.johniversen.listenerQueue", DISPATCH_QUEUE_CONCURRENT);
	dispatch_set_target_queue(_listenerQueue, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
	
	dispatch_async(_processingQueue, ^{
		atomic_store(&_MIDIConsumerReady, true); // signal to readproc that we're ready to consume
		while (_isRunning) {
			// Wait until signaled - blocks efficiently with no polling
			dispatch_semaphore_wait(_dataAvailableSemaphore, DISPATCH_TIME_FOREVER);
			
			// Get data from the circular buffer
			uint32_t availableBytes;
			void* packetList = TPCircularBufferTail(&_packetBuffer, &availableBytes);
			
			//process packet list for delayed notes
			[self emitDelayedNotes:(const MIDIPacketList*)packetList availableBytes:availableBytes];

			//process packet list for listeners
			[self handleMIDIPktlist:(const MIDIPacketList*)packetList availableBytes:availableBytes];
			
			//mark bytes as consumed
			TPCircularBufferConsume(&_packetBuffer, availableBytes);

		} // while _isRunning
	});
}

// *********************************************
//    external readProc support
// *********************************************
#pragma mark external readProc support

- (MIDIReadProc)defaultReadProc
{
	return myReadProc;
}

- (void)setDefaultReadProc
{
	[self setReadProc:[self defaultReadProc] refCon:self];
}

// :jri:20050913 Something new to try--add an external readproc
- (void)setReadProc:(MIDIReadProc)newReadProc refCon:(void *)refCon
{
	NSAssert( (_inPort != kMIDIInvalidRef), @"an InputPort should already exist");
	
	OSStatus status;
	status = MIDIPortDispose(_inPort);
	NSAssert( (status == noErr), @"problem disposing old input port");
	_inPort = kMIDIInvalidRef;
	
	status = MIDIInputPortCreate(_MIDIClient, CFSTR("MIDIIO Input Port"), newReadProc, (void*)refCon, &_inPort);
}

// *********************************************
//    things an external readProc will need to know to re-transmit MIDI

- (MIDIPortRef)outPort {
	return _outPort;
}

- (MIDIEndpointRef)MIDIDest {
	return _MIDIDest;
}

// *********************************************
//    source/destination management
// *********************************************
#pragma mark source/destination management

- (NSArray *)getSourceList
{
	NSUInteger		n, i;
	CFStringRef		name;
	NSMutableArray	*list		= [NSMutableArray arrayWithCapacity:0];
	NSMutableString 	*uniqueName = [NSMutableString stringWithCapacity:10];
	
	if (_MIDISource == kMIDIInvalidRef)
		[list addObject:@"(not connected)"]; //add a placeholder if we're not connected

	n = MIDIGetNumberOfSources();

	for (i = 0; i < n; i++) {
		MIDIEndpointRef src = MIDIGetSource(i);
		MIDIObjectGetStringProperty(src, kMIDIPropertyName, &name);
		[uniqueName setString:(NSString *)name];

		while ([list containsObject:uniqueName]) {
			char tag = 'A';
			[uniqueName setString:(NSString *)name];
			[uniqueName appendFormat:@"-%c", tag++];
		}

		[list addObject:[uniqueName copy]];
		CFRelease(name);
	}

	if ([list count] == 0) {
		[list addObject:@"(not connected)"];
	}

	return [NSArray arrayWithArray:list];	// returns immutable version
}

// *********************************************
- (NSArray *)getDestinationList
{
	NSUInteger 		n,i;
	CFStringRef 		name;
	NSMutableArray 	*list = [NSMutableArray arrayWithCapacity:0];
	
	if (_MIDIDest == kMIDIInvalidRef)
		[list addObject:@"(not connected)"];
	
	n = MIDIGetNumberOfDestinations();
	
	for (i = 0; i < n; i++) {
		MIDIEndpointRef dest = MIDIGetDestination(i);
		MIDIObjectGetStringProperty(dest, kMIDIPropertyName, &name);
		[list addObject:(NSString *)name];
		CFRelease(name);
	}
	
	if ([list count] == 0) {
		[list addObject:@"(not connected)"];
	}

return [NSArray arrayWithArray:list];	// returns immutable version
}

// *********************************************
- (BOOL)useSourceNamed:(NSString *)sourceName
{
	OSStatus	status;
    NSUInteger n,i;
	CFStringRef name;
	BOOL		didConnect = FALSE;
	
	NSAssert(self != _delayMIDIIO, @"useSourceNamed: should not be called on _delayMIDIIO directly!");

	// iterate thru sources, finding first match to sourceName
	n = MIDIGetNumberOfSources();

	for (i = 0; i < n; i++) {
		MIDIEndpointRef src = MIDIGetSource(i);
		MIDIObjectGetStringProperty(src, kMIDIPropertyName, &name);
		
		if ([sourceName isEqualToString:(NSString *)name]) {
			if (_MIDISource != kMIDIInvalidRef)
				MIDIPortDisconnectSource(_inPort,_MIDISource);
			_MIDISource = src;
			status		= MIDIPortConnectSource(_inPort, _MIDISource, (void *)i);
			if (status == noErr) {
				NSLog(@"connecting to source %@", sourceName);
				didConnect = TRUE;
				if (_isLeader) {
					[self setDefaultSourceName:sourceName]; // only update default for the leader
				}
			} else {
				didConnect = FALSE;
			}
		}
		CFRelease(name);
	}

	// didn't find it, don't connect to anything
	if (!didConnect) {
		NSLog(@"Could not connect: source %@ does not exist", sourceName);
		_MIDISource = kMIDIInvalidRef;
	}

	return didConnect;
}

// *********************************************
- (BOOL)useDestinationNamed:(NSString *)destinationName
{
	CFStringRef name;
	BOOL		didConnect = FALSE;
	
	NSAssert(self != _delayMIDIIO, @"useDestinationNamed: should not be called on _delayMIDIIO directly!");

	// iterate thru sources, finding first match to sourceName
	ItemCount n = MIDIGetNumberOfDestinations();

	for (int i = 0; i < n; i++) {
		MIDIEndpointRef dest = MIDIGetDestination(i);
		MIDIObjectGetStringProperty(dest, kMIDIPropertyName, &name);

		if ([destinationName isEqualToString:(NSString *)name]) {
			_MIDIDest = dest;
			NSLog(@"connecting to destination %@", destinationName);
			didConnect = TRUE;
            if (_isLeader) {
                [self setDefaultDestinationName:destinationName];
            }
		}
		CFRelease(name);
	}

	if (!didConnect) {
		NSLog(@"Could not connect: destination %@ does not exist", destinationName);
		_MIDIDest = kMIDIInvalidRef;
		if (_delayMIDIIO) {
			_delayMIDIIO->_MIDIDest = kMIDIInvalidRef;
		}
		return NO;
	}
	
	// now update follower, output only
	if (_isLeader && _delayMIDIIO) {
		if ([self destinationIsConnected]) {
			[_delayMIDIIO useDestinationNamed:NextPortName([self destinationName])];
		}
	}
	
	//publish our new destination (only MIDICore listens...what is this for?)
	if (_isLeader) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MIDIIO_newDestinationNotification" object:self];
    }
    
	return YES;
}

// *********************************************
- (NSString *)sourceName
{
	CFStringRef name;
	if (_MIDISource != kMIDIInvalidRef) {
		MIDIObjectGetStringProperty(_MIDISource, kMIDIPropertyName, &name);
		return [NSString stringWithString:(NSString *)name];
	} else {
		return @"(not connected)";
	}
}

- (NSString *)destinationName
{
	CFStringRef name;
	if (_MIDIDest != kMIDIInvalidRef) {
		MIDIObjectGetStringProperty(_MIDIDest, kMIDIPropertyName, &name);
		return [NSString stringWithString:(NSString *)name];
	} else {
		return @"(not connected)";
	}
}

// *********************************************
// simple queries of connection state
- (BOOL)sourceIsConnected
{
	return (_MIDISource != kMIDIInvalidRef);
}

- (BOOL)destinationIsConnected
{
	return (_MIDIDest != kMIDIInvalidRef);
}

// *********************************************
// user defaults
// if no default, return empty string, otherwise return last stored default
- (NSString *)defaultSourceName
{
	NSString *defaultName = [[NSUserDefaults standardUserDefaults] stringForKey:@"MIDIIO_defaultSourceName"];

	if (defaultName == nil) {
		defaultName = [NSString string];
	}

	return defaultName;
}

- (NSString *)defaultDestinationName
{
	NSString *defaultName = [[NSUserDefaults standardUserDefaults] stringForKey:@"MIDIIO_defaultDestinationName"];

	if (defaultName == nil) {
		defaultName = [NSString string];
	}

	return defaultName;
}

- (void)setDefaultSourceName:(NSString *)sourceName
{
	[[NSUserDefaults standardUserDefaults] setObject:sourceName forKey:@"MIDIIO_defaultSourceName"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setDefaultDestinationName:(NSString *)destinationName
{
	[[NSUserDefaults standardUserDefaults] setObject:destinationName forKey:@"MIDIIO_defaultDestinationName"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

// *********************************************
// function to find the next port name in sequence for use with follower MIDIIO
NSString *NextPortName(NSString *currentPortName) {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^(.*?)(\\d+|[A-Za-z])$" options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:currentPortName options:0 range:NSMakeRange(0, currentPortName.length)];
    
    NSCAssert(match != nil && match.numberOfRanges == 3, @"NextPortName: Unrecognized format %@", currentPortName);
    
    NSString *prefix = [currentPortName substringWithRange:[match rangeAtIndex:1]];
    NSString *suffix = [currentPortName substringWithRange:[match rangeAtIndex:2]];
    
    unichar c = [suffix characterAtIndex:0];
    
    // Handle numeric suffix
    if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:c]) {
        NSInteger number = [suffix integerValue];
        return [NSString stringWithFormat:@"%@%ld", prefix, (long)(number + 1)];
    }
    
    // Handle alphabetic suffix
    if ((c >= 'A' && c < 'Z') || (c >= 'a' && c < 'z')) {
        return [NSString stringWithFormat:@"%@%c", prefix, c + 1];
    }

	//fallthrough
    NSCAssert(NO, @"NextPortName: Unable to increment suffix %@", suffix);
    return nil;
}

// *********************************************
//  Handle changes in the midi setup--
//		this executes on our main thread, but still follows pattern of calling object method to handle things
//
static void myMIDINotifyProc(const MIDINotification *message, void *refCon)
{
	MIDIIO *me = (MIDIIO *)refCon;

	switch (message->messageID) {
		case kMIDIMsgSetupChanged:
			[me handleMIDISetupChange];
			break;
	}
}

// *********************************************
- (void)handleMIDISetupChange
{
	BOOL	found = FALSE;
	
	//if we're still unconnected, check if default has appeared
	if (_MIDISource == kMIDIInvalidRef) {
		[self useSourceNamed:[self defaultSourceName]]; //if this fails, source still = NULL
	} else {
		// is our current source still in the list?
		// if not, clear our _MIDISource
		ItemCount n = MIDIGetNumberOfSources();

		for (int i = 0; i < n; i++) {
			MIDIEndpointRef src = MIDIGetSource(i);

			if (_MIDISource == src) {
				found = TRUE;
			}
		}
		if (!found)
			_MIDISource = kMIDIInvalidRef;
	}

			
	if (_MIDIDest == kMIDIInvalidRef) {
		[self useDestinationNamed:[self defaultDestinationName]]; //if this fails, dest = NULL
	} else {
		ItemCount n = MIDIGetNumberOfDestinations();

		for (int i = 0; i < n; i++) {
			MIDIEndpointRef dest = MIDIGetDestination(i);

			if (_MIDIDest == dest) {
				found = TRUE;
			}
		}
		if (!found)
            _MIDIDest = kMIDIInvalidRef;
	}
	
	// now update follower, output only
	if (_isLeader && _delayMIDIIO) {
		if ([self destinationIsConnected]) {
			[_delayMIDIIO useDestinationNamed:NextPortName([self destinationName])];
		}
	}

	// once we're sorted out, let everyone else know
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MIDIIOSetupChangeNotification"
	object:self];
}

// *********************************************
//    RECEIVING MIDI
// *********************************************
#pragma mark RECEIVING

// quickly copy packet list to lockless ring buffer and raise semaphore for processing thread
static void myReadProc(const MIDIPacketList *pktlist, void *refCon, void *connRefCon)
{
		
	MIDIIO *selfMIDIIO = (MIDIIO *)refCon;
	
	if (!atomic_load(&selfMIDIIO->_MIDIConsumerReady)) return; // short out if our listening thread is not up yet

	// packet list
	MIDIPacket *packet = (MIDIPacket *)&pktlist->packet[0];
	
	// find total length of packet list
	for (int i = 0; i < pktlist->numPackets; i++) {
		packet = MIDIPacketNext(packet);
	}
	long pktlistLength = (Byte *)packet - (Byte *)pktlist;
	
	// copy entire packetlist to ring buffer
	bool status = TPCircularBufferProduceBytes(&selfMIDIIO->_packetBuffer, pktlist, (uint32_t) pktlistLength);
	
	assert(status && "Buffer overrun in MIDI readProc--consider increasing buffer size.");
	
	if (!status) {
		return;
	}
	
	// signal processing thread that data are available
	dispatch_semaphore_signal(selfMIDIIO->_dataAvailableSemaphore);
}

// These next two methods are called from the high-priority processing thread. Both walk the packetList(s) & packets with two aims: 1) to output delay packets and 2) to send sysex and note on to listeners, which handle configuration, data saving, and UI
// Not sure there is any way around walking through entire sysex streams because it may be spread across packets and not sure there is a test for a packet being sysex based on its first byte...In our use, sysex receiving is very rare, never during critical path, and short so it is really not any kind of issue

// *********************************************
// quickly send out delayed midi [runs from high-priority processing thread]
- (void)emitDelayedNotes:(const MIDIPacketList*)startList availableBytes:(uint32_t)availableBytes {
	
	if (_routingTable == nil) { // with no routing table, this is a NOP!
		return;
	}
	
	
	//  note, must handle case that multiple packet lists are available; create some vars to help us conceptualize
	const Byte *bufferPtr = (const Byte *)startList;
	const Byte *bufferEnd = bufferPtr + availableBytes;
	int nPacketList = 0;
	
	while (bufferPtr < bufferEnd) {
		
		const MIDIPacketList *pktlist = (const MIDIPacketList *) bufferPtr; //start of packet list
		const MIDIPacket *packet = &pktlist->packet[0]; //first packet in list
		// find total length of (first) packet list
		for (int i = 0; i < pktlist->numPackets; i++) {
			packet = MIDIPacketNext(packet);
		}
		//packet now points to byte beyond the packetlist
		NSAssert((Byte *)packet <= bufferEnd+1, @"MIDIPacketList has overrun input buffer.");
		size_t pktlistLength = (const Byte *)packet - (Byte *)pktlist;
		
		// Safety check: is packetList contained within availableBytes?
		if (bufferPtr + pktlistLength > bufferEnd) {
			NSLog(@"Incomplete MIDIPacketList in input buffer. Skipping.");
			break;
		}
		
		//grab the routing and delay matrices (we'll maintain it constant across each packet list
		NodeMatrix *weightMatrix = atomic_load(&_routingTable->weightMatrix);
		NodeMatrix *delayMatrix = atomic_load(&_routingTable->delayMatrix);
		
		//prolly makes sense to iterate through all the notes and do a single packet list rather than a smaller packet list for each note--figure out the max possible notes in it: (someday) 12 tappers * 11 delay outputs = 132 note on events (worst case if everyone taps at same time and have an all-all network. In general N*(N-1), so now, for 6, 30
		
		// initialize the output packetList
		MIDIPacket *curPkt = MIDIPacketListInit(_delayPacketList);
		
		MIDITimeStamp earliestTimestamp = UINT64_MAX;
		
		// walk through packets, handling note on
		packet = &pktlist->packet[0];
		MIDITimeStamp packetTimeStamp = packet->timeStamp;
		for (int i = 0; i < pktlist->numPackets; i++) {
			const Byte *bp			= packet->data;
			const Byte *packetEnd	= bp + packet->length;
			
			while (bp < packetEnd) {
				
				const Byte status = *bp++;
				
				// handle sysex (and ignore)
				if (status == 0xF0) {		// Sysex start
					_isReceivingSysex = YES;
					continue;
				}
				if (_isReceivingSysex) {	// Sysex continuation
					if (status == 0xF7) {	// Sysex end
						_isReceivingSysex = NO;
						continue;
					}
				}

				if ((status & 0xF0) == 0x90) {
					NSAssert(bp + 1 < packetEnd, @"Problem: partial note-on message in packet. Shouldn't happen");
					
					Byte	note		= *bp++;
					Byte	velocity	= *bp++;
					
					// DELAY PROCESSING
					// Quickly scan for note on and re-emit any delayed messages to other channels/notes
					
					// NB: check if target timestamp is _past_ now, in which case we're not able to meet the target and say by how far off
					// Special case if delay is 0 pass 0 as timestamp (not input timestamp) as that means 'send as soon as possible' since there is no actual way to send with 0 delay.
					// TODO: implement velocity weithging
					if (velocity > 0) {	// only note on
						Byte channel		= (status & 0x0F) + 1; // we use 1-based counting
						//loop over potential destinations
						float wt;
						for (int to=1; to<=kMaxNodes; to++) {
							if ((wt = (*weightMatrix)[channel][to])) {
								float delay_ms = (*delayMatrix)[channel][to];
								
								MIDITimeStamp delayTimeStamp = 0;
								if (delay_ms > 0.0) {
									delayTimeStamp = packetTimeStamp + AudioConvertNanosToHostTime(delay_ms * 1000.0);
									earliestTimestamp = MIN(earliestTimestamp, delayTimeStamp); //Keep track of earliest event so we can test for overrun when we send.
								}
								_onMessage[0] = 0x90 + (to - 1); //NB convert to MIDI 0-based index
								_onMessage[1] = note;
								_onMessage[2] = velocity;
								
								curPkt =  MIDIPacketListAdd(_delayPacketList,kDelayPacketListLength,curPkt,delayTimeStamp,3,_onMessage);
								
								if (kDoEmitNoteOff) {
									_offMessage[0] = _onMessage[0];
									_offMessage[1] = _onMessage[1];
									_offMessage[2] = 0;
									MIDITimeStamp offTimeStamp = delayTimeStamp + AudioConvertNanosToHostTime(kNoteOffDelay_ms * 1000.0);
									curPkt =  MIDIPacketListAdd(_delayPacketList,kDelayPacketListLength,curPkt,offTimeStamp,3,_offMessage);
								}
								
								NSAssert((curPkt != NULL), @"Packet List Overflow [%d -> %d]",channel,to);
							}
						}
					}
				}
			}	// loop over packet contents
			
			packet = MIDIPacketNext(packet); // next packet in input list
		}	// loop over packets
		
		UInt64 now = AudioGetCurrentHostTime();
		
		// PROBLEM: earliest target timestamp is _past_ now--we took too long to schedule them
		if (now > earliestTimestamp){
			NSLog(@"emitDelayedNotes: overrun, delay time of earliest event (%lld) has passed (%lld ns over)", AudioConvertHostTimeToNanos(earliestTimestamp), AudioConvertHostTimeToNanos(now - earliestTimestamp));
		}
		// send our delayPacketList to Core MIDI
		UInt64 pre = AudioGetCurrentHostTime();
		OSStatus status = MIDISend(_outPort, _MIDIDest, pktlist);
		UInt64 post = AudioGetCurrentHostTime();
		NSLog(@"MIDISend time ~ %lld (+/- %lld) ns", (pre+post)/2, (post-pre)/2);

		CHECK_OSSTATUS(status, "MIDISend delay packet list");
		
		nPacketList++;
		bufferPtr += pktlistLength;
	}
	NSLog(@"handleMIDIPktlist handled %d MIDIPacketLists with %ld bytes left over.", nPacketList, bufferEnd-bufferPtr);
}

// *********************************************
// send midi to listeners [runs from high-priority processing thread]
- (void)handleMIDIPktlist:(const MIDIPacketList *)pktlist availableBytes:(uint32_t)availableBytes
{
	
	//  note, must handle case that multiple packet lists are available; create some vars to help us conceptualize
	const Byte *bufferPtr = (const Byte *)pktlist;
	const Byte *bufferEnd = bufferPtr + availableBytes;
	int nPacketList = 0;
	
	while (bufferPtr < bufferEnd) {
		
		pktlist = (const MIDIPacketList *) bufferPtr;
		// find total length of (first) packet list
		const MIDIPacket *packet = (MIDIPacket *)&pktlist->packet[0]; //first packet in list
		for (int i = 0; i < pktlist->numPackets; i++) {
			packet = MIDIPacketNext(packet);
		}
		//packet now points to byte beyond the packetlist
		NSAssert((Byte *)packet <= bufferEnd+1, @"MIDIPacketList has overrun input buffer.");
		size_t pktlistLength = (Byte *)packet - (Byte *)pktlist;
		
		// Safety check: is packetList contained within availableBytes?
		if (bufferPtr + pktlistLength > bufferEnd) {
			NSLog(@"Incomplete MIDIPacketList in input buffer. Skipping.");
			break;
		}
		
		// Second, thoroughly parse midi packets in list--keeping it simple for now, and only doing what we need
		packet = (MIDIPacket *)&pktlist->packet[0];
		for (int i = 0; i < pktlist->numPackets; i++) {
			const Byte *bp			= packet->data;
			const Byte *packetEnd	= bp + packet->length;	// could include single-byte realtime, so copy one byte at a time
			
			while (bp < packetEnd) {
				const Byte byte = *bp++;
				
				if (byte == 0xF0) {		// Sysex start
					_isReceivingSysex = YES;
					[_sysexData setLength:0];
					[_sysexData appendBytes:&byte length:1];
				} else if (_isReceivingSysex) {	// Sysex continuation
					if (byte < 0xF8) { // ignore realtime messages embedded in sysex
						[_sysexData appendBytes:&byte length:1];
					}
					
					if (byte == 0xF7) {	// Sysex end
						if (bp != packetEnd) {
							NSLog(@"Interesting: %ld bytes following end of sysex message in packet.", packetEnd - bp);
						}
						
						NSString *hexStr = [[NSString alloc] initHexStringWithData:_sysexData];
						NSLog(@"MIDIIO Received Sysex (%lu bytes): %@\n", (unsigned long)[_sysexData length], hexStr);
						
						for (id listener in _sysexListenerArray) {
							dispatch_async(_listenerQueue, ^{
								NSData *listenerCopy = [_sysexData copy];
								[listener receiveSysexData:_sysexData];
								[listenerCopy release];
							});
						}
						_isReceivingSysex = NO;
					}
				} else {// non sysex
					// note-on (all we care about in RhythmNetwork, so this is hardly general purpose)
					// we create our own structure, one step abstracted from raw MIDI, and with time in real units
					if ((byte & 0xF0) == 0x90) {
						NSAssert(bp + 1 < packetEnd, @"Problem: partial note-on message in packet. Shouldn't happen");
						Byte channel		= (byte & 0x0F) + 1; // we use 1-based counting
						Byte	note		= *bp++;
						Byte	velocity	= *bp++;
						
						if (velocity > 0) {	// only note on
						
							NoteOnMessage thisMessage;
							thisMessage.eventTime_ns	= AudioConvertHostTimeToNanos(packet->timeStamp);
							thisMessage.channel		= channel;
							thisMessage.note			= note;
							thisMessage.velocity		= velocity;
							
							NSData *MIDIData = [NSData dataWithBytes:&thisMessage length:sizeof(NoteOnMessage)];
							for (id listener in _MIDIListenerArray) {
								dispatch_async(_listenerQueue, ^{
									[listener receiveMIDIData:MIDIData];
								});
							}
						}
					} else {
						NSLog(@"Received non note-on event! %x %x %x", packet->data[0], packet->data[1], packet->data[2]);
					}
				}
			}	// loop over packet contents
			
			packet = MIDIPacketNext(packet);
		}	// loop over packets
		nPacketList++;
		bufferPtr += pktlistLength;
	}
	NSLog(@"handleMIDIPktlist handled %d MIDIPacketLists with %ld bytes left over.", nPacketList, bufferEnd-bufferPtr);

}

// *********************************************
//     PUBLIC METHODS
// *********************************************

#pragma mark  managing listeners

// *********************************************
//
// add object to list of objects to send sysex data to
//	ensure it responds to appropriate selector and is not already in list
- (void)registerSysexListener:(id<SysexDataReceiver>)object
{
	NSAssert([object conformsToProtocol:@protocol(SysexDataReceiver)],
			 @"Cannot register %@ as Sysex Listener. (Does not conform to <SysexDataReceiver>)", object);
	
	NSAssert(![_sysexListenerArray containsObject:object],
			 @"Trying to add Sysex Listener object %@ again!", object);
	
	[_sysexListenerArray addObject:object];	// this retains object
}

- (void)removeSysexListener:(id<SysexDataReceiver>)object {
	NSAssert([_sysexListenerArray containsObject:object],
			 @"Trying to remove non-registered Sysex listener!: %@", object);
	
	[_sysexListenerArray removeObject:object];
}

// *********************************************
//
- (void)registerMIDIListener:(id<MIDIDataReceiver>)object
{
	NSAssert([object conformsToProtocol:@protocol(MIDIDataReceiver)],
			 @"Cannot register %@ as MIDI Listener. (Does not conform to <MIDIDataReceiver>)", object);
	
	NSAssert(![_MIDIListenerArray containsObject:object],
			 @"Trying to add MIDI Listener object %@ again!", object);
	
	[_MIDIListenerArray addObject:object];	// this retains object
}

- (void)removeMIDIListener:(id<MIDIDataReceiver>)object
{
	NSAssert([_MIDIListenerArray containsObject:object],
			 @"Removing non-registered MIDI listener!: %@", object);
	
	[_MIDIListenerArray removeObject:object];
}

// *********************************************
//    SENDING MIDI
// *********************************************
#pragma mark  sending midi

// *********************************************
// all input data are placed in a single packet, timestamped 'now' for immediate delivery
- (BOOL)sendMIDI:(NSData *)data
{
	MIDIPacketList *pktlist;
	MIDIPacket *curPacket;
	size_t dataLength, pktlistLength;
	OSStatus status;

	if ([self destinationIsConnected] == NO) {
		return kSendMIDIFailure;
	}

	dataLength		= [data length];
	pktlistLength	= dataLength + 256;	// allocate adequate space--assumes overhead in
										// MIDIPacketList < 256 bytes. From 10.3 headers it appears to be only 4 bytes, but allow extra

	pktlist		= (MIDIPacketList *)malloc(pktlistLength);
	curPacket	= MIDIPacketListInit(pktlist);
	curPacket	= MIDIPacketListAdd(pktlist, pktlistLength, curPacket, 0, dataLength, [data bytes]);

	status = MIDISend(_outPort, _MIDIDest, pktlist);
	CHECK_OSSTATUS(status, "MIDIIO sendMIDI");

	if (status == noErr) {
		return kSendMIDISuccess;
	} else {
		return kSendMIDIFailure;
	}
}

// *********************************************
//    send a packet list (wrapped as NSData)
//
- (BOOL)sendMIDIPacketList:(NSData *)wrappedPacketList
{
	OSStatus status;

	if ([self destinationIsConnected] == NO) {
		return kSendMIDIFailure;
	}

	MIDIPacketList *pktlist = (MIDIPacketList *)[wrappedPacketList bytes];
	status = MIDISend(_outPort, _MIDIDest, pktlist);
	CHECK_OSSTATUS(status, "MIDIIO sendMIDIPacketList");


	if (status == noErr) {
		return kSendMIDISuccess;
	} else {
		return kSendMIDIFailure;
	}
}

// *********************************************
//  Sending Sysex

// this is called in sysex-sending thread
static void mySysexCompletionProc(MIDISysexSendRequest *request)
{
	// NSLog(@"reached sysex completion proc; request = %x", request);
	NSData *data = (NSData *)request->completionRefCon;
	[data release];	// balances retain in sendSysex:
	free(request);	// free the one we malloc'ed before sending--is this cool? when else could we free?
}

- (BOOL)sendSysex:(NSData *)data
{
	OSStatus status;

	if ([self destinationIsConnected] == NO) {
		return kSendMIDIFailure;
	}

	[data retain];

	MIDISysexSendRequest *req = malloc(sizeof(MIDISysexSendRequest));

	req->destination		= _MIDIDest;
	req->data			= (Byte *)[data bytes];
	req->bytesToSend		= (UInt32)[data length];
	req->complete		= FALSE;
	req->completionProc	= mySysexCompletionProc;
	req->completionRefCon	= (void *)data;

	status = MIDISendSysex(req);

	if (status != noErr) {
		free(req);
		[data release];
		return kSendMIDIFailure;
	}
	
	return kSendMIDISuccess;

	// !!! this would be the place to start a timer if we're concerned about tracking progress
	// for present needs, messages are so short this is overkill
}

- (BOOL)flushOutput
{
	OSStatus err;

	if ([self destinationIsConnected] == YES) {
		err = MIDIFlushOutput(_MIDIDest);

		if (err == 0) {
			return kSendMIDISuccess;
		} else {
			return kSendMIDIFailure;
		}
	} else {
		return kSendMIDIFailure;
	}
}

@end
