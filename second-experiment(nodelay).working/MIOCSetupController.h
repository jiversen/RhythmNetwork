/* MIOCSetupController */

//manage setup drawer for MIOC device

#import <Cocoa/Cocoa.h>

@class MIOCModel;

@interface MIOCSetupController : NSObject
{
	IBOutlet NSDrawer		*_myDrawer;
	IBOutlet MIOCModel		*_deviceObject;
	IBOutlet NSTextField	*_MIOCName;
	IBOutlet NSPopUpButton	*_sourcePopup;
    IBOutlet NSPopUpButton	*_destinationPopup;
	IBOutlet NSTextField	*_messageToSend;
    IBOutlet NSTextView		*_response;
	IBOutlet NSForm			*_inForm;
	IBOutlet NSForm			*_outForm;
}

- (void) awakeFromNib;
- (void) dealloc;

- (MIOCModel *) deviceObject;

- (IBAction) resetMIOCAction:(id)sender;

- (void) populatePopups; 
- (IBAction) SendAction:(id)sender;
- (IBAction) ConnectAction:(id)sender;
- (IBAction) DisconnectAction:(id)sender;

- (void) receiveSysexData:(NSData *)data;

- (IBAction) selectDestination:(id)sender;
- (IBAction) selectSource:(id)sender;
- (IBAction) toggle:(id)sender;
@end
