//
//  RNExperiment.m
//  RhythmNetwork
//
//  Created by John Iversen on 1/24/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

#import "RNExperiment.h"

#import "RNExperimentPart.h"
#import "RNStimulus.h"
#import "RNNetwork.h"
#import "RNGlobalConnectionStrength.h"
#import "RNBBNode.h"
#import "MIDIIO.h"
#import "MIOCModel.h"
#import <CoreAudio/HostTime.h>

#define kInitialEventCapacity 10000 

@implementation RNExperiment


- (RNExperiment *) initFromPath: (NSString *) filePath
{
	self = [super init];
	
	//initialize from file
	_definitionFilePath = [filePath copy];
	_definitionDictionary = [[NSDictionary dictionaryWithContentsOfFile:filePath] retain];
	NSAssert1( (_definitionDictionary != nil), @"File doesn't contain valid dictionary: %@", filePath);
	
	//grab general structural information: number of nodes and stimulus channels
	NSDictionary *networkSize = [_definitionDictionary valueForKey:@"networkSize"];
	
	[self initializeExperimentPartsWithArray: [_definitionDictionary valueForKey:@"experimentParts"] 
							 NetworkSizeDict: networkSize];
		
	//initialize others
	_experimentDescription	= [[_definitionDictionary valueForKey:@"description"] copy];
	_experimentNotes		= [[_definitionDictionary valueForKey:@"notes"] copy];
	NSNumber *durationNum = [_definitionDictionary valueForKey:@"experimentDuration"];
	NSAssert1( (durationNum != nil), @"Experiment Part is missing experimentDuration: %@", _definitionDictionary);
	_experimentDuration_s	= [durationNum doubleValue];
	
	_recordedEvents = [[NSMutableData dataWithCapacity: (sizeof(NoteOnMessage) * kInitialEventCapacity)] retain];
	

	[self setNeedsSave:NO];
	
	return self; 
}

- (void) initializeExperimentPartsWithArray: (NSArray *) partArray NetworkSizeDict: (NSDictionary *) sizeDict
{
	NSMutableDictionary 	*aDict;
	RNExperimentPart		*part;
	NSArray				*subPartArray;
		
	NSEnumerator *partEnumerator = [partArray objectEnumerator];
	_experimentParts = [[NSMutableArray arrayWithCapacity:[partArray count]] retain];

	while (aDict = [partEnumerator nextObject]) {
		aDict = [NSMutableDictionary dictionaryWithDictionary:aDict];
		[aDict addEntriesFromDictionary:sizeDict]; 		//add size info to aDict
		subPartArray = [RNExperimentPart experimentPartArrayFromDictionary: aDict];
		[_experimentParts addObjectsFromArray:subPartArray];
		
		//take the first one, and initialize current network
		// note, since experiment has not started yet, the MIOC is not programmed
		if ([subPartArray count] == 1) {
			part = subPartArray[0]; //grab the first (and only) part
			if ([[part partType] isEqualToString:@"RNNetwork"]) {
				if ([part startTime] == 0)
					[self setCurrentNetwork:[part experimentPart] ];
			}
		}
		
	} //enumerate over part-defining dictionaries
}

- (void) dealloc
{
	[_definitionFilePath autorelease];
	[_definitionDictionary autorelease];
	[_experimentParts autorelease];
	[_experimentStartDate autorelease];
	[_experimentEndTimer invalidate];
	[_experimentEndTimer autorelease];
	[_recordedEvents autorelease];
	[_experimentDescription autorelease];
	[_experimentNotes autorelease];
	[_experimentSaveFilePath autorelease];
	[_experimentSaveDictionary autorelease];
	
	_definitionFilePath = nil;
	_definitionDictionary = nil;
	_experimentParts = nil;
	_currentNetwork = nil;
	_experimentStartDate = nil;
	_experimentEndTimer = nil;
	_recordedEvents = nil;
	_experimentDescription = nil;
	_experimentNotes = nil;
	_experimentSaveFilePath = nil;
	_experimentSaveDictionary = nil;
	[super dealloc];
}

// *********************************************
//    Accessors
// *********************************************
#pragma mark  ACCESSORS

// *********************************************
//    Structure
#pragma mark  Structure

//path to file that defined us
- (NSString *) definitionFilePath
{
	return _definitionFilePath;
}

//return currently 'active' network
- (RNNetwork *) currentNetwork
{
	return _currentNetwork;
}

