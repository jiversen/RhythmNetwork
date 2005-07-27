/* RNNetworkView */

#import <Cocoa/Cocoa.h>

@class RNNetwork;
@class RNNodeHistogramView;
@class RNDataView;

@interface RNNetworkView : NSView {
	RNNetwork	*_network;				//network this view will display
	double		_drawRadius;			//radius of network (assume circular)
	BOOL		_doShowMIDIActivity;	//whether to dynamically show midi activity
	BOOL		_doShowNodeHistograms;	//whether to show histograms
	NSMutableArray *_nodeHistogramViews; //array of views
	RNDataView  *_dataView;
}

- (RNNetwork *) network;
- (void) setNetwork: (RNNetwork *) newNetwork;
- (void) synchronizeWithStimuli;
- (double) drawRadius;

- (void) initNodeHistograms;
- (void) removeNodeHistograms;

- (void) showNodeHistograms;
- (void) hideNodeHistograms;

- (void) setDataView: (RNDataView *) dataView;

- (void) receiveMIDIData: (NSData *) MIDIData;

@end
