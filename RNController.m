#import "RNController.h"

#import "RNExperiment.h"
#import "RNExperimentPart.h"
#import "RNNetwork.h"
#import "RNNetworkView.h"
#import "MIOCModel.h"
#import "MIDIIO.h"

#import "MIOCSetupController.h"
#import "RNTapperNode.h"
#import "RNStimulus.h"
#import <CoreAudio/HostTime.h>

@implementation RNController

- (void) awakeFromNib
{
	//set up the UI to reflect no-experiment open
	//e.g. disable start-experiment, save-experiment, text fields
	[_titleText setEnabled:NO];
	[_notesText setEditable:NO];
	[_saveButton setEnabled:NO];
	[_startButton setEnabled:NO];
	[_testPartButton setEnabled:NO];
	[_testStopButton setEnabled:NO];
	
	//register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(newStimulusNotificationHandler:) 
												 name:@"newStimulusNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(newNetworkNotificationHandler:) 
												 name:@"newNetworkNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(experimentEndNotificationHandler:) 
												 name:@"experimentHasEndedNotification" object:nil];
	
	[_experimentTimer setFont:[NSFont fontWithName:@"Helvetica" size:16]];
	[_experimentTimer setStringValue:@"  -:--"];
}

- (void) dealloc
{
	
	[_experiment autorelease];
	_experiment = nil;
	[super dealloc];
}

- (MIOCSetupController *) MIOCController
{
	return _MIOCController;
}

- (void)loadSaveAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	
    if (returnCode == NSAlertFirstButtonReturn) { //OK: save it first
		[self saveExperiment:nil];
		[self loadExperiment:nil];
    } else if (returnCode == NSAlertSecondButtonReturn) {
		[_experiment setNeedsSave:NO];
		[self loadExperiment:nil];
	} //cancel: do nothing
}

- (IBAction)loadExperiment:(id)sender;
{	
	int result;	
	
	//if an experiment is already loaded, and needs saving, check first
	if (_experiment != nil && [_experiment needsSave]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"OK"];
		[alert addButtonWithTitle:@"Don't save"];
		[alert addButtonWithTitle:@"Cancel"];
		[alert setMessageText:@"Save current experiment data?"];
		[alert setInformativeText:@"Before you load a new experiment, would you like to save the current one? If not, all data will be lost."];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		[alert beginSheetModalForWindow:[self window] 
						  modalDelegate:self
						 didEndSelector:@selector(loadSaveAlertDidEnd:returnCode:contextInfo:) 
							contextInfo:nil];
		return;
	}

		
	//load it
    NSArray *fileTypes = [NSArray arrayWithObject:@"netdef"];
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];	
    [oPanel setAllowsMultipleSelection:NO];
    result = [oPanel runModalForDirectory:NSHomeDirectory()
								     file:nil types:fileTypes];
    if (result == NSOKButton) {		
		
		//clear out the old one
		if (_experiment != nil) {
			[[[_MIOCController deviceObject] MIDILink] removeMIDIListener:_networkView];
			[_networkView setNetwork:nil];
			
			[_experimentPartsController setSelectedObjects:[NSArray array]]; //??pass empty array to clear?
			[_experimentPartsController setContent:nil];
			[_testPartButton setEnabled:NO];

			[_titleText setStringValue:@""];
			[_titleText setEnabled:NO];
			[_notesText setString:@""];
			//[_notesText setEnabled:NO];
			[_experimentTimer setStringValue:@"  -:--"];
			
			[_startButton setEnabled:NO];
			[_saveButton setEnabled:NO];

			[_experiment release];
			_experiment = nil;
		}
		
		//instantiate experiment from file
        NSArray *filesToOpen = [oPanel filenames];
		NSString *filePath = [filesToOpen objectAtIndex:0];
		_experiment = [[RNExperiment alloc] initFromPath: filePath];
		
		//Configure view: current network and register view to receive midi
		[_networkView setNetwork: [_experiment currentNetwork]];	
		[[[_MIOCController deviceObject] MIDILink] registerMIDIListener:_networkView];
		
		//fill in text fields (we are their delegate)
		[[self window] setTitleWithRepresentedFilename:filePath];
		[_titleText setStringValue:[_experiment experimentDescription] ];
		[_titleText setEnabled:YES];
		[_notesText setString:[_experiment	experimentNotes] ];
		[_notesText setEditable:YES];
		[_startButton setEnabled:YES];
		[_saveButton setEnabled:NO];
		
		//experiment has not started yet, so clear MIOC
		[[_MIOCController deviceObject] disconnectAll];
		
		//Bind experiment parts to List view controller
		[_experimentPartsController setContent: [_experiment experimentParts]];
		//[self synchronizePartsListSelection]; 
		if ([[_experiment experimentParts] count] > 0)
			[_testPartButton setEnabled:YES];
		//add a doubleclick handler--same as for test button (assume controller's updated by double click)
		[_experimentPartsTable setDoubleAction:@selector(testPart:)];
		[_experimentPartsTable setTarget:self];
    }
}

