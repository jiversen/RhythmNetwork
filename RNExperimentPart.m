//
//  RNExperimentPart.m
//  RhythmNetwork
//
//  Created by John Iversen on 1/26/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

#import "RNExperimentPart.h"

#import <CoreAudio/HostTime.h>
#import "MIOCModel.h"
#import "MIDIIO.h"
#import "RNStimulus.h"
#import "RNNetwork.h"
#import "RNGlobalConnectionStrength.h"

@implementation RNExperimentPart

+ (RNExperimentPart *)experimentPartFromDictionary:(NSDictionary *)aDict
{
	id part;

	NSString *type = [aDict valueForKey:@"type"];

	NSAssert1((type != nil), @"Experiment Part is missing Type: %@", aDict);

	NSNumber *startNum = [aDict valueForKey:@"startTime"];
	NSAssert1((startNum != nil), @"Experiment Part is missing StartTime: %@", aDict);
	NSTimeInterval startTime_s = [startNum doubleValue];

	NSString *description = [aDict valueForKey:@"description"];

	// based on type, initialize stimulus or network
	if ([type isEqualToString:@"stimulus"]) {
		NSString *stimStr = [aDict valueForKey:@"stimulus"];
		NSAssert1((type != nil), @"Experiment Part is missing Stimulus: %@", aDict);
		part = [[[RNStimulus alloc] initWithString:stimStr] autorelease];
		NSAssert1((part != nil), @"Could not create Stimulus: %@", stimStr);
		// set start time
		[part setStartTimeSeconds:startTime_s];
	} else if ([type isEqualToString:@"network"]) {
		part = [[(RNNetwork *)[RNNetwork alloc] initFromDictionary:aDict] autorelease];	// note cast :jri:20050906
		NSAssert1((part != nil), @"Could not create Network: %@", aDict);
	} else if ([type isEqualToString:@"globalConnectionStrength"]) {
		part = [[(RNGlobalConnectionStrength *)[RNGlobalConnectionStrength alloc] initFromDictionary:aDict] autorelease];
		NSAssert1((part != nil), @"Could not create globalConnectionStrength event: %@", aDict);
	} else {
		NSAssert1(0, @"Experiment Part: unknown type (%@)", type);
		return nil;
	}

	RNExperimentPart *temp = [[RNExperimentPart alloc] initWithObject:part
		RelativeStartTime	:startTime_s
		Description			:description];
	return [temp autorelease];
}

// mutant factory: return an array of parts--takes care of umbrella parts that auto-expand into
//  multiple real parts
// let this be the main entry point, and let non-expanded parts be returned as an array of one part
// this'll call experimentPartFromDictionary as needed
+ (NSArray *)experimentPartArrayFromDictionary:(NSDictionary *)aDict
{
	RNExperimentPart	*part;
	NSMutableArray		*partArray = [NSMutableArray arrayWithCapacity:1];
	NSArray				*dictArray;

	NSString *type = [aDict valueForKey:@"type"];

	NSAssert1((type != nil), @"Experiment Part is missing Type: %@", aDict);

	// handle based on type
	if ([type isEqualToString:@"globalConnectionStrengthRamp"]) {	// expand this kind
		dictArray = [RNGlobalConnectionStrength globalConnectionStrengthDictionaryArrayFromRampDictionary:aDict];
		// enumerate over dictionaries, instantiating a part for each one
		NSEnumerator *partEnumerator = [dictArray objectEnumerator];

		while (aDict = [partEnumerator nextObject]) {
			part = [RNExperimentPart experimentPartFromDictionary:aDict];
			[partArray addObject:part];
		}
	} else {// non-expanding kinds: instantiate and wrap in array
		part = [RNExperimentPart experimentPartFromDictionary:aDict];
		[partArray addObject:part];
	}

	return [NSArray arrayWithArray:partArray];	// return non-mutable
}

