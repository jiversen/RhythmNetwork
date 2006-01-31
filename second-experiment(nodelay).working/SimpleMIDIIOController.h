/* SimpleMIDIIOController */

#import <Cocoa/Cocoa.h>

@class MIOCModel, MIDIIO;

@interface SimpleMIDIIOController : NSObject
{
	MIDIIO				 *ioObject;
	MIOCModel			 *deviceObject;
    IBOutlet NSTextField *messageToSend;
    IBOutlet NSTextView  *response;
}

- (SimpleMIDIIOController *)init;
- (void)dealloc;

- (void)awakeFromNib;

- (IBAction)SendAction:(id)sender;
- (void)receiveSysexData:(NSData *)data;


@end
