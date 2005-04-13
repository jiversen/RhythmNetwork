/* MIOCModel */
//takes care of low level decoding/encoding sysex messages,
// and higher level message composition and display for communication w/ MIDITEMP MIOC
// Maintains a model of MIOC state

#import <Cocoa/Cocoa.h>

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
	Byte	data[];
} MIOCMessage;

//bytes before start of data
#define kPreambleLength 8

#define kModeEncodedMask (1<<6)
#define kModeHandshakeMask (1<<2)
#define kModeMsgTypeMask (0x03)
#define kOpcodeDirectionMask (1<<6)

@class MIDIIO, MIOCConnection;

@interface MIOCModel : NSObject
{
	Byte			_deviceID;			//Fornet address
	Byte			_deviceType;		//Miditemp defined device types
	NSString		*_deviceName;		//User-specified name of device
	
	NSMutableArray	*_connectionList;	//set of MIOCConnection objects (our model of MIOC state)
	
	MIDIIO			*_MIDILink;			//our bridge to MIDI
}

- (MIOCModel *) init;
- (void) dealloc;

- (void) connectOne:(MIOCConnection *) aConnection;
- (void) connectMany:(NSArray *) aConnectionList;
- (void) connectInPort: (int) anInPort InChannel: (int) anInChannel OutPort: (int) anOutPort OutChannel: (int) anOutChannel;
- (void) disconnectOne:(MIOCConnection *) aConnection;
- (void) disconnectMany:(NSArray *) aConnectionList;
- (void) disconnectInPort: (int) anInPort InChannel: (int) anInChannel OutPort: (int) anOutPort OutChannel: (int) anOutChannel;
- (void) disconnectAll;

- (NSArray *) connectionList;
- (void) setConnectionList: (NSArray *) aConnectionList;

- (MIDIIO *) MIDILink;
- (void)receiveSysexData:(NSData *)data;

//private
- (BOOL) sendConnectSysex:(MIOCConnection *) aConnection;
- (BOOL) sendDisconnectSysex:(MIOCConnection *) aConnection;
- (NSData *) sysexMessageForConnection: (MIOCConnection *) aConnection withFlag:(Byte *)flagPtr;
- (BOOL) sendConnectDisconnectSysex: (MIOCConnection *) aConnection withFlag:(Byte *)flagPtr;

- (NSMutableData *) addChecksum:(NSMutableData *)message;
- (BOOL) verifyChecksum:(NSData *) message;
- (NSData *) encode87:(NSData *) sourceData;
- (NSData *) decode87:(NSData *) sourceData;
- (NSData *) decodeMessage:(NSData *) sourceData;

@end
