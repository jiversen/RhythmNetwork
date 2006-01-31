#import "SimpleMIDIIOController.h"

#import "MIDIIO.h"
#import "MIOCModel.h"
#import "MIOCConnection.h"
#import "NSStringHexStringCategory.h"


@implementation SimpleMIDIIOController

// *********************************************
//     
- (SimpleMIDIIOController *)init
{
	self = [super init];
	//deviceObject = [[MIOCModel alloc] init];
	//ioObject	 = [[MIDIIO alloc] init];

	return self;
}

// *********************************************
//     
- (void) dealloc
{
	//[deviceObject dealloc];
	//[ioObject removeSysexListener:self];
	//[ioObject dealloc];
	[super dealloc];
}

// *********************************************
//     
- (void)awakeFromNib
{
	//temporary
	//[messageToSend setStringValue:@"f0 00 20 0d 00 01 02 f7"];
	
	//register us as a listener for sysex from MIDIIO
	//[ioObject registerSysexListener:self];
	
	//testing
	//MIOCConnection *conn = [[MIOCConnection alloc] initWithInPort:1 InChannel:2 OutPort:3 OutChannel:4];
	//MIOCConnection *conn2 = [[MIOCConnection alloc] initWithInPort:1 InChannel:2 OutPort:1 OutChannel:kOutChannelSameAsInput];
	//BOOL temp;
	//temp = [conn isEqual: conn2];
	
	//[deviceObject connectOne:conn];
	//[deviceObject connectOne:conn];
	//[deviceObject connectOne:conn2];
	//[deviceObject disconnectOne:conn];

	//[deviceObject disconnectAll];
	
	//NSString *str1 = @"hi";
	//NSString *str2 = [NSString stringWithString:@"hi"];
	
	//temp = [str1 isEqual: str2];
	

}

// *********************************************
//     
- (IBAction)SendAction:(id)sender
{
	//NSString *sendStr = [messageToSend stringValue];
	//NSData *data = [sendStr convertHexStringToData];
		
	NSLog(@"Send Button Pressed in old controller");
	//[ioObject sendSysex:data];
	//[ioObject sendMIDI:data];

}

// *********************************************
//     
- (void)receiveSysexData:(NSData *)data
{
	//NSString *hexStr = [[NSString alloc] initHexStringWithData:data];
	NSLog(@"Received Sysex in old controller\n");
	//[response setString:hexStr];
}

@end