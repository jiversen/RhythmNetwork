//
//  MIOCMessage.h
//  RhythmNetwork
//
//  Created by John R. Iversen on 2025-07-17.
//

// Define structures and constants for communicating with MIOC device using MIDI Sysex messages.
// Providex C functions for message parsing and display formatting

#import <Foundation/Foundation.h>

#define kMIDITEMPID			0x00, 0x20, 0x0d

#define kDevicePMM88E		0x20

// MIOC message structure (per MIOC MIDI SYSEX specs.txt)
typedef struct _MIOCMessage {
	Byte	sysexStart;	    ///< SysEx start byte (0xF0)
	Byte	manuID[3];	    ///< Manufacturer ID (0x00, 0x20, 0x0d)
	Byte	deviceID;       ///< Device ID (e.g. 0x20)
	Byte	deviceType;     ///< Device Type (e.g. 0x01)
	Byte	mode;           ///< Mode Flags
	Byte	opcode;         ///< Opcode
	Byte	data[];         ///< Variable length data payload (includes 0xF7 Sysex terminator)
} MIOCMessage;

// MIOC processor structure
typedef struct _MIOCProcessor {
	Byte	type;
	Byte	port;
	Byte	channel;
	Byte	parameters[1];
} MIOCProcessor;

// Pretty-printing functions
/**
 * @brief Generate human-readable string for MIOC processor
 * @param p Pointer to MIOCProcessor structure
 * @return Autoreleased NSString describing the processor
 */
static NSString * MIOCProcessorString(const MIOCProcessor *p);

/**
 * @brief Generate human-readable string for MIOC message
 * @param msg Pointer to MIOCMessage structure
 * @return Autoreleased NSString describing the message
 */
static NSString * MIOCMessageString(const MIOCMessage *msg);

/// ===== CONSTANTS =====
/// bytes before start of data
#define kPreambleLength			8

/// ===== Mode flags =====
#define kModeEncodedMask		(1 << 6)
#define kModeHandshakeMask		(1 << 2)
#define kModeMsgTypeMask		(0x03)


/// ===== Data Lengths =====
#define kMIOCPortNameLength		8
#define kMIOCPortCount		    8
#define kMIOCDeviceNameLength	9

/// ===== Message Types ====

#define kOpcodeDirectionMask	(1 << 6)

#define kMIOCAddRemoveMIDIProcessorOpcode 0x04
#define kMIOCAddMIDIProcessorFlag 0x80
#define kMIOCRemoveMIDIProcessorFlag 0x00 //FIXME: this was 0x80 but I believe it should be 0x00

#define kMIOCPortNamesRequestOpcode 0x42
#define kMIOCPortNamesResponseOpcode 0x02

#define kMIOCRDeviceNameRequestOpcode 0x45
#define kMIOCRDeviceNameResponseOpcode 0x05

// return which port we are connected to (we use this to test if MIOC is online and correctly connected)
#define kMIOCAllPortAddressRequestOpcode 0x78
#define kMIOCAllPortAddressResponseOpcode 0x38

#define kMIOCAcknowledgeOpcode 0x7F
#define kMIOCCancelOpcode 0x7D



/// ===== PROCESSSORS ====
// General Structure:
// Proc.-type, I/O-number, [Channel] [P0..Pn = parameters]

/// ROUTING
#define kMIOCInChannelAll			0x80
#define kMIOCOutChannelSameAsInput	0x80
#define kMIOCRoutingProcessorType   0x00

/// FILTERS
// define opcodes we plan to use
#define kMIOCInputNoteOffFilterProcessorType 0x08
#define kMIOCOutputNoteOffFilterProcessorType 0x09

#define kMIOCInputActiveSenseFilterProcessorType 0x1A
#define kMIOCOutputActiveSenseFilterProcessorType 0x1B

#define kMIOCFilterChannelAll 0x00 //OMNI