//new network: update current network, grab current stimuli and initialize network
- (void) setCurrentNetwork: (RNNetwork *) newNet
{
	if (_currentNetwork != newNet) {		
		_currentNetwork = newNet; //networks 'live' in experimentParts, so don't need to retain
		[_currentNetwork setStimulusArray:[self currentStimulusArray]];
	}
}

- (RNStimulus *) currentStimulusForChannel: (Byte) stimulusChannel
{
	return _currentStimulusArray[stimulusChannel];
}

//new stimulus: update current stimuli, update network
- (void) setCurrentStimulus: (RNStimulus *) stim ForChannel: (Byte) stimulusChannel
{
	_currentStimulusArray[stimulusChannel]=stim;
	[[self currentNetwork] setStimulus:stim ForChannel:stimulusChannel];
}

- (RNStimulus **) currentStimulusArray
{
	return _currentStimulusArray;
}

- (RNGlobalConnectionStrength *) currentGlobalConnectionStrength
{
	return _currentGlobalConnectionStrength;
}

- (void) setCurrentGlobalConnectionStrength: (RNGlobalConnectionStrength *) newConnectionStrength
{
	_currentGlobalConnectionStrength = newConnectionStrength;
}

- (NSArray *) experimentParts
{
	return _experimentParts;
}

//enumerate thru parts, returning one containing object (nil of none)
- (RNExperimentPart *) experimentPartContainingObject:(id)aPart
{
	NSEnumerator *partEnumerator = [[self experimentParts] objectEnumerator];
	RNExperimentPart *part;
	while (part = [partEnumerator nextObject]) {
		if ([part containsObject:aPart])
			return part;
	}
	return nil;
}

//return experiment part objects that are 'current'
- (NSArray *) currentParts
{
	NSAssert( ([self currentNetwork] != nil), @"no current network");
	
	unsigned int iStim, nStim = [[self currentNetwork] numStimulusChannels];

	//look at all active stimuli
	NSMutableArray *currentParts = [NSMutableArray arrayWithCapacity:(nStim+1)];
	RNStimulus *stim;
	RNExperimentPart *part;
	for (iStim = 1; iStim <= nStim; iStim++) {
		stim = [[self currentNetwork] stimulusForChannel:iStim];
		if (stim != nil) {
			part = [self experimentPartContainingObject:stim];
			NSAssert1( (part != nil), @"couldn't find part containing stimulus %@", stim);
			[currentParts addObject: part];
		}
	}
	//add active network
	[currentParts addObject:[self experimentPartContainingObject:[self currentNetwork]] ];
	
	//add active global connection strength
	if ([self currentGlobalConnectionStrength] != nil) 
	[currentParts addObject:[self experimentPartContainingObject:[self currentGlobalConnectionStrength]] ];
	
	return [NSArray arrayWithArray:currentParts]; //return unmutable
}

// *********************************************
//    Time
// 
#pragma mark  Time

- (NSDate *) experimentStartDate { return _experimentStartDate; }
- (void) setExperimentStartDate: (NSDate *) newExperimentStartDate
{
    if (_experimentStartDate != newExperimentStartDate) {
        [_experimentStartDate autorelease];
        _experimentStartDate = [newExperimentStartDate copy];
    }
}

- (MIDITimeStamp) experimentStartTimestamp { return _experimentStartTimestamp; }
- (void) setExperimentStartTimestamp: (MIDITimeStamp) newExperimentStartTimestamp
{
    _experimentStartTimestamp = newExperimentStartTimestamp;
}
//convenience
- (UInt64) experimentStartTimeNanoseconds 
{
	return AudioConvertHostTimeToNanos(_experimentStartTimestamp);
}
- (NSTimeInterval) secondsSinceExperimentStartDate
{
	return ( - [[self experimentStartDate] timeIntervalSinceNow]);
}

- (UInt64) nanosecondsSinceExperimentStartTimestamp
{
	return AudioConvertHostTimeToNanos(AudioGetCurrentHostTime() - [self experimentStartTimestamp] );
}

// *********************************************
//    Textual Info
// 
#pragma mark  Textual Info

- (NSString *) experimentDescription { return _experimentDescription; }
- (void) setExperimentDescription: (NSString *) newExperimentDescription
{
    if (_experimentDescription != newExperimentDescription) {
        [_experimentDescription autorelease];
        _experimentDescription = [newExperimentDescription copy];
    }
}