//keep text in experiment object in sync with UI
//title
-(void) controlTextDidEndEditing: (NSNotification *) notification
{
	id source = [notification object];
	if (source == _titleText)
		[_experiment setExperimentDescription:[_titleText stringValue] ];
}
	
-(void) textDidEndEditing: (NSNotification *) notification
{
	id source = [notification object];
	if (source == _notesText)
		[_experiment setExperimentNotes:[_notesText string] ];
}

//
- (IBAction) programMIOCWithNetwork:(id)sender
{
	if ([_experiment currentNetwork] != nil) {
		MIOCModel *device = [_MIOCController deviceObject];
		NSAssert( (device != nil), @"MIOC hasn't been initialized!");
		[device setConnectionList:[[_experiment currentNetwork] MIOCConnectionList] ];	
	}
}

//handle notifications of experiment parts becoming active
// stimulus: shedule midi, update experiment (which updates network), update view
- (void) newStimulusNotificationHandler: (NSNotification *) notification
{
	MIDIIO *io = [[_MIOCController deviceObject] MIDILink];
	
	RNStimulus *stim = (RNStimulus *) [[notification object] experimentPart];
	NSLog(@"received notification stimulus: %@", [stim description]);
	//schedule midi
	NSData *pl = [stim MIDIPacketListForExperimentStartTime:[_experiment experimentStartTimeNanoseconds] ];
	[io sendMIDIPacketList:pl];
	//update experiment
	[_experiment setCurrentStimulus:stim ForChannel:[stim stimulusChannel]];
	//update view (picks up new stimuli in network)
	[_networkView synchronizeWithStimuli];	
	
	[self synchronizePartsListSelection]; 
}

//program MIOC, documenting actual time of network instantiation,
// update experiment currentNetwork
// update  view
- (void) newNetworkNotificationHandler: (NSNotification *) notification
{
	RNExperimentPart *part = [notification object];
	RNNetwork *net = (RNNetwork *) [ part experimentPart];
	NSLog(@"received notification network: %@", [net description]);
	[part setActualStartTime:[_experiment secondsSinceExperimentStartDate] ];
	[self programMIOCWithNetwork:net];
	NSTimeInterval uncertainty = [_experiment secondsSinceExperimentStartDate] - [part actualStartTime];
	[part setStartTimeUncertainty:uncertainty];
	NSLog(@"MIOC has been programmed");
	
	[_experiment setCurrentNetwork:net];
	[_networkView setNetwork:net];
	
	[self synchronizePartsListSelection]; 
}

- (void) synchronizePartsListSelection
{
	[_experimentPartsController setSelectedObjects:[_experiment currentParts]];
}

- (void)startSaveAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo 
{
	if (returnCode == NSAlertFirstButtonReturn) { //OK: save it first
		[self saveExperiment:nil];
		//[self startExperiment:nil];
    } else if (returnCode == NSAlertSecondButtonReturn) {
		[_experiment setNeedsSave:NO]; //Don't save
		[self startExperiment:nil];
	} //cancel: do nothing
}

