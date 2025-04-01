/* RNNetworkView */

#import <Cocoa/Cocoa.h>

@class	RNNetwork;
@class	RNNodeHistogramView;
@class	RNDataView;

@interface RNNetworkView : NSView
{
	RNNetwork		*_network;				// network this view will display
	double			_drawRadius;			// radius of network (assume circular)
	BOOL				_doShowMIDIActivity;	// whether to dynamically show midi activity
	BOOL				_doShowNodeHistograms;	// whether to show histograms
	BOOL				_doPlotData;			// whether midi input is added to data plots
	NSMutableArray	*_nodeHistogramViews;	// array of views
	RNDataView		*_dataView;
}

+ (instancetype)sharedNetworkView;
- (void)updateDrawingMetricsForScale:(CGFloat)scale;

- (RNNetwork *)network;
- (void)setNetwork:(RNNetwork *)newNetwork;
- (void)synchronizeWithStimuli;
- (double)drawRadius;

- (void)initNodeHistograms;
- (void)removeNodeHistograms;

- (void)showNodeHistograms;
- (void)hideNodeHistograms;

- (void)clearData;
- (void)setPlotData:(BOOL)doIt;

- (void)setDataView:(RNDataView *)dataView;

- (void)receiveMIDIData:(NSData *)MIDIData;

@end