- (RNExperimentPart *)initWithObject:(id)anObject RelativeStartTime:(NSTimeInterval)startTime_s Description:(NSString *)description
{
	self			= [super init];
	_experimentPart = [anObject retain];	// !!!:jri:20050627 did not retain prior, yet did autorelease; now balanced
	_startTime_s	= startTime_s;
	_description	= [description copy];	// !!!:jri:20050627 more appropriate to copy; added release in dealloc
	return self;
}

- (void)dealloc
{
	[_experimentPart release];
	_experimentPart = nil;
	[_startTimer invalidate];
	[_startTimer release];
	_startTimer = nil;
	[_description release];
	_description = nil;
	[_subEventTimes release];
	_subEventTimes = nil;
	[super dealloc];
}

// *********************************************
//    Accessors
//
#pragma mark  Accessors

- (NSString *)partType
{
	return [_experimentPart className];
}

- (NSString *)typeInitial
{
	if ([[self partType] isEqualToString:@"RNStimulus"]) {
		return [NSString stringWithFormat:@"S"];
	} else if ([[self partType] isEqualToString:@"RNNetwork"]) {
		return [NSString stringWithFormat:@"N"];
	} else if ([[self partType] isEqualToString:@"RNGlobalConnectionStrength"]) {
		return [NSString stringWithFormat:@"W"];// for weight
	} else {
		NSAssert((0), @"typeInitial called for unknown part type.");
		return [NSString stringWithFormat:@"?"];// not reached
	}
}

- (id)experimentPart
{
	return _experimentPart;
}

- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"%@: %@", [self typeInitial], _description];
}

- (NSTimeInterval)startTime
{
	return _startTime_s;
}

- (NSTimeInterval)actualStartTime {
	return _actualStartTime_s;
}

- (void)setActualStartTime:(NSTimeInterval)time
{
	_actualStartTime_s = time;
}

- (NSTimeInterval)startTimeUncertainty {
	return _startTimeUncertainty_s;
}

- (void)setStartTimeUncertainty:(NSTimeInterval)time
{
	_startTimeUncertainty_s = time;
}

- (NSString *)subEventTimes {
	return _subEventTimes;
}

- (void)setSubEventTimes:(NSString *)timesStr
{
	[_subEventTimes autorelease];	// auto protects against something silly like [obj setSubEventTimes: [obj subEventTimes]];
	_subEventTimes	= nil;
	_subEventTimes	= [timesStr copy];
}

- (NSTimer *)startTimer
{
	return _startTimer;
}

// passing nil removes the timer
- (void)setStartTimer:(NSTimer *)theTimer
{
	if ((_startTimer != nil) && (theTimer != nil)) {
		NSAssert((0), @"Assigning a new timer on top of an existing one");
	}

	[_startTimer invalidate];
	[_startTimer autorelease];
	_startTimer = [theTimer retain];
}

- (BOOL)containsObject:(id)aPart
{
	return [self experimentPart] == aPart;
}

// *********************************************
//    Actions
//
#pragma mark  Actions

// timer callbacks that post notifications
- (void)postNewStimulusNotification:(NSTimer *)timer
{
	RNStimulus *stim = (RNStimulus *)[timer userInfo];

	NSLog(@"activating stimulus %@", [stim description]);
	[[NSNotificationCenter defaultCenter] postNotificationName:@"newStimulusNotification" object:self];
}

- (void)postNewNetworkNotification:(NSTimer *)timer
{
	RNNetwork *net = (RNNetwork *)[timer userInfo];

	NSLog(@"activating network %@", [net description]);
	[[NSNotificationCenter defaultCenter] postNotificationName:@"newNetworkNotification" object:self];
}

- (void)postNewGlobalConnectionStrengthNotification:(NSTimer *)timer
{
	RNGlobalConnectionStrength *weight = (RNGlobalConnectionStrength *)[timer userInfo];

	NSLog(@"activating global connection strength %@", [weight description]);
	[[NSNotificationCenter defaultCenter] postNotificationName:@"newGlobalConnectionStrengthNotification" object:self];
}