- (IBAction)startExperiment:(id)sender
{
	UInt64	startTimeDelay_ns, now_ns, now2_ns, now, now2, maxPossibleError_ns;
	startTimeDelay_ns =  5 * (UInt64) 1000000000; //***later: pull from UI
	
	NSAssert( (_experiment != nil), @"should never happen--starting, but no experiment");
	// if current experiment needs saving, check
	if ([_experiment needsSave]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"OK"];
		[alert addButtonWithTitle:@"Don't save"];
		[alert addButtonWithTitle:@"Cancel"];
		[alert setMessageText:@"Save current experiment data?"];
		[alert setInformativeText:@"Before you restart this experiment, would you like to save the current data? If not, all data will be lost."];
		[alert setAlertStyle:NSWarningAlertStyle];
		
		[alert beginSheetModalForWindow:[self window] 
						  modalDelegate:self
						 didEndSelector:@selector(startSaveAlertDidEnd:returnCode:contextInfo:) 
							contextInfo:nil];
		return;
	}
	
	//record 'now'+ n sec delta as experiment start time
	// we have two time references--one defined by HostTime, the other by NSDate
	// ***best: find a way to convert between the two
	// for now: get a measure of the maximum possible error between the two and complain if it's large
	// so far, I've seen always < 0.1 ms, which is acceptable
	// note, found that repeating the code 2x results in much closer match--likely due to it all being in cache
	
	now = AudioGetCurrentHostTime();
	NSDate *startDate = [NSDate date];
	now2 = AudioGetCurrentHostTime();
		
	now = AudioGetCurrentHostTime();
	startDate = [NSDate date];
	now2 = AudioGetCurrentHostTime();
	//convert to ns, judge error
	now_ns = AudioConvertHostTimeToNanos(now);
	now2_ns = AudioConvertHostTimeToNanos(now2);
	maxPossibleError_ns = now2_ns - now_ns;
	UInt64 granularity = AudioGetHostClockMinimumTimeDelta();
	UInt64 granularity_ns = AudioConvertHostTimeToNanos(granularity);
	//test error
	NSLog(@"\n\tStart Time max possible error: %g ms (granularity = %d; %qu ns)", maxPossibleError_ns / 1000000.0 , granularity, granularity_ns);
	NSAssert1( (maxPossibleError_ns < 200000), @"Time Uncertainty > 0.2 ms (%g ms)", maxPossibleError_ns / 1000000.0 );
	
	//now advance these times by start time delay
	now_ns = startTimeDelay_ns + (now_ns + now2_ns) / 2; //split the difference between the two estimates
	startDate = [[[NSDate alloc] initWithTimeInterval: (startTimeDelay_ns/kNStoS) sinceDate:startDate] autorelease];
		
	[_experiment prepareToStartAtTimestamp: AudioConvertNanosToHostTime(now_ns) 
								 StartDate: startDate ];
	
	[_experiment startRecordingFromDevice:[_MIOCController deviceObject] ];
	
	//synchronize view
	[_networkView synchronizeWithStimuli];
	
	//change UI state
	[_startButton setTitle:@"Stop Experiment"];
	[_startButton setAction:@selector(stopExperiment:)];
	//[_startButton setKeyEquivalent:@"\r"];	//takes 10% cpu just to flash button!
	[_saveButton setEnabled:NO];
	[_testPartButton setEnabled:NO];
	[_loadButton setEnabled:NO];
		
	//sanity check: we're done initialization; make sure start time hasn't passed us by
	NSDate *rightNow = [NSDate date];
	NSTimeInterval timeUntilStart_s = [startDate timeIntervalSinceDate:rightNow];
	NSLog(@"\n\tStartTime: %@\n\t(Now: %@)\n\t%.3f s before start", startDate, [rightNow description], timeUntilStart_s);
	NSAssert( (timeUntilStart_s > 0), @"Problem: start time has already passed, init taking too long");
	
	//setup experiment timer timer
	_experimentTimerTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 
															target:self 
														  selector:@selector(updateExperimentTimer:) 
														  userInfo:nil 
														   repeats:YES] retain];
	
	//from here, experiment is automatically carried out via timers
	// ending naturally with experiment's stop, or via user action stopExperiment
}

