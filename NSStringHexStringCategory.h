//
//  NSStringHexStringCategory.h
//  RhythmNetwork
//
//  Created by John Iversen on 9/2/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

// simple category on NSString to support conversion between binary data and byte-wise
//	hexadecimal representations
// could just have well made this part of NSData, but felt it was more related to human-readable
//  UI

#import <Cocoa/Cocoa.h>


@interface NSString ( HexStringCategory )

- (NSString *)initHexStringWithData:(NSData *) data;

- (NSData *)convertHexStringToData;

@end
