#import <Cocoa/Cocoa.h>
#import "BuddieCharacter.h"
#import "BuddieMotion.h"

// Coordinates are points, with the origin at the top left, like native hotspots.
@interface BuddieView : NSView
@property BOOL softwareStyle;
@property(nonatomic) BuddieCharacter *character;
@property(nonatomic) BOOL manualAnimation;
@property BOOL reduceMotion;
@property CGFloat characterScale;
@property(readonly) NSPoint hotspot;
@property(readonly) CGFloat drawingScale;
// Read-only geometry for renderer diagnostics, in motion units.
@property(readonly) BuddiePose motionPose;
@property(readonly) double facingProgress;
- (void)animateAtTime:(double)time anchor:(BuddiePoint)anchor;
- (void)press:(BOOL)down atTime:(double)time;
// A settings-only edit keeps the running gait, turn, blink and press state.
- (void)applySavedCharacter:(BuddieCharacter *)character preservingMotion:(BOOL)preserve;
@end

BOOL BuddieIsCursorWindow(NSWindow *window);
BOOL BuddieReplaceContent(NSWindow *window, NSView *original);