- (NSString *) experimentNotes { return _experimentNotes; }
- (void) setExperimentNotes: (NSString *) newExperimentNotes
{
    if (_experimentNotes != newExperimentNotes) {
        [_experimentNotes autorelease];
        _experimentNotes = [newExperimentNotes copy];
    }
}

// *********************************************
//    Recording Events
// 
#pragma mark  Recording Events

//initialize recorded events
- (void) clearRecordedEvents
{
	if (_recordedEvents != nil) {
		[_recordedEvents autorelease];
		_recordedEvents = [[NSMutableData dataWithCapacity: (sizeof(NoteOnMessage) * kInitialEventCapacity)] retain];
	}
}

//method to convert recorded events data into a string representation
- (NSString *) recordedEventsString 
{
	NoteOnMessage *eventPtr;
	size_t nEvents;
	unsigned int iEvent = 0;
	NSMutableString *eventsString;
	NSString *singleEventString;
	
	nEvents = [_recordedEvents length] / sizeof(NoteOnMessage);
	eventPtr = (NoteOnMessage *) [_recordedEvents bytes];
	eventsString = [NSMutableString stringWithCapacity:(nEvents * 32)]; //rough estimate
	
	while (iEvent < nEvents) {
		SInt64 signedEventTime_ns = UInt64ToSInt64(eventPtr->eventTime_ns);
		singleEventString = [NSString stringWithFormat:@"%qi\t%d\t%d\t%d\n", \
			signedEventTime_ns, eventPtr->channel, eventPtr->note, eventPtr->velocity];
		[eventsString appendString:singleEventString];
		eventPtr++;
		iEvent++;
	}
	
	return [NSString stringWithString:eventsString]; //make immutable
}


//here is where we receive and store incoming MIDI note on events
//  so long as we're listed as a listener, we'll store
//  note, we adjust timestamps to be relative to experiment start
- (void) receiveMIDIData: (NSData *) MIDIData
{
	NSAssert( ([MIDIData length] == sizeof(NoteOnMessage)), @"Unexpected MIDI Data size");
	
	NoteOnMessage *message = (NoteOnMessage *) [MIDIData bytes];
	UInt64 startTime_ns = AudioConvertHostTimeToNanos([self experimentStartTimestamp]);
	SInt64 experimentTime_ns = message->eventTime_ns - startTime_ns;
	message->eventTime_ns = experimentTime_ns;
	[_recordedEvents appendData:MIDIData];
}

// *********************************************
//    Saving
// 
#pragma mark  Saving

- (BOOL) needsSave { return _needsSave; }
- (void) setNeedsSave: (BOOL) flag
{
    _needsSave = flag;
}

//create dictionary for save
- (NSDictionary *) experimentSaveDictionary
{
	NSAssert( (_experimentSaveDictionary == nil), @"overwriting existing save dictionary");
	[_experimentSaveDictionary autorelease];
	
	NSMutableDictionary *temp = [NSMutableDictionary dictionaryWithCapacity:1];
	
	//now add what we want to save
	temp[@"definitionFilePath"] = _definitionFilePath;
	temp[@"definitionDictionary"] = _definitionDictionary;
	//wrap our starting timestamp in NSNumber
	NSNumber *timestamp = @([self experimentStartTimestamp]);
	temp[@"experimentStartTimestamp"] = timestamp;
	temp[@"experimentStartDate"] = _experimentStartDate;
	NSNumber *endTime = @(_experimentActualStopTime_s);
	temp[@"experimentStopTime"] = endTime;
	temp[@"recordedEvents"] = [self recordedEventsString];
	temp[@"experimentDescription"] = _experimentDescription;
	temp[@"experimentNotes"] = _experimentNotes;
	//save data on part scheduling times (note: only meaningful for network, but include all)
	NSEnumerator *partEnumerator = [_experimentParts objectEnumerator];
	RNExperimentPart *part;
	NSMutableArray *partTimingArray = [NSMutableArray arrayWithCapacity:1];
	NSDictionary *dict;
	while (part = [partEnumerator nextObject]) {
		dict = @{@"type": [part partType], \
			@"description": [[part experimentPart] description], \
			@"startTime": @([part startTime]), \
			@"actualStartTime": @([part actualStartTime]), \
			@"startTimeUncertainty": @([part startTimeUncertainty]), \
            @"subEventTimes": [part subEventTimes]?:@"" };
        // ???:jri:20050627 How sleazy is this? If subEventTimes undefined, it's nil therefore ending dict;
        // ???:jri:20141211 pretty sleazy! this now breaks modern-style dictionary definition, so use empty string when subEventTimes is empty--for this use of 'binary' form of ternary, see http://stackoverflow.com/questions/18190323/ternary-operator-assignment-in-objective-c
		[partTimingArray addObject:dict];
	}
	temp[@"partTiming"] = partTimingArray;
	
	return [NSDictionary dictionaryWithDictionary:temp];
}


