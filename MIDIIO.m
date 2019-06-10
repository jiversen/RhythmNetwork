#import "MIDIIO.h"

#import <CoreMIDI/MIDIServices.h>
#import <CoreAudio/HostTime.h>

// wrapper for simple midi io

// Forward definitions of callbacks
static void	myReadProc(const MIDIPacketList *pktlist, void *refCon, void *connRefCon);
static void	mySysexCompletionProc(MIDISysexSendRequest *request);
static void myMIDINotifyProc(const MIDINotification *message, void * refCon);

@implementation MIDIIO

// *********************************************
//    INITIALIZATION
// *********************************************
#pragma mark INIT

- (MIDIIO*)init
{
	self				= [super init];
	_MIDIClient			= NULL;
	_inPort				= NULL;
	_outPort			= NULL;
	_MIDISource			= NULL;
	_MIDIDest			= NULL;
	_sysexListenerArray = [[NSMutableArray arrayWithCapacity:0] retain];
	_MIDIListenerArray  = [[NSMutableArray arrayWithCapacity:0] retain];

	[self setupMIDI];    
    return self;
}

// *********************************************
//     
- (void)dealloc
{
	MIDIClientDispose(_MIDIClient); //automatically disposes of ports
	[_sysexListenerArray release];
	[_MIDIListenerArray  release];
	[super dealloc];
}

// *********************************************
//     
//Setup a midi client, create its input and output ports, connect ports to outside world
- (void)setupMIDI
{
	OSStatus status;
    
    //create this client
    status = MIDIClientCreate(CFSTR("MIDIIO"), myMIDINotifyProc, (void*)self, &_MIDIClient);
	
	//create an input port
    status = MIDIInputPortCreate(_MIDIClient, CFSTR("MIDIIO Input Port"), myReadProc, (void*)self, &_inPort);
	
	//create an output port
	status = MIDIOutputPortCreate(_MIDIClient, CFSTR("MIDIIO Output Port"), &_outPort);
	
	//set source and destination (take user default, otherwise first--after initial entry, which will be "(not connected)")
	NSArray *sourceList = [self getSourceList];
	//try to use default
	if ([self useSourceNamed:[self defaultSourceName]] == NO) {
		//set to no connection
		[self useSourceNamed:sourceList[0]]; //during init, list will always have (not connected) as first
	}
	
	NSArray *destinationList = [self getDestinationList];
	if ([self useDestinationNamed:[self defaultDestinationName]] == NO) {
		[self useDestinationNamed:destinationList[0]];
	}
}

// *********************************************
//    external readProc support
// *********************************************
#pragma mark external readProc support

- (MIDIReadProc) defaultReadProc
{
	return myReadProc;
}

- (void) setDefaultReadProc
{
	[self setReadProc:[self defaultReadProc] refCon:self];
}

// :jri:20050913 Something new to try--add an external readproc
- (void) setReadProc:(MIDIReadProc) newReadProc refCon:(void *)refCon
{
	NSAssert( (_inPort != NULL), @"an InputPort should already exist");
	
	OSStatus status;
	status = MIDIPortDispose(_inPort);
	NSAssert( (status == noErr), @"problem disposing old input port");
	_inPort = NULL;
	
	status = MIDIInputPortCreate(_MIDIClient, CFSTR("MIDIIO Input Port"), newReadProc, (void*)refCon, &_inPort);
}

// *********************************************
//    things an external readProc will need to know to re-transmit MIDI

- (MIDIPortRef) outPort { return _outPort; }

- (MIDIEndpointRef) MIDIDest { return _MIDIDest; }

// *********************************************
//    source/destination management
// *********************************************
#pragma mark source/destination management

- (NSArray *) getSourceList
{
    int n,i;
	CFStringRef name;
	NSMutableArray *list = [NSMutableArray arrayWithCapacity:0];
	NSMutableString *uniqueName = [NSMutableString stringWithCapacity:10];
	
	if (_MIDISource == NULL)
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
	
	return [NSArray arrayWithArray:list]; //returns immutable version
	
}

