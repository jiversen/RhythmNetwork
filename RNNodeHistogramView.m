//
//  RNNodeHistogramView.m
//  RhythmNetwork
//
//  Created by John Iversen on 2/24/05.
//  Copyright 2005 John Iversen. All rights reserved.
//

#import "RNNodeHistogramView.h"

#import <CoreAudio/HostTime.h>
#import "RNStimulus.h"

#define kFontSize 9

static const NSInteger kNoSingleBinUpdatePending = -1;

@implementation RNNodeHistogramView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		// specific instance variables are initialized in setTargetStimulus:
		NSRect bounds;
		// set origin half way along x axis, keep same dimensions (in owning view's coordinates (pixels))
		bounds = NSMakeRect(-(frameRect.size.width / 2.0), 0.0, frameRect.size.width, frameRect.size.height);
		[self setBounds:bounds];
		_updatedBinIndex = -1; //default to full draw
	}

	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (BOOL)isOpaque
{
	return YES;
}

// this does actual initialization of ivars, bounds rectangle and allocate counts
- (void)setTargetStimulus:(RNStimulus *)stim
{
	NSRect	frame;
	int		nBins, i;

	// NSAssert( (stim != nil), @"nil stimulus");

	if ((_targetStimulus != stim) && (stim != nil)) {
		_targetStimulus = stim;
		_targetIOI_ms	= [stim IOI_ms];
		_yMax			= kInitialYMax;
		_isNormalized	= NO;
		_ITI_ms			= 0;// invalid value

		frame = [self frame];
		// calculate binWidth based on actual width in pixels, **add some minimum width checking?
		_binWidth_ms	= _targetIOI_ms / frame.size.width;
		nBins			= _targetIOI_ms / _binWidth_ms;

		// zero out counts (could contain data from last stimulus)
		// **later--make some way to preserve the counts, e.g. a line on the plot
		// ** also--posibility to reinterpret (or not) past events in terms of new stimulus periodicity
		for (i = 0; i < nBins; i++) {
			_counts[i] = 0;
		}

		_numEvents = 0;	// necessary when re-setting stimulus
	}
}

- (void)clearData
{
	int nBins, i;

	nBins = _targetIOI_ms / _binWidth_ms;

	// zero out counts (could contain data from last stimulus)
	for (i = 0; i < nBins; i++) {
		_counts[i] = 0;
	}

	_numEvents		= 0;// necessary when re-setting stimulus
	_ITI_ms			= 0;
	_smoothITI_ms	= 0;
}

- (int *)counts
{
	return _counts;
}

- (double)lastEventTime
{
	if (_targetStimulus != nil) {
		double expStart_ms = [_targetStimulus experimentStartTime] / 1e6;
		return (_eventTimes[_numEvents] / 1e6) - expStart_ms;
	} else {
		return 0;
	}
}

- (double)lastITI
{
	return _ITI_ms;
}

- (double)smoothedITI
{
	return _smoothITI_ms;
}

- (NSRect)barRectForIndex:(NSUInteger)iBin {
	CGFloat yCount = (_counts[iBin] / _yMax) * self.bounds.size.height * 0.8;
	CGFloat x = iBin - (self.bounds.size.width / 2.0);
	return NSMakeRect(x, 0.0, 1.0, yCount);
}

- (void)addEventAtTime:(UInt64)eventTime_ns
{
	// figure out which bin this event belongs into
	int		iBin, nBins;
	double	asynchrony_ms;

	NSAssert((_numEvents < kMaxNumEvents - 1), @"Event storage overflow");
	_eventTimes[++_numEvents] = eventTime_ns;

	// calculate estimate of ITI, smoothed after last few points
	if (_numEvents > 1) {										// need more than 1 event (count from 1)
		_ITI_ms			= (_eventTimes[_numEvents] - _eventTimes[_numEvents - 1]) / 1e6;
		_smoothITI_ms	= (3.0 * _smoothITI_ms + _ITI_ms) / 4.0;// weight history more than new to smooth
	}

	// NSAssert(( _targetStimulus != nil ), @"cannot add event: targetStimulus = nil");
	if (_targetStimulus != nil) {
		asynchrony_ms	= [_targetStimulus asynchronyForNanoseconds:eventTime_ns];
		iBin			= (int)floor((asynchrony_ms + (_targetIOI_ms / 2.0)) / _binWidth_ms);
		nBins			= _targetIOI_ms / _binWidth_ms;
		NSAssert3((iBin >= 0 && iBin < nBins), @"iBin out of range (%d > %d), async %.1f", iBin, nBins, asynchrony_ms);
		_counts[iBin] += 1;

		// have we grown past yMax? Yes, rescale and request redraw of entire histogram
		if (_counts[iBin] > _yMax) {
			_yMax += 5;
			[self setNeedsDisplay:YES];
			return;
		}

		// no rescale, so just update the single bin
		// If a previous bin update hasn't been flushed to the screen yet,
		// we fall back to a full redraw to ensure all changes are visible.
		if (_updatedBinIndex == kNoSingleBinUpdatePending) {
			_updatedBinIndex = iBin;
			[self setNeedsDisplayInRect:[self barRectForIndex:iBin]];
		} else { //another single bin had been requested, so just redraw it all
			NSLog(@"!!! RNHistogramView: ⚠️ Multiple bins queued before redraw — falling back to full redraw.Oh, ");
			_updatedBinIndex = kNoSingleBinUpdatePending; //aka draw them all
			[self setNeedsDisplay:YES];
		}
		
		//TODO: if the log above shows up a lot, keep track of multiple bin update, but I doubt this'll be the case
		//NSMutableIndexSet *_binsToRedraw;
		//[binsToRedraw addIndex:iBin];
		//[self setNeedsDisplayInRect:[self barRectForIndex:iBin]];
		// in drawRect,  iterate over [binsToRedraw enumerateIndexesUsingBlock:].
		
	}
}

