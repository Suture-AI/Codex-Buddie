#import "../Sources/BuddieCursorLibrary.h"
#import "../Sources/BuddieView.h"
#import <stdatomic.h>

static atomic_int loads, mainThreadLoads;
static void Until(BOOL (^condition)(void),NSString *message) {
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
    BOOL ready=condition();
    while(!ready && deadline.timeIntervalSinceNow>0) {
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
        ready=condition();
    }
    NSCAssert(ready,@"%@",message);
}
static void Pump(void) { [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.25]]; }
static NSData *Bytes(NSURL *root) { return [NSData dataWithContentsOfURL:[root URLByAppendingPathComponent:@"library.json"]]; }
static void Write(NSURL *root,NSDictionary *json) {
    NSCAssert([[NSJSONSerialization dataWithJSONObject:json options:0 error:nil] writeToURL:[root URLByAppendingPathComponent:@"library.json"] atomically:YES],@"Write isolated manifest");
}
static NSDictionary *Read(NSURL *root) { return [NSJSONSerialization JSONObjectWithData:Bytes(root) options:0 error:nil]; }
static void SamePose(BuddiePose a,BuddiePose b) {
    NSCAssert(a.phase==b.phase && a.walkWeight==b.walkWeight && a.bodyY==b.bodyY && a.squash==b.squash &&
        a.feet[0].x==b.feet[0].x && a.feet[1].x==b.feet[1].x && a.eyeOpen==b.eyeOpen,@"Settings preserve the current pose and contact");
}
int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSFileManager *fm=NSFileManager.defaultManager;
        NSURL *temporary=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"buddie-cursor-library-test-" stringByAppendingString:NSUUID.UUID.UUIDString]]];
        [fm createDirectoryAtURL:temporary withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *root=[temporary URLByAppendingPathComponent:@"New/Studio"];
        NSURL *art=[NSURL fileURLWithPath:[fm.currentDirectoryPath stringByAppendingPathComponent:@"Characters"]];
        BuddieCharacter *bit=[BuddieCharacter loadPack:[art URLByAppendingPathComponent:@"bit"] error:nil];
        BuddieCharacter *miso=[BuddieCharacter loadPack:[art URLByAppendingPathComponent:@"miso"] error:nil];
        NSCAssert(bit && miso,@"Test needs the real character packs");
        dispatch_semaphore_t slowStarted=dispatch_semaphore_create(0),slowRelease=dispatch_semaphore_create(0);
        BuddieCursorLibrary *cursor=[[BuddieCursorLibrary alloc] initWithURL:root bundledLoader:^BuddieCharacter *(NSString *identifier) {
            atomic_fetch_add(&loads,1); if(NSThread.isMainThread) atomic_fetch_add(&mainThreadLoads,1);
            if([identifier isEqual:@"slow"]) {
                dispatch_semaphore_signal(slowStarted);
                dispatch_semaphore_wait(slowRelease,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC));
                BuddieCharacter *c=[bit copy]; c.identifier=@"slow"; return c;
            }
            return [identifier isEqual:@"bit"] ? [bit copy]:[identifier isEqual:@"miso"] ? [miso copy]:nil;
        }];
        __weak BuddieCursorLibrary *releasedCursor;
        @autoreleasepool { @try {
            BuddieView *view=[[BuddieView alloc] initWithFrame:NSMakeRect(0,0,300,300)]; view.manualAnimation=YES;
            [cursor attachView:view]; [cursor start];
            Until(^BOOL { return cursor.character!=nil; },@"Initial snapshot arrives without an existing library");
            NSCAssert([cursor.character.identifier isEqual:@"bit"] && ![fm fileExistsAtPath:root.path],@"Missing library uses Bit without creating folders");

            BuddieLibrary *studio=[[BuddieLibrary alloc] initWithURL:root bundled:@[bit,miso]];
            BuddieCharacter *edited=[studio characterForIdentifier:@"miso"]; edited.armLength=1.2; edited.legLength=1.6; edited.stanceWidth=1.3;
            NSMutableDictionary *colors=[edited.materialColors mutableCopy]; colors[@"shell"]=[NSColor colorWithSRGBRed:1 green:0 blue:0 alpha:1]; edited.materialColors=colors;
            [studio rememberCharacter:edited]; studio.selectedIdentifier=@"miso"; [studio save:nil];
            NSData *saved=Bytes(root);
            Until(^BOOL { return [view.character.identifier isEqual:@"miso"]; },@"Ancestor watch follows first Studio save");
            NSCAssert(view.character.armLength==1.2 && view.character.legLength==1.6 && view.character.stanceWidth==1.3 && [saved isEqual:Bytes(root)],@"Native snapshot restores saved anatomy and leaves the library untouched");
            NSCAssert([[view.character imageForClip:@"headPress" frame:2].TIFFRepresentation isEqual:[edited imageForClip:@"headPress" frame:2].TIFFRepresentation],@"Prepared native palette exactly matches the Studio render source");

            [view animateAtTime:100 anchor:(BuddiePoint){0,0}];
            for(int i=1;i<=25;i++) [view animateAtTime:100+i/60. anchor:(BuddiePoint){-i*.25,0}];
            [view press:YES atTime:100.42];
            BuddiePose pose=view.motionPose; double facing=view.facingProgress;
            edited.headScale=1.1;
            colors=[edited.materialColors mutableCopy]; colors[@"shell"]=[NSColor colorWithSRGBRed:.3 green:.8 blue:1 alpha:1]; edited.materialColors=colors;
            [studio rememberCharacter:edited]; [studio save:nil];
            Until(^BOOL { return view.character.headScale==1.1; },@"Atomic save updates the current character");
            SamePose(pose,view.motionPose); NSCAssert(view.facingProgress==facing,@"Live settings do not restart a turn");
            NSCAssert([[view.character imageForClip:@"headPress" frame:2].TIFFRepresentation isEqual:[edited imageForClip:@"headPress" frame:2].TIFFRepresentation],@"Live recoloring arrives already prepared without resetting the pressed pose");

            BuddieCharacter *before=view.character; int decoded=atomic_load(&loads);
            BuddieCharacter *other=[studio characterForIdentifier:@"bit"]; other.armLength=.8;
            [studio rememberCharacter:other]; [studio save:nil]; Pump();
            NSCAssert(view.character==before && atomic_load(&loads)==decoded,@"Another buddy's edits do not decode or reset the active one");
            studio.reducedMotion=YES; [studio save:nil];
            Until(^BOOL { return view.reduceMotion; },@"Reduced Motion follows the Studio");
            NSCAssert(view.character==before && atomic_load(&loads)==decoded,@"Reduced Motion does not decode art"); SamePose(pose,view.motionPose);
            BuddieView *second=[[BuddieView alloc] initWithFrame:view.frame]; second.manualAnimation=YES; [cursor attachView:second];
            NSCAssert(second.character==view.character && second.reduceMotion,@"Later cursor windows receive the current snapshot");

            NSDictionary *valid=Read(root); Write(root,@{@"version":@99});
            Until(^BOOL { return cursor.loadError!=nil; },@"Malformed manifest is detected");
            NSCAssert(view.character==before && second.character==before,@"Bad settings never blank or replace the last good buddy");
            Write(root,valid); Until(^BOOL { return cursor.loadError==nil; },@"Restoring the same good settings clears the error");
            NSCAssert(view.character==before,@"Recovery does not restart unchanged animation");
            NSMutableDictionary *withMissingOther=[valid mutableCopy];
            withMissingOther[@"installed"]=@[@{@"id":@"other-missing-pack",@"folder":NSUUID.UUID.UUIDString}];
            Write(root,withMissingOther); Pump();
            NSCAssert(!cursor.loadError && view.character==before && atomic_load(&loads)==decoded,@"Unselected imports are neither decoded nor required to exist");

            BuddieCharacter *custom=[bit copy]; custom.identifier=@"custom-bit"; custom.legLength=1.7;
            NSCAssert([studio installCharacter:custom error:nil],@"Install custom artwork");
            Until(^BOOL { return [view.character.identifier isEqual:@"custom-bit"]; },@"Selected imported pack reaches both cursor windows");
            NSCAssert(second.character==view.character && view.character.legLength==1.7,@"Portable pack proportions survive native selection");
            custom.legLength=.9; [studio installCharacter:custom error:nil];
            Until(^BOOL { return view.character.legLength==.9; },@"Replacing an imported identity reloads its new artwork revision");

            before=view.character; NSMutableDictionary *bad=[Read(root) mutableCopy]; bad[@"selected"]=@"unavailable"; Write(root,bad);
            Until(^BOOL { return cursor.loadError!=nil; },@"Unavailable selection reports an error"); NSCAssert(view.character==before,@"Missing pack keeps last good character");
            studio.selectedIdentifier=@"bit"; [studio save:nil]; Until(^BOOL { return [view.character.identifier isEqual:@"bit"]; },@"Next valid selection recovers");

            NSMutableDictionary *slow=[Read(root) mutableCopy]; slow[@"selected"]=@"slow"; Write(root,slow);
            Until(^BOOL { return dispatch_semaphore_wait(slowStarted,DISPATCH_TIME_NOW)==0; },@"Slow decode began on the worker");
            studio.selectedIdentifier=@"miso"; [studio save:nil]; dispatch_semaphore_signal(slowRelease);
            Until(^BOOL { NSCAssert(![cursor.character.identifier isEqual:@"slow"],@"Obsolete decode is never published"); return [view.character.identifier isEqual:@"miso"]; },@"Latest selection wins during slow artwork loading");

            [cursor stop]; before=view.character; studio.selectedIdentifier=@"bit"; [studio save:nil]; Pump();
            NSCAssert(view.character==before,@"Stopped subscription ignores saves");
            [cursor start]; Until(^BOOL { return [view.character.identifier isEqual:@"bit"]; },@"Restart reads the current manifest");
            NSURL *moved=[temporary URLByAppendingPathComponent:@"OldStudio"];
            [fm moveItemAtURL:root toURL:moved error:nil]; [studio save:nil];
            studio.selectedIdentifier=@"miso"; [studio save:nil];
            Until(^BOOL { return [view.character.identifier isEqual:@"miso"]; },@"Watcher recovers after replacing the library directory");
            NSCAssert(atomic_load(&mainThreadLoads)==0,@"No native artwork loader runs on the animation thread");
            __weak BuddieView *releasedView;
            @autoreleasepool {
                BuddieView *transient=[[BuddieView alloc] initWithFrame:view.frame]; transient.manualAnimation=YES;
                releasedView=transient; [cursor attachView:transient];
            }
            NSCAssert(!releasedView,@"The subscription never retains retired cursor windows");
            [cursor stop]; releasedCursor=cursor; cursor=nil;
        } @finally { [cursor stop]; Pump(); [fm removeItemAtURL:temporary error:nil]; } }
        Until(^BOOL { return releasedCursor==nil; },@"Stopping releases the watcher and subscription after temporary observations drain");
        printf("PASS: native saved selection, palette/anatomy equality, motion continuity, first-save/atomic/directory replacement, imports, two views, corruption recovery, latest-result wins, stop/restart/teardown; %d background loads, zero main-thread loads\n",atomic_load(&loads));
    }
}
