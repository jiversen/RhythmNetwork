#import "RNController.h"

#import "RNExperiment.h"
#import "RNExperimentPart.h"
#import "RNNetwork.h"
#import "RNNetworkView.h"
#import "RNDataView.h"
#import "MIOCModel.h"
#import "MIDIIO.h"
#import "RNCustomButton.h"


#import "MIOCSetupController.h"
#import "MIOCConnection.h"
#import "RNTapperNode.h"
#import "RNBBNode.h"
#import "RNStimulus.h"
#import "RNGlobalConnectionStrength.h"
#import <CoreAudio/HostTime.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation RNController

- (void) awakeFromNib
{
    
	// Scale up the UI by 150%
	CGFloat scaleFactor = 2.0;
	[self applyUIScale:scaleFactor];

	// origial buttons do not do well with scaling
	_loadButton		= (NSButton *)[self replaceOldButton:_loadButton];
	_saveButton		= (NSButton *)[self replaceOldButton:_saveButton];
	_startButton		= (NSButton *)[self replaceOldButton:_startButton];
	_testPartButton 	= (NSButton *)[self replaceOldButton:_testPartButton];
	_testStopButton 	= (NSButton *)[self replaceOldButton:_testStopButton];

	// set up the UI to reflect no-experiment open
	// e.g. disable start-experiment, save-experiment, text fields
	[_titleText setEnabled:NO];
	[_notesText setEditable:NO];
	[_loadButton setEnabled:YES];
	[_saveButton setEnabled:NO];
	[_startButton setEnabled:NO];
	[_testPartButton setEnabled:NO];
	[_testStopButton setEnabled:NO];
	
	[_titleText setDelegate:self];
	
	//register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(newStimulusNotificationHandler:) 
												 name:@"newStimulusNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(newNetworkNotificationHandler:) 
												 name:@"newNetworkNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(newGlobalConnectionStrengthNotificationHandler:) 
												 name:@"newGlobalConnectionStrengthNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(experimentEndNotificationHandler:) 
												 name:@"experimentHasEndedNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(experimentOvertimeNotificationHandler:) 
												 name:@"experimentOvertimeNotification" object:nil];

		
	[_experimentTimer setFont:[NSFont fontWithName:@"Helvetica" size:16]];
	[_experimentTimer setStringValue:@"  -:--"];

	// show network view where data view is
	[_networkView setDataView:_dataView];
	[_networkView setPlotData:NO];

	[_drumSetNumber setStringValue:@"--"];

	// a few fixes for dark mode
	[_experimentPartsTable setBackgroundColor:[NSColor controlBackgroundColor]];
	[_titleText setDrawsBackground:NO];
	
}

- (void) applyUIScale:(CGFloat)scaleFactor {
    NSView *contentView = self.window.contentView;
    [self scaleSubviewsOfView:contentView byFactor:scaleFactor];

    // Resize the window to match the scaled content
    NSRect frame = self.window.frame;
    NSRect contentRect = [self.window contentRectForFrameRect:frame];

    // Scale the content size
    contentRect.size.width *= scaleFactor;
    contentRect.size.height *= scaleFactor;

    // Convert back to full window frame size (including title bar etc.)
    NSRect scaledWindowFrame = [self.window frameRectForContentRect:contentRect];

    // Optionally reposition to keep it centered
    scaledWindowFrame.origin.x -= (scaledWindowFrame.size.width - frame.size.width) / 2;
    scaledWindowFrame.origin.y -= (scaledWindowFrame.size.height - frame.size.height) / 2;

    // Apply new frame
    [self.window setFrame:scaledWindowFrame display:YES animate:NO];
    [self.window makeKeyAndOrderFront:nil];
    
    [_networkView updateDrawingMetricsForScale:scaleFactor];
    [_networkView setNeedsDisplay:YES];
}

- (void)scaleSubviewsOfView:(NSView *)view byFactor:(CGFloat)scale {
    for (NSView *subview in view.subviews) {
        // Disable constraints to allow manual sizing
        subview.translatesAutoresizingMaskIntoConstraints = YES;
        
        // Scale frame
        NSRect f = subview.frame;
        f.origin.x *= scale;
        f.origin.y *= scale;
        f.size.width *= scale;
        f.size.height *= scale;
        [subview setFrame:f];

        if ([subview respondsToSelector:@selector(font)]) {
            NSFont *font = [subview performSelector:@selector(font)];
            if (font) {
                NSFont *scaledFont = [NSFont fontWithDescriptor:font.fontDescriptor size:font.pointSize * scale];
                [subview performSelector:@selector(setFont:) withObject:scaledFont];
            }
        }

        [self scaleSubviewsOfView:subview byFactor:scale];
    }
}