- (NSArray *) getDestinationList
{
    int n,i;
	CFStringRef name;
	NSMutableArray *list = [NSMutableArray arrayWithCapacity:0];
	
	if (_MIDIDest == NULL)
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
	return [NSArray arrayWithArray:list]; //returns immutable version
}

- (BOOL) useSourceNamed:(NSString *)sourceName
{
	OSStatus	status;
    int n,i;
	CFStringRef name;
	BOOL didConnect = FALSE;

	//iterate thru sources, finding first match to sourceName
	n = MIDIGetNumberOfSources();
    for (i = 0; i < n; i++) {
        MIDIEndpointRef src = MIDIGetSource(i);		
		MIDIObjectGetStringProperty(src, kMIDIPropertyName, &name);
		if ([sourceName isEqualToString:(NSString *)name]) {
			if (_MIDISource != NULL)
				MIDIPortDisconnectSource(_inPort,_MIDISource);
			_MIDISource = src;
			status = MIDIPortConnectSource(_inPort, _MIDISource, (void *) i);
			NSLog(@"connecting to source %@",sourceName);
			didConnect = TRUE;
			[self setDefaultSourceName:sourceName];
		}
		CFRelease(name);
    }	
	//didn't find it, don't connect to anything
	if (!didConnect) {
		NSLog(@"Could not connect: source %@ does not exist", sourceName);
		_MIDISource = NULL;
	}
		
	
	return didConnect;
}

- (BOOL) useDestinationNamed:(NSString *)destinationName
{
    int n,i;
	CFStringRef name;
	BOOL didConnect = FALSE;
	
	//iterate thru sources, finding first match to sourceName
	n = MIDIGetNumberOfDestinations();
    for (i = 0; i < n; i++) {
        MIDIEndpointRef dest = MIDIGetDestination(i);		
		MIDIObjectGetStringProperty(dest, kMIDIPropertyName, &name);
		if ([destinationName isEqualToString:(NSString *)name]) {
			_MIDIDest = dest;
			NSLog(@"connecting to destination %@",destinationName);
			didConnect = TRUE;
			[self setDefaultDestinationName:destinationName];
		}
		CFRelease(name);
    }		
	if (!didConnect) {
		NSLog(@"Could not connect: destination %@ does not exist", destinationName);
		_MIDIDest = NULL;
	}
	
	//publish our new destination
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MIDIIO_newDestinationNotification" object:self];
	
	return didConnect;
}

- (NSString *) sourceName
{
	CFStringRef name;
	if (_MIDISource != NULL) {
		MIDIObjectGetStringProperty(_MIDISource, kMIDIPropertyName, &name);		
		return [NSString stringWithString:(NSString *)name];
	} else
        return @"(not connected)";
}

- (NSString *) destinationName
{
	CFStringRef name;
	if (_MIDIDest != NULL) {
		MIDIObjectGetStringProperty(_MIDIDest, kMIDIPropertyName, &name);	
		return [NSString stringWithString:(NSString *)name];
	} else
		return @"(not connected)";
}

//simple queries of connection state
- (BOOL) sourceIsConnected 
{
	return (_MIDISource != NULL);
}
- (BOOL) destinationIsConnected
{
	return (_MIDIDest != NULL);
}

//user defaults
// if no default, return empty string, otherwise return last stored default
- (NSString *) defaultSourceName
{
	NSString *defaultName = [[NSUserDefaults standardUserDefaults] stringForKey:@"MIDIIO_defaultSourceName"];
	if (defaultName == nil)
		defaultName = [NSString string];
	return defaultName;
}

- (NSString *) defaultDestinationName
{
	NSString *defaultName = [[NSUserDefaults standardUserDefaults] stringForKey:@"MIDIIO_defaultDestinationName"];
	if (defaultName == nil)
		defaultName = [NSString string];
	return defaultName;
}

