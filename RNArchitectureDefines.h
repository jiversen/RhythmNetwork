//
//  RNArchitectureDefines.h
//  RhythmNetwork
//
//  Created by John R. Iversen on 2025-06-26.
//

// @BUILD_FINGERPRINT

#ifndef RNArchitectureDefines_h
#define RNArchitectureDefines_h

// ====== MIDI ======
#define kNumMIDIChans	16
#define kNumMIDINotes	128

// Trigger to MIDI 'concentrators'
#define kNumConcentrators 4 // Max number of TMC-6 devices (based on available ports on MIOC
#define kNumInputsPerConcentrator 3 // TMC-6 has 6 inputs; 08/06/2025 change to 3 (for group of 6) to reduce congestion


// MIOC Ports
#define kBigBrotherPort 8 // MIOC port used to monitor all activity, deliver stimuli and program MIOC
#define kPatchThruPort 7  // MIOC port for adding varying velocity processors
#define kDelayPort 6	// MIOC port for delay messages

// MIDI Channel & Note definitions NOTE: all of our 'channel' defintions are 1-based, so true MIDI channel is x-1
#define kBigBrotherControlChannel 1
#define kBigBrotherChannel 16

// MIDI Constants
#define kBaseNote 64		// Tappers each identified with a unique note number beginning with this
#define kStimulusNoteVelocity	127 // Velocity for metronome events

// CONFIGURATION
#define kDoEmitNoteOff FALSE // whether to send out note-off events
#define kNoteOffDelay_ms 200

#define kSelfFeedbackNoDelayThroughMIOC TRUE //route self-feedback through MIOC, not CoreMIDI router, for reduced latency


// ====== Network Architecture =======

// Maximum number of tappers
//#define kMaxNodes (255 - kBaseNote) //based on unique notes, but we are limited to midi channels and are further currently limited by the number of trigger-midi inputs to 12
#define kMaxNodes 16 // Maximum number of tappers

// utilty
#define FEQ(a,b) fabs(a-b) < 1e9

// Types
typedef UInt16 RNNodeNum_t; //TODO: consider making this float so I can add stim channel

// Define mapping from node number (1-based) to port, channel, note
// as of July 2025, we're using channel = tapper ID and note is unique to node
// these don't do any bounds checking, but recal node 1->channel 0; node 0->kBigBrotherChannel (16)

// port depends on how many tappers per trigger to MIDI device concentrated into a port. NB 1-based
static inline Byte portForNode(RNNodeNum_t node) {
	return (node == 0) ? kBigBrotherPort :
	((node-1) / kNumInputsPerConcentrator) + 1;
}

// channel is the same as the port number for tappers. NB this is 0-based MIDI channel counting
static inline Byte channelForNode(RNNodeNum_t node) {
	return (node == 0) ? kBigBrotherChannel : node-1;
}

// for now, all stimuli use same note, but could use notes below kBaseNote in future (e.g. noteForNode - (stimNo-1))
static inline Byte noteForNode(RNNodeNum_t node) {
	return (node == 0) ? kBaseNote :
	kBaseNote + node;
}

//reverse lookup--channel completely determines the node (actually, only for tappers)
//static inline RNNodeNum_t nodeForChannel(Byte channel) {
//	return (channel==kBigBrotherChannel) ? 0 : channel+1;
//}

//reverse lookup--Note completely determines the node (for tappers and BB)
static inline RNNodeNum_t nodeForNote(Byte note) {
	return note - kBaseNote;
}


#endif /* RNArchitectureDefines_h */
