#import "RNDataView.h"

@implementation RNDataView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		// Add initialization code here
	}
	return self;
}

- (void)drawRect:(NSRect)rect
{
	//clear background and outline edges
	NSBezierPath *aPath = [NSBezierPath bezierPathWithRect:[self bounds]];
	[[NSColor windowBackgroundColor] setFill];
	[aPath fill];
	[[NSColor blackColor] setStroke];
	[aPath stroke];
	
}

@end
