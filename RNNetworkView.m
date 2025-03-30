#import "RNNetworkView.h"

#import "RNNetwork.h"
#import "RNTapperNode.h"
#import "RNBBNode.h"
#import "MIDIIO.h"
#import "RNStimulus.h"
#import "RNNodeHistogramView.h"
#import "RNDataView.h"

#define kRadiusScale 0.75

static RNNetworkView *_sharedNetworkView = nil;

@implementation RNNetworkView

+ (instancetype)sharedNetworkView {
    return _sharedNetworkView;
}

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
        if (!_sharedNetworkView)
            _sharedNetworkView = self;
        self.wantsLayer = YES;
		_network = nil;
		_doShowMIDIActivity = YES;
		//calculate radius from frameRect size
		_drawRadius = fmax(NSHeight(frameRect), NSWidth(frameRect)) / 2.0 * kRadiusScale;
		//change bounds so origin is at center
		[self setBounds:NSOffsetRect([self bounds],
									 -NSWidth([self bounds])/2.0,
									 -NSHeight([self bounds])/2.0)];
	}

	[self setNeedsDisplay: YES];
	return self;
}

// workaround for manually scaling up the UI in RNController awakeFromNib
- (void)updateDrawingMetricsForScale:(CGFloat) scale {
    NSRect frameRect = self.frame;
    _drawRadius = fmax(NSHeight(frameRect), NSWidth(frameRect)) / 2.0 * kRadiusScale;

    // Recenter the coordinate system
    CGFloat shiftRatio = (scale - 1.0) / (2.0 * scale);
    [self setBounds:NSOffsetRect([self bounds],
                                 -NSWidth([self bounds]) * shiftRatio,
                                 -NSHeight([self bounds]) * shiftRatio)];
}

- (void) dealloc
{
	[_network autorelease];
	_network = nil;
	[_nodeHistogramViews release];
	_nodeHistogramViews = nil;
    [super dealloc];
}

- (RNNetwork *) network {
	return _network;
}

- (double) drawRadius 
{
	return _drawRadius;
}

//setNetwork: nil resets and empties the view
- (void) setNetwork: (RNNetwork *) newNetwork
{
	if (_network != newNetwork) {
		[_network release];
		_network = [newNetwork retain];
		if (newNetwork != nil)
			[self synchronizeWithStimuli]; //setup histogram views
		else 
			[self removeNodeHistograms];
			
		[self setNeedsDisplay: YES];
	}
}

- (void) synchronizeWithStimuli
{
	//for each tapper node, figure out associated stimulus & initialize a view & make subview of this one
	id node;
	int subChannel;
	RNNodeNum_t nodeNumber;
	RNStimulus *stim;
	RNNodeHistogramView *histView;
	
	if ([[self network] numStimulusChannels] == 0) //only do this if we have stimulus channels
		return;
	
	if (_nodeHistogramViews == nil) {
		[self initNodeHistograms];
	}	
	
	NSEnumerator *nodeEnumerator = [[[self network] nodeList] objectEnumerator];
	
	while (node = [nodeEnumerator nextObject]) {
		nodeNumber = [node nodeNumber];
		if (nodeNumber != 0) {
			if ([node hearsBigBrother])
				subChannel = [node bigBrotherSubChannel];
			else
				subChannel = 1; //if not, link to first stimulus? better would be to link to subnet's dominant stim
			
			stim = [[self network] stimulusForChannel:subChannel];
			histView = _nodeHistogramViews[(nodeNumber-1)]; //-1 bec bb node was not added in the array
			[histView setTargetStimulus:stim];
		}
	}
	[self setNeedsDisplay: YES];
}

- (void) initNodeHistograms
{
	//for each tapper node, initialize a view & make subview of this one
	id node;
	RNNodeNum_t nodeNumber;
	RNNodeHistogramView *histView;
	NSPoint nodeLocation;
	NSRect frameRect;
	float x, y, width, height;
	
	NSEnumerator *nodeEnumerator = [[[self network] nodeList] objectEnumerator];
	
	_nodeHistogramViews = [[NSMutableArray arrayWithCapacity:1] retain];
	
	while (node = [nodeEnumerator nextObject]) {
		nodeNumber = [node nodeNumber];
		if (nodeNumber != 0) {
			//locate it on view. round to get more uniform drawing (we're using thin lines)
			nodeLocation = [node plotLocation];
			x = round( (nodeLocation.x + 0.1) * _drawRadius );
			y = round( (nodeLocation.y + 0.1) * _drawRadius );
			width = round( 0.2 * _drawRadius );
			height = round( 0.2 * _drawRadius );
			frameRect = NSMakeRect(x,y,width,height);
			histView = [[[RNNodeHistogramView alloc] initWithFrame:frameRect] autorelease];
			[self addSubview:histView]; //this retains, balance with [histView removeFromSuperview]
			[_nodeHistogramViews addObject:histView]; //this also retains, release in dealloc
		}
	}
}

