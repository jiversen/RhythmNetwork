//
//  RNGlobalConnectionStrength.m
//  RhythmNetwork
//
//  Created by John Iversen on 9/6/05.
//  Copyright 2005 John Iversen (iversen@nsi.edu). All rights reserved.
//

#import "RNGlobalConnectionStrength.h"
#import "MIOCVelocityProcessor.h"

@implementation RNGlobalConnectionStrength

//return an array of dictionaries themselves capable of defining RNGlobalConnectionStrength
// used to define an umbrella definition into components
// ramp dictionary is defined by its start time, duration, start and end parameter values, and type
//  type may be weight or constant, and parameter is given that key
+ (NSArray *) globalConnectionStrengthDictionaryArrayFromRampDictionary:(NSDictionary *)rampDict
{
	//extract parameters from dictionary
	NSNumber *startTimeNum = [rampDict valueForKey:@"startTime"];
	NSAssert1( (startTimeNum != nil), @"Experiment Part is missing startTime: %@", rampDict);
	NSTimeInterval startTime_s = [startTimeNum doubleValue];
	
	NSNumber *durationNum = [rampDict valueForKey:@"duration"];
	NSAssert1( (durationNum != nil), @"Experiment Part is missing duration: %@", rampDict);
	NSTimeInterval duration_s = [durationNum doubleValue];
	
	NSString *parameterType = [rampDict valueForKey:@"parameterType"];
	NSAssert1( (parameterType != nil), @"Experiment Part is missing parameterType: %@", rampDict);
	
	NSNumber *startNum = [rampDict valueForKey:@"startValue"];
	NSAssert1( (startNum != nil), @"Experiment Part is missing startValue: %@", rampDict);
	double startParam = [startNum doubleValue];
	
	NSNumber *endNum = [rampDict valueForKey:@"endValue"];
	NSAssert1( (endNum != nil), @"Experiment Part is missing endValue: %@", rampDict);
	double endParam = [endNum doubleValue];
	
	//decide how many time steps, generate dictionary for each one
	unsigned iStep, nSteps;
	double stepParam, paramDelta, stepStartTime;
	NSMutableDictionary *stepDict;
	
	//nSteps depends on parameter type--
	if ([parameterType isEqualToString:@"weight"]) {
		nSteps = (endParam-startParam) * 8; //weight (slope) is quantized to 1/8
	} else if ([parameterType isEqualToString:@"constant"]) {
		nSteps = (endParam-startParam) / 4; //change constant in steps of 4 velocity value (what's jnd?)
	} else {
		NSAssert1( (0), @"incorrect parameterType (%@)", rampDict);
	}
	
	paramDelta = (endParam-startParam) / nSteps;
	NSMutableArray *dictionaryArray = [NSMutableArray arrayWithCapacity:nSteps];

	for (iStep = 0; iStep <= nSteps; iStep++) {
		stepStartTime = startTime_s + iStep*duration_s/nSteps;
		stepParam = startParam + iStep*paramDelta;
		stepDict = [NSMutableDictionary dictionaryWithCapacity:3];
		[stepDict setObject:@"globalConnectionStrength" forKey:@"type"];
		[stepDict setObject:[NSNumber numberWithDouble:stepStartTime] forKey:@"startTime"];
		[stepDict setObject:[NSNumber numberWithDouble:stepParam] forKey:parameterType];
		[dictionaryArray addObject:stepDict];
	}
	
	return [NSArray arrayWithArray:dictionaryArray];
}

- (RNGlobalConnectionStrength *) initFromDictionary:(NSDictionary *)aDict;
{
	NSString *type;
	double param;
	//will have a parameter keyed as 'weight' or 'constant'--take the type from the key & param from value
	NSNumber *paramNumber;
	if (paramNumber = [aDict objectForKey:@"weight"]) {
		type = @"weight";
		param = [paramNumber doubleValue];
	} else if (paramNumber = [aDict objectForKey:@"constant"]) {
		type = @"constant";
		param = [paramNumber doubleValue];
	} else {
		NSAssert1( (0), @"found no weight or constant parameter (%@)", aDict);
	}	
	
	return [[RNGlobalConnectionStrength alloc] initWithType:type value:param];
}

//designated initializer
- (RNGlobalConnectionStrength *) initWithType:(NSString *)type value:(double)param
{
	
	self = [super init];
	
	_type = type;
	_param = param;

	_processor = [[MIOCVelocityProcessor alloc] initWithPort:1 Channel:1 OnInput:NO];

	if ([type isEqualToString:@"weight"]) {
		[_processor setWeight:_param];
		
	} else if ([type isEqualToString:@"constant"]) {
		Byte MIDIVelocity = (Byte) roundf(_param);
		[_processor setConstantVelocity:MIDIVelocity];
		
	} else {
		NSAssert1( (0), @"unknown globalConnectionStrength type (%@)", type);
	}
	
	return self;
}

@end