/* RNController */

#import <Cocoa/Cocoa.h>

//conversion factor
#define kNStoS	1000000000

@class RNNetworkView;
@class MIOCSetupController;
@class RNExperiment;
@class RNNetwork;

@interface RNController : NSWindowController
{
	RNExperiment *_experiment;
    IBOutlet RNNetworkView *_networkView;
	IBOutlet MIOCSetupController *_MIOCController;
	IBOutlet NSTextField *_titleText; //we are these fields' delegate
	IBOutlet NSTextView *_notesText;
	IBOutlet NSButton *_loadButton;
	IBOutlet NSButton *_saveButton;
	IBOutlet NSButton *_startButton;
	IBOutlet NSTableView *_experimentPartsTable;
	IBOutlet NSArrayController *_experimentPartsController;
	IBOutlet NSButton *_testPartButton;
	IBOutlet NSButton *_testStopButton;
	IBOutlet NSTextField *_experimentTimer;
	NSTimer *_experimentTimerTimer;
}

- (void) awakeFromNib;
- (void) dealloc;

- (MIOCSetupController *) MIOCController;

- (void) programMIOCWithNetwork:(RNNetwork *)newNet;

- (void) newStimulusNotificationHandler: (NSNotification *) notification;
- (void) newNetworkNotificationHandler: (NSNotification *) notification;

- (void) synchronizePartsListSelection;

- (void)loadSaveAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)startSaveAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (IBAction)loadExperiment:(id)sender;
- (IBAction)startExperiment:(id)sender;
- (IBAction)stopExperiment:(id)sender;
- (IBAction)saveExperiment:(id)sender;
- (IBAction)testPart:(id)sender;
- (IBAction)stopTestPart:(id)sender;

- (void) updateExperimentTimer: (NSTimer *) timer;
- (void) experimentEndNotificationHandler: (NSNotification *) notification;


@end
