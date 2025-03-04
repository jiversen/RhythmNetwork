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
		paramDelta = (endParam-startParam) / nSteps;
		
	} else if ([parameterType isEqualToString:@"constant"]) {
		nSteps = duration_s * 2; //constant # steps per second
		paramDelta = 3.0; //controls acceleration
			
	} else {
		NSAssert1( (0), @"incorrect parameterType (%@)", rampDict);
	}
	
	NSMutableArray *dictionaryArray = [NSMutableArray arrayWithCapacity:nSteps];

	for (iStep = 0; iStep <= nSteps; iStep++) {
		stepStartTime = startTime_s + iStep*duration_s/nSteps;
		
		if ([parameterType isEqualToString:@"weight"]) { //assert above catches invalid parameterType so can assume one of these two paths will execute
			stepParam = startParam + paramDelta*iStep;
		} else if ([parameterType isEqualToString:@"constant"]) {
			stepParam = startParam + (endParam-startParam) * pow( (double)iStep / (double) nSteps, paramDelta);
			stepParam = round(stepParam);
		}
		stepDict = [NSMutableDictionary dictionaryWithCapacity:4];
		stepDict[@"type"] = @"globalConnectionStrength";
		stepDict[@"startTime"] = @(stepStartTime);
		stepDict[parameterType] = @(stepParam);
		stepDict[@"description"] = [NSString stringWithFormat:@"%@=%g (%d/%d)", parameterType, stepParam, iStep, nSteps];
		[dictionaryArray addObject:stepDict];
	}
	
	return [NSArray arrayWithArray:dictionaryArray];
}

- (RNGlobalConnectionStrength *) initFromDictionary:(NSDictionary *)aDict;
{
    NSString *type = nil;
    double param = 0.0;
	//will have a parameter keyed as 'weight' or 'constant'--take the type from the key & param from value
	NSNumber *paramNumber;
	if ((paramNumber = aDict[@"weight"])) {
		type = @"weight";
		param = [paramNumber doubleValue];
	} else if ((paramNumber = aDict[@"constant"])) {
		type = @"constant";
		param = [paramNumber doubleValue];
	} else if ((paramNumber = aDict[@"constantInput"])) {
		type = @"constantInput";
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
		
	} else if ([type isEqualToString:@"constantInput"]) {
		Byte MIDIVelocity = (Byte) roundf(_param);
		[_processor setConstantVelocity:MIDIVelocity];
		[_processor setOnInput:YES];
		
	} else {
		NSAssert1( (0), @"unknown globalConnectionStrength type (%@)", type);
	}
	
	return self;
}

- (MIOCVelocityProcessor *) processor
{
	return _processor;
}

- (NSString *) type
{
	return _type;
}

- (NSString *) description
{
	NSAssert( (_processor != nil), @"description requested for uninitialized object!");
	return [_processor description];
}

@end