- (RNCustomButton *)replaceOldButton:(NSButton *)oldButton {
    RNCustomButton *newButton = [[RNCustomButton alloc] initWithButtonToReplace:oldButton];
    newButton.translatesAutoresizingMaskIntoConstraints = YES;

    NSView *parent = oldButton.superview;
    if (parent) {
        [parent replaceSubview:oldButton with:newButton];
    }
    return newButton;
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

- (void)loadSaveAlertDidEndWithReturnCode:(NSModalResponse)returnCode {

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
	
	//if an experiment is already loaded, and needs saving, notify & give chance to save
	if (_experiment != nil && [_experiment needsSave]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"OK"];
		[alert addButtonWithTitle:@"Don't save"];
		[alert addButtonWithTitle:@"Cancel"];
		[alert setMessageText:@"Save current experiment data?"];
		[alert setInformativeText:@"Before you load a new experiment, would you like to save the current one? If not, all data will be lost."];
		[alert setAlertStyle:NSAlertStyleWarning];
		[alert beginSheetModalForWindow:[self window]
					  completionHandler:^(NSModalResponse returnCode) {
			[self loadSaveAlertDidEndWithReturnCode:returnCode];
		}];

		return;
	}

	//load it
    NSString *fileType = @"netdef";
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:NO];
	//*** starting Path: note, this is  hard coded for my laptop // !!!:jri:20050906
    NSURL *jriStartPath = [NSURL fileURLWithPathComponents: @[NSHomeDirectory(),
		@"Documents", @"matlab", @"matlab", @"projects", @"experiment_mfiles", @"rhythm_network", @"Rhythm Network", @""] ];
	
	// Load last used directory from defaults
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *lastPath = [defaults stringForKey:@"LastOpenDirectory"];
	NSURL *startPath = nil;
	if (lastPath && [[NSFileManager defaultManager] fileExistsAtPath:lastPath]) {
		startPath = [NSURL fileURLWithPath:lastPath];
	} else {
		startPath = jriStartPath;
	}
	
    [oPanel setDirectoryURL:startPath];
	oPanel.allowedContentTypes = @[ [UTType typeWithFilenameExtension:fileType] ];
    long result = [oPanel runModal];
	if (result == NSModalResponseOK) {
		
		//clear out the old one
		if (_experiment != nil) {
			[[[_MIOCController deviceObject] MIDILink] removeMIDIListener:_networkView]; //***fix, may already be removed
			[_networkView setNetwork:nil];
			
			[_experimentPartsController setSelectedObjects:@[]]; //TODO: there's another way using indexes used elsewhere
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
		NSString *filePath = [[oPanel URL] path];
		_experiment = [[RNExperiment alloc] initFromPath: filePath];
		
		// Save selected directory
		NSURL *selectedDir = [[oPanel URL] URLByDeletingLastPathComponent];
		[defaults setObject:selectedDir.path forKey:@"LastOpenDirectory"];
		
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
		
    } //Else, user hit cancel; do nothing
}

//keep text in experiment object in sync with UI title
-(void) controlTextDidEndEditing: (NSNotification *) notification
{
	id source = [notification object];
	if (source == _titleText)
		[_experiment setExperimentDescription:[_titleText stringValue] ];
}
	
//experiment notes
-(void) textDidEndEditing: (NSNotification *) notification
{
	id source = [notification object];
	if (source == _notesText)
		[_experiment setExperimentNotes:[_notesText string] ];
}

// new more general programming routine that covers both MIOC and MIDIRouting
- (void) programMIDIRoutingWithNetwork:(RNNetwork *)newNet {
	if (newNet != nil) {
		[self programMIOCWithNetwork:newNet];
		
		MIDIIO *io = [[_MIOCController deviceObject] MIDILink];
		if ([newNet MIDIRouting]) {
			[io setMIDIRoutingTable:[[newNet MIDIRouting] routingTable]];
		} else {
			[io setMIDIRoutingTable:NULL];
		}
	}
}

//
- (void) programMIOCWithNetwork:(RNNetwork *)newNet
{
	if (newNet != nil) {
		MIOCModel *device = [_MIOCController deviceObject];
		NSAssert( (device != nil), @"MIOC hasn't been initialized!");
		[device setConnectionList:[newNet MIOCConnectionList] ];	
	}
}

- (void) programMIOCVelocityProcessorsForNetwork:(RNNetwork *)newNet
{
	if (newNet != nil) {
		MIOCModel *device = [_MIOCController deviceObject];
		NSAssert( (device != nil), @"MIOC hasn't been initialized!");
		
		[device setVelocityProcessorList:[newNet MIOCVelocityProcessorList] ];	
	}
}

