//
//  RNTapperNode.h
//  RhythmNetwork
//
//  Created by John Iversen on 10/10/04.
//  Copyright 2004 John Iversen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

#define kNumConcentrators 4
#define kNumInputsPerConcentrator 6
#define kPatchThruPort 7
#define kBigBrotherPort 8
#define kBigBrotherChannel 16
#define kBaseNote 64

#define kNodeScale 0.075

typedef UInt16 RNNodeNum_t;

@class MIOCVelocityProcessor;

@interface RNTapperNode : NSObject {
	RNNodeNum_t	_nodeNumber; //as if...we'll ever have > 255 tappers, but it's logically possible
	Byte	_sourcePort; //where to find tapper's performance
	Byte	_sourceChan;
	Byte	_sourceNote;
	Byte	_destPort; //where to send sound for this tapper to hear
	Byte	_destChan;
	Byte	_destNote; //can this also be mapped by MIOC?
	Byte    _drumsetNumber; //program number on drum machine (0 to 49 for user sets)
	MIOCVelocityProcessor	*_sourceVelocityProcessor; //processing applied to performance
	MIOCVelocityProcessor	*_destVelocityProcessor; //processing applied to sound sent to tapper
	MIOCVelocityProcessor	*_otherNodeVelocityProcessor; //applied to performance destined for other nodes
	BOOL	_hearsSelf;
	BOOL	_hearsBigBrother;
	Byte	_bigBrotherSubChannel;
	NSPoint _plotLocation; //for drawing, in normalized coordinates
	NSColor *_flashColor;
	double	_flashIntensity;  //1 then fades to 0
	NSTimer	*_flashTimer;
    CAShapeLayer *_flashLayer;
    CAShapeLayer *_ringLayer;
}

+ (CAShapeLayer *)flashLayerForRect:(NSRect)rect;
+ (CAShapeLayer *)ringLayerForRect:(NSRect)rect;

+ (NSArray *) colorArray;

- (RNTapperNode *)initWithNodeNumber: (RNNodeNum_t) nodeNumber; //designated initializer
- (void)dealloc;

- (RNNodeNum_t) nodeNumber;

- (void) setSourcePort: (Byte) newSourcePort SourceChan: (Byte) newSourceChan SourceNote: (Byte) newSourceNote;
- (void) setDestPort: (Byte) newDestPort DestChan: (Byte) newDestChan DestNote: (Byte) newDestNote;

- (Byte) sourcePort;
- (void) setSourcePort: (Byte) newSourcePort;

- (Byte) sourceChan;
- (void) setSourceChan: (Byte) newSourceChan;

- (Byte) sourceNote;
- (void) setSourceNote: (Byte) newSourceNote;

- (Byte) destPort;
- (void) setDestPort: (Byte) newDestPort;

- (Byte) destChan;
- (void) setDestChan: (Byte) newDestChan;

- (Byte) destNote;
- (void) setDestNote: (Byte) newDestNote;

- (Byte) otherNodePassthroughPort;
- (Byte) otherNodePassthroughChan;

- (MIOCVelocityProcessor *) sourceVelocityProcessor;
- (void) setSourceVelocityProcessor: (MIOCVelocityProcessor *) newSourceVelocityProcessor;

- (MIOCVelocityProcessor *) destVelocityProcessor;
- (void) setDestVelocityProcessor: (MIOCVelocityProcessor *) newDestVelocityProcessor;

- (MIOCVelocityProcessor *) otherNodeVelocityProcessor;
- (void) setOtherNodeVelocityProcessor: (MIOCVelocityProcessor *) newVelocityProcessor;

- (Byte) drumsetNumber;
- (void) setDrumsetNumber:(Byte) newDrumsetNumber;

- (NSPoint) plotLocation;
- (void) setPlotLocation: (NSPoint) newPlotLocation;
- (void) setPlotLocationX: (double) x Y: (double) y; //convenience

- (BOOL) hearsSelf;
- (void) setHearsSelf: (BOOL) flag;

- (BOOL) hearsBigBrother;
- (void) setHearsBigBrother: (BOOL) flag;

- (Byte) bigBrotherSubChannel;
- (void) setBigBrotherSubChannel: (Byte) newSubChannel;

- (void) drawWithRadius: (double) radius;
- (void) flashWithColor: (NSColor *) flashColor;


@end
