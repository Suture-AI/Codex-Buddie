#import "BuddieLibrary.h"
@class BuddieView;

// Native-only, read-only subscription. All public methods run on the main thread.
// Artwork and settings are read/prepared on a serial worker queue, then published
// as an immutable snapshot to registered cursor views.
@interface BuddieCursorLibrary : NSObject
@property(readonly) BuddieCharacter *character;
@property(readonly) BOOL reducedMotion;
@property(readonly) NSError *loadError;
- (instancetype)initWithURL:(NSURL *)root bundledLoader:(BuddieBundledLoader)loader;
- (void)start;
- (void)stop;
- (void)attachView:(BuddieView *)view;
@end

void BuddieStartNativeLibrary(void);
void BuddieAttachNativeLibrary(BuddieView *view);
