//
//  RNNetwork.m
//  RhythmNetwork
//
//  Created by John Iversen on 10/10/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "RNNetwork.h"


@implementation RNNetwork

- (RNNetwork *) init
{
	NSAssert(FALSE, @"RNNetwork init, shouldn't be called");
	self = [super init];
	return self;
}

- (RNNetwork *) initFromPath: (NSString *) filePath
{
	self = [super init];
	
	//read file
	NSFileWrapper *fileWrapper = [[NSFileWrapper alloc] initWithPath: filePath];
	NSAssert1( (fileWrapper != nil), @"Could not open file %@", filePath);
	NSData *fileData = [fileWrapper regularFileContents];
	NSAssert1( (fileData != nil), @"Could not read data from file %@", filePath);
	//parse data line by line, first creating Nodes, then creating connections
	NSString *fileString = [[NSString alloc] initWithData:fileData encoding: NSASCIIStringEncoding];	
	NSCharacterSet *newlineSet = [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
	NSScanner	*theScanner = [NSScanner scannerWithString:fileString];
	NSString *line;
	BOOL gotLine;
	
	while ([theScanner isAtEnd] == NO) {
		gotLine = [theScanner scanUpToCharactersFromSet:newlineSet intoString:&line];
		NSAssert( (gotLine == YES), @"file scanning error");
		NSLog(line);
		//ignore lines starting with #
		//get 
	}
	
	return self;
}

- (void) drawWithRadius: (double) radius
{
	//test: draw a circle around origin
	NSRect aRect = NSMakeRect(-radius, -radius, 2.0*radius, 2.0*radius);
	NSBezierPath *aPath = [NSBezierPath	bezierPathWithOvalInRect:aRect];
	[aPath stroke];
}

@end
