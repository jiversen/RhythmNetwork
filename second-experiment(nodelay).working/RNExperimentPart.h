//
//  RNExperimentPart.h
//  RhythmNetwork
//
//  Created by John Iversen on 1/26/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <CoreMIDI/MIDIServices.h>

@class RNController;
@class MIOCModel;

@interface RNExperimentPart : NSObject {
	id				_experimentPart;
	NSString		*_description;
	NSTimeInterval	_startTime_s;
	NSTimeInterval  _actualStartTime_s;
	NSTimeInterval  _startTimeUncertainty_s;
	NSString		*_subEventTimes;
	NSTimer			*_startTimer;
}

+ (RNExperimentPart *) experimentPartFromDictionary: (NSDictionary *) aDict;
+ (NSArray *) experimentPartArrayFromDictionary: (NSDictionary *) aDict;

- (RNExperimentPart *) initWithObject: (id) anObject RelativeStartTime: (NSTimeInterval) startTime_s Description: (NSString *) description;
- (void) dealloc;

//Accessors
- (NSString *) partType;
- (id) experimentPart;
- (NSString *) shortDescription;
- (NSTimeInterval) startTime;
- (NSTimeInterval) actualStartTime;
- (void) setActualStartTime: (NSTimeInterval) time;
- (NSTimeInterval) startTimeUncertainty;
- (void) setStartTimeUncertainty: (NSTimeInterval) time;
- (NSString *) subEventTimes;
- (void) setSubEventTimes: (NSString *) timesStr;


- (NSTimer *) startTimer;
- (void) setStartTimer: (NSTimer *) theTimer;

- (BOOL) containsObject:(id)aPart;

//Actions
- (void) postNewStimulusNotification: (NSTimer *) timer;
- (void) postNewNetworkNotification: (NSTimer *) timer;
- (void) postNewGlobalConnectionStrengthNotification: (NSTimer *) timer;
- (void) scheduleForExperimentStartTime: (NSDate *) time Timestamp: (MIDITimeStamp) timestamp;
- (void) unschedule;

@end
