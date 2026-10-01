#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static Class cursorClass, fogClass;
static NSTextField *Label(NSString *s, CGFloat size, NSColor *color, NSRect frame) {
    NSTextField *l = [NSTextField labelWithString:s];
    l.font = [NSFont systemFontOfSize:size weight:size>24 ? NSFontWeightBold : NSFontWeightMedium];
    l.textColor=color; l.frame=frame; return l;
}

@interface LabView : NSView
@end
@implementation LabView
- (void)drawRect:(NSRect)rect {
    [[NSColor colorWithSRGBRed:.96 green:.96 blue:.93 alpha:1] setFill]; NSRectFill(self.bounds);
    [[NSColor colorWithSRGBRed:.88 green:.90 blue:.85 alpha:1] setFill];
    for(int x=28;x<self.bounds.size.width;x+=24) for(int y=110;y<380;y+=24)
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x,y,2,2)] fill];
}
@end

@interface Delegate : NSObject <NSApplicationDelegate>
@property NSWindow *window;
@property NSWindow *cursor;
@property NSTimer *timer;
@property NSTextField *status;
@property BOOL software;
@property NSInteger step;
@end
@implementation Delegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,700,510) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"Codex Buddie — Renderer Lab";
    LabView *v=[[LabView alloc] initWithFrame:NSMakeRect(0,0,700,510)]; self.window.contentView=v;
    NSColor *ink=[NSColor colorWithSRGBRed:.10 green:.16 blue:.14 alpha:1];
    [v addSubview:Label(@"SUTURE  /  EXPERIMENT 001",11,NSColor.secondaryLabelColor,NSMakeRect(32,464,630,20))];
    [v addSubview:Label(@"Meet your new point person.",30,ink,NSMakeRect(32,410,640,42))];
    [v addSubview:Label(@"A character at the agent’s click point.",15,ink,NSMakeRect(34,382,630,25))];
    NSArray *titles=@[@"01  Look",@"02  Move",@"03  Click"];
    for(int i=0;i<3;i++) {
        NSButton *b=[NSButton buttonWithTitle:titles[i] target:self action:@selector(target:)];
        b.tag=i; b.frame=NSMakeRect(65+i*210,234,150,55); b.bezelStyle=NSBezelStyleRounded;
        [v addSubview:b];
    }
    self.status=Label(@"Renderer test • Codex connection not yet verified",12,NSColor.secondaryLabelColor,NSMakeRect(34,162,630,23));
    [v addSubview:self.status];
    NSButton *demo=[NSButton buttonWithTitle:@"Play / pause movement" target:self action:@selector(toggle:)];
    demo.frame=NSMakeRect(30,108,220,36); demo.bezelStyle=NSBezelStyleRounded; [v addSubview:demo];
    NSButton *style=[NSButton buttonWithTitle:@"Switch cursor style" target:self action:@selector(style:)];
    style.frame=NSMakeRect(254,108,200,36); style.bezelStyle=NSBezelStyleRounded; [v addSubview:style];
    [v addSubview:Label(@"This lab simulates the native cursor window. It does not control other apps.",11,NSColor.secondaryLabelColor,NSMakeRect(34,51,640,20))];
    [v addSubview:Label(@"The antenna tip is the hotspot. Your own mouse stays unchanged.",11,NSColor.secondaryLabelColor,NSMakeRect(34,30,640,20))];
    [self.window center]; [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
    [self createCursor];
}
- (void)createCursor {
    if(self.cursor) { [self.window removeChildWindow:self.cursor]; [self.cursor orderOut:nil]; }
    NSSize size=self.software ? NSMakeSize(20,23) : NSMakeSize(96,96);
    self.cursor=[[cursorClass alloc] initWithContentRect:NSMakeRect(0,0,size.width,size.height) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    self.cursor.opaque=NO; self.cursor.backgroundColor=NSColor.clearColor; self.cursor.hasShadow=NO;
    self.cursor.ignoresMouseEvents=YES; self.cursor.releasedWhenClosed=NO;
    NSView *original=self.software ? [[NSImageView alloc] initWithFrame:NSMakeRect(0,0,size.width,size.height)] : [[fogClass alloc] initWithFrame:NSMakeRect(0,0,size.width,size.height)];
    self.cursor.contentView=original;
    [self.window addChildWindow:self.cursor ordered:NSWindowAbove];
    [self moveToStep:NO];
}
- (void)moveToStep:(BOOL)animate {
    NSRect target=[self.window convertRectToScreen:NSMakeRect(140+(self.step%3)*210,261,0,0)];
    NSSize s=self.cursor.frame.size;
    NSPoint hot=self.software ? NSMakePoint(4,4) : NSMakePoint(s.width/2,s.height/2);
    NSRect next=NSMakeRect(target.origin.x-hot.x,target.origin.y-(s.height-hot.y),s.width,s.height);
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration=animate && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion ? .4 : 0;
        [[self.cursor animator] setFrame:next display:YES];
    } completionHandler:nil];
    [self.cursor orderFront:nil];
}
- (void)target:(NSButton *)sender { self.step=sender.tag; [self moveToStep:YES]; }
- (void)toggle:(id)sender {
    if(self.timer) { [self.timer invalidate]; self.timer=nil; return; }
    __weak Delegate *weak=self;
    self.timer=[NSTimer scheduledTimerWithTimeInterval:1.3 repeats:YES block:^(NSTimer *t) { Delegate *s=weak; s.step++; [s moveToStep:YES]; }];
}
- (void)style:(id)sender { self.software=!self.software; [self createCursor]; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
@end

static int SelfTest(void) {
    NSRect r=NSMakeRect(0,0,20,23);
    NSWindow *plain=[[NSWindow alloc] initWithContentRect:r styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    NSImageView *ordinary=[[NSImageView alloc] initWithFrame:r]; plain.contentView=ordinary;
    NSCAssert(plain.contentView==ordinary,@"Unrelated windows must stay untouched");
    NSWindow *cursor=[[cursorClass alloc] initWithContentRect:r styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    NSImageView *image=[[NSImageView alloc] initWithFrame:r]; cursor.contentView=image;
    NSCAssert([NSStringFromClass(cursor.contentView.class) isEqual:@"BuddieView"],@"Native image must be replaced");
    NSCAssert(NSEqualSizes(cursor.contentView.frame.size,r.size),@"Native dimensions must stay intact");
    NSCAssert(image.superview==nil,@"Original artwork must be detached");
    NSImageView *refresh=[[NSImageView alloc] initWithFrame:r]; cursor.contentView=refresh;
    NSCAssert([NSStringFromClass(cursor.contentView.class) isEqual:@"BuddieView"],@"Replacing native content again must work");
    NSView *unknown=[[NSView alloc] initWithFrame:r]; cursor.contentView=unknown;
    NSCAssert(cursor.contentView==unknown,@"Unknown renderer must fail open");
    NSView *fog=[[fogClass alloc] initWithFrame:r]; cursor.contentView=fog;
    NSCAssert([NSStringFromClass(cursor.contentView.class) isEqual:@"BuddieView"],@"Native fog must be replaced");
    puts("PASS: software + fog replacement, unchanged geometry, detached artwork, repeated assignment, unrelated windows, unknown renderer fallback");
    return 0;
}
int main(int argc,const char **argv) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        cursorClass=objc_allocateClassPair(NSWindow.class,"ComputerUse.ComputerUseCursor.Window",0); objc_registerClassPair(cursorClass);
        fogClass=objc_allocateClassPair(NSView.class,"BuddieTest.NSHostingView.CursorView",0); objc_registerClassPair(fogClass);
        NSString *path=[NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:@"libBuddie.dylib"];
        if(!dlopen(path.fileSystemRepresentation,RTLD_NOW)) { fprintf(stderr,"%s\n",dlerror()); return 1; }
        if(argc>1 && strcmp(argv[1],"--self-test")==0) return SelfTest();
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        Delegate *delegate=[Delegate new]; NSApp.delegate=delegate; [NSApp run];
    }
}
