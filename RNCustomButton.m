//
//  RNCustomButton.m
//  RhythmNetwork
//
//  Created by John R. Iversen on 2025-03-23.
// https://chatgpt.com/share/67e08ad4-80f8-8007-8a2e-7ecf9481071a

#import "RNCustomButton.h"
#import <QuartzCore/QuartzCore.h>

@implementation RNCustomButton

- (instancetype)initWithFrame:(NSRect)frameRect title:(NSString *)title {
    self = [super initWithFrame:frameRect];
    if (self) {
        _title = [title copy];
        _font = [NSFont systemFontOfSize:13];
        _enabled = YES;
        self.wantsLayer = YES;
    }
    return self;
}

- (void)dealloc {
    [_font release];
    [_title release];
    [super dealloc];
}

- (instancetype)initWithButtonToReplace:(NSButton *)oldButton {
    
    NSRect originalFrame = oldButton.frame;
    NSRect insetFrame = NSInsetRect(originalFrame, 12.0, 12.0); // ⬅️ inset by 12 points on all sides

    self = [super initWithFrame:insetFrame];
    
    
    if (self) {
        _title = [oldButton.title copy];
        [self setTarget:oldButton.target action:oldButton.action];
        
        NSFont *oldFont = oldButton.font;
        // Scale down the font size slightly
        CGFloat newSize = oldFont.pointSize * 0.8;

        // Create a new font with the same descriptor, but semibold weight
        NSFontDescriptor *desc = [oldFont.fontDescriptor fontDescriptorByAddingAttributes:@{
            NSFontTraitsAttribute: @{ NSFontWeightTrait: @(NSFontWeightSemibold) }
        }];
        NSFont *adjustedFont = [NSFont fontWithDescriptor:desc size:newSize];
        [self setFont:adjustedFont];
    }
    return self;
}

- (void)setFont:(NSFont *)font {
    if (_font != font) {
        [_font release];
        _font = [font retain];
    }
    [self setNeedsDisplay:YES];
}

- (void)setTarget:(id)target action:(SEL)action {
    _target = target;
    _action = action;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [self setNeedsDisplay:YES];
}

- (BOOL)isEnabled {
    return _enabled;
}

- (BOOL)isFlipped {
    return YES;
}

- (void)mouseEntered:(NSEvent *)event {
    _isHovered = YES;
    [self updateGlow];
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event {
    _isHovered = NO;
    [self updateGlow];
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event {
    if (!_enabled) return;
    _isHighlighted = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    if (!_enabled) return;
    _isHighlighted = NO;
    [self setNeedsDisplay:YES];

    [self animatePulse];

    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (_enabled && NSPointInRect(point, self.bounds)) {
        if (_target && _action && [_target respondsToSelector:_action]) {
            [NSApp sendAction:_action to:_target from:self];
        }
    }
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];

    if (_trackingArea) {
        [self removeTrackingArea:_trackingArea];
    }

    _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                 options:(NSTrackingMouseEnteredAndExited |
                                                          NSTrackingActiveInActiveApp |
                                                          NSTrackingInVisibleRect)
                                                   owner:self
                                                userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor clearColor] setFill];
    NSRectFill(dirtyRect);

    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:12 yRadius:12];

    if (_enabled) {
        [[NSColor controlColor] setFill]; //controlColor
    } else {
        [[NSColor disabledControlTextColor] setFill];
    }
    [path fill];

    if (_isHighlighted) {
        [[NSColor selectedControlColor] setFill];
        [path fill];
    }
    

    // Title drawing
    NSColor *textColor = _enabled ? [NSColor controlTextColor] : [NSColor disabledControlTextColor];

    NSDictionary *attrs = @{
        NSFontAttributeName: _font,
        NSForegroundColorAttributeName: textColor
    };
    NSSize textSize = [_title sizeWithAttributes:attrs];
    NSPoint textPoint = NSMakePoint((NSWidth(self.bounds) - textSize.width) / 2,
                                    (NSHeight(self.bounds) - textSize.height) / 2);
    [_title drawAtPoint:textPoint withAttributes:attrs];
}

- (void)updateGlow {
    if (_isHovered && _enabled) {
        self.layer.shadowColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.7].CGColor;
        self.layer.shadowOpacity = 0.4;
        self.layer.shadowRadius = 6.0;
        self.layer.shadowOffset = CGSizeZero;
    } else {
        self.layer.shadowOpacity = 0.0;
    }
}

- (void)animatePulse {
    self.wantsLayer = YES;

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    pulse.fromValue = @(1.0);
    pulse.toValue = @(0.3);
    pulse.duration = 0.15;
    pulse.autoreverses = YES;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];

    [self.layer addAnimation:pulse forKey:@"pulseAnimation"];
}

@end
