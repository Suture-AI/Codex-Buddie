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
static NSMutableDictionary *MutableJSON(NSDictionary *json) {
    return [NSJSONSerialization JSONObjectWithData:[NSJSONSerialization dataWithJSONObject:json options:0 error:nil] options:NSJSONReadingMutableContainers error:nil];
}
static void ArticulatedPack(NSURL *root) {
    NSError *error=nil;
    BuddieCharacter *pip=[BuddieCharacter loadPack:[NSURL fileURLWithPath:@"Characters/pip-articulated"] error:&error];
    NSCAssert(pip && !error && pip.puppetParts.count==9 && pip.clips[@"head"].frames.count==5,@"Articulated pack loads every part: %@",error);
    NSCAssert(pip.clips[@"head"].frames[0]==pip.clips[@"head"].frames[4],@"Repeated blink poses share decoded pixels");
    BuddieCharacter *custom=[pip copy]; custom.torsoWidth=1.22; custom.torsoHeight=1.18; custom.headScale=1.15;
    custom.materialColors=@{@"coat":[NSColor colorWithSRGBRed:.4 green:.6 blue:.3 alpha:1],@"boots":NSColor.whiteColor};
    [custom prepareAppearance];
    NSCAssert(pip.torsoWidth==1 && custom.torsoWidth!=pip.torsoWidth,@"Proportions are independent per buddy");
    NSURL *saved=[root URLByAppendingPathComponent:@"puppet.buddie"];
    NSCAssert([custom savePack:saved error:&error],@"Save articulated pixels, masks, pivots, clips and proportions: %@",error);
    BuddieCharacter *restored=[BuddieCharacter loadPack:saved error:&error];
    NSCAssert(restored && restored.torsoWidth==1.22 && restored.torsoHeight==1.18 && restored.headScale==1.15,@"Proportions round-trip");
    NSCAssert([restored.puppetParts isEqual:custom.puppetParts] && restored.puppetMotionScale==custom.puppetMotionScale,@"Attachment geometry round-trips");
    for(NSString *role in custom.clips) for(NSUInteger i=0;i<custom.clips[role].frames.count;i++)
        NSCAssert([[restored imageForClip:role frame:i].TIFFRepresentation isEqual:[custom imageForClip:role frame:i].TIFFRepresentation],@"Every editable colored part survives save/import: %@",role);
    NSDictionary *json=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[saved URLByAppendingPathComponent:@"buddy.json"]] options:0 error:nil];
    for(NSString *key in @[@"parts",@"proportions",@"motionScale"]) {
        NSMutableDictionary *bad=MutableJSON(json); bad[@"puppet"][key]=NSNull.null; Reject(saved,bad);
    }
    for(NSString *key in @[@"torsoWidth",@"torsoHeight",@"headScale",@"unexpected"]) {
        NSMutableDictionary *bad=MutableJSON(json); bad[@"puppet"][@"proportions"][key]=@99; Reject(saved,bad);
    }
    for(NSString *role in pip.puppetParts) {
        NSMutableDictionary *bad=MutableJSON(json); [bad[@"puppet"][@"parts"] removeObjectForKey:role]; Reject(saved,bad);
    }
    for(NSDictionary *change in @[@{@"pivot":@[@999,@999]},@{@"anchor":@[@448,@448]},@{@"scale":@YES},@{@"scale":@0},@{@"script":@"run.js"},@{@"frames":@[]}]) {
        NSMutableDictionary *bad=MutableJSON(json); [bad[@"puppet"][@"parts"][@"head"] addEntriesFromDictionary:change]; Reject(saved,bad);
    }
    for(NSDictionary *change in @[@{@"cuff":@[]},@{@"span":@0},@{@"span":@YES}]) {
        NSMutableDictionary *bad=MutableJSON(json); [bad[@"puppet"][@"parts"][@"legNear"] addEntriesFromDictionary:change]; Reject(saved,bad);
    }
    for(NSString *image in @[@"../escape.png",@"body-00.png"]) {
        NSMutableDictionary *bad=MutableJSON(json); bad[@"puppet"][@"parts"][@"head"][@"frames"][0][@"image"]=image; Reject(saved,bad);
    }
    NSMutableDictionary *bad=MutableJSON(json); bad[@"sprites"]=@{}; Reject(saved,bad);
    bad=MutableJSON(json); bad[@"version"]=@2; Reject(saved,bad);
    bad=MutableJSON(json); bad[@"puppet"][@"parts"][@"head"][@"frames"][0][@"mask"]=@"body-00-mask.png"; Reject(saved,bad);
    puts("PASS: nine-part articulated pack; shared decode; proportions/geometry/colors round-trip; independent customization; missing roles, unsafe files, incompatible dimensions and invalid transforms rejected");
    BuddieCharacter *bit=[BuddieCharacter loadPack:[NSURL fileURLWithPath:@"Characters/bit"] error:&error];
    NSCAssert(bit.pixelArt && bit.puppetParts.count==18 && bit.stride==8 && bit.footSpacing==5,@"Compact pixel rig with authored directions and expression heads loads");
    NSCAssert(bit.clips[@"bodyTurn"].frames.count==5 && bit.clips[@"bodyLeft"].frames.count==1,@"Torso directions remain independently editable");
    NSCAssert(bit.clips[@"headTurn"].frames.count==5 && bit.clips[@"headLeft"].frames.count==5,@"Turning and left blink art are preserved");
    NSURL *pixelCopy=[root URLByAppendingPathComponent:@"bit.buddie"];
    NSCAssert([bit savePack:pixelCopy error:&error],@"Save pixel sampling and optional head tracks: %@",error);
    BuddieCharacter *bitCopy=[BuddieCharacter loadPack:pixelCopy error:&error];
    NSCAssert(bitCopy.pixelArt && [bitCopy.puppetParts isEqual:bit.puppetParts] && bitCopy.stride==8,@"Pixel/turn metadata round-trips");
    for(NSString *role in @[@"headFocus",@"headPress",@"headRelease",@"headHalf",@"headClosed"]) {
        NSCAssert(bitCopy.clips[role].frames.count==5,@"Each expression survives portable export in every direction");
        for(int i=0;i<5;i++) {
            NSBitmapImageRep *a=[NSBitmapImageRep imageRepWithData:bit.clips[@"headTurn"].frames[i].TIFFRepresentation];
            NSBitmapImageRep *b=[NSBitmapImageRep imageRepWithData:bitCopy.clips[role].frames[i].TIFFRepresentation];
            NSUInteger changes=0;
            for(int y=0;y<64;y++) for(int x=0;x<64;x++) {
                NSUInteger p[4],q[4]; [a getPixel:p atX:x y:y]; [b getPixel:q atX:x y:y];
                NSCAssert(p[3]==q[3],@"Expressions preserve the complete generated silhouette");
                if(memcmp(p,q,sizeof(p))) { NSCAssert(x>=19 && x<=44 && y>=28 && y<=33,@"Expression edits stay inside the eyes"); changes++; }
            }
            NSCAssert(changes>=8 && changes<=60,@"Expression visibly changes a small number of face pixels");
        }
    }
    for(NSString *role in @[@"head",@"headLeft"]) {
        NSBitmapImageRep *open=[NSBitmapImageRep imageRepWithData:bit.clips[role].frames[0].TIFFRepresentation];
        NSBitmapImageRep *closed=[NSBitmapImageRep imageRepWithData:bit.clips[role].frames[2].TIFFRepresentation]; NSUInteger changed=0;
        for(NSInteger y=0;y<open.pixelsHigh;y++) for(NSInteger x=0;x<open.pixelsWide;x++) {
            NSUInteger a[4],b[4]; [open getPixel:a atX:x y:y]; [closed getPixel:b atX:x y:y];
            NSCAssert(a[3]==b[3],@"A blink cannot change the head silhouette");
            if(a[0]!=b[0] || a[1]!=b[1] || a[2]!=b[2]) {
                NSCAssert(x>=18 && x<=45 && y>=26 && y<=35,@"Blink changes remain inside the reviewed screen-eye area");
                changed++;
            }
        }
        NSCAssert(changed>=8 && changed<=50,@"Pixel blink has a visible, localized change");
    }
    NSDictionary *pixelJSON=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[pixelCopy URLByAppendingPathComponent:@"buddy.json"]] options:0 error:nil];
    bad=MutableJSON(pixelJSON); bad[@"puppet"][@"pixelArt"]=@1; Reject(pixelCopy,bad);
    bad=MutableJSON(pixelJSON); bad[@"puppet"][@"parts"][@"headTurn"][@"pivot"]=@[@99,@99]; Reject(pixelCopy,bad);
    bad=MutableJSON(pixelJSON); [bad[@"puppet"][@"parts"] removeObjectForKey:@"bodyLeft"]; Reject(pixelCopy,bad);
    bad=MutableJSON(pixelJSON); bad[@"puppet"][@"parts"][@"headPress"][@"anchor"]=@[@40,@49]; Reject(pixelCopy,bad);
    bad=MutableJSON(pixelJSON); bad[@"puppet"][@"parts"][@"headPress"][@"frames"][0][@"duration"]=@.1; Reject(pixelCopy,bad);
    bad=MutableJSON(pixelJSON); [bad[@"puppet"][@"parts"] removeObjectForKey:@"headLeft"]; Reject(pixelCopy,bad);
    puts("PASS: 25 directional expression textures change only eyes; portable round-trip; mismatched registration/timing rejected");
    puts("PASS: pixel rig import/export, optional directional heads, compact stride, stable blink silhouettes and localized eye changes");
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
            ArticulatedPack(root);
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
            NSCAssert(pip.materials.count==2 && pip.clips[@"idle"].masks.count==6,@"Pip exposes both outfit materials in every pose");
            NSImage *original=[pip imageForClip:@"idle" frame:0];
            NSCAssert(original==pip.clips[@"idle"].frames[0],@"Default palette must return the untouched original art");
            BuddieCharacter *custom=[pip copy];
            NSMutableDictionary *palette=[custom.materialColors mutableCopy];
            palette[@"coat"]=[NSColor colorWithSRGBRed:.8 green:.35 blue:.58 alpha:1]; custom.materialColors=palette;
            double began=NSProcessInfo.processInfo.systemUptime; [custom prepareAppearance];
            printf("Appearance preparation: %.1f ms for 14 poses\n",(NSProcessInfo.processInfo.systemUptime-began)*1000);
            NSImage *painted=[custom imageForClip:@"idle" frame:0];
            NSCAssert(painted!=original && painted==[custom imageForClip:@"idle" frame:0],@"Recolored artwork is cached, never regenerated on animation ticks");
            NSCAssert([pip imageForClip:@"idle" frame:0]==original,@"Changing a copy must not repaint its preset");
            NSBitmapImageRep *before=[NSBitmapImageRep imageRepWithData:original.TIFFRepresentation];
            NSBitmapImageRep *after=[NSBitmapImageRep imageRepWithData:painted.TIFFRepresentation];
            NSBitmapImageRep *mask=[NSBitmapImageRep imageRepWithData:custom.clips[@"idle"].masks[0].TIFFRepresentation];
            NSUInteger changed=0,protected=0;
            for(NSInteger y=0;y<before.pixelsHigh;y++) for(NSInteger x=0;x<before.pixelsWide;x++) {
                NSUInteger a[4],b[4],m[4]; [before getPixel:a atX:x y:y]; [after getPixel:b atX:x y:y]; [mask getPixel:m atX:x y:y];
                NSCAssert(a[3]==b[3],@"Color edits preserve every alpha sample, including soft edges");
                if(a[3]>0 && m[0]==0) {
                    for(int k=0;k<3;k++) NSCAssert(labs((long)a[k]-(long)b[k])<=1,@"Pixels outside the edited coat stay unchanged");
                    protected++;
                } else if(a[3]>0 && labs((long)a[0]-(long)b[0])>20) changed++;
            }
            NSCAssert(changed>1000 && protected>1000,@"Recoloring changes the coat while protecting the face, boots and fur");
            NSURL *paintCopy=[root URLByAppendingPathComponent:@"paint.buddie"];
            NSCAssert([custom savePack:paintCopy error:nil],@"Save original pixels, masks and selected colors");
            BuddieCharacter *restored=[BuddieCharacter loadPack:paintCopy error:nil];
            NSCAssert([[restored imageForClip:@"idle" frame:0].TIFFRepresentation isEqual:painted.TIFFRepresentation],@"Save/import produces exactly the same recolored frame");
            custom.materialColors=pip.materialColors;
            NSCAssert([custom imageForClip:@"idle" frame:0]==original,@"Reset invalidates the cache and restores original pixels");
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
            NSMutableDictionary *legacy=[spriteJSON mutableCopy],*legacySprites=[spriteJSON[@"sprites"] mutableCopy];
            [legacySprites removeObjectForKey:@"materials"];
            legacySprites[@"clips"]=@{@"idle":@[@{@"image":@"idle-00.png",@"duration":@1}]}; legacy[@"sprites"]=legacySprites;
            Write(spriteCopy,legacy);
            BuddieCharacter *legacyPack=[BuddieCharacter loadPack:spriteCopy error:nil];
            NSCAssert(legacyPack && !legacyPack.materials.count && [legacyPack imageForClip:@"idle" frame:0]==legacyPack.clips[@"idle"].frames[0],@"Existing version-2 packs need no materials or masks");
            for(NSString *key in @[@"canvas",@"hotspot",@"height",@"mirrorWalk",@"directionalIdle",@"pixelArt",@"clips",@"materials"]) {
                NSMutableDictionary *bad=[spriteJSON mutableCopy], *sprites=[spriteJSON[@"sprites"] mutableCopy];
                sprites[key]=NSNull.null; bad[@"sprites"]=sprites; Reject(spriteCopy,bad);
            }
            for(id materials in @[@[@{}],@[@{@"id":@"coat",@"name":@"Coat",@"channel":@YES,@"base":@"#123456"}],@[@{@"id":@"coat",@"name":@"Coat",@"channel":@3,@"base":@"#123456"}],@[pip.materials[0],pip.materials[0]]]) {
                NSMutableDictionary *bad=[spriteJSON mutableCopy], *s=[spriteJSON[@"sprites"] mutableCopy];
                s[@"materials"]=materials; bad[@"sprites"]=s; Reject(spriteCopy,bad);
            }
            for(id maskName in @[@"../outside.png",@"missing-mask.png",NSNull.null,@"idle-00.png"]) {
                NSMutableDictionary *bad=[spriteJSON mutableCopy], *s=[spriteJSON[@"sprites"] mutableCopy];
                s[@"clips"]=@{@"idle":@[@{@"image":@"idle-00.png",@"duration":@1,@"mask":maskName}]}; bad[@"sprites"]=s; Reject(spriteCopy,bad);
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
            puts("PASS: generated and sprite packs; timing boundaries; editable material save/import; cached recoloring; alpha and protected pixels; reset; independent copies; legacy packs; schema/range/dimension validation; unsafe artwork/masks; invalid colors");
        } @finally { [fm removeItemAtURL:root error:nil]; }
    }
}
