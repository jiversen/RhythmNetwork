//
//  RNExperiment.m
//  RhythmNetwork
//
//  Created by John Iversen on 1/24/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "RNExperiment.h"

#import "RNStimulus.h"
#import "RNNetwork.h"
#import "MIDIIO.h"
#import <CoreAudio/HostTime.h>

#define kInitialEventCapacity 10000 

@implementation RNExperiment


- (RNExperiment *) initFromPath: (NSString *) filePath
{
	self = [super init];
	
	//initialize from file
	// first phase--load a single stimulus and network
	// second phase--load a sequence of such
	_definitionFilePath = [filePath copy];
	_definitionDictionary = [[NSDictionary dictionaryWithContentsOfFile:filePath] retain];
	NSAssert1( (_definitionDictionary != nil), @"File doesn't contain valid dictionary: %@", filePath);
	_experimentParts = nil; //***not  yet used
	
	//initialize stimulus
	NSString *stimulusString = [_definitionDictionary valueForKey:@"Stimulus"];
	NSAssert( (stimulusString != nil), @"File is missing a Stimulus");
	_stimulus = [[RNStimulus alloc] initWithString: stimulusString];
	NSAssert( (_stimulus != nil), @"Problem initializing stimulus");

	
	//initialize network
	_network = [[RNNetwork alloc] initFromDictionary: (NSDictionary *) _definitionDictionary];
	NSAssert( (_network != nil), @"Problem initializing network");
	
	//initialize others
	_experimentDescription	= [[_definitionDictionary valueForKey:@"Description"] copy];
	_experimentNotes		= [[_definitionDictionary valueForKey:@"Notes"] copy];
	_experimentDuration_s	= [[_definitionDictionary valueForKey:@"ExperimentDuration"] doubleValue];
	
	_recordedEvents = [[NSMutableData dataWithCapacity: (sizeof(NoteOnMessage) * kInitialEventCapacity)] retain];

	[self setNeedsSave:NO];
	
	//keep it clean
	_experimentEndTimer = nil;
	_experimentStartDate = nil;
	_experimentSaveFilePath = nil;
	_experimentSaveDictionary = nil;
	
	return self; 
}

- (void) dealloc
{
	[_definitionFilePath autorelease];
	[_definitionDictionary autorelease];
	[_experimentParts autorelease];
	[_stimulus autorelease];
	[_network autorelease];
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
	_stimulus = nil;
	_network = nil;
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
#pragma mark  Accessors

- (RNStimulus *) stimulus { return _stimulus; }
- (void) setStimulus: (RNStimulus *) newStimulus
{
    if (_stimulus != newStimulus) {
        [_stimulus autorelease];
        _stimulus = [newStimulus retain];
    }
}

- (RNNetwork *) network { return _network; }
- (void) setNetwork: (RNNetwork *) newNetwork
{
    if (_network != newNetwork) {
        [_network autorelease];
        _network = [newNetwork retain];
    }
}

- (NSDate *) experimentStartDate { return _experimentStartDate; }
- (void) setExperimentStartDate: (NSDate *) newExperimentStartDate
{
    if (_experimentStartDate != newExperimentStartDate) {
        [_experimentStartDate autorelease];
        _experimentStartDate = [newExperimentStartDate retain];
    }
}


- (MIDITimeStamp) experimentStartTimestamp { return _experimentStartTimestamp; }
- (void) setExperimentStartTimestamp: (MIDITimeStamp) newExperimentStartTimestamp
{
    _experimentStartTimestamp = newExperimentStartTimestamp;
}

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


- (BOOL) needsSave { return _needsSave; }
- (void) setNeedsSave: (BOOL) flag
{
    _needsSave = flag;
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

// *********************************************
//    MIDI
#pragma mark  MIDI

//prepare stimuli and schedule for MIDI play
- (void) sendStimuliToMIDI: (MIDIIO *) io
{
	//***temporary--later, iterate through experiment parts
	NSData *pl = [[self stimulus] MIDIPacketListForExperimentStartTime:AudioConvertHostTimeToNanos([self experimentStartTimestamp]) ];
	[io sendMIDIPacketList:pl];
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
//    Actions
#pragma mark  Actions

- (void) prepareToStartAtTimestamp: (MIDITimeStamp) timestamp StartDate: (NSDate *) date
{
	[self setExperimentStartTimestamp:timestamp];
	[self setExperimentStartDate:date];
	
	//set up experiment ending timer
	NSTimeInterval interval1, interval2, uncertainty;
	NSDate *absEndTime = [[self experimentStartDate] addTimeInterval: _experimentDuration_s]; //***add accessor
	interval1 = [absEndTime timeIntervalSinceNow];
	_experimentEndTimer = [[NSTimer scheduledTimerWithTimeInterval:interval1 target:self selector:@selector(stop:) 
												 userInfo:nil repeats:NO] retain];
	interval2 = [absEndTime timeIntervalSinceNow];
	uncertainty = interval1 - interval2;
	NSLog(@"\n\tUncertainty in experiment end timer maximum %g ms (%g - %g)", uncertainty, interval1, interval2);
	
}

- (void) stop
{
	//invalidate end timer & part timers
	NSLog(@"\n\tStopping Experiment");
	[_experimentEndTimer invalidate];
	[_experimentEndTimer autorelease];
	_experimentEndTimer = nil;
	[self setNeedsSave:YES];
}

- (void) saveToPath: (NSString *) filePath
{
	BOOL success = [ [self experimentSaveDictionary] writeToFile:filePath atomically:YES];
	NSAssert( (success == YES), @"file did not save successfully");
	
	//consider an alternate way of saving
	[self setNeedsSave:NO];
}

//create dictionary for save
- (NSDictionary *) experimentSaveDictionary
{
	NSAssert( (_experimentSaveDictionary == nil), @"overwriting existing save dictionary");
	
	NSMutableDictionary *temp = [[NSMutableDictionary dictionaryWithCapacity:1] retain];
	
	//now add what we want to save
	[temp setObject:_definitionFilePath forKey:@"definitionFilePath"];
	[temp setObject:_definitionDictionary forKey:@"definitionDictionary"];
	//wrap our starting timestamp in 
	NSNumber *timestamp = [NSNumber numberWithUnsignedLongLong: [self experimentStartTimestamp]];
	[temp setObject:timestamp forKey:@"experimentStartTimestamp"];
	[temp setObject:_experimentStartDate forKey:@"experimentStartDate"];
	[temp setObject:[self recordedEventsString] forKey:@"recordedEvents"];
	[temp setObject:_experimentDescription forKey:@"experimentDescription"];
	[temp setObject:_experimentNotes forKey:@"experimentNotes"];
	
	return [NSDictionary dictionaryWithDictionary:temp];
}


@end
