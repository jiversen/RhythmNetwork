#import "RNDataView.h"

@implementation RNDataView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {

		//initialize data storage
		// hardwired for now
		_xlim = NSMakeSize(0.0,60.0); //unconventional usage
		_ylim = NSMakeSize(400.0, 1500.0); //ms
	}
	return self;
}

- (void) clearData
{
	[_x release];
	_x = nil;
	[_y release];
	_y = nil;
	_x = [[NSMutableArray alloc] initWithCapacity:10];
	_y = [[NSMutableArray alloc] initWithCapacity:10];
	
	[self setNeedsDisplay:YES];
}

- (void) dealloc
{
	[_x release];
	_x = nil;
	[_y release];
	_y = nil;
	[super dealloc];
}

- (void) addEventAtTime:(double) time_ms withITI:(double) ITI_ms forNode:(RNNodeNum_t) iNode
{
	//add event to appropriate array (indexed by node)
	// if necessary, extend 
	int nNodes = [_x count]-1; //we use 1-based indexes
	if (iNode > nNodes) {
		int i;
		for (i = (nNodes+1); i <= iNode; i++) {
			[_x addObject: [[NSMutableArray alloc] initWithCapacity:100] ];
			[_y addObject: [[NSMutableArray alloc] initWithCapacity:100] ];
		}
	}
	//don't add 0 iti (e.g. first tap has no ITI defined)
	if (ITI_ms > 0) {
		[[_x objectAtIndex:iNode] addObject:[NSNumber numberWithDouble:time_ms]];
		[[_y objectAtIndex:iNode] addObject:[NSNumber numberWithDouble:ITI_ms]];
		
		[self setNeedsDisplay:YES];
	}

}

//for the future...
- (void) addMarkAtTime:(double) time_ms
{
	
}
- (void) addMarkAtITI:(double) ITI_ms
{
	
}

- (void)drawRect:(NSRect)rect
{
	//clear background and outline edges
	NSRect bounds = [self bounds];

	NSBezierPath *aPath = [NSBezierPath bezierPathWithRect:bounds];
	[[NSColor windowBackgroundColor] setFill];
	[aPath fill];
	[[NSColor blackColor] setStroke];
	[aPath stroke];
	
	//now draw curves for nodes
	int nNodes = [_x count] - 1; //we don't use element 0
	int iNode, nPoints, iPoint;
	NSColor *color;
	NSMutableArray *thisx, *thisy;
	double px, py;
	
	if (nNodes >= 1) {

		for (iNode = 1; iNode <= nNodes; iNode++) {
			color = [[RNTapperNode colorArray] objectAtIndex:iNode];
			thisx = [_x objectAtIndex:iNode];
			thisy = [_y objectAtIndex:iNode];
			[aPath removeAllPoints];
			nPoints = [thisx count];
			for (iPoint = 0; iPoint < nPoints; iPoint++) {
				px = [[thisx objectAtIndex:iPoint] doubleValue] / 1e3; //convert to s
				py = [[thisy objectAtIndex:iPoint] doubleValue];
				//scale into pixels (nb w = min; h = max for axes limits)
				px = (px - _xlim.width) / (_xlim.height - _xlim.width) * bounds.size.width;
				py = (py - _ylim.width) / (_ylim.height - _ylim.width) * bounds.size.height;
				if (iPoint==0)
					[aPath moveToPoint:NSMakePoint(px,py)];
				else
					[aPath lineToPoint:NSMakePoint(px, py)];
				[color setStroke];
				[aPath stroke];
			} //loop on points
			
			//NSLog(@"Draw Node %d (color %@), x data: %@; y data: %@", iNode, color, thisx, [_y objectAtIndex:iNode]);
		}
	}
}

@end