-(void) removeNodeHistograms
{
	if (_nodeHistogramViews == nil) //only if histograms have been initialized
		return;
	
	//remove histogram views from view hierarchy
	NSEnumerator *histEnumerator = [_nodeHistogramViews objectEnumerator];
	RNNodeHistogramView *hist;
	while (hist = [histEnumerator nextObject]) {
		[hist removeFromSuperview];
	}
	[_nodeHistogramViews release];
	_nodeHistogramViews = nil;
}


- (void) showNodeHistograms
{
	
}

- (void) hideNodeHistograms
{
	
}

- (void) clearData
{
	//for each tapper node, figure out associated stimulus & initialize a view & make subview of this one
	id node;
	RNNodeNum_t nodeNumber;
	RNNodeHistogramView *histView;
	
	if ([[self network] numStimulusChannels] == 0) //only do this if we have stimulus channels
		return;
	
	if (_nodeHistogramViews == nil) {
		[self initNodeHistograms];
	}	
	
	NSEnumerator *nodeEnumerator = [[[self network] nodeList] objectEnumerator];
	
	while (node = [nodeEnumerator nextObject]) {
		nodeNumber = [node nodeNumber];
		if (nodeNumber != 0) {
			histView = _nodeHistogramViews[(nodeNumber-1)]; //-1 bec bb node was not added in the array
			[histView clearData];
		}
	}
	[self setNeedsDisplay: YES];
	
}

- (void) setPlotData:(BOOL) doIt
{
	_doPlotData = doIt;
}

- (void) setDataView: (RNDataView *) dataView
{
	_dataView = dataView;
}


- (void)drawRect:(NSRect)rect
{	
	//clear the rect
	//stroke around edges
	NSBezierPath *aPath = [NSBezierPath bezierPathWithRect:[self bounds]];
	//[[NSColor windowBackgroundColor] setFill];
    [[NSColor whiteColor] setFill]; // Not Dark-mode friendly, but I don't like windowBackgroundColor look so keep it
	[aPath fill];
    [[NSColor blackColor] setStroke];
	[aPath stroke];
	
	if (_network != nil) {
		[_network drawWithRadius: _drawRadius];
	}	
}

// TEST CODE
// test flashing with key 1-6
- (void)keyDown:(NSEvent *)event {
    NSString *chars = [event charactersIgnoringModifiers];
    unichar c = [chars characterAtIndex:0];
    
    NSArray *nodeList = [_network nodeList];
    
    if (c >= '1' && c <= '6') {
        NSInteger index = c - '0';
        [nodeList[index] flashWithColor:[NSColor systemBlueColor]];
    }
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void) viewDidMoveToWindow {
    [self.window makeFirstResponder:self];
}
// TEST CODE END

// this is merely for display purposes: to flash nodes when input has arrived
// need to do it here, as network itself doesn't know the view it's drawn in
- (void) receiveMIDIData: (NSData *) MIDIData
{
	NSAssert( (_network != nil), @"Receiving midi, but no network associated with view");
	
	//Flash the node, if we're set to do so
	if (_doShowMIDIActivity) {
		//from channel, note figure out which node this is from
		NoteOnMessage *message = (NoteOnMessage *) [MIDIData bytes];
		RNNodeNum_t iNode = [_network nodeIndexForChannel:message->channel Note: message->note];
		NSArray *nodeList = [_network nodeList];
		
		// it's a valid node
		if (iNode != 0xFFFF) {
			//for bb, recover which subchannel this is based on the midi channel
			if ( iNode == 0) {
				Byte stimulusChannel = [nodeList[iNode] stimulusNumberForMIDIChannel:message->channel];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [nodeList[iNode] flashStimulusChannel:stimulusChannel];
                });
				
			} else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [nodeList[iNode] flashWithColor:[NSColor systemBlueColor]];
                });
				
                //send event to appropriate histogramView
				if (_doPlotData == YES) {
					if (_nodeHistogramViews != nil) {
						RNNodeHistogramView *hview = _nodeHistogramViews[(iNode-1)]; //**note indexing
						[hview addEventAtTime:message->eventTime_ns];
						//mine histogram view data to add to ITI plot
						if (_dataView != nil) {
                            [_dataView addEventAtTime: [hview lastEventTime] withITI: [hview lastITI] forNode:iNode];
						}
					}
				}
			}
		} else { 	//if it's unexpected, display the offending channel, note info		
					//NSAssert( (iNode != 0xFFFF), @"Received MIDI channel,note that doesn't correspond to a node!");
					//NSAssert( (iNode < [nodeList count]), @"Shouldn't happen--iNode out of range in channel,note conversion");
			NSString *badMIDIStr = [NSString stringWithFormat:@"?c%d, %d?", message->channel, message->note];
			NSLog(@"\n\t%@", badMIDIStr);
		}
	}

}


@end
