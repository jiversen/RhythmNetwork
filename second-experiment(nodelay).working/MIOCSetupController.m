#import "MIOCSetupController.h"

#import "MIOCModel.h"
#import "MIOCConnection.h"
#import "MIDIIO.h"
#import "NSStringHexStringCategory.h"

#import "RNTapperNode.h"
#import "RNConnection.h"
#import "RNStimulus.h"
#import "RNExperimentPart.h"
#import "MIOCVelocityProcessor.h"

enum connectFormIdx {
	kFormPortIdx = 0,
	kFormChanIdx
};

@implementation MIOCSetupController

// *********************************************
//    INIT
// *********************************************

- (void)awakeFromNib
{
	_deviceObject = [[MIOCModel alloc] init];
	[self populatePopups];
	//register to receive notifications of MIDI setup changes
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(handleMIDISetupChange:) 
												 name:@"MIDIIOSetupChangeNotification" 
											   object:nil];
	//register us to receive sysex, too
	[[_deviceObject MIDILink] registerSysexListener:self];
	
	//initialize UI
	[_messageToSend setStringValue:@"f0 00 20 0d 00 20 00 45 f7"];
	[_response setFont:[NSFont userFontOfSize:10.0]];
	
	//register to receive notifications of MIOC device status changes
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(handleMIOCChange:) 
												 name:@"MIOCModelChangeNotification" 
											   object:nil];
		
	//hack place--testing
	
	//RNTapperNode *test = [[RNTapperNode alloc] initWithNodeNumber:6];
	//test = [[RNTapperNode alloc] initWithNodeNumber:7];
	
	//RNConnection *conn;
	//NSString *str;
	//conn = [[RNConnection alloc] initWithFromNode: 1 ToNode: 2];
	//[conn autorelease];

	//str = @"{3, 4} 0.52";
	//conn = [[RNConnection alloc] initWithString: str];
	//[conn autorelease];

	//str = @"{3, 4}";
	//[conn autorelease];
	//conn = [[RNConnection alloc] initWithString: str];
	
	//NSString *str;
	//str = @"1(64): IOI=800.0, events=2, phase=400.0";
	//RNStimulus *stim = [[RNStimulus alloc] initWithString:str];
	//NSData *pl = [stim MIDIPacketListForExperimentStartTime:1];
	
	//NSDate *absStartTime = [NSDate dateWithTimeIntervalSinceNow:2.0];
	//NSLog(@"\n\tStart time: %@", [absStartTime description]);
	//RNExperimentPart *temp = [[RNExperimentPart alloc] initWithObject:nil RelativeStartTime:1.0];
	//[temp scheduleForExperimentStartTime:absStartTime];
	
//	MIOCVelocityProcessor *velproc1 = [[MIOCVelocityProcessor alloc] initWithPort:1 Channel:2 OnInput:NO];
//	MIOCVelocityProcessor *velproc2 = [[MIOCVelocityProcessor alloc] initWithPort:1 Channel:2 OnInput:NO];
//	MIOCVelocityProcessor *velproc3 = [[MIOCVelocityProcessor alloc] initWithPort:1 Channel:2 OnInput:YES];
//	[velproc3 setWeight:0.5];
//	[velproc1 setConstant:100];
//	BOOL b;
//	b = [velproc1 isEqual:velproc2];
//	b = [velproc1 isEqual:velproc3];
//	NSLog(@"velocity proc: %@", [velproc1 description]);
	
}
    
- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"MIDIIOSetupChangeNotification" object:nil];
	[[_deviceObject MIDILink] removeSysexListener:self];
	[_deviceObject dealloc];
	[super dealloc];
}

- (MIOCModel *) deviceObject
{
	return _deviceObject;
}

// *********************************************
//    MANAGE UI
// *********************************************

//reset MIOC model and internal state (ensure synchronized)
- (IBAction) resetMIOCAction:(id)sender
{
	NSLog(@"Reset MIOC...");
	[_deviceObject reset];
}


// *********************************************
//  Source & Destination selection popups

- (void)populatePopups 
{
	[_sourcePopup removeAllItems];
	[_sourcePopup addItemsWithTitles:[[_deviceObject MIDILink] getSourceList]];
	[_sourcePopup selectItemWithTitle:[[_deviceObject MIDILink] sourceName]];
	[_destinationPopup removeAllItems];
	[_destinationPopup addItemsWithTitles:[[_deviceObject MIDILink] getDestinationList]];
	[_destinationPopup selectItemWithTitle:[[_deviceObject MIDILink] destinationName]];
}