//handle notifications of experiment parts becoming active
// stimulus: schedule midi, update experiment (which updates network), update view
- (void) newStimulusNotificationHandler: (NSNotification *) notification
{
	MIDIIO *io = [[_MIOCController deviceObject] MIDILink];
	
	RNExperimentPart *part = [notification object];
	RNStimulus *stim = (RNStimulus *) [part experimentPart];
	NSLog(@"received notification stimulus: %@", [stim description]);
	//schedule midi
	NSData *pl = [stim MIDIPacketListForExperimentStartTime:[_experiment experimentStartTimeNanoseconds] ];
	[io sendMIDIPacketList:pl];
	//store scheduled times in experiment part
	[part setSubEventTimes:[stim eventTimes]];
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
	RNNetwork *net = (RNNetwork *) [part experimentPart];
	NSLog(@"received notification network: %@", [net description]);
	[part setActualStartTime:[_experiment secondsSinceExperimentStartDate] ];
	[self programMIDIRoutingWithNetwork:net];
	NSTimeInterval uncertainty = [_experiment secondsSinceExperimentStartDate] - [part actualStartTime];
	[part setStartTimeUncertainty:uncertainty];
	NSLog(@"MIOC has been programmed");
	
	[_experiment setCurrentNetwork:net];
	[_networkView setNetwork:net];
	
	[self synchronizePartsListSelection]; 
}

- (void) newGlobalConnectionStrengthNotificationHandler: (NSNotification *) notification
{
	RNExperimentPart *part = [notification object];
	RNGlobalConnectionStrength *weight = (RNGlobalConnectionStrength *) [part experimentPart];
	NSLog(@"received notification global connection strength: %@", [weight description]);
	[part setActualStartTime:[_experiment secondsSinceExperimentStartDate] ];
	RNNetwork *net = [_experiment currentNetwork];
	NSAssert( (net != nil), @"no current network.");
	[net setGlobalConnectionStrength:weight];
	[self programMIOCVelocityProcessorsForNetwork:net];
	NSTimeInterval uncertainty = [_experiment secondsSinceExperimentStartDate] - [part actualStartTime];
	[part setStartTimeUncertainty:uncertainty];
	NSLog(@"MIOC has been programmed with velocity processors");
	[_experiment setCurrentGlobalConnectionStrength:weight];
	
	[self synchronizePartsListSelection]; 
}


- (void) synchronizePartsListSelection
{
	[_experimentPartsController setSelectedObjects:[_experiment currentParts]];
}

- (void)startSaveAlertDidEndWithReturnCode:(NSModalResponse)returnCode
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
		[alert setAlertStyle:NSAlertStyleWarning];
		[alert beginSheetModalForWindow:[self window] 
					  completionHandler:^(NSModalResponse returnCode) {
						  [self startSaveAlertDidEndWithReturnCode:returnCode];
					  }];
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
	NSLog(@"\n\tStart Time max possible error: %g ms (granularity = %llu; %qu ns)", maxPossibleError_ns / 1000000.0 , granularity, granularity_ns);
	NSAssert( (maxPossibleError_ns < 200000), @"Time Uncertainty > 0.2 ms (%g ms)", maxPossibleError_ns / 1000000.0 );
	
	//now advance these times by start time delay
	now_ns = startTimeDelay_ns + (now_ns + now2_ns) / 2; //split the difference between the two estimates
	startDate = [[[NSDate alloc] initWithTimeInterval: (startTimeDelay_ns/kNStoS) sinceDate:startDate] autorelease];
		
	[_experiment prepareToStartAtTimestamp: AudioConvertNanosToHostTime(now_ns) 
								 StartDate: startDate ];
	
	//setup experiment timer timer
	_experimentTimerTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 
															  target:self 
															selector:@selector(updateExperimentTimer:) 
															userInfo:nil 
															 repeats:YES] retain];
	
	[_experiment startRecordingFromDevice:[_MIOCController deviceObject] ];
	
	//synchronize view
	[_networkView synchronizeWithStimuli];
	
	//clear data, start plotting
	[_dataView clearData];
	[_networkView clearData];
	[_networkView setPlotData:YES];

	
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
	
	//from here, experiment is automatically carried out via timers
	// ending naturally with experiment's stop, or via user action stopExperiment
}

- (void) updateExperimentTimer: (NSTimer *) timer
{
	NSMutableString *timerStr;
	NSTimeInterval secsSinceStart = [_experiment secondsSinceExperimentStartDate];
	NSTimeInterval modifiedSecsSinceStart = secsSinceStart;
	if (secsSinceStart < 0) {
		timerStr = [NSMutableString stringWithString: @"-"];
		modifiedSecsSinceStart = fabs(secsSinceStart) + 1;
	} else
		timerStr = [NSMutableString stringWithString: @" "];
	
	NSUInteger seconds = (NSUInteger)modifiedSecsSinceStart;
	NSString *temp = [NSString stringWithFormat:@"%02lu:%02lu", (seconds / 60), (seconds % 60)];
	[timerStr appendString:temp];
	[_experimentTimer setStringValue:timerStr];
}