// *********************************************
//    Actions
// *********************************************
#pragma mark  ACTIONS

- (void) prepareToStartAtTimestamp: (MIDITimeStamp) timestamp StartDate: (NSDate *) date
{
	[self setExperimentStartTimestamp:timestamp];
	[self setExperimentStartDate:date];
	
	//set up experiment ending timer
	NSTimeInterval interval1, interval2, uncertainty;
	NSDate *absEndTime = [[self experimentStartDate] dateByAddingTimeInterval: _experimentDuration_s]; //***add accessor
	interval1 = [absEndTime timeIntervalSinceNow];
	_experimentEndTimer = [[NSTimer scheduledTimerWithTimeInterval:interval1 
															target:self 
														  selector:@selector(stopTimerHandler:) 
														  userInfo:nil 
														   repeats:NO] retain];
	interval2 = [absEndTime timeIntervalSinceNow];
	uncertainty = interval1 - interval2;
	NSLog(@"\n\tUncertainty in experiment end timer maximum %g ms (%g - %g)", uncertainty * 1000.0, interval1, interval2);
	
	//set up experiment parts
	[self scheduleExperimentParts];

	[self clearRecordedEvents]; //controller starts recording
	
	[self setNeedsSave:YES];
}

//iterate thru experiment parts, scheduling as needed
- (void) scheduleExperimentParts
{
	RNExperimentPart *part;
	NSEnumerator *partEnumerator = [_experimentParts objectEnumerator];
	
	while (part = [partEnumerator nextObject]) {
		[part scheduleForExperimentStartTime:[self experimentStartDate]
								   Timestamp:[self experimentStartTimestamp] ];
		//set the current network and stimuli
		if ([[part partType] isEqualToString:@"RNNetwork"]) {
			if ([part startTime] == 0)
				[self setCurrentNetwork:[part experimentPart] ];
		}
	}
}

- (void) unscheduleExperimentParts
{
	RNExperimentPart *part;
	NSEnumerator *partEnumerator = [_experimentParts objectEnumerator];
	
	while (part = [partEnumerator nextObject]) 
		[part unschedule];
}

- (void) startRecordingFromDevice: (MIOCModel *) MIOC
{
	_MIOC = [MIOC retain];
	MIDIIO *io = [_MIOC MIDILink];
	[io registerMIDIListener:self];
}

- (void) stopRecording
{
	MIDIIO *io = [_MIOC MIDILink];
	[io removeMIDIListener:self];
	//remove any pending midi events
	[io flushOutput];	
}

//take care of the ending timer !!!:jri:20050923 don't actually stop-keep recording
- (void) stopTimerHandler: (NSTimer *) timer
{
	[_experimentEndTimer invalidate];
	[_experimentEndTimer autorelease];
	_experimentEndTimer = nil;
	//[self stop];
	//send notification to UI that it's stopped?
	[[NSNotificationCenter defaultCenter] postNotificationName:@"experimentOvertimeNotification" object:self];
}

- (void) stop
{
	//invalidate end timer & part timers
	NSLog(@"\n\tStopping Experiment");
	
	_experimentActualStopTime_s = [self secondsSinceExperimentStartDate];
	
	[self stopRecording];
	
	//invalidate timers for parts & end timer
	[self unscheduleExperimentParts];
	[_experimentEndTimer invalidate];
	[_experimentEndTimer autorelease];
	_experimentEndTimer = nil;
	
	[self setNeedsSave:YES];
	
	//send notification to UI that it's stopped?
	[[NSNotificationCenter defaultCenter] postNotificationName:@"experimentHasEndedNotification" object:self];
}

- (void) saveToPath: (NSString *) filePath
{
	BOOL success = [ [self experimentSaveDictionary] writeToFile:filePath atomically:YES];
	NSAssert( (success == YES), @"file did not save successfully");
	
	//consider an alternate way of saving
	[self setNeedsSave:NO];
}

@end