- (void) updateExperimentTimer: (NSTimer *) timer
{
	NSMutableString *timerStr;
	NSTimeInterval secsSinceStart = [_experiment secondsSinceExperimentStartDate];
	NSCalendarDate *experimentTime = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate:fabs(secsSinceStart)];
	NSString *temp = [experimentTime descriptionWithCalendarFormat:@"%M:%S"];
	if (secsSinceStart < 0)
		timerStr = [NSMutableString stringWithString: @"-"];
	else
		timerStr = [NSMutableString stringWithString: @" "];
	[timerStr appendString:temp];
	[_experimentTimer setStringValue:timerStr];
}

//if experiment stops itself (e.g. at end of allotted time) it'll notify us
- (void) experimentEndNotificationHandler: (NSNotification *) notification
{
	//stop time counter
	[_experimentTimerTimer invalidate];
	[_experimentTimerTimer autorelease];
	_experimentTimerTimer = nil;
	
	//UI State
	[_saveButton setEnabled:YES];
	[_startButton setTitle:@"Start Experiment"];
	[_startButton setAction:@selector(startExperiment:)];
	[_startButton setKeyEquivalent:@""];
	[_loadButton setEnabled:YES];
	[_testPartButton setEnabled:YES];
}

//stop button handler
- (IBAction)stopExperiment:(id)sender
{
	[_experiment stop]; //this will send a  notification back to us, so handle the rest in that handler	
}

- (IBAction)saveExperiment:(id)sender
{
	
	//synchronize object with UI data (mainly in case we never left the notes field, in which case it wouldn't have
	//	been in sync
	[_experiment setExperimentDescription:[_titleText stringValue] ];
	[_experiment setExperimentNotes:[_notesText string] ];
	
	int result;	
	NSString *fileName = @"test.experiment";
    NSSavePanel *sPanel = [NSSavePanel savePanel];	
    result = [sPanel runModalForDirectory:NSHomeDirectory()
								     file:fileName];
    if (result == NSOKButton) {		
		NSString *filePath = [sPanel filename];
		[_experiment saveToPath: filePath];
		[_saveButton setEnabled:NO];
	}
}

//
- (IBAction)doubleClickPart:(id)sender
{
	int row = [sender clickedRow];
}

//
- (IBAction)testPart:(id)sender
{
	RNExperimentPart *testPart;
	NSArray *selectedParts = [_experimentPartsController selectedObjects];
	if ([selectedParts count] == 0)
		return;
	testPart = [selectedParts objectAtIndex:0];
	[_experimentPartsController setSelectedObjects: [NSArray arrayWithObject:testPart] ]; //visually indicate we only test the first selected one
	
	[_experimentTimer setStringValue:@"  -:--"]; //to make clear that experiment is not running
	
	if ([[testPart partType] isEqualToString: @"RNStimulus"]) {
		//Play Stimulus
		MIDIIO *io = [[_MIOCController deviceObject] MIDILink];
		UInt64 now_ns = AudioConvertHostTimeToNanos(AudioGetCurrentHostTime()) + 1000000; //1ms later
		NSData *pl = [[testPart experimentPart] MIDIPacketListForExperimentStartTime:now_ns ];
		[io sendMIDIPacketList:pl];
		[_testStopButton setEnabled:YES];
	} else if ([[testPart partType] isEqualToString: @"RNNetwork"]) {
		//Program network
		[self programMIOCWithNetwork:[testPart experimentPart]];
		[_networkView setNetwork:[testPart experimentPart]];
	}
	
}

//stop any ongoing stimuli started by testPart
- (IBAction)stopTestPart:(id)sender
{
	MIDIIO *io = [[_MIOCController deviceObject] MIDILink];
	[io flushOutput];
	[_testStopButton setEnabled:NO];
}

@end
