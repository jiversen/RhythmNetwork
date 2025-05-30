//
//  TimingUtils.c
//  RhythmNetwork
//
//  Created by John R. Iversen on 2025-04-10.
//

#include "TimingUtils.h"
#include <termios.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <libgen.h>
#include <stdlib.h>
#include <dispatch/dispatch.h>

// Global FTDI context for FT232H bitbang use
struct ftdi_context _ftdiH_ctx;
int _ftdiH_initialized = 0;

// Helper: search for /dev/cu.usbserial-*
char *find_usbserial_device(void) {
	DIR *d;
	struct dirent *dir;
	d = opendir("/dev");
	if (!d) return NULL;

	while ((dir = readdir(d)) != NULL) {
		if (strncmp(dir->d_name, "cu.usbserial", 12) == 0) {
			closedir(d);
			char *fullpath = malloc(256);
			snprintf(fullpath, 255, "/dev/%s", dir->d_name);
			return fullpath;
		}
	}
	closedir(d);
	return NULL;
}

int initTimingOnFD(const char *devicePath) {
	int fd = open(devicePath, O_RDWR | O_NOCTTY | O_NONBLOCK);
	if (fd < 0) {
		perror("open serial timing device");
		return -1;
	}
	
	// Clear all modem control lines first
	int flags = 0;
	ioctl(fd, TIOCMSET, &flags);

	// Optional: configure serial parameters here if needed
//	struct termios options;
//		if (tcgetattr(fd, &options) != 0) {
//			perror("tcgetattr");
//			close(fd);
//			return -1;
//		}
//
//	cfmakeraw(&options);
//	cfsetspeed(&options, B9600);  // Speed doesn't matter for RTS-only usage
//	
//	if (tcsetattr(fd, TCSANOW, &options) != 0) {
//		perror("tcsetattr");
//		close(fd);
//		return -1;
//	}

	return fd;
}

int initFTDIBitbangOnFD(const char *devicePath) {
	int fd = open(devicePath, O_RDWR | O_NOCTTY);
	if (fd < 0) {
		perror("open");
		return -1;
	}
	
	// Set bitbang mode using FTDI command sequence
	   // This sends the USB control transfer: Set Bit Mode (0x0B)
	   // Assuming D1 is connected to RTS
	   unsigned char setup[1] = { 0x00 }; // all pins low
	   if (write(fd, setup, 1) != 1) {
		   perror("write low state\n");
		   close(fd);
		   return -1;
	   }

	   // Enable bitbang mode on D1 (bitmask = 0x02, mode = 0x01)
	   unsigned char bitmode[2] = { 0x02, 0x01 };
	   if (write(fd, bitmode, 2) != 2) {
		   perror("write bitbang mode\n");
		   close(fd);
		   return -1;
	   }

	
	return fd;
	
}

int initFT232H(void) {
	if (_ftdiH_initialized) return 0;

	ftdi_init(&_ftdiH_ctx);
	if (ftdi_usb_open(&_ftdiH_ctx, 0x0403, 0x6014) < 0) {
		ftdi_deinit(&_ftdiH_ctx);
		return -1;
	}

	if (ftdi_set_bitmode(&_ftdiH_ctx, 0xFF, BITMODE_BITBANG) < 0) {
		ftdi_usb_close(&_ftdiH_ctx);
		ftdi_deinit(&_ftdiH_ctx);
		return -1;
	}

	_ftdiH_initialized = 1;
	return 0;
}

// FX3 Section

#define VENDOR_ID     0x08b9
#define PRODUCT_ID    0x0001
#define ENDPOINT_OUT  0x01
#define INTERFACE_NUM 0

// FX3 Globals
#define FX3_MAX_TRANSFER_LENGTH 1024
unsigned char *fx3_buffer = NULL;
struct libusb_transfer *fx3_transfer = NULL;
bool fx3_device_connected = false;
bool fx3_ready = false; //for now, we reuse a transfer, so until we've received ack in callback, we can't use again

static libusb_context *ctx = NULL;
static libusb_device_handle *handle = NULL;

//static dispatch_semaphore_t transfer_complete_sem;
static volatile uint64_t complete_time;

pthread_t event_thread;

int setup_usb_transfer(void);
void cleanup_after_disconnect(void);

int initFX3(void) {
	
	int r = libusb_init(&ctx);
	if (r < 0) {
		fprintf(stderr, "libusb_init: %s\n", libusb_error_name(r));
		return r;
	}
	
	r = setup_usb_transfer();
	if (r < 0) {
		fprintf(stderr, "libusb_init: %s\n", libusb_error_name(r));
		return r;
	}
	
	
	return EXIT_SUCCESS;
}

