/* MIDIIO */

// a minimal MIDI interface

#import <Foundation/Foundation.h>
#import <CoreMIDI/MIDIServices.h>
#import <stdatomic.h>
#import "RNArchitectureDefines.h"
#import "TPCircularBuffer.h"
#import "TimingUtils.h"
#import "MIDIListenerProtocols.h"
#import "RNMIDIRouting.h"

#define kSendMIDISuccess		TRUE
#define kSendMIDIFailure		FALSE
#define kMIDIInvalidRef ((MIDIObjectRef)0)

#define kSysexStart 0xF0
#define kSysexEnd 0xF7
#define kNoteOnCommand 0x90
#define kNoteOffCommand 0x80
#define kCommandMask 0xF0

typedef struct _NoteOnMessage {
	UInt64	eventTime_ns;
	Byte		channel;
	Byte		note;
	Byte		velocity;
	Byte		spare;		// seems good to keep it multiple of 4 bytes--only matters if I'm going to pack them into a buffer
} NoteOnMessage;

typedef struct _ProgramChangeMessage {
	UInt64	eventTime_ns;
	Byte		channel;
	Byte		program;
	Byte		spare1;
	Byte		spare2;
} ProgramChangeMessage;

@interface MIDIIO : NSObject {
	MIDIClientRef                          _MIDIClient;
	MIDIPortRef                            _inPort;
	MIDIPortRef                            _outPort;
	MIDIEndpointRef                        _MIDISource; // only one source & destination
	MIDIEndpointRef                        _MIDIDest;
	NSMutableArray<id<SysexDataReceiver>> *_sysexListenerArray;
	NSMutableArray<id<MIDIDataReceiver>>  *_MIDIListenerArray;
	TPCircularBuffer                       _packetBuffer;
	atomic_bool                            _MIDIConsumerReady;
	dispatch_semaphore_t                   _dataAvailableSemaphore;
	BOOL                                   _isRunning; // true with it's possible to receive MIDI
	dispatch_queue_t                       _processingQueue;
	dispatch_queue_t                       _listenerQueue;
	NSMutableData                         *_sysexData;
	BOOL                                   _isReceivingSysex;
	BOOL                                   _isLeader;     // are we the owner of a sub-interface, or the sub-interface
	MIDIIO                                *_delayMIDIIO;  // our sub-interface for delay outputs
	_Atomic(RNRealtimeRoutingTable *)      _routingTable; // used in midi reception to calculate and output delayed packets
	Byte                                   _onMessage[3];
	Byte                                   _offMessage[3];
	MIDIPacket                             _delayPacket;
	MIDIPacketList                        *_delayPacketList;
}

- (MIDIIO*)init;
- (MIDIIO*)initFollower;
- (void)dealloc;
- (void)startMIDIProcessingThread;
- (void)setupMIDI;
- (void)setMIDIRoutingTable:(RNRealtimeRoutingTable *)routingTable;

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

- (void)emitDelayedNotes:(const MIDIPacketList*)pktlist availableBytes:(uint32_t)availableBytes;
- (void)handleMIDIPktlist:(const MIDIPacketList *)pktlist availableBytes:(uint32_t)availableBytes;

- (void)registerSysexListener:(id<SysexDataReceiver>)object;
- (void)removeSysexListener:  (id<SysexDataReceiver>)object;
- (void)registerMIDIListener: (id<MIDIDataReceiver>)object;
- (void)removeMIDIListener:   (id<MIDIDataReceiver>)object;

- (BOOL)sendMIDI:(NSData *)data;
- (BOOL)sendMIDIPacketList:(NSData *)wrappedPacketList;
- (BOOL)sendSysex:(NSData *)data;

- (BOOL)flushOutput;

@end
