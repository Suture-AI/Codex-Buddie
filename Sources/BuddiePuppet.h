#import "BuddieCharacter.h"
#import "BuddieMotion.h"

// Draw in top-left canvas coordinates; the caller supplies the hotspot transform.
void BuddieDrawPuppet(BuddieCharacter *character, BuddiePose pose, BOOL facingLeft, double elapsed, BOOL reduced);
// Canvas-space sole contacts before the caller's scale/translation, for geometry checks.
NSPoint BuddiePuppetSole(BuddieCharacter *character, BuddiePose pose, NSUInteger foot);
