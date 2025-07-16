#import "RNDataView.h"

@implementation RNDataView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		// initialize data storage
		// hardwired for now
		_x		= [[NSMutableArray alloc] initWithCapacity:10];
		_y		= [[NSMutableArray alloc] initWithCapacity:10];
		_xlim	= NSMakeSize(0.0, 60.0);	// unconventional usage
		_ylim	= NSMakeSize(400.0, 1500.0);// ms
	}

	return self;
}

- (void)clearData
{
	[_x release];
	_x = nil;
	[_y release];
	_y	= nil;
	_x	= [[NSMutableArray alloc] initWithCapacity:10];
	_y	= [[NSMutableArray alloc] initWithCapacity:10];

	[self setNeedsDisplay:YES];
}

- (void)dealloc
{
	[_x release];
	_x = nil;
	[_y release];
	_y = nil;
	[super dealloc];
}

- (void)addEventAtTime:(double)time_ms withITI:(double)ITI_ms forNode:(RNNodeNum_t)iNode
{
	// add event to appropriate array (indexed by node)
	// if necessary, extend
	RNNodeNum_t nNodes = [_x count] - 1;// we use 1-based indexes

	if (iNode > nNodes) {
		for (int i = (nNodes + 1); i <= iNode; i++) {
			[_x addObject:[[NSMutableArray alloc] initWithCapacity:100]];
			[_y addObject:[[NSMutableArray alloc] initWithCapacity:100]];
		}
	}

	// don't add 0 iti (e.g. first tap has no ITI defined)
	if (ITI_ms > 0) {
		[_x[iNode] addObject:@(time_ms)];
		[_y[iNode] addObject:@(ITI_ms)];

		// if exceeds limit, rescale axis limits
		if (time_ms / 1e3 > _xlim.height) {
			_xlim.height = _xlim.height + 10;	// add in 10s steps
		}

		[self setNeedsDisplay:YES];
	}
}

// for the future...
- (void)addMarkAtTime:(double)time_ms
{}

- (void)addMarkAtITI:(double)ITI_ms
{}

- (void)drawRect:(NSRect)rect
{
	// clear background and outline edges
	NSRect bounds = [self bounds];

	NSBezierPath *aPath = [NSBezierPath bezierPathWithRect:bounds];

	[[NSColor windowBackgroundColor] setFill];
	[aPath fill];
	[[NSColor blackColor] setStroke];
	[aPath stroke];
	
	// July 2025 for some reason this never failed before--why is this view being drawn on init now--it's hidden and there is no experiment loaded
	if ([_x count] == 0) {
		return;
	}

	// now draw curves for nodes
	RNNodeNum_t		nNodes = [_x count] - 1;// we don't use element 0
	NSUInteger		iNode, nPoints, iPoint;
	NSColor			*color;
	NSMutableArray	*thisx, *thisy;
	double			px, py;

	if (nNodes >= 1) {
		for (iNode = 1; iNode <= nNodes; iNode++) {
			color	= [RNTapperNode colorArray][iNode - 1];
			thisx	= _x[iNode];
			thisy	= _y[iNode];
			[aPath removeAllPoints];
			nPoints = [thisx count];

			for (iPoint = 0; iPoint < nPoints; iPoint++) {
				px	= [thisx[iPoint] doubleValue] / 1e3;// convert to s
				py	= [thisy[iPoint] doubleValue];
				// scale into pixels (nb w = min; h = max for axes limits)
				px	= (px - _xlim.width) / (_xlim.height - _xlim.width) * bounds.size.width;
				py	= (py - _ylim.width) / (_ylim.height - _ylim.width) * bounds.size.height;

				if (iPoint == 0) {
					[aPath moveToPoint:NSMakePoint(px, py)];
				} else {
					[aPath lineToPoint:NSMakePoint(px, py)];
				}

				[color setStroke];
				[aPath stroke];
			}	// loop on points

			// NSLog(@"Draw Node %d (color %@), x data: %@; y data: %@", iNode, color, thisx, [_y objectAtIndex:iNode]);
		}
	}

	// to do: axes, limits
}

@end
