#import <Cocoa/Cocoa.h>

// A pack is data and local PNGs, never executable code.
@interface BuddieCharacter : NSObject <NSCopying>
@property(copy) NSString *identifier;
@property(copy) NSString *name;
@property NSColor *bodyColor;
@property NSColor *inkColor;
@property NSColor *accentColor;
@property NSSize bodySize;
@property CGFloat cornerRadius;
@property CGFloat eyeSpacing;
@property CGFloat eyeSize;
@property CGFloat faceY;
@property CGFloat footSpacing;
@property CGFloat footSize;
@property CGFloat stride;
@property CGFloat footLift;
@property NSImage *bodyImage;
@property NSImage *footImage;
+ (NSArray<BuddieCharacter *> *)presets;
+ (instancetype)loadPack:(NSURL *)folder error:(NSError **)error;
- (BOOL)savePack:(NSURL *)folder error:(NSError **)error;
@end
