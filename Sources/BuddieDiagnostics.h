#import <Cocoa/Cocoa.h>
@class BuddieView;
// Opt-in captures of our own renderer only, never desktop/window contents.
void BuddieCaptureCursor(BuddieView *view);
