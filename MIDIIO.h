/* MIDIIO */

// a minimal MIDI interface

#import <Cocoa/Cocoa.h>
#import <CoreMIDI/MIDIServices.h>
#import <os/log.h>
#import "TPCircularBuffer.h"
#import "TimingUtils.h"
#import "MIDIListenerProtocols.h"


#define kSendMIDISuccess		TRUE
#define kSendMIDIFailure		FALSE
#define kMIDIInvalidRef ((MIDIObjectRef)0)

// Error Handling (CGPT)
#define CHECK_OSSTATUS(s, msg) do { \
	if ((s) != noErr) { \
		NSLog(@"%s failed: %@ (%d)", msg, (NSString *)CMIDIErrorDescription(s), (int)(s)); \
		goto bail; \
	} \
} while (0)

NSString *CMIDIErrorDescription(OSStatus status);

typedef struct _NoteOnMessage {
	UInt64	eventTime_ns;
	Byte		channel;
	Byte		note;
	Byte		velocity;
	Byte		spare;		// seems good to keep it even # of bytes, not sure of impact on storage performance
} NoteOnMessage;

typedef struct _ProgramChangeMessage {
	UInt64	eventTime_ns;
	Byte		channel;
	Byte		program;
	Byte		spare1;
	Byte		spare2;
} ProgramChangeMessage;

@interface MIDIIO : NSObject
{
	MIDIClientRef			_MIDIClient;
	MIDIPortRef			_inPort;
	MIDIPortRef			_outPort;
	MIDIEndpointRef		_MIDISource;	// only one source & destination
	MIDIEndpointRef		_MIDIDest;
	NSMutableArray<id<SysexDataReceiver>>		*_sysexListenerArray;
	NSMutableArray<id<MIDIDataReceiver>>		*_MIDIListenerArray;
	TPCircularBuffer		*_packetBuffer;
	dispatch_semaphore_t 	_dataAvailableSemaphore;
	BOOL					_isRunning; // true with it's possible to receive MIDI
	dispatch_queue_t		_processingQueue;
	dispatch_queue_t		_listenerQueue;
	NSMutableData			*_sysexData;
	BOOL					_isReceivingSysex;
	MIDIIO				*_delayMIDIIO;	// our sub-interface for delay outputs
	BOOL					_isLeader;	 	// are we the owner of a sub-interface, or the sub-interface
}

- (MIDIIO*)init;
- (MIDIIO*)initFollower;
- (void)dealloc;
- (void)startMIDIProcessingThread;
- (void)setupMIDI;

- (MIDIReadProc)defaultReadProc;
- (void)setDefaultReadProc;
- (void)setReadProc:(MIDIReadProc)newReadProc refCon:(void *)refCon;
- (MIDIPortRef)outPort;
- (MIDIEndpointRef)MIDIDest;

- (NSArray *)getSourceList;
- (NSArray *)getDestinationList;
- (BOOL)useSourceNamed:(NSString *)sourceName;
- (BOOL)useDestinationNamed:(NSString *)destinationName;
- (NSString *)sourceName;
- (NSString *)destinationName;
- (BOOL)sourceIsConnected;
- (BOOL)destinationIsConnected;

// user defaults--any time source/dest is set, save to defaults. When starting, use default if it exists
- (NSString *)defaultSourceName;
- (NSString *)defaultDestinationName;
- (void)setDefaultSourceName:(NSString *)sourceName;
- (void)setDefaultDestinationName:(NSString *)destinationName;

- (void)handleMIDISetupChange; // change in MIDI system configuration

- (void)handleMIDIInput:(NSData *)wrappedPktlist;
- (void)handleMIDIPktlist:(const MIDIPacketList *)pktlist;

- (void)registerSysexListener:(id<SysexDataReceiver>)object;
- (void)removeSysexListener:  (id<SysexDataReceiver>)object;
- (void)registerMIDIListener: (id<MIDIDataReceiver>)object;
- (void)removeMIDIListener:   (id<MIDIDataReceiver>)object;

- (BOOL)sendMIDI:(NSData *)data;
- (BOOL)sendMIDIPacketList:(NSData *)wrappedPacketList;
- (BOOL)sendSysex:(NSData *)data;

- (BOOL)flushOutput;

@end
