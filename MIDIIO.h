/* MIDIIO */

//a minimal MIDI interface

#import <Cocoa/Cocoa.h>
#import <CoreMIDI/MIDIServices.h>
#import <os/log.h>
//#import "TPCircularBuffer.h"

#define kSendMIDISuccess		TRUE
#define kSendMIDIFailure		FALSE

typedef struct _NoteOnMessage {
	UInt64 	eventTime_ns;
	Byte	channel;
	Byte	note;
	Byte	velocity;
	Byte	spare;		//seems good to keep it even # of bytes, not sure of impact on storage performance
} NoteOnMessage;

typedef struct _ProgramChangeMessage {
	UInt64 	eventTime_ns;
	Byte	channel;
	Byte	program;
	Byte	spare1;
	Byte	spare2;
} ProgramChangeMessage;
	
@interface MIDIIO : NSObject
{
	MIDIClientRef	_MIDIClient;
	MIDIPortRef	   _inPort;
	MIDIPortRef	   _outPort;
	MIDIEndpointRef  _MIDISource;	//only one source & destination
	MIDIEndpointRef  _MIDIDest;
	NSMutableArray  *_sysexListenerArray;
	NSMutableArray  *_MIDIListenerArray;
    dispatch_queue_t _midiLoggingQueue;
    NSMutableData   *_sysexData;
    BOOL            _isReceivingSysex;
}

- (MIDIIO*)init;
- (void)dealloc;
- (void)setupMIDI;

- (MIDIReadProc) defaultReadProc;
- (void) setDefaultReadProc;
- (void) setReadProc:(MIDIReadProc) newReadProc refCon:(void *)refCon;
- (MIDIPortRef) outPort;
- (MIDIEndpointRef) MIDIDest;

- (NSArray *) getSourceList;
- (NSArray *) getDestinationList;
- (BOOL) useSourceNamed:(NSString *)sourceName;
- (BOOL) useDestinationNamed:(NSString *)destinationName;
- (NSString *) sourceName;
- (NSString *) destinationName;
- (BOOL) sourceIsConnected;
- (BOOL) destinationIsConnected;
//user defaults--any time source/dest is set, save to defaults. When starting, use default if it exists
- (NSString *) defaultSourceName;
- (NSString *) defaultDestinationName;
- (void) setDefaultSourceName:(NSString *)sourceName;
- (void) setDefaultDestinationName:(NSString *)destinationName;

- (void) handleMIDISetupChange;

- (void)handleMIDIInput:(NSData *) wrappedPktlist;

- (void)registerSysexListener:(id)object;
- (void)removeSysexListener:(id)object;
- (void)registerMIDIListener:(id)object;
- (void)removeMIDIListener:(id)object;

- (BOOL)sendMIDI:(NSData *) data;
- (BOOL)sendMIDIPacketList: (NSData *) wrappedPacketList;
- (BOOL)sendSysex:(NSData *) data;

- (BOOL)flushOutput;

@end