//if experiment passes end of allotted time it'll notify us here--we want to keep recording
- (void) experimentOvertimeNotificationHandler: (NSNotification *) notification
{
	//change color of timer to indicate we're still going
	[_experimentTimer setTextColor:[NSColor redColor] ];
}

// once experiment has really stopped, we'll be notified here
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
	//[_startButton setKeyEquivalent:@""];
	[_loadButton setEnabled:YES];
	[_testPartButton setEnabled:YES];
	
	//stop updating plots w/ midi input
	[_networkView setPlotData:NO];
	
	//deselect parts
	[_experimentPartsController setSelectionIndexes:[NSIndexSet indexSet]];}

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
	
	//save in .experiment file w/ same name as our .netdef file
    NSURL *definitionDirectory = [NSURL fileURLWithPath:[[_experiment definitionFilePath] stringByDeletingLastPathComponent] isDirectory:TRUE];
	NSString *expFileName = [[[[_experiment definitionFilePath] lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"experiment"];
	
    NSSavePanel *sPanel = [NSSavePanel savePanel];
    [sPanel setDirectoryURL:definitionDirectory];
    [sPanel setNameFieldStringValue:expFileName];
    long result = [sPanel runModal];
	if (result == NSModalResponseOK) {
		NSString *filePath = [[sPanel URL] path];
		[_experiment saveToPath: filePath];
		[_saveButton setEnabled:NO];
	}
}

- (IBAction) setDrumSetAction:(id)sender
{
	int drumset = [_drumSetNumber intValue];
	if (_experiment == nil) {
		[_drumSetNumber setStringValue:@"ex?"];
		NSLog(@"Must load an experiment before programming drumset %d",drumset);
		return;
	}
	if (drumset < 0 || drumset > 49) {
		[_drumSetNumber setStringValue:@"??"];
		NSLog(@"Drum set number %d out of range (0 to 49)",drumset);
		return;
	}
	//create and send a program change to all drumsets (note, they may not be connected to bb, so connect first)
	[[_experiment currentNetwork] setDrumsetNumber:drumset];
	MIOCModel *device = [_MIOCController deviceObject];
	MIDIIO *io = [device MIDILink];
	
	MIOCConnection *con;
	NSArray *nodeList = [[_experiment currentNetwork] nodeList];
	RNNodeNum_t nNodes = [nodeList count];
	RNBBNode *bb = nodeList[0];
		
	//make program change message
	Byte pcMessage[2];
	//note on and off MIDI messages
	pcMessage[0] = 0xC0 + ([bb controlMIDIChannel] - 1); //NB convert to MIDI 0-based index
	pcMessage[1] = (Byte) drumset;
	//wrap
	NSData *pcData = [NSData dataWithBytes:pcMessage length:2];
	
	//hack for now--loop over network's nodes, connect each in turn to BB's control channel, send program change message
	// as is, midi data gets queued ahead of sysex connections, need to make this synchronous,
	//  easiest way for now is to simply wait...
	NSLog(@"Setting drum set to #%d",drumset);
	for (RNNodeNum_t iNode = 1; iNode < nNodes; iNode++) {
		con = [MIOCConnection connectionWithInPort:[bb sourcePort]
										 InChannel:[bb controlMIDIChannel]
										   OutPort:[nodeList[iNode] destPort]
										OutChannel:[nodeList[iNode] destChan] ];
		[device connectOne:con];
		//sleep for long enough to ensure sysex transmitted before pc
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]]; 
		if ([io sendMIDI:pcData] == NO)
			NSLog(@"could not send program change data to node %d",iNode);
		[device disconnectOne:con];
	}	
}

// unused, retire
- (IBAction)doubleClickPart:(id)sender
{
	NSAssert( (0), @"doubleClickPart is obsolete.");
	//int row = [sender clickedRow];
}

//
- (IBAction)testPart:(id)sender
{
	RNExperimentPart *testPart;
	NSArray *selectedParts = [_experimentPartsController selectedObjects];
	if ([selectedParts count] == 0)
		return;
	testPart = selectedParts[0];
	[_experimentPartsController setSelectedObjects: @[testPart] ]; //visually indicate we only test the first selected one
	
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
		RNNetwork *net = [testPart experimentPart];
		[self programMIDIRoutingWithNetwork:net];
		[_experiment setCurrentNetwork:net];
		[_networkView setNetwork:net];
		
	} else if (([[testPart partType] isEqualToString: @"RNGlobalConnectionStrength"])) {
		RNNetwork *net = [_experiment currentNetwork];
		NSAssert( (net != nil), @"no current network.");
		[net setGlobalConnectionStrength:[testPart experimentPart]];
		[self programMIOCVelocityProcessorsForNetwork:net];
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
