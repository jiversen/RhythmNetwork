# RhythmNetwork — project instructions

## Relationship to Quadropus (sibling project at `../Quadropus`)

Quadropus was forked from RhythmNetwork's MIDI core and has since moved **ahead** of it. Several
low-level pieces here are stale relative to Quadropus. When picking up real-time / MIDI work, check
the Quadropus version first.

### Already synced (2026-06-07)
- **`TPCircularBuffer.{h,c}`** — the aligned-record API is now identical to Quadropus. Records are
  padded to `kTPAlignedRecordAlignment` (now **8**, was 4) via the single helper
  `TPAlignedRecordLength(len)`; producer and **every** consumer derive their stride from it. The two
  packet-walk sites in `MIDIIO.m` (`emitDelayedNotes:`, `handleMIDIPktlist:`) were converted from the
  old `(pktlistLength + 3) & ~3` to `bufferPtr += TPAlignedRecordLength((uint32_t)pktlistLength)`.
  Why 8: variable-length `MIDIPacketList`s embed a `uint64` `MIDITimeStamp`, which only lands aligned
  if each list *starts* on an 8-byte boundary — 4-byte padding doesn't guarantee that. See the long
  comment block in `TPCircularBuffer.h`. **If you ever re-sync, keep these two headers byte-identical.**

## NOT YET DONE — port Quadropus's decoupled hot-loop architecture (notes only; no code written)

The big stale piece: in RhythmNetwork, MIDI parsing/transform/emit lives **inline in `MIDIIO.m`**
(`handleMIDIPktlist:` + `emitDelayedNotes:`). Quadropus pulled all of that out behind a protocol so
the I/O object and the processing logic are independent. Porting that back here means:

1. **Adopt `MIDIRealtimeProcessorProtocol.h`** (copy from
   `../Quadropus/MIDIRealtimeProcessorProtocol.h`). It defines:
   - the one hot method `-processPacketList:availableBytes:outputTarget:`,
   - `MIDIOutputTarget { MIDIPortRef outPort; MIDIEndpointRef dest; MIDIEndpointRef virtualSource; }`
     (physical via `MIDISend`, virtual via `MIDIReceived`, both = tee),
   - the **RT contract** (no alloc / no locks / no blocking / no ObjC except on pre-allocated objects /
     `os_log` ok / bounded < 1 ms / shared state via `stdatomic`), and the `MIDI_RT_LOG(category)` macro
     (note: its bundle id string still says "quadropus" — fix when copying).

2. **Create `RNMIDIProcessor`** (the analog of `QPMIDIProcessor`): move the transform/decode and the
   delayed-note scheduling out of `MIDIIO.m` into a processor object conforming to the protocol. Keep
   the output buffer(s) pre-allocated at init, exactly as `QPMIDIProcessor` does. (RhythmNetwork already
   has a stale `RNMIDIProcessor.m` *template* — confirm whether to build on it or start clean.)

3. **Port the generalized `MIDIIO` back from Quadropus**, which is the cleaner version:
   - `initWithInputMode:outputMode:virtualName:` (input physical|virtual; output physical|virtual as a
     tee-able `NS_OPTIONS`), `-setMIDIProcessor:` settable any time,
   - read proc → `AlignedTPCircularBufferProduceBytes` → semaphore → processing thread drains
     `TPCircularBufferTail` (whole `availableBytes`) → `processPacketList:…` → **wholesale**
     `TPCircularBufferConsume(availableBytes)`. Walk lists with `TPAlignedRecordLength`.

### THE difference to preserve: the separate physical delay-port output
RhythmNetwork's MIDIIO has a feature Quadropus's does NOT: a **second physical destination** for
delayed output, implemented as a follower sub-interface `_delayMIDIIO` (`initFollower`, leader/follower
client/config sharing) plus `emitDelayedNotes:`, which schedules future-timestamped **note-on AND an
explicit note-off** to `_delayMIDIIO->_outPort/_MIDIDest`. Quadropus deliberately dropped this:
- Quadropus emits via `MIDIOutputTarget` (one physical dest + one virtual source, tee) and **drops
  note-offs** (drums ignore them); its negative-delay path uses *schedule-ahead + `MIDIFlushOutput` to
  abort*, not a separate delay port.
- So Quadropus's `MIDIOutputTarget` has **no slot for a delay destination**. To port forward *and*
  keep RhythmNetwork's delay port, you must either (a) extend `MIDIOutputTarget` with a delay
  `outPort`/`dest`, or (b) give the processor its own delay output target / a second processor. Also
  preserve the explicit note-off emission and the leader/follower config plumbing — neither exists in
  the Quadropus MIDIIO.

**Working style:** plan-first for anything on the RT path; small reviewable chunks; user commits.
