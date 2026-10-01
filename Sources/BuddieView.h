#import <Cocoa/Cocoa.h>

// Coordinates are points, with the origin at the top left, like native hotspots.
@interface BuddieView : NSView
@property BOOL softwareStyle;
@end

BOOL BuddieIsCursorWindow(NSWindow *window);
BOOL BuddieReplaceContent(NSWindow *window, NSView *original);
