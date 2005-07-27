/* RNDataView */

#import <Cocoa/Cocoa.h>

#import "RNTapperNode.h"

@interface RNDataView : NSView
{ 
	NSMutableArray	*_x;
	NSMutableArray	*_y;
	NSMutableArray  *_xMarks;
	NSMutableArray  *_yMarks;
	NSSize			_xlim;
	NSSize			_ylim;
		
}

- (void) clearData;

- (void) addEventAtTime:(double) time_ms withITI:(double) ITI_ms forNode:(RNNodeNum_t) iNode;

- (void) addMarkAtTime:(double) time_ms;
- (void) addMarkAtITI:(double) ITI_ms;

@end
