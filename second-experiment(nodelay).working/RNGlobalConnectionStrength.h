//
//  RNGlobalConnectionStrength.h
//  RhythmNetwork
//
//  Created by John Iversen on 9/6/05.
//  Copyright 2005 John Iversen (iversen@nsi.edu). All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MIOCVelocityProcessor;

@interface RNGlobalConnectionStrength : NSObject {

	NSString				*_type; // 'weight' or 'constant' or 'inputConstant'
	MIOCVelocityProcessor	*_processor;
	double					_param; //weight if 'weight', midi velocity if 'constant'
}

//wierd factory: generate an array of dictionaries from a dictionary defining the ramp
+ (NSArray *) globalConnectionStrengthDictionaryArrayFromRampDictionary:(NSDictionary *)aDict;

- (RNGlobalConnectionStrength *) initFromDictionary:(NSDictionary *)aDict;

- (RNGlobalConnectionStrength *) initWithType:(NSString *)type value:(double)param;

- (MIOCVelocityProcessor *) processor;
- (NSString *) type;

//- (NSString *) description;

@end
