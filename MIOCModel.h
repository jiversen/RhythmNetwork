/* MIOCModel */
// takes care of low level decoding/encoding sysex messages,
// and higher level message composition and display for communication w/ MIDITEMP MIOC
// Maintains a model of MIOC state

#import <Foundation/Foundation.h>

#import "MIOCProcessorProtocol.h"
#import "MIDIListenerProtocols.h"

#define kMIDITEMPID			0x00200d
#define kSendSysexSuccess	TRUE
#define kSendSysexFailure	FALSE

#define kDevicePMM88E		0x20

// MIOC message structure (per dump.txt)
typedef struct _MIOCMessage {
	Byte	sysexStart;	// junk
	Byte	manuID[3];
	Byte	deviceID;
	Byte	deviceType;
	Byte	mode;
	Byte	opcode;
	Byte	data[1];// open ended...
} MIOCMessage;

// bytes before start of data
#define kPreambleLength			8

#define kModeEncodedMask		(1 << 6)
#define kModeHandshakeMask		(1 << 2)
#define kModeMsgTypeMask		(0x03)
#define kOpcodeDirectionMask	(1 << 6)

@class MIDIIO, MIOCConnection, MIOCVelocityProcessor, MIDICore;

@interface MIOCModel : NSObject <SysexDataReceiver> {
{
	Byte				_deviceID;					// Fornet address
	Byte				_deviceType;				// Miditemp defined device types
	NSString			*_deviceName;				// User-specified name of device

	NSMutableArray	*_connectionList;			// set of MIOCConnection objects (our model of MIOC state)
	NSMutableArray	*_velocityProcessorList;	// set of MIOCVelocityProcessor objects (model of MIOC state)
	BOOL				_filtersInitialized;		// yes if filters have been initialized
	BOOL				_isOnline;					// yes if MIOC is online
	BOOL				_correctPort;				// connected to port 8?
	BOOL				_awaitingReply;				// yes if we've sent a sysex and expecting a reply
												// assuming mioc responds fifo to requests!
	NSTimer 			*_replyTimer;					// timer to check for MIOC reply timeout

	MIDIIO			*_MIDILink;					// our bridge to MIDI
	MIDICore			*_MIDICore;					// internal midi processor (stands in for MIOC)
	BOOL				_useInternalMIDIProcessor;	// converse: use internal MIDICore
}

- (MIOCModel *)init;
- (void)dealloc;
- (void)reset;
- (void)initialize;
- (void)checkOnline;

- (BOOL)useInternalMIDIProcessor;
- (void)setUseInternalMIDIProcessor:(BOOL)useInternal;

- (BOOL)sendVerifiedMIOCQuery:(NSData *)data;
- (BOOL)sendMIOCQuery:(NSData *)data;
- (void)handleMIOCReply:(NSNotification *)notification;
- (void)handleMIOCReplyTimeout:(NSTimer *)timer;

- (BOOL)queryPortAddress;
- (BOOL)queryDeviceName;
- (NSString *)deviceName;
- (BOOL)setDeviceName:(NSString *)name;

- (void)connectOne:(MIOCConnection *)aConnection;
- (void)connectMany:(NSArray *)aConnectionList;
- (void)connectInPort:(int)anInPort InChannel:(int)anInChannel OutPort:(int)anOutPort OutChannel:(int)anOutChannel;
- (void)disconnectOne:(MIOCConnection *)aConnection;
- (void)disconnectMany:(NSArray *)aConnectionList;
- (void)disconnectInPort:(int)anInPort InChannel:(int)anInChannel OutPort:(int)anOutPort OutChannel:(int)anOutChannel;
- (void)disconnectAll;

- (void)addVelocityProcessor:(MIOCVelocityProcessor *)aVelProc;
- (void)removeVelocityProcessor:(MIOCVelocityProcessor *)aVelProc;
- (void)addVelocityProcessorsInArray:(NSArray *)aProcessorList;
- (void)removeVelocityProcessorsInArray:(NSArray *)aProcessorList;
- (NSArray *)velocityProcessorList;
- (void)setVelocityProcessorList:(NSArray *)newVelocityProcessorList;

- (void)addFilterProcessors;

- (NSArray *)connectionList;
- (void)setConnectionList:(NSArray *)aConnectionList;

- (MIDIIO *)MIDILink;
- (void)receiveSysexData:(NSData *)data;

// private
- (BOOL)sendConnect:(MIOCConnection *)aConnection;
- (BOOL)sendDisconnect:(MIOCConnection *)aConnection;
- (BOOL)sendConnectDisconnectSysex:(MIOCConnection *)aConnection withFlag:(Byte *)flagPtr;

- (BOOL)sendAddVelocityProcessor:(MIOCVelocityProcessor *)aVelProc;
- (BOOL)sendRemoveVelocityProcessor:(MIOCVelocityProcessor *)aVelProc;
- (BOOL)sendAddRemoveVelocityProcessorSysex:(MIOCVelocityProcessor *)aVelProc withFlag:(Byte *)flagPtr;

- (BOOL)sendAddProcessor:(id <MIOCProcessor>)aProc;
- (BOOL)sendRemoveProcessor:(id <MIOCProcessor>)aProc;
- (BOOL)sendAddRemoveProcessorSysex:(id <MIOCProcessor>)aProc withFlag:(Byte *)flagPtr;

- (NSData *)sysexMessageForProcessor:(id <MIOCProcessor>)aProc withFlag:(Byte *)flagPtr;

- (NSMutableData *)addChecksum:(NSMutableData *)message;
- (BOOL)verifyChecksum:(NSData *)message;
- (NSData *)encode87:(NSData *)sourceData;
- (NSData *)decode87:(NSData *)sourceData;
- (NSData *)decodeMessage:(NSData *)sourceData;

@end
