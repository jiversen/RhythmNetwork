//
//  RNNodeHistogramView.h
//  RhythmNetwork
//
//  Created by John Iversen on 2/24/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kInitialYMax	5
#define kMaxNumBins		1000
#define kMaxNumEvents	10000

@class RNStimulus;

@interface RNNodeHistogramView : NSView
{
	RNStimulus		*_targetStimulus;		// stimulus this node should be tracking
	double			_targetIOI_ms;			// desired IOI--determines timebase of histogram
	UInt64			_stimStartTime_ns;		// convenience--absolute start time of stimulus (re experiment start)
	double			_sweepTime_ms;			// varies from - to + IOI/2
	double			_binWidth_ms;			// histogram bin
	double			_yMax;					// histogram max
	BOOL				_isNormalized;			// raw counts, or normalized to max=1
	int				_counts[kMaxNumBins];		// array of counts for each bin
	UInt64			_eventTimes[kMaxNumEvents];	// raw event times (used to re-format histogram w/ new IOI or bin)
	unsigned int		_numEvents;				// number of events stored in _eventTimes
	double			_ITI_ms;				// instantaneous ITI
	double			_smoothITI_ms;			// smoothed measure of ITI
}

- (void)setTargetStimulus:(RNStimulus *)stim;	// initializes histogram

- (void)addEventAtTime:(UInt64)eventTime_ns;	// update with a new event

- (void)clearData;

- (int *)counts;

- (double)lastEventTime;
- (double)lastITI;
- (double)smoothedITI;

@end
