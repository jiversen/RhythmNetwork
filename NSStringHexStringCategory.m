//
//  NSStringHexStringCategory.m
//  RhythmNetwork
//
//  Created by John Iversen on 9/2/04.
//  Copyright 2004 John Iversen. All rights reserved.
//

#import "NSStringHexStringCategory.h"

@implementation NSString ( HexStringCategory )

// *********************************************
//  create hexidecimal string w/ space between bytes xx xx xx...
- (NSString *)initHexStringWithData:(NSData *) data
{
	unsigned int i, n, stringLen;
	char *cStr, tmpStr[16], space;
	Byte *src, byteVal;
			
	n = [data length];
	src = (Byte *) [data bytes];
	stringLen = n * 3; //allow for 2 hex digits plus space (& null at end)
	cStr = (char *) calloc(stringLen, sizeof(char)); // initializes to zeros; malloc does not
	for (i = 1; i<= n; i++) {
		byteVal = *src++;
		space = (i < n)?0x20:0x00;
		if (byteVal < 0x10)
			sprintf(tmpStr, "0%X%c", byteVal, space);
		else
			sprintf(tmpStr, "%X%c", byteVal, space);
		strcat(cStr, tmpStr);
	}
	
    self = [self initWithCString:cStr encoding:NSASCIIStringEncoding];
	free(cStr);
	return self;

}

// *********************************************
//  Convert a hex string w/ space between bytes into a data buffer
- (NSData *)convertHexStringToData
{
	const char *hexStrUTF;
	char *endPtr;
	unsigned long	longVar;
	Byte *dest, *p;
	size_t	buflen, n=0;
	
	hexStrUTF = [self UTF8String];
	buflen = (strlen(hexStrUTF)/3) + 1; //approximation of length of data
										// assumes xx xx xx (space between bytes)
	dest = malloc(buflen);
	p = dest;
	//decode a hex text string and place bytes into source buffer
	longVar = strtoul(hexStrUTF, &endPtr, 16);
	*p++ = (Byte) longVar;
	++n;
	while (*endPtr != '\0') {
		longVar = strtoul(endPtr, &endPtr, 16);
		*p++ = (Byte) longVar;		
		++n;
		NSAssert( (n <= buflen), @"Buffer overflow");
	}
		
	NSData *data = [NSData dataWithBytes:dest length:n];
	free(dest);
	return data;
}

@end
