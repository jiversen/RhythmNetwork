//
//  RNExperiment.h
//  RhythmNetwork
//
//  Created by John Iversen on 1/24/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMidi/MidiServices.h>
#import "MIDIListenerProtocols.h"

@class	RNNetwork;
@class	MIDIIO;
@class	MIOCModel;
@class	RNStimulus;
@class	RNExperimentPart;
@class	RNGlobalConnectionStrength;

@interface RNExperiment : NSObject <MIDIDataReceiver>
{
	// the structure of the experiment
	NSString                   *_definitionFilePath;
	NSDictionary               *_definitionDictionary;     // copy of the dictionary used to define the experiment
	NSMutableArray             *_experimentParts;          // a list of experiment parts, stimuli, networks w/ associated start times
	RNNetwork                  *_currentNetwork;           // currently active network
	RNStimulus                 *_currentStimulusArray[17]; // currently active stimuli
	RNGlobalConnectionStrength *_currentGlobalConnectionStrength;

	// these refer to an instantiation of the experiment--data to be saved
	// coming perilously close to document/file wrapper classes, but here will roll my own
	NSTimeInterval _experimentDuration_s;
	NSTimeInterval _experimentActualStopTime_s;
	NSTimer       *_experimentEndTimer;
	MIDITimeStamp  _experimentStartTimestamp; // we maintain two formats of the starting moment
	NSDate        *_experimentStartDate;
	NSMutableData *_recordedEvents;
	NSString      *_experimentDescription;
	NSString      *_experimentNotes;

	// pertaining to saving--we'll create a dictionary for the save
	BOOL          _needsSave;
	NSString     *_experimentSaveFilePath;
	NSDictionary *_experimentSaveDictionary;

	// we do know where our recorded events are coming from
	MIOCModel *_MIOC;
}

- (RNExperiment *)initFromPath:(NSString *)filePath;
- (void)dealloc;
- (void)initializeExperimentPartsWithArray:(NSArray *)partArray NetworkSizeDict:(NSDictionary *)sizeDict;

// accessors--structure
- (NSString *)definitionFilePath;
- (RNNetwork *)currentNetwork;
- (void)setCurrentNetwork:(RNNetwork *)newNet;
- (RNStimulus *)currentStimulusForChannel:(Byte)stimulusChannel;
- (void)setCurrentStimulus:(RNStimulus *)stim ForChannel:(Byte)stimulusChannel;
- (RNStimulus **)currentStimulusArray;
- (RNGlobalConnectionStrength *)currentGlobalConnectionStrength;
- (void)setCurrentGlobalConnectionStrength:(RNGlobalConnectionStrength *)newConnectionStrength;
- (NSArray *)experimentParts;
- (RNExperimentPart *)experimentPartContainingObject:(id)aPart;
- (NSArray *)currentParts;

// start time
- (NSDate *)experimentStartDate;
- (void)setExperimentStartDate:(NSDate *)newExperimentStartDate;
- (MIDITimeStamp)experimentStartTimestamp;
- (void)setExperimentStartTimestamp:(MIDITimeStamp)newExperimentStartTimestamp;

- (UInt64)experimentStartTimeNanoseconds;
- (NSTimeInterval)secondsSinceExperimentStartDate;
- (UInt64)nanosecondsSinceExperimentStartTimestamp;

// textual info
- (NSString *)experimentDescription;
- (void)setExperimentDescription:(NSString *)newExperimentDescription;
- (NSString *)experimentNotes;
- (void)setExperimentNotes:(NSString *)newExperimentNotes;

// recording events, saving
- (BOOL)needsSave;
- (void)setNeedsSave:(BOOL)flag;
- (void)clearRecordedEvents;
- (NSString *)recordedEventsString;
- (NSDictionary *)experimentSaveDictionary;

- (void)receiveMIDIData:(NSData *)MIDIData;

// actions
- (void)prepareToStartAtTimestamp:(MIDITimeStamp)timestamp StartDate:(NSDate *)date;
- (void)scheduleExperimentParts;
- (void)unscheduleExperimentParts;
- (void)startRecordingFromDevice:(MIOCModel *)MIOC;
- (void)stopRecording;

- (void)stopTimerHandler:(NSTimer *)timer;
- (void)stop;
- (void)saveToPath:(NSString *)filePath;

@end
