#import "../Sources/BuddieLibrary.h"

static NSDictionary *Read(NSURL *root) {
    return [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[root URLByAppendingPathComponent:@"library.json"]] options:0 error:nil];
}
static void Write(NSURL *root,NSDictionary *json) {
    NSCAssert([[NSJSONSerialization dataWithJSONObject:json options:0 error:nil] writeToURL:[root URLByAppendingPathComponent:@"library.json"] atomically:YES],@"Write isolated fixture");
}
static NSArray *Packs(NSURL *root) {
    return [NSFileManager.defaultManager contentsOfDirectoryAtURL:[root URLByAppendingPathComponent:@"Packs"] includingPropertiesForKeys:nil options:0 error:nil];
}
int main(void) {
    @autoreleasepool {
        NSFileManager *fm=NSFileManager.defaultManager;
        NSURL *root=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"buddie-library-test-" stringByAppendingString:NSUUID.UUID.UUIDString]]];
        [fm createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:nil];
        @try {
            NSURL *art=[NSURL fileURLWithPath:[fm.currentDirectoryPath stringByAppendingPathComponent:@"Characters"]];
            BuddieCharacter *bit=[BuddieCharacter loadPack:[art URLByAppendingPathComponent:@"bit"] error:nil];
            BuddieCharacter *miso=[BuddieCharacter loadPack:[art URLByAppendingPathComponent:@"miso"] error:nil];
            NSArray *bundled=@[bit,miso];
            NSURL *libraryURL=[root URLByAppendingPathComponent:@"Library"];
            BuddieLibrary *library=[[BuddieLibrary alloc] initWithURL:libraryURL bundled:bundled];
            BuddieCharacter *edited=[library characterForIdentifier:@"bit"];
            edited.torsoWidth=1.12; edited.torsoHeight=.91; edited.headScale=.93;
            edited.spriteHeight=76; edited.stride=15; edited.footLift=5;
            edited.materialColors=@{@"shell":NSColor.redColor,@"face":NSColor.greenColor,@"antenna":NSColor.blueColor};
            [edited prepareAppearance]; NSData *paint=[edited imageForClip:@"headPress" frame:2].TIFFRepresentation;
            [library rememberCharacter:edited]; library.selectedIdentifier=@"miso"; library.reducedMotion=YES;
            NSCAssert([library save:nil],@"Save settings");
            BuddieLibrary *reopened=[[BuddieLibrary alloc] initWithURL:libraryURL bundled:bundled];
            BuddieCharacter *restored=[reopened characterForIdentifier:@"bit"];
            NSCAssert(restored.torsoWidth==1.12 && restored.torsoHeight==.91 && restored.headScale==.93 && restored.spriteHeight==76 && restored.stride==15 && restored.footLift==5,@"Every exposed articulated control survives reopening");
            NSCAssert([[restored imageForClip:@"headPress" frame:2].TIFFRepresentation isEqual:paint],@"Reopening renders identical custom colors");
            NSCAssert([reopened.selectedIdentifier isEqual:@"miso"] && reopened.reducedMotion,@"Selection and Reduced Motion survive reopening");
            NSCAssert([reopened characterForIdentifier:@"miso"].torsoWidth==1 && bit.torsoWidth==1,@"Editing a buddy never changes another or its original");
            [reopened resetIdentifier:@"bit"]; [reopened save:nil];
            NSCAssert([reopened characterForIdentifier:@"bit"].torsoWidth==1,@"Reset restores the installed design");

            NSURL *portable=[root URLByAppendingPathComponent:@"portable.buddie"];
            BuddieCharacter *custom=[edited copy]; custom.identifier=@"custom-bit"; custom.name=bit.name;
            NSCAssert([custom savePack:portable error:nil],@"Create a portable pack");
            BuddieCharacter *imported=[BuddieCharacter loadPack:portable error:nil];
            NSCAssert([reopened installCharacter:imported error:nil],@"Install the pack");
            [fm removeItemAtURL:portable error:nil];
            reopened=[[BuddieLibrary alloc] initWithURL:libraryURL bundled:bundled];
            restored=[reopened characterForIdentifier:@"custom-bit"];
            NSCAssert(reopened.characters.count==3 && [restored.name isEqual:bit.name] && [[restored imageForClip:@"headPress" frame:2].TIFFRepresentation isEqual:paint],@"Duplicate names stay distinct; deleting the download does not affect installed art");
            restored.headScale=1.15; [reopened rememberCharacter:restored];
            custom.headScale=.99;
            NSCAssert([reopened installCharacter:custom error:nil],@"Reimport same identity");
            NSCAssert(reopened.characters.count==3 && [reopened characterForIdentifier:@"custom-bit"].headScale==.99 && Packs(libraryURL).count==1,@"Reimport updates the original, removes stale edits and only retires the superseded copy");
            restored=[reopened characterForIdentifier:@"custom-bit"]; restored.headScale=.85; [reopened rememberCharacter:restored];
            [reopened resetIdentifier:@"custom-bit"];
            NSCAssert([reopened characterForIdentifier:@"custom-bit"].headScale==.99,@"Imported buddy reset restores its imported proportions");
            [reopened save:nil];

            NSMutableDictionary *json=[Read(libraryURL) mutableCopy];
            json[@"settings"]=@{@"bit":@{@"torsoWidth":@9000,@"headScale":@YES,@"stride":@"15",@"faceY":NSNull.null,@"materials":@{@"shell":@"red",@"face":@"#12ZZ00"},@"identifier":@"changed"}};
            Write(libraryURL,json); reopened=[[BuddieLibrary alloc] initWithURL:libraryURL bundled:bundled];
            restored=[reopened characterForIdentifier:@"bit"];
            NSCAssert(restored.torsoWidth==1 && restored.headScale==1 && restored.stride==bit.stride && [restored.identifier isEqual:@"bit"] && [restored.materialColors isEqual:bit.materialColors],@"Malformed values and unknown keys cannot corrupt a rig or its identity");
            [fm removeItemAtURL:Packs(libraryURL).firstObject error:nil];
            reopened=[[BuddieLibrary alloc] initWithURL:libraryURL bundled:bundled];
            NSCAssert(reopened.loadError && reopened.characters.count==2 && [reopened save:nil] && [Read(libraryURL)[@"installed"] count]==1,@"A missing pack does not erase its recovery record or block other buddies");

            for(id bad in @[@{@"version":@2},@{@"version":@1,@"selected":@"bit",@"reducedMotion":@NO,@"settings":@{},@"installed":@[@{@"id":@"escape",@"folder":@"../outside"}]}]) {
                Write(libraryURL,bad); NSData *before=[NSData dataWithContentsOfURL:[libraryURL URLByAppendingPathComponent:@"library.json"]];
                reopened=[[BuddieLibrary alloc] initWithURL:libraryURL bundled:bundled];
                NSCAssert(reopened.loadError && ![reopened save:nil] && ![reopened installCharacter:custom error:nil],@"Unknown versions and unsafe paths are left read-only");
                NSCAssert([before isEqual:[NSData dataWithContentsOfURL:[libraryURL URLByAppendingPathComponent:@"library.json"]]],@"Unreadable library bytes remain untouched");
            }
            NSURL *failure=[root URLByAppendingPathComponent:@"Failure"];
            BuddieLibrary *broken=[[BuddieLibrary alloc] initWithURL:failure bundled:bundled];
            [fm createDirectoryAtURL:[failure URLByAppendingPathComponent:@"library.json"] withIntermediateDirectories:YES attributes:nil error:nil];
            NSCAssert(![broken installCharacter:custom error:nil] && broken.characters.count==2 && [broken.selectedIdentifier isEqual:@"bit"] && Packs(failure).count==0,@"A failed manifest write rolls back installation and leaves no unreferenced copy");
            puts("PASS: persistent per-buddy colors/proportions/gait; selected buddy and Reduced Motion; portable art installation; duplicate names; reimport/reset; corrupt settings; missing packs; read-only recovery; failed-write rollback");
        } @finally { [fm removeItemAtURL:root error:nil]; }
    }
}
