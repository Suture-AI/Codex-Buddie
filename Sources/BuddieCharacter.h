#import <Cocoa/Cocoa.h>

// Complete poses keep the artist's face, hands, clothes and feet together.
@interface BuddieSpriteClip : NSObject
@property(copy) NSArray<NSImage *> *frames;
@property(copy) NSArray<NSNumber *> *durations;
// Optional RGB material masks, one per frame. Black preserves the original art.
@property(copy) NSArray<NSImage *> *masks;
@property(readonly) NSTimeInterval duration;
- (NSUInteger)frameIndexAtTime:(double)time loop:(BOOL)loop;
@end

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
@property(copy) NSDictionary<NSString *,BuddieSpriteClip *> *clips;
@property NSSize spriteCanvas;
@property NSPoint spriteHotspot;
@property CGFloat spriteHeight;
@property BOOL mirrorWalk;
@property BOOL directionalIdle;
// Version 3: independent artwork parts, using the same clips/material pipeline.
@property(copy) NSDictionary<NSString *,NSDictionary *> *puppetParts;
@property CGFloat puppetMotionScale;
@property CGFloat torsoWidth;
@property CGFloat torsoHeight;
@property CGFloat headScale;
@property(nonatomic,copy) NSArray<NSDictionary *> *materials;
@property(nonatomic,copy) NSDictionary<NSString *,NSColor *> *materialColors;
- (void)prepareAppearance;
- (NSImage *)imageForClip:(NSString *)name frame:(NSUInteger)index;
+ (NSArray<BuddieCharacter *> *)presets;
+ (instancetype)bundledDefault;
+ (instancetype)loadPack:(NSURL *)folder error:(NSError **)error;
- (BOOL)savePack:(NSURL *)folder error:(NSError **)error;
@end
