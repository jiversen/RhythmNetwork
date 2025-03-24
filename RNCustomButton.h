//
//  RNCustomButton.h
//  RhythmNetwork
//
//  Created by John R. Iversen on 2025-03-23.
// https://chatgpt.com/share/67e08ad4-80f8-8007-8a2e-7ecf9481071a

#import <Cocoa/Cocoa.h>

@interface RNCustomButton : NSView {
    NSString *_title;
    NSFont *_font;
    BOOL _isHighlighted;
    BOOL _isHovered;
    BOOL _enabled;
    id _target;
    SEL _action;
    NSTrackingArea *_trackingArea;
}

// Initialize from an existing NSButton
- (instancetype)initWithButtonToReplace:(NSButton *)oldButton;

// Set title font
- (void)setFont:(NSFont *)font;

// Target-action interface
- (void)setTarget:(id)target action:(SEL)action;

// Standard enable/disable support
- (void)setEnabled:(BOOL)enabled;
- (BOOL)isEnabled;

@end
