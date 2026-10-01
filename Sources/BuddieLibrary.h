#import "BuddieCharacter.h"

// Original artwork is installed once. Small, atomic settings files hold edits.
// A caller-supplied root keeps tests separate from the user's library.
@interface BuddieLibrary : NSObject
@property(readonly) NSArray<BuddieCharacter *> *characters;
@property(copy) NSString *selectedIdentifier;
@property BOOL reducedMotion;
@property(readonly) NSError *loadError;
+ (NSURL *)defaultURL;
- (instancetype)initWithURL:(NSURL *)root bundled:(NSArray<BuddieCharacter *> *)bundled;
- (BuddieCharacter *)characterForIdentifier:(NSString *)identifier;
- (void)rememberCharacter:(BuddieCharacter *)character;
- (void)resetIdentifier:(NSString *)identifier;
- (BOOL)installCharacter:(BuddieCharacter *)character error:(NSError **)error;
- (BOOL)save:(NSError **)error;
@end