/// some ideas--at change in experiment conditions, freeze current histogram (as a line drawing showing outline)
// and begin building histogram of new inputs
// - absolute or normalized scale?
// -sweep bar or not
// animate adding new tap--brighten that bar and fade down
// have a radial display, as well as linear

- (void)drawRect:(NSRect)rect
{
	NSBezierPath	*aPath;
	NSRect			barRect, bounds;
	NSUInteger		iBin, nBins;

	// aPath = [NSBezierPath bezierPathWithRect:[self bounds]];
	// [aPath setLineWidth:1.0];
	// [aPath stroke];

	if (_targetStimulus != nil) {
		
		// New: a shortcircuited single-bin draw
		if (_updatedBinIndex != kNoSingleBinUpdatePending) {
			iBin = _updatedBinIndex;
			_updatedBinIndex = kNoSingleBinUpdatePending;
			if (_counts[iBin] > 0) {
				barRect = [self barRectForIndex:iBin];
				[[NSColor blueColor] setFill];
				aPath	= [NSBezierPath bezierPathWithRect:barRect];
				[aPath fill];
			}
			return;
		}
		
		// FULL REDRAW
		// clear
		bounds	= [self bounds];
		aPath	= [NSBezierPath bezierPathWithRect:bounds];
		[[NSColor windowBackgroundColor] setFill];
		[[NSColor windowBackgroundColor] setStroke];
		[aPath fill];
		[aPath removeAllPoints];

		// draw IOI target
		[aPath moveToPoint:NSMakePoint(0.0, 0.0)];
		[aPath lineToPoint:NSMakePoint(0.0, bounds.size.height * 0.8)];
		[[NSColor redColor] setStroke];
		[aPath stroke];
		[aPath removeAllPoints];

		// baseline
		[aPath moveToPoint:NSMakePoint(-(bounds.size.width / 2.0), 0.0)];
		[aPath lineToPoint:NSMakePoint((bounds.size.width / 2.0), 0.0)];
		[aPath setLineWidth:1.0];
		[aPath stroke];
		[aPath removeAllPoints];

		// CGContextFlush([[NSGraphicsContext currentContext] graphicsPort]);

		// target IOI text--start stimple w/ NSString additions draw methods
		NSString *IOIStr;

		if (_targetIOI_ms != 0) {
			IOIStr = [NSString stringWithFormat:@"%.0f", _targetIOI_ms];
		} else {
			IOIStr = [NSString stringWithFormat:@"---"];
		}

		NSDictionary *attributes = @{
			NSForegroundColorAttributeName: [NSColor redColor],
			NSFontAttributeName:[NSFont fontWithName:@"Helvetica" size:kFontSize]
		};
		[IOIStr drawAtPoint:NSMakePoint(-(bounds.size.width / 2.0), (bounds.size.height * 0.7)) withAttributes:attributes];

		// smoothed ITI text
		NSString *ITIStr;

		if (_ITI_ms != 0) {
			ITIStr = [NSString stringWithFormat:@"%.0f", _ITI_ms];
		} else {
			ITIStr = [NSString stringWithFormat:@"---"];
		}

		attributes = @{
			NSForegroundColorAttributeName: [NSColor redColor],
			NSFontAttributeName:[NSFont fontWithName:@"Helvetica" size:kFontSize]
		};
		[ITIStr drawAtPoint:NSMakePoint((0.15 * bounds.size.width / 2.0), (bounds.size.height * 0.7)) withAttributes:attributes];

		// draw histogram
		[[NSColor blueColor] setFill];
		// nBins = _targetIOI_ms / _binWidth_ms;
		nBins = bounds.size.width;
		float yCount;

		for (iBin = 0; iBin < nBins; iBin++) {
			if (_counts[iBin] > 0) {
				// barRect = NSMakeRect( (iBin * _binWidth_ms) - (_targetIOI_ms/2.0), 0, _binWidth_ms, _counts[iBin]);
				yCount	= (_counts[iBin] / _yMax) * bounds.size.height * 0.8;
				barRect = NSMakeRect(iBin - (bounds.size.width / 2.0), 0.0, 1.0, yCount);
				aPath	= [NSBezierPath bezierPathWithRect:barRect];
				[aPath fill];
			}
		}
	}
}

@end
