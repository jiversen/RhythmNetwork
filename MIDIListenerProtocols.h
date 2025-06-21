//
//  MIDIListenerProtocols.h
//  RhythmNetwork
//
//  Created by John R. Iversen on 2025-06-01.
//

#import <Foundation/Foundation.h>

@protocol MIDIDataReceiver <NSObject>
- (void)receiveMIDIData:(NSData *)data;
@end

@protocol SysexDataReceiver <NSObject>
- (void)receiveSysexData:(NSData *)data;
@end