- (void) handleMIDISetupChange:(NSNotification *) notification
{	
	[self populatePopups];
}

- (void) handleMIOCChange:(NSNotification *) notification
{	
	[_MIOCName setStringValue:[_deviceObject deviceName]];
}


- (IBAction)selectDestination:(id)sender
{
	[[_deviceObject MIDILink] useDestinationNamed:[sender titleOfSelectedItem]];
}

- (IBAction)selectSource:(id)sender
{
	[[_deviceObject MIDILink] useSourceNamed:[sender titleOfSelectedItem]];
}

// *********************************************
//  Toggle Drawer

- (IBAction)toggle:(id)sender
{
	if ([_myDrawer state] == NSDrawerClosedState || [_myDrawer state] == NSDrawerClosingState) {
		[self populatePopups];
		[_myDrawer openOnEdge:NSMaxXEdge];
	} else
		[_myDrawer close];
}

// *********************************************
//  Device information

//TODO: query model for this info; pull the info from the model
//eventually, have a list of all devices


// *********************************************
//    SYSEX SEND/RECEIVE
// *********************************************
     
- (IBAction)SendAction:(id)sender
{
	NSString *sendStr = [_messageToSend stringValue];
	NSData *data = [sendStr convertHexStringToData];
	
	NSLog(@"Send Button Pressed\n\tData (%d B): %@", [data length], data);
	[[_deviceObject MIDILink] sendSysex:data];
	
	//add outgoing to receive box
	[_response setString:sendStr];
	
}

//test connect/disconnect routing processor
- (IBAction)ConnectAction:(id) sender
{
	MIOCConnection *con = [MIOCConnection connectionWithInPort:[[_inForm  cellAtIndex:kFormPortIdx] intValue]
													 InChannel:[[_inForm  cellAtIndex:kFormChanIdx] intValue]
													   OutPort:[[_outForm cellAtIndex:kFormPortIdx] intValue]
													OutChannel:[[_outForm cellAtIndex:kFormChanIdx] intValue]];
	NSLog(@"will connect %@", con);
	[_deviceObject connectOne:con];
	
	// this is just to show the result in the window
	Byte flag[1] = {0x80};
	NSData *message = [_deviceObject sysexMessageForProcessor:con withFlag:flag];
	//***test of decoding process
	NSData *decoded = [_deviceObject decodeMessage:message];
	[_response setString: [[[NSString alloc] initHexStringWithData:decoded] autorelease] ];
}

- (IBAction)DisconnectAction:(id) sender
{
	MIOCConnection *con = [MIOCConnection connectionWithInPort:[[_inForm  cellAtIndex:kFormPortIdx] intValue]
													 InChannel:[[_inForm  cellAtIndex:kFormChanIdx] intValue]
													   OutPort:[[_outForm cellAtIndex:kFormPortIdx] intValue]
													OutChannel:[[_outForm cellAtIndex:kFormChanIdx] intValue]];
	NSLog(@"will disconnect %@", con);
	[_deviceObject disconnectOne:con];
	
	// this is just to show the result in the window
	Byte flag[1] = {0x00};
	NSData *message = [_deviceObject sysexMessageForProcessor:con withFlag:flag];
	[_response setString: [[[NSString alloc] initHexStringWithData:message] autorelease] ];
}
    
- (void)receiveSysexData:(NSData *)data
{
	NSString *hexStr = [[[NSString alloc] initHexStringWithData:data] autorelease];
	//NSLog(@"MIOCSetupController Received Sysex (%d bytes): %@\n",[data length], hexStr);
	//append to outgoing data that is in view
	NSMutableString *outStr = [NSMutableString stringWithString:[_response string]];
	[outStr appendString:@" -> "];
	[outStr appendString:hexStr];
	
	//also, decode it
	NSData *decoded = [_deviceObject decodeMessage:data];
	hexStr =[[[NSString alloc] initHexStringWithData:decoded] autorelease];
	[outStr appendFormat:@"\n[ %@ ]", hexStr];
	
	[_response setString:outStr];
}

@end
