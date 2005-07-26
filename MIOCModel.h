/* MIOCModel */
//takes care of low level decoding/encoding sysex messages,
// and higher level message composition and display for communication w/ MIDITEMP MIOC
// Maintains a model of MIOC state

#import <Cocoa/Cocoa.h>

#import "MIOCProcessorProtocol.h"

#define kMIDITEMPID				0x00200d
#define kSendSysexSuccess		TRUE
#define kSendSysexFailure		FALSE

#define kDevicePMM88E			0x20

//MIOC message structure (per dump.txt)
typedef struct _MIOCMessage {
	Byte	sysexStart; //junk
	Byte	manuID[3];
	Byte	deviceID;
	Byte	deviceType;
	Byte	mode;
	Byte	opcode;
	Byte	data[1]; //open ended...
} MIOCMessage;

//bytes before start of data
#define kPreambleLength 8

#define kModeEncodedMask (1<<6)
#define kModeHandshakeMask (1<<2)
#define kModeMsgTypeMask (0x03)
#define kOpcodeDirectionMask (1<<6)

@class MIDIIO, MIOCConnection, MIOCVelocityProcessor;

@interface MIOCModel : NSObject
{
	Byte			_deviceID;			//Fornet address
	Byte			_deviceType;		//Miditemp defined device types
	NSString		*_deviceName;		//User-specified name of device
	
	NSMutableArray	*_connectionList;	//set of MIOCConnection objects (our model of MIOC state)
	NSMutableArray	*_velocityProcessorList; //set of MIOCVelocityProcessor objects (part of model of MIOC state)
	BOOL			_filtersInitialized; //yes if filters have been initialized
	BOOL			_isOnline;		     //yes if MIOC is online
	BOOL			_correctPort;		 //connected to port 8?
	BOOL			_awaitingReply;		 //yes if we've sent a sysex and expecting a reply
										 //assuming mioc responds fifo to requests!
	NSTimer			*_replyTimer;		 //timer to check for MIOC reply timeout
	
	MIDIIO			*_MIDILink;			//our bridge to MIDI
}

- (MIOCModel *) init;
- (void) dealloc;
- (void) reset;
- (void) initialize;
- (void) checkOnline;

- (BOOL) sendVerifiedMIOCQuery:(NSData *)data;
- (BOOL) sendMIOCQuery:(NSData *)data;
- (void) handleMIOCReply:(NSNotification *)notification;
- (void) handleMIOCReplyTimeout:(NSTimer *)timer;

- (BOOL) queryPortAddress;
- (BOOL) queryDeviceName;
- (NSString *) deviceName;
- (BOOL) setDeviceName:(NSString *) name;

- (void) connectOne:(MIOCConnection *) aConnection;
- (void) connectMany:(NSArray *) aConnectionList;
- (void) connectInPort: (int) anInPort InChannel: (int) anInChannel OutPort: (int) anOutPort OutChannel: (int) anOutChannel;
- (void) disconnectOne:(MIOCConnection *) aConnection;
- (void) disconnectMany:(NSArray *) aConnectionList;
- (void) disconnectInPort: (int) anInPort InChannel: (int) anInChannel OutPort: (int) anOutPort OutChannel: (int) anOutChannel;
- (void) disconnectAll;

- (void) addVelocityProcessor:(MIOCVelocityProcessor *) aVelProc;
- (void) removeVelocityProcessor:(MIOCVelocityProcessor *) aVelProc;

- (void) addFilterProcessors;

- (NSArray *) connectionList;
- (void) setConnectionList: (NSArray *) aConnectionList;

- (MIDIIO *) MIDILink;
- (void)receiveSysexData:(NSData *)data;

//private
- (BOOL) sendConnectSysex:(MIOCConnection *) aConnection;
- (BOOL) sendDisconnectSysex:(MIOCConnection *) aConnection;
- (BOOL) sendConnectDisconnectSysex: (MIOCConnection *) aConnection withFlag:(Byte *)flagPtr;

- (BOOL) sendAddVelocityProcessorSysex:(MIOCVelocityProcessor *) aVelProc;
- (BOOL) sendRemoveVelocityProcessorSysex:(MIOCVelocityProcessor *) aVelProc;
- (BOOL) sendAddRemoveVelocityProcessorSysex:(MIOCVelocityProcessor *) aVelProc withFlag:(Byte *)flagPtr;

- (BOOL) sendAddProcessorSysex:(id <MIOCProcessor>) aProc;
- (BOOL) sendRemoveProcessorSysex:(id <MIOCProcessor>) aProc;
- (BOOL) sendAddRemoveProcessorSysex:(id <MIOCProcessor>) aProc withFlag:(Byte *)flagPtr;

- (NSData *) sysexMessageForProcessor: (id <MIOCProcessor>) aProc withFlag:(Byte *)flagPtr;

- (NSMutableData *) addChecksum:(NSMutableData *)message;
- (BOOL) verifyChecksum:(NSData *) message;
- (NSData *) encode87:(NSData *) sourceData;
- (NSData *) decode87:(NSData *) sourceData;
- (NSData *) decodeMessage:(NSData *) sourceData;

@end