- (void) setDefaultSourceName:(NSString *)sourceName
{
	[[NSUserDefaults standardUserDefaults] setObject:sourceName forKey:@"MIDIIO_defaultSourceName"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) setDefaultDestinationName:(NSString *)destinationName
{
	[[NSUserDefaults standardUserDefaults] setObject:destinationName forKey:@"MIDIIO_defaultDestinationName"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

// *********************************************
//  Handle changes in the midi setup--
//		this executes on our main thread, but still follows pattern of calling object method to handle things
static void myMIDINotifyProc(const MIDINotification *message, void * refCon)
{
	MIDIIO *me = (MIDIIO *)refCon;
	
	switch (message->messageID) {
		case kMIDIMsgSetupChanged:
			[me handleMIDISetupChange];
			break;
	}
}

- (void) handleMIDISetupChange
{
	int n,i;
	BOOL	found = FALSE;
	
	//if we're still unconnected, check if default has appeared
	if (_MIDISource == NULL) {
		[self useSourceNamed:[self defaultSourceName]]; //if this fails, source still = NULL
	} else {
		//is our current source still in the list?
		// if not, clear our _MIDISource
		n = MIDIGetNumberOfSources();
		for (i = 0; i < n; i++) {
			MIDIEndpointRef src = MIDIGetSource(i);		
			if (_MIDISource == src)
				found = TRUE;
		}
		if (!found)
			_MIDISource = NULL;
	}

			
	if (_MIDIDest == NULL) {
		[self useDestinationNamed:[self defaultDestinationName]]; //if this fails, dest = NULL
	} else {
		n = MIDIGetNumberOfDestinations();
		for (i = 0; i < n; i++) {
			MIDIEndpointRef dest = MIDIGetDestination(i);		
			if (_MIDIDest == dest)
				found = TRUE;
		}
		if (!found)
			_MIDIDest = NULL;
	}
				
	//once we're sorted out, let everyone else know
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MIDIIOSetupChangeNotification"
																	object:self];
}

// *********************************************
//    RECEIVING MIDI
// *********************************************
#pragma mark RECEIVING

//quickly pass on to the object method and get out of the thread
static void	myReadProc(const MIDIPacketList *pktlist, void *refCon, void *connRefCon)
{
	unsigned int i, pktlistLength;
    MIDIIO *selfMIDIIO = (MIDIIO *) refCon;
	
	//find total length of packet list
	MIDIPacket *packet = (MIDIPacket *) &pktlist->packet[0];
    for (i = 0; i < pktlist->numPackets; i++) {
		packet = MIDIPacketNext(packet);
	}
	pktlistLength = (Byte *) packet - (Byte *) pktlist;
	
	//wrap packet list as object (we're ignoring connRefCon for now)
	// we can use packet list bytes in place, but how long are these guaranteed? Who frees them?
	// presumably it's the caller, so let's not trust it. So, shucks, let's go ahead and allocate
	// a new object here.
	// otherwise, could use a shared ring-buffer
	
	//CFDataRef wrappedPktlist = CFDataCreateWithBytesNoCopy(NULL,pktlist,pktlistLength,kCFAllocatorNull);
	CFDataRef wrappedPktlist = CFDataCreate(kCFAllocatorDefault,(const UInt8 *) pktlist, (CFIndex) pktlistLength);
	
	//pass wrapped list on to our handler, execute on main thread to 
	//	1) get out of realtime thread asap & 2) stop worrying about memory allocation (use main thread's) autorelease pool
    [selfMIDIIO performSelectorOnMainThread:@selector(handleMIDIInput:) withObject:(NSData *)wrappedPktlist waitUntilDone:NO];
	CFRelease(wrappedPktlist); //since we created it; one ref still retained by performSelector... as long as it needs it
}

// *********************************************
//  parse packets and send out to listeners
//	will execute on main thread, so no worries about object allocation, realtime priority, etc
//	Note that input argument was retained by performSelectorOnMainThread, so we don't have to retain
- (void)handleMIDIInput:(NSData *) wrappedPktlist
{
    unsigned int i;
		
	//i = [wrappedPktlist retainCount];
	//printf("ref %d\n",i);

	MIDIPacketList *pktlist = (MIDIPacketList *) [wrappedPktlist bytes];	
	MIDIPacket *packet = (MIDIPacket *) &pktlist->packet[0];
	NSMutableData *sysexData = nil;
	NSData *MIDIData;
	NoteOnMessage thisMessage;
	Byte *bp, *packetEnd;

	//parse midi--keeping it simple for now, and only doing what we need
    for (i = 0; i < pktlist->numPackets; i++) {
        if ( packet->data[0] == 0xF0 || packet->data[0] <0x80) {	//Sysex start or continuation (exhaustive?)
			
			if (sysexData == nil)
				sysexData = [NSMutableData dataWithCapacity:packet->length];
			
			packetEnd = packet->data + packet->length - 1; //could include single-byte realtime, so copy one byte at a time
			bp = packet->data;
			[sysexData appendBytes:bp length:1];
			bp++;
			//note, assuming only one (or part of one) sysex message per packet
			//	so a little overkill to end at first 0xF7--there 'should' never be anything worth including
			//	after that
			while (bp <= packetEnd && *bp != 0xF7) {
				if (*bp < 0x80)
					[sysexData appendBytes:bp length:1];
				bp++;
			}
			if (*bp == 0xF7) 
				[sysexData appendBytes:bp length:1];
			//***just for curiousity
			NSAssert2( (bp == packetEnd), @"Interesting: bytes following end of sysex message in packet. F7@%x, end@%x", bp, packetEnd);

        } else { //non sysex
			//note-on (all we care about in RhythmNetwork, so this is hardly general purpose)
			// we create our own structure, one step abstracted from raw MIDI, and with time in real units
			if ( (packet->data[0] & 0xF0) == 0x90 && packet->data[2] > 0) {				
				thisMessage.eventTime_ns = AudioConvertHostTimeToNanos(packet->timeStamp);
				thisMessage.channel = (packet->data[0] & 0x0F) + 1; //we use 1-based counting
				thisMessage.note = packet->data[1];
				thisMessage.velocity = packet->data[2];
				//packetLength = sizeof(MIDITimeStamp) + sizeof(UInt16) + (packet->length); //**depends on packet structure
				//MIDIData = [NSData dataWithBytes:packet length:packetLength];
				MIDIData = [NSData dataWithBytes:&thisMessage length:sizeof(NoteOnMessage)];
				[_MIDIListenerArray makeObjectsPerformSelector:@selector(receiveMIDIData:) withObject:MIDIData];
			} else {
				//NSLog(@"Received non note-on event! %x %x %x", packet->data[0], packet->data[1], packet->data[2]);
			}
		}
		packet = MIDIPacketNext(packet);
    }
	// if we got sysex data, send it to our client(s)
	//		for now, we ensure that it has a receiveSysexData: method in registerSysexListener
	if ( ([sysexData length] > 0) && ([_sysexListenerArray count] > 0) )
	{
		[_sysexListenerArray makeObjectsPerformSelector:@selector(receiveSysexData:) withObject:sysexData];
	}
}


// *********************************************
//     PUBLIC METHODS
// *********************************************

#pragma mark  managing listeners

// *********************************************
//     
//add object to list of objects to send sysex data to
//	ensure it responds to appropriate selector and is not already in list
- (void)registerSysexListener:(id)object
{
	if ( [object respondsToSelector:@selector(receiveSysexData:)] )
		if ( [_sysexListenerArray containsObject:object] )
			NSLog(@"Problem: Trying to add object %@ again!",object);
		else
			[_sysexListenerArray addObject:object]; //this retains object
	else
		NSLog(@"Problem: Cannot register %@ as sysexListener. (Does not respond to receiveSysexData:)",object);
}

- (void)removeSysexListener:(id)object{
	if ( ![_sysexListenerArray containsObject:object] )
		NSLog(@"Problem: Trying to remove non-listener object %@!",object);
	else
		[_sysexListenerArray removeObject:object];
}

// *********************************************
//     
- (void)registerMIDIListener:(id)object
{
	if ( [object respondsToSelector:@selector(receiveMIDIData:)] )
		if ( [_MIDIListenerArray containsObject:object] )
			NSLog(@"Problem: Trying to add object %@ again!",object);
		else
			[_MIDIListenerArray addObject:object]; //this retains object
	else
		NSLog(@"Problem: Cannot register %@ as MIDIListener. (Does not respond to receiveMIDIData:)",object);	
}

- (void)removeMIDIListener:(id)object
{
	if ( ![_MIDIListenerArray containsObject:object] )
		NSLog(@"Problem: Trying to remove non-listener object %@!",object);
	else
		[_MIDIListenerArray removeObject:object];
	
}

// *********************************************
//    SENDING MIDI
// *********************************************
#pragma mark  sending midi

// *********************************************
// all input data are placed in a single packet, timestamped 'now' for immediate delivery
- (BOOL)sendMIDI:(NSData *) data 
{
	MIDIPacketList	*pktlist;
	MIDIPacket		*curPacket;
	size_t			dataLength, pktlistLength;
	OSStatus status;
	
	if ([self destinationIsConnected]==NO)
		return kSendMIDIFailure;
	
	dataLength		= [data length];
	pktlistLength	= dataLength + 256; //allocate adequate space--assumes overhead in
									   //MIDIPacketList < 256 bytes. From 10.3 headers it appears to be only 4 bytes, but allow extra

	pktlist			= (MIDIPacketList *) malloc(pktlistLength); 	
	curPacket		= MIDIPacketListInit(pktlist);
	curPacket		= MIDIPacketListAdd(pktlist,pktlistLength,curPacket,0,dataLength,[data bytes]);
	
	status = MIDISend(_outPort, _MIDIDest, pktlist);
	
	if (status==noErr)
		return kSendMIDISuccess;
	else
		return kSendMIDIFailure;
}

// *********************************************
//    send a packet list (wrapped as NSData)
// 
- (BOOL)sendMIDIPacketList: (NSData *) wrappedPacketList
{
	OSStatus status;
	
	if ([self destinationIsConnected]==NO)
		return kSendMIDIFailure;
	
	MIDIPacketList *pktlist = (MIDIPacketList *) [wrappedPacketList bytes];
	status = MIDISend(_outPort, _MIDIDest, pktlist);
	
	if (status==noErr)
		return kSendMIDISuccess;
	else
		return kSendMIDIFailure;
}


// *********************************************
//  Sending Sysex

//this is called in sysex-sending thread
static void	mySysexCompletionProc(MIDISysexSendRequest *request)
{
	//NSLog(@"reached sysex completion proc; request = %x", request);
	NSData *data = (NSData *) request->completionRefCon;
	[data release]; // balances retain in sendSysex:
	free(request); //free the one we malloc'ed before sending--is this cool? when else could we free?
}


- (BOOL)sendSysex:(NSData *) data
{
	OSStatus status;

	if ([self destinationIsConnected]==NO)
		return kSendMIDIFailure;

	[data retain];
	
	MIDISysexSendRequest *req = malloc(sizeof(MIDISysexSendRequest));
		
	req->destination		= _MIDIDest;
	req->data				= (Byte *) [data bytes];
	req->bytesToSend		= [data length];
	req->complete			= FALSE;
	req->completionProc		= mySysexCompletionProc;
	req->completionRefCon	= (void *)data;
	
	status = MIDISendSysex(req);
	
	if (status==noErr)
		return kSendMIDISuccess;
	else
		return kSendMIDIFailure;
	
	// !!! this would be the place to start a timer if we're concerned about tracking progress
	// for present needs, messages are so short this is overkill
}

- (BOOL) flushOutput
{
	OSStatus err;
	if ([self destinationIsConnected]==YES) {
		err = MIDIFlushOutput(_MIDIDest);
		if (err==0)
			return kSendMIDISuccess;
		else
			return kSendMIDIFailure;
	} else
		return kSendMIDIFailure;
}
@end
