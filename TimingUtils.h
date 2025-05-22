//
//  TimingUtils.h
//  RhythmNetwork
//
//  Created by John R. Iversen on 2025-04-10.
//

#ifndef TimingUtils_h
#define TimingUtils_h

//#include <sys/time.h>
//#include <IOKit/serial/ioss.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>
#include <CoreMIDI/MIDIServices.h>
#include <CoreAudio/HostTime.h>
#include <stdio.h>
#include <stdint.h>
#include <libftdi1/ftdi.h>
#include <libusb-1.0/libusb.h>

#ifdef __cplusplus
extern "C" {
#endif

// Global FTDI context for FT232H bitbang use: set in initFT232H; used in emitFT232HPulse
extern struct ftdi_context _ftdiH_ctx;
extern int _ftdiH_initialized;

// Utility returns malloc'd path to first /dev/cu.usbserial-* device, or NULL if none.
// Caller must free().
char *find_usbserial_device(void);

// Open and initialize serial port for RTS pulsing.
// Returns the file descriptor, or -1 on error.
int initTimingOnFD(const char *devicePath);

// Initialize an FTDI device in bitbang mode (D1 output assumed RTS).
// Returns file descriptor or -1 on error.
int initFTDIBitbangOnFD(const char *devicePath);

// Initialize FT232H using libftdi for general-purpose bitbanging.
// Returns 0 on success, -1 on failure.
int initFT232H(void);

// FX3 Globals
#define FX3_MAX_TRANSFER_LENGTH 1024
extern unsigned char *fx3_buffer;
extern struct libusb_transfer *fx3_transfer;
extern bool fx3_device_connected;
extern bool fx3_ready; //for now, we reuse a transfer, so until we've received ack in callback, we can't use again

// Initialize connection to FX3 running usGPIO firmware
int initFX3(void);

// Emit a short RTS pulse and return the AudioGetCurrentHostTime()
// when the pulse was initiated.
static inline MIDITimeStamp emitPulseOnFD(int fd, useconds_t pulsewidth_us) {
	MIDITimeStamp now = AudioGetCurrentHostTime();

	int flags = TIOCM_RTS;
	ioctl(fd, TIOCMSET, &flags);
	usleep(pulsewidth_us);  // Pulse duration in µs
	flags = 0;
	ioctl(fd, TIOCMSET, &flags);

	return now;
}

// Emit a pulse on FTDI bitbang D1 pin (assumed RTS pin).
// High for pulsewidth_us µs, then low. Returns host timestamp at rising edge.
static inline MIDITimeStamp emitBitbangPulseOnFD(int fd, useconds_t pulsewidth_us) {
	MIDITimeStamp now = AudioGetCurrentHostTime();

	unsigned char high = 0x02;  // D1 high
	unsigned char low = 0x00;   // All low

	write(fd, &high, 1);
	usleep(pulsewidth_us);
	write(fd, &low, 1);

	return now;
}

// Emit a pulse on FT232H data pin using libftdi.
// `bitmask` indicates which bit to pulse (e.g., 0x01 = D0, 0x02 = D1, etc.)
// Returns AudioGetCurrentHostTime() at pulse start.
static inline MIDITimeStamp emitFT232HPulse(uint8_t bitmask, useconds_t pulsewidth_us) {
	if (!_ftdiH_initialized) return 0;

	MIDITimeStamp now = AudioGetCurrentHostTime();
	unsigned char value[1];

	value[0] = bitmask;
	ftdi_write_data(&_ftdiH_ctx, value, 1);
	usleep(pulsewidth_us);
	value[0] = 0x00;
	ftdi_write_data(&_ftdiH_ctx, value, 1);

	return now;
}

// FX3

static inline MIDITimeStamp emitFX3Pulse(uint8_t bitmask, int length) {
		
	if (!fx3_device_connected) {
		fprintf(stderr, "emitFX3Pulse: No device connected!\n");
		return -1;
	}
	if (!fx3_ready) {
		fprintf(stderr, "emitFX3Pulse: Not ready!\n");
		return -1;
	}
	if (length > FX3_MAX_TRANSFER_LENGTH) {
		length = FX3_MAX_TRANSFER_LENGTH;
	}
	memset(fx3_buffer, bitmask, length);
	fx3_transfer->length = length;
	MIDITimeStamp now = AudioGetCurrentHostTime();
	int r = libusb_submit_transfer(fx3_transfer);
	if (r != 0) {
		fprintf(stderr, "emitFX3Pulse: Data submit error: %s\n", libusb_error_name(r));
		return -1;
	}
	fx3_ready = false;

	fprintf(stderr,"emitFX3Pulse: Triggered %02X, length %d at host time: %llu\n", bitmask, length, now); //TODO: Remove Debug
	return now;
}

#ifdef __cplusplus
}
#endif

#endif /* TimingUtils_h */
