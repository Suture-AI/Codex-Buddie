#import "BuddieView.h"
#import <objc/runtime.h>

static NSColor *Ink(void) { return [NSColor colorWithSRGBRed:.10 green:.16 blue:.14 alpha:1]; }
static NSColor *Lime(void) { return [NSColor colorWithSRGBRed:.76 green:.95 blue:.46 alpha:1]; }
static void Oval(NSRect r, NSColor *c) { [c setFill]; [[NSBezierPath bezierPathWithOvalInRect:r] fill]; }

@implementation BuddieView
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (NSView *)hitTest:(NSPoint)p { return nil; }
- (void)drawRect:(NSRect)dirty {
    [NSGraphicsContext saveGraphicsState];
    // SoftwareCursorStyle's native hotspot is (4, 4). FogCursorStyle's is
    // the centre of its view. Neither the window frame nor the hotspot changes.
    NSPoint hotspot = self.softwareStyle ? NSMakePoint(4, 4) : NSMakePoint(NSMidX(self.bounds), NSMidY(self.bounds));
    CGFloat scale = MIN(1., MIN((self.bounds.size.width-hotspot.x)/26., (self.bounds.size.height-hotspot.y)/32.));
    if (scale <= 0) { [NSGraphicsContext restoreGraphicsState]; return; }
    NSAffineTransform *t = [NSAffineTransform transform];
    [t translateXBy:hotspot.x - 4*scale yBy:hotspot.y - 4*scale];
    [t scaleBy:scale];
    [t concat];
    // The antenna tip is the exact click point. Body extends down and right.
    NSBezierPath *antenna = [NSBezierPath bezierPath];
    [antenna moveToPoint:NSMakePoint(4, 4)];
    [antenna lineToPoint:NSMakePoint(12, 13)];
    antenna.lineWidth = 2.4; antenna.lineCapStyle = NSLineCapStyleRound;
    [Ink() setStroke]; [antenna stroke];
    Oval(NSMakeRect(1.5, 1.5, 5, 5), Ink());
    Oval(NSMakeRect(2.5, 2.5, 3, 3), Lime());
    NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(5, 11, 25, 23) xRadius:9 yRadius:9];
    [Lime() setFill]; [body fill]; body.lineWidth = 1.8; [Ink() setStroke]; [body stroke];
    Oval(NSMakeRect(10, 18, 4, 6), Ink());
    Oval(NSMakeRect(21, 18, 4, 6), Ink());
    Oval(NSMakeRect(10.9, 18.5, 1.3, 1.6), NSColor.whiteColor);
    Oval(NSMakeRect(21.9, 18.5, 1.3, 1.6), NSColor.whiteColor);
    NSBezierPath *smile = [NSBezierPath bezierPath];
    [smile moveToPoint:NSMakePoint(15, 27)];
    [smile curveToPoint:NSMakePoint(20, 27) controlPoint1:NSMakePoint(16, 30) controlPoint2:NSMakePoint(19, 30)];
    smile.lineWidth = 1.5; [Ink() setStroke]; [smile stroke];
    Oval(NSMakeRect(8, 32, 7, 4), Ink()); Oval(NSMakeRect(22, 32, 7, 4), Ink());
    [NSGraphicsContext restoreGraphicsState];
}
@end

static const char originalKey, replacementKey;

BOOL BuddieIsCursorWindow(NSWindow *window) {
    NSString *name = NSStringFromClass(window.class);
    return [name isEqualToString:@"ComputerUse.ComputerUseCursor.Window"] ||
           [name isEqualToString:@"_TtCC11ComputerUse17ComputerUseCursor6Window"];
}

BOOL BuddieReplaceContent(NSWindow *window, NSView *original) {
    if (!BuddieIsCursorWindow(window) || !original || [original isKindOfClass:BuddieView.class]) return NO;
    NSString *name = NSStringFromClass(original.class);
    BOOL software = [original isKindOfClass:NSImageView.class];
    BOOL fog = [name containsString:@"NSHostingView"] && [name containsString:@"CursorView"];
    if (!software && !fog) {
        fprintf(stderr, "[Buddie] Unsupported cursor content; leaving original renderer intact.\n");
        return NO;
    }
    BuddieView *replacement = [[BuddieView alloc] initWithFrame:original.frame];
    replacement.softwareStyle = software;
    replacement.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [replacement setAccessibilityElement:NO];
    // Keep the original view alive: native Style retains/queries it for geometry.
    // It is detached, not layered under the new character.
    objc_setAssociatedObject(window, &originalKey, original, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(window, &replacementKey, replacement, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    window.contentView = replacement;
    fprintf(stderr, "[Buddie] Replaced native %s cursor artwork.\n", software ? "software" : "fog");
    return YES;
}