// schedule timers
- (void)scheduleForExperimentStartTime:(NSDate *)time Timestamp:(MIDITimeStamp)timestamp
{
	// setup a timer to trigger the start
	NSTimeInterval	interval1, interval2, preroll, uncertainty;
	NSDate			*absStartTime;

	//  in the case of a stimulus, schedule it now with the MIDI system
	if ([[self partType] isEqualToString:@"RNStimulus"]) {
		NSLog(@"Scheduling stimulus: %@\n\t%@", [self description], [self experimentPart]);
		preroll			= 0.001;// empirical: notification received ~1ms after timer fires
		absStartTime	= [time dateByAddingTimeInterval:_startTime_s];
		interval1		= [absStartTime timeIntervalSinceNow] - preroll;
		NSTimer *startTimer = [NSTimer scheduledTimerWithTimeInterval:interval1
			target	:self
			selector:@selector(postNewStimulusNotification:)
			userInfo:[self experimentPart]
			repeats :NO];
		interval2	= [absStartTime timeIntervalSinceNow] - preroll;
		uncertainty = (interval1 - interval2) * 1000.0;
		NSLog(@"Scheduling stimulus @T+%.2f: %@\n\t%@", _startTime_s, [self description], [self experimentPart]);
		NSLog(@"\n\tUncertainty in part timer scheduling is maximum %.3f ms (%g - %g)", uncertainty, interval1, interval2);
		[self setStartTimer:startTimer];

		// for network, setup a timer to trigger the reprogramming
	} else if ([[self partType] isEqualToString:@"RNNetwork"]) {
		preroll = 0.03;	// just a guess for how long it'll take to reprogram MIOC
		NSDate *absStartTime = [time dateByAddingTimeInterval:_startTime_s];
		interval1 = [absStartTime timeIntervalSinceNow] - preroll;
		NSTimer *startTimer = [NSTimer scheduledTimerWithTimeInterval:interval1
			target	:self
			selector:@selector(postNewNetworkNotification:)
			userInfo:[self experimentPart]
			repeats :NO];
		// NSTimer *startTimer = [NSTimer scheduledTimerWithTimeInterval:interval1
		//													   target:MIOC
		//													 selector:@selector(setConnectionListTimerHandler:)
		//													 userInfo:[[self experimentPart] MIOCConnectionList]
		//													  repeats:NO];
		interval2	= [absStartTime timeIntervalSinceNow] - preroll;
		uncertainty = (interval1 - interval2) * 1000.0;
		NSLog(@"Scheduling network @T+%.2f: %@\n\t%@", _startTime_s, [self description], [self experimentPart]);
		NSLog(@"\n\tUncertainty in part timer scheduling is maximum %.3f ms (%g - %g)", uncertainty, interval1, interval2);
		[self setStartTimer:startTimer];
	} else if ([[self partType] isEqualToString:@"RNGlobalConnectionStrength"]) {
		preroll = 0.02;	// just a guess for how long it'll take to reprogram MIOC
		NSDate *absStartTime = [time dateByAddingTimeInterval:_startTime_s];
		interval1 = [absStartTime timeIntervalSinceNow] - preroll;
		NSTimer *startTimer = [NSTimer scheduledTimerWithTimeInterval:interval1
			target	:self
			selector:@selector(postNewGlobalConnectionStrengthNotification:)
			userInfo:[self experimentPart]
			repeats :NO];
		interval2	= [absStartTime timeIntervalSinceNow] - preroll;
		uncertainty = (interval1 - interval2) * 1000.0;
		NSLog(@"Scheduling global connection strength @T+%.2f: %@\n\t%@", _startTime_s, [self description], [self experimentPart]);
		NSLog(@"\n\tUncertainty in part timer scheduling is maximum %.3f ms (%g - %g)", uncertainty, interval1, interval2);
		[self setStartTimer:startTimer];
	} else {
		NSAssert1(0, @"Unknown experiment part type: %@", [self partType]);
	}
}

- (void)unschedule
{
	[self setStartTimer:nil];
}

@end
