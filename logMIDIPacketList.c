// logging and forwarding received packets on async queue

void logMIDIPacketList(const MIDIPacketList *packetList, long pktlistLength, const MIDIIO *selfMIDIO)
{
	// LOG
#if 0
		os_log(OS_LOG_DEFAULT, "MIDI PacketList - Length: %d", packetList->numPackets);

		const MIDIPacket *packet = packetList->packet;

		for (int i = 0; i < packetList->numPackets; i++) {
			NSMutableString *dataString = [NSMutableString string];

			for (int j = 0; j < packet->length; j++) {
				[dataString appendFormat:@"%02X ", packet->data[j]];
			}

			os_log(OS_LOG_DEFAULT, " MIDI Packet - Timestamp: %llu, Length: %d, Data: %@", packet->timeStamp, packet->length, dataString);

			packet = MIDIPacketNext(packet);
		}
#endif

	// WRAP and forward to our  handler
	CFDataRef wrappedPktlist = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)packetList, (CFIndex)pktlistLength);
	[selfMIDIO handleMIDIInput:(NSData *)wrappedPktlist];
}
