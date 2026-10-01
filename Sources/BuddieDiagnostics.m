#import "BuddieDiagnostics.h"
#import "BuddieView.h"

void BuddieCaptureCursor(BuddieView *view) {
    static NSURL *root;
    static dispatch_queue_t writer;
    static NSUInteger frames,encodedBytes;
    static double epoch,lastSample;
    static NSPoint lastAnchor;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const char *path=getenv("BUDDIE_CAPTURE_DIRECTORY");
        if(!path || !*path || ![NSBundle.mainBundle.bundleIdentifier isEqual:@"ai.suture.codex-buddie.runtime"]) return;
        NSURL *candidate=[NSURL fileURLWithPath:[NSString stringWithUTF8String:path] isDirectory:YES];
        // Each run owns a new directory; never overwrite existing evidence.
        if(!candidate.path.isAbsolutePath || [NSFileManager.defaultManager fileExistsAtPath:candidate.path]) return;
        if(![NSFileManager.defaultManager createDirectoryAtURL:candidate withIntermediateDirectories:YES attributes:nil error:nil]) return;
        root=candidate; writer=dispatch_queue_create("ai.suture.buddie.capture",DISPATCH_QUEUE_SERIAL);
        fprintf(stderr,"[Buddie] Cursor-only diagnostic capture enabled (maximum 480 samples).\n");
    });
    if(!root || frames>=480 || !view.window.visible) return;
    double now=NSProcessInfo.processInfo.systemUptime;
    if(now-lastSample<1./30.) return;
    NSWindow *window=view.window;
    NSPoint anchor=[window convertPointToScreen:[view convertPoint:view.hotspot toView:nil]];
    BuddiePose pose=view.motionPose;
    BOOL moving=hypot(anchor.x-lastAnchor.x,anchor.y-lastAnchor.y)>.1 || pose.walkWeight>.01 || fabs(pose.squash-1)>.01;
    if(!moving && frames && now-lastSample<1) return;
    if(!epoch) epoch=now; lastSample=now; lastAnchor=anchor;
    NSUInteger index=frames++;
    NSDictionary *sample=@{@"frame":@(index),@"time":@(now-epoch),@"window":@(window.windowNumber),
        @"windowFrame":@[@(window.frame.origin.x),@(window.frame.origin.y),@(window.frame.size.width),@(window.frame.size.height)],
        @"viewBounds":@[@(view.bounds.origin.x),@(view.bounds.origin.y),@(view.bounds.size.width),@(view.bounds.size.height)],
        @"sourceFrame":NSStringFromRect(view.nativeLayoutSource.frame),
        @"hotspot":@[@(anchor.x),@(anchor.y)],@"drawingScale":@(view.drawingScale),
        @"alpha":@(window.alphaValue),@"software":@(view.softwareStyle),@"character":view.character.identifier ?: @"unknown",
        @"contentIsBuddie":@(window.contentView==view),@"ignoresMouseEvents":@(window.ignoresMouseEvents),
        @"phase":@(pose.phase),@"walkWeight":@(pose.walkWeight),@"facing":@(view.facingProgress),
        @"feet":@[@[@(pose.feet[0].x),@(pose.feet[0].y)],@[@(pose.feet[1].x),@(pose.feet[1].y)]],
        @"bodyY":@(pose.bodyY),@"squash":@(pose.squash),@"eyeOpen":@(pose.eyeOpen)};
    NSData *png=nil;
    // Capture the character's transparent view, with pixel and total byte bounds.
    // The native screenshot path and all other windows remain untouched.
    if(encodedBytes<64*1024*1024 && NSWidth(view.bounds)>0 && NSHeight(view.bounds)>0 && NSWidth(view.bounds)<=512 && NSHeight(view.bounds)<=512) {
        NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
        if(bitmap && bitmap.pixelsWide<=1024 && bitmap.pixelsHigh<=1024) {
            [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
            NSData *candidate=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            if(candidate.length<=64*1024*1024-encodedBytes) { png=candidate; encodedBytes+=png.length; }
        }
    }
    dispatch_async(writer, ^{
        NSString *stem=[NSString stringWithFormat:@"%04lu",(unsigned long)index];
        [[NSJSONSerialization dataWithJSONObject:sample options:NSJSONWritingSortedKeys error:nil]
            writeToURL:[root URLByAppendingPathComponent:[stem stringByAppendingString:@".json"]] atomically:YES];
        if(png) [png writeToURL:[root URLByAppendingPathComponent:[stem stringByAppendingString:@".png"]] atomically:YES];
    });
}