/// VELOCITY PROCESSORS
#define kMIOCInputVelocityProcessorType	0x24
#define kMIOCOutputVelocityProcessorType	0x25


static NSString * MIOCProcessorString(const MIOCProcessor *p) {

	switch (p->type) {
			// Routing
		case kMIOCRoutingProcessorType:
			return [NSString stringWithFormat:@"Routing [IN %d, c%d] -> [OUT %d, c%d]", p->port+1, p->channel, p->parameters[0]+1, p->parameters[1]];

			//Filters
		case kMIOCInputNoteOffFilterProcessorType:
			return [NSString stringWithFormat:@"NoteOff Filter [IN %d, c%d]", p->port+1, p->channel];

		case kMIOCOutputNoteOffFilterProcessorType:
			return [NSString stringWithFormat:@"NoteOff Filter [OUT %d, c%d]", p->port+1, p->channel];

		case kMIOCInputActiveSenseFilterProcessorType:
			return [NSString stringWithFormat:@"ActiveSense Filter [IN %d]", p->port+1];

		case kMIOCOutputActiveSenseFilterProcessorType:
			return [NSString stringWithFormat:@"ActiveSense Filter [OUT %d]", p->port+1];

			// Velocity
		case kMIOCInputVelocityProcessorType:
			return [NSString stringWithFormat:@"Velocity Processor [IN %d, c%d] %.2f (%u) %.2f +%u", p->port+1, p->channel, p->parameters[2]/8.0, p->parameters[1], p->parameters[3]/8.0, p->parameters[4] ];

		case kMIOCOutputVelocityProcessorType:
			return [NSString stringWithFormat:@"Velocity Processor (OUT) [OUT %d, c%d] %.2f (%u) %.2f +%u", p->port+1, p->channel, p->parameters[2]/8.0, p->parameters[1], p->parameters[3]/8.0, p->parameters[4] ];

		default: return [NSString stringWithFormat:@"Unknown processor (0x%x)", p->type];
	}
}


static NSString *MIOCMessageString(const MIOCMessage *m) {

	NSString *str;
	Byte opcode = m->opcode;

	switch (opcode) {
		/// Processors
		case kMIOCAddRemoveMIDIProcessorOpcode: {
			Byte addremove = m->data[0] & 0x80;
			MIOCProcessor *p = (MIOCProcessor *)&m->data[1];
			return [NSString stringWithFormat:@"%@: %@", addremove?@"Add":@"Remove", MIOCProcessorString(p)]; }

		/// Port Names
		case kMIOCPortNamesRequestOpcode:
			return @"Port Names Request";
		case kMIOCPortNamesResponseOpcode: {
			NSString *names = [[[NSString alloc] initWithBytes: &m->data length:2*kMIOCPortCount*kMIOCPortNameLength encoding:NSASCIIStringEncoding] autorelease];
			return [NSString stringWithFormat:@"Port Names Response: '%@'", names]; }

		/// Device Name
		case kMIOCRDeviceNameRequestOpcode:
			return @"Device Name Request";
		case kMIOCRDeviceNameResponseOpcode: {
			NSString *devName = [[[NSString alloc] initWithBytes: &m->data[0] length:kMIOCDeviceNameLength encoding:NSASCIIStringEncoding] autorelease];
			return [NSString stringWithFormat:@"Device Name Response: '%@'", devName]; }

		/// Port Address
		case kMIOCAllPortAddressRequestOpcode:
			return @"Port Connection Request";
		case kMIOCAllPortAddressResponseOpcode:
			return [NSString stringWithFormat:@"Port Connection Response: IN %d, OUT %d", m->data[1], m->data[0]];

		/// Handshaking
		case kMIOCAcknowledgeOpcode:
			return @"ACK: Handshake Acknowledge";
		case kMIOCCancelOpcode:
			return @"CANCEL: Abort Transmission";

		default: return [NSString stringWithFormat:@"Unknown MIOC Message (0x%x)", opcode];
	}
}