// Background libusb event handling thread
void *usb_event_thread(void *arg) {
	while (true) {
		int r = libusb_handle_events(ctx);
		if (r != 0) {
			fprintf(stderr, "handle_events error: %s\n", libusb_error_name(r));
		}
	}
	return NULL;
}

void cleanup_after_disconnect(void) {
	
	fx3_device_connected = false;

	if (fx3_transfer) {
		libusb_free_transfer(fx3_transfer);
		fx3_transfer = NULL;
	}

	if (handle) {
		libusb_close(handle);
		handle = NULL;
	}
	
}

// Callbacks
int LIBUSB_CALL hotplug_callback(struct libusb_context *ctx,
								  struct libusb_device *device,
								  libusb_hotplug_event event,
								  void *user_data) {
	struct libusb_device_descriptor desc;
	libusb_get_device_descriptor(device, &desc);

	if (desc.idVendor == VENDOR_ID && desc.idProduct == PRODUCT_ID) {
		if (event == LIBUSB_HOTPLUG_EVENT_DEVICE_ARRIVED) {
			fprintf(stderr, "Device is plugged in!\n");
			// Open device, setup transfer, etc
			if (setup_usb_transfer() != 0) {
				return EXIT_FAILURE;
			}
		} else if (event == LIBUSB_HOTPLUG_EVENT_DEVICE_LEFT) {
			fprintf(stderr, "Device unplugged!\n");
			// Free transfer, close handle, etc
			cleanup_after_disconnect();
		}
	}
	return 0;
}

// Transfer completion callback
void LIBUSB_CALL transfer_complete_cb(struct libusb_transfer *transfer) {
	complete_time = AudioConvertHostTimeToNanos(AudioGetCurrentHostTime());
	if (transfer->length != transfer->actual_length) {
		fprintf(stderr,"FX3 transfer incomplete: only %d of %d bytes were transfrred\n",transfer->actual_length, transfer->length);
	}
	fx3_ready = true;
	//dispatch_semaphore_signal(transfer_complete_sem);
}


// Initialize libusb and prepare transfer
int setup_usb_transfer(void) {
	int r;
	
	if (fx3_device_connected) {
		fprintf(stderr,"Error: setup called when device already connected!");
		return -1;
	}
	
	handle = libusb_open_device_with_vid_pid(ctx, VENDOR_ID, PRODUCT_ID);
	if (!handle) {
		fprintf(stderr, "Device not found. Plug in and try again.\n");
		return LIBUSB_ERROR_NO_DEVICE;
	}
	
	if (libusb_kernel_driver_active(handle, INTERFACE_NUM)) {
		r = libusb_detach_kernel_driver(handle, INTERFACE_NUM);
		fprintf(stderr, "Kernel driver active. Detach result (%d): %s\n", r, libusb_error_name(r));
		if (r) {
			libusb_close(handle);
			libusb_exit(ctx);
			return r;
		}
	}
	
	r = libusb_claim_interface(handle, INTERFACE_NUM);
	if (r) {
		fprintf(stderr, "Cannot claim interface: %s\n", libusb_error_name(r));
		libusb_close(handle);
		libusb_exit(ctx);
		return r;
	}
	
	fx3_buffer = aligned_alloc(64, FX3_MAX_TRANSFER_LENGTH);
	if (!fx3_buffer) {
		fprintf(stderr, "Buffer allocation failed\n");
		libusb_close(handle);
		libusb_exit(ctx);
		return -1;
	}
	memset(fx3_buffer, 0, FX3_MAX_TRANSFER_LENGTH);
	
	fx3_transfer = libusb_alloc_transfer(0);
	if (!fx3_transfer) {
		fprintf(stderr, "Transfer allocation failed\n");
		free(fx3_buffer);
		libusb_close(handle);
		libusb_exit(ctx);
		return -1;
	}
	
	struct libusb_config_descriptor *config;
	r = libusb_get_active_config_descriptor(libusb_get_device(handle), &config);
	if (r == 0) {
		printf("Device has %d interfaces\n", config->bNumInterfaces);
		for (int i = 0; i < config->bNumInterfaces; i++) {
			const struct libusb_interface_descriptor *intf = &config->interface[i].altsetting[0];
			printf("  Interface %d: class=0x%02x, numEndpoints=%d\n",
				   intf->bInterfaceNumber, intf->bInterfaceClass, intf->bNumEndpoints);
		}
		libusb_free_config_descriptor(config);
	} else {
		fprintf(stderr, "Cannot get active config descriptor: %s\n", libusb_error_name(r));
	}
	
	fprintf(stderr, "Successfully configured device\n");
	fx3_device_connected = true;
	return 0;
}

