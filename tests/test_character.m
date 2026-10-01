#import <Cocoa/Cocoa.h>
#import "../Sources/BuddieCharacter.h"

static void Write(NSURL *root,id object) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingFragmentsAllowed error:nil];
    NSCAssert([data writeToURL:[root URLByAppendingPathComponent:@"buddy.json"] atomically:YES],@"Write fixture");
}
static void Reject(NSURL *root,id object) {
    Write(root,object); NSError *error=nil;
    NSCAssert(![BuddieCharacter loadPack:root error:&error] && error,@"Reject invalid pack with useful error: %@",object);
}
int main(void) {
    @autoreleasepool {
        for(NSString *name in @[@"sprout",@"mochi",@"orbit"]) {
            NSError *error=nil;
            BuddieCharacter *c=[BuddieCharacter loadPack:[NSURL fileURLWithPath:[@"Characters" stringByAppendingPathComponent:name]] error:&error];
            NSCAssert(c.bodyImage && !error,@"Bundled pack must load: %@",error);
            BuddieCharacter *copy=[c copy]; copy.eyeSize=3;
            NSCAssert(c.eyeSize!=copy.eyeSize,@"Customization must not mutate the preset");
        }
        NSURL *root=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
        NSFileManager *fm=NSFileManager.defaultManager;
        NSCAssert([fm createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:nil],@"Fixture directory");
        @try {
            BuddieCharacter *source=[BuddieCharacter loadPack:[NSURL fileURLWithPath:@"Characters/mochi"] error:nil];
            source.eyeSpacing=18; source.stride=20;
            NSURL *saved=[root URLByAppendingPathComponent:@"saved.buddie"];
            NSCAssert([source savePack:saved error:nil],@"Save complete pack");
            BuddieCharacter *loaded=[BuddieCharacter loadPack:saved error:nil];
            NSCAssert(loaded.bodyImage && loaded.eyeSpacing==18 && loaded.stride==20,@"Artwork and customization round-trip");
            NSCAssert(![source savePack:saved error:nil],@"Existing packs must not be overwritten");
            BuddieCharacter *pip=[BuddieCharacter loadPack:[NSURL fileURLWithPath:@"Characters/pip"] error:nil];
            NSCAssert(pip.clips[@"idle"].frames.count==6 && !pip.bodyImage,@"Complete character pack loads its own face and feet");
            NSCAssert(pip.clips[@"walkRight"].frames.count==8 && pip.directionalIdle,@"Pip has the refined gait and matching directional idle");
            BuddieSpriteClip *blink=pip.clips[@"idle"];
            NSCAssert([blink frameIndexAtTime:2.39 loop:YES]==0 && [blink frameIndexAtTime:2.426 loop:YES]==1,@"Blink uses per-frame durations, not uniform FPS");
            NSCAssert([blink frameIndexAtTime:blink.duration+.02 loop:YES]==0,@"Idle wraps at the clip duration");
            NSCAssert([blink frameIndexAtTime:99 loop:NO]==5 && [blink frameIndexAtTime:NAN loop:YES]==0,@"One-shot clamps and invalid time is safe");
            NSURL *spriteCopy=[root URLByAppendingPathComponent:@"pip.buddie"];
            NSCAssert([pip savePack:spriteCopy error:nil],@"Save sprite pack with every frame");
            BuddieCharacter *pipCopy=[BuddieCharacter loadPack:spriteCopy error:nil];
            NSCAssert(pipCopy.clips.count==pip.clips.count && pipCopy.clips[@"idle"].duration==blink.duration && NSEqualPoints(pipCopy.spriteHotspot,pip.spriteHotspot),@"Sprite timings and hotspot round-trip");
            NSCAssert(pipCopy.directionalIdle==pip.directionalIdle && pipCopy.mirrorWalk==pip.mirrorWalk,@"Facing contract round-trips with its art");
            NSData *spriteData=[NSData dataWithContentsOfURL:[spriteCopy URLByAppendingPathComponent:@"buddy.json"]];
            NSDictionary *spriteJSON=[NSJSONSerialization JSONObjectWithData:spriteData options:0 error:nil];
            for(NSString *key in @[@"canvas",@"hotspot",@"height",@"mirrorWalk",@"directionalIdle",@"clips"]) {
                NSMutableDictionary *bad=[spriteJSON mutableCopy], *sprites=[spriteJSON[@"sprites"] mutableCopy];
                sprites[key]=NSNull.null; bad[@"sprites"]=sprites; Reject(spriteCopy,bad);
            }
            for(id frames in @[@[],@[@{@"image":@"idle-00.png",@"duration":@0}],@[@{@"image":@"../outside.png",@"duration":@.1}],@[@{@"image":@"idle-00.png",@"duration":@YES}]]) {
                NSMutableDictionary *bad=[spriteJSON mutableCopy], *sprites=[spriteJSON[@"sprites"] mutableCopy];
                sprites[@"clips"]=@{@"idle":frames}; bad[@"sprites"]=sprites; Reject(spriteCopy,bad);
            }
            NSMutableDictionary *wrongCanvas=[spriteJSON mutableCopy], *sprites=[spriteJSON[@"sprites"] mutableCopy];
            sprites[@"canvas"]=@[@512,@512]; wrongCanvas[@"sprites"]=sprites; Reject(spriteCopy,wrongCanvas);
            NSDictionary *valid=@{@"version":@1,@"id":@"test",@"name":@"Test"};
            Write(root,valid); NSCAssert([BuddieCharacter loadPack:root error:nil],@"Procedural pack is valid");
            Reject(root,@[]); Reject(root,@{@"version":@2}); Reject(root,@{@"version":@YES,@"id":@"test",@"name":@"Test"});
            for(id rig in @[@[],@{@"width":@9000},@{@"eyeSize":@"large"},@{@"mystery":@4}]) {
                NSMutableDictionary *p=[valid mutableCopy]; p[@"rig"]=rig; Reject(root,p);
            }
            for(id art in @[@[],@{@"body":@"../outside.png"},@{@"body":@"https://example.com/a.png"},@{@"body":@"missing.png"},@{@"script":@"run.js"}]) {
                NSMutableDictionary *p=[valid mutableCopy]; p[@"art"]=art; Reject(root,p);
            }
            [fm createSymbolicLinkAtURL:[root URLByAppendingPathComponent:@"escape.png"] withDestinationURL:[NSURL fileURLWithPath:[fm.currentDirectoryPath stringByAppendingPathComponent:@"Characters/sprout/body.png"]] error:nil];
            NSMutableDictionary *p=[valid mutableCopy]; p[@"art"]=@{@"body":@"escape.png"}; Reject(root,p);
            p=[valid mutableCopy]; p[@"colors"]=@{@"body":@"#FF0000garbage"}; Reject(root,p);
            puts("PASS: generated and sprite packs; timing boundaries; save/import round-trip; independent copies; procedural fallback; schema/range/dimension validation; path traversal; remote path; symlink escape; missing artwork; invalid colors");
        } @finally { [fm removeItemAtURL:root error:nil]; }
    }
}
