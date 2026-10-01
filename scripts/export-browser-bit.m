#import <Cocoa/Cocoa.h>
#import "../Sources/BuddiePuppet.h"

@interface AtlasView : NSView
@property BuddieCharacter *character;
@property NSArray<NSDictionary *> *frames;
@end
@implementation AtlasView
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty {
    for(NSUInteger index=0;index<self.frames.count;index++) {
        NSDictionary *f=self.frames[index]; BuddiePose pose;
        [f[@"pose"] getValue:&pose size:sizeof(pose)];
        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext.currentContext.imageInterpolation=NSImageInterpolationNone;
        NSAffineTransform *t=[NSAffineTransform transform];
        [t translateXBy:(index%16)*80 yBy:(index/16)*80]; [t concat];
        BuddieDrawPuppet(self.character,pose,[f[@"turn"] doubleValue]>.5,[f[@"turn"] doubleValue],0,NO);
        [NSGraphicsContext restoreGraphicsState];
    }
}
@end

int main(int argc,const char **argv) {
    @autoreleasepool {
        if(argc!=3) { fprintf(stderr,"Usage: export-browser-bit CHARACTER_FOLDER OUTPUT_FOLDER\n"); return 1; }
        [NSApplication sharedApplication]; NSError *error=nil;
        BuddieCharacter *c=[BuddieCharacter loadPack:[NSURL fileURLWithPath:@(argv[1])] error:&error];
        if(!c) { fprintf(stderr,"%s\n",error.description.UTF8String); return 1; }
        [c prepareAppearance]; NSMutableArray *frames=[NSMutableArray array]; NSMutableDictionary *states=[NSMutableDictionary dictionary];
        NSDictionary *counts=@{@"idle":@1,@"blink":@3,@"walk":@24,@"run":@24,@"press":@1,@"release":@8};
        BuddieRig rig={c.stride,c.footSpacing,c.footLift};
        for(NSString *state in @[@"idle",@"blink",@"walk",@"run",@"press",@"release"]) {
            NSUInteger count=[counts[state] unsignedIntegerValue]; states[state]=@{@"start":@(frames.count),@"count":@(count)};
            for(int direction=0;direction<5;direction++) {
                BuddieMotion motion; BuddieMotionInit(&motion);
                double sign=direction>2 ? -1:1, speed=[state isEqual:@"walk"] ? 16:[state isEqual:@"run"] ? 96:0;
                double period=[state isEqual:@"walk"] ? c.stride/16.:[state isEqual:@"run"] ? .2:.38;
                for(int warm=0;warm<=240;warm++) BuddieMotionUpdate(&motion,(BuddiePoint){sign*speed*warm/60.,0},100+warm/60.,rig,false);
                if([state isEqual:@"press"] || [state isEqual:@"release"]) {
                    BuddieMotionPress(&motion,true,104); BuddieMotionUpdate(&motion,(BuddiePoint){0,0},104.1,rig,false);
                    if([state isEqual:@"release"]) BuddieMotionPress(&motion,false,104.1);
                }
                for(NSUInteger i=0;i<count;i++) {
                    double t=(i+1)*period/count;
                    double base=([state isEqual:@"press"] || [state isEqual:@"release"]) ? 104.1:104;
                    BuddieMotionUpdate(&motion,(BuddiePoint){sign*speed*(4+t),0},base+t,rig,false);
                    BuddiePose pose=motion.pose;
                    if([state isEqual:@"blink"]) pose.eyeOpen=i==1 ? .07:.4;
                    else if([state isEqual:@"idle"]) pose.eyeOpen=1;
                    [frames addObject:@{@"pose":[NSValue valueWithBytes:&pose objCType:@encode(BuddiePose)],@"turn":@(direction/4.)}];
                }
            }
        }
        NSSize size=NSMakeSize(16*80,ceil(frames.count/16.)*80);
        NSWindow *window=[[NSWindow alloc] initWithContentRect:(NSRect){NSZeroPoint,size} styleMask:0 backing:NSBackingStoreBuffered defer:NO];
        AtlasView *view=[[AtlasView alloc] initWithFrame:(NSRect){NSZeroPoint,size}]; view.character=c; view.frames=frames; window.contentView=view;
        NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:size.width pixelsHigh:size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
        NSURL *output=[NSURL fileURLWithPath:@(argv[2]) isDirectory:YES];
        if(![NSFileManager.defaultManager createDirectoryAtURL:output withIntermediateDirectories:YES attributes:nil error:&error]) return 1;
        if(![[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToURL:[output URLByAppendingPathComponent:@"bit-atlas.png"] options:NSDataWritingAtomic error:&error]) return 1;
        NSDictionary *meta=@{@"cell":@80,@"columns":@16,@"height":@64,@"hotspot":@[@42,@24],@"directions":@5,@"states":states,@"frames":@(frames.count)};
        [[NSJSONSerialization dataWithJSONObject:meta options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:nil] writeToURL:[output URLByAppendingPathComponent:@"bit-atlas.json"] atomically:YES];
        printf("Exported %lu Bit poses from the native renderer\n",(unsigned long)frames.count);
    }
}
