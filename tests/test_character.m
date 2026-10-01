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
            NSDictionary *valid=@{@"version":@1,@"id":@"test",@"name":@"Test"};
            Write(root,valid); NSCAssert([BuddieCharacter loadPack:root error:nil],@"Procedural pack is valid");
            Reject(root,@[]); Reject(root,@{@"version":@2});
            for(id rig in @[@[],@{@"width":@9000},@{@"eyeSize":@"large"},@{@"mystery":@4}]) {
                NSMutableDictionary *p=[valid mutableCopy]; p[@"rig"]=rig; Reject(root,p);
            }
            for(id art in @[@[],@{@"body":@"../outside.png"},@{@"body":@"https://example.com/a.png"},@{@"body":@"missing.png"},@{@"script":@"run.js"}]) {
                NSMutableDictionary *p=[valid mutableCopy]; p[@"art"]=art; Reject(root,p);
            }
            [fm createSymbolicLinkAtURL:[root URLByAppendingPathComponent:@"escape.png"] withDestinationURL:[NSURL fileURLWithPath:[fm.currentDirectoryPath stringByAppendingPathComponent:@"Characters/sprout/body.png"]] error:nil];
            NSMutableDictionary *p=[valid mutableCopy]; p[@"art"]=@{@"body":@"escape.png"}; Reject(root,p);
            p=[valid mutableCopy]; p[@"colors"]=@{@"body":@"#FF0000garbage"}; Reject(root,p);
            puts("PASS: generated packs, independent copies, procedural fallback, schema/range validation, path traversal, remote path, symlink escape, missing artwork, invalid colors");
        } @finally { [fm removeItemAtURL:root error:nil]; }
    }
}
