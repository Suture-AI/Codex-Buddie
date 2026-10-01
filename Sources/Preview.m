#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "BuddieView.h"

static Class cursorClass, fogClass;
static NSColor *Ink(void) { return [NSColor colorWithSRGBRed:.16 green:.22 blue:.19 alpha:1]; }
static NSTextField *Label(NSString *s, CGFloat size, NSColor *color, NSRect frame) {
    NSTextField *l=[NSTextField labelWithString:s];
    l.font=[NSFont systemFontOfSize:size weight:size>24 ? NSFontWeightSemibold:NSFontWeightMedium];
    l.textColor=color; l.frame=frame; return l;
}
static NSButton *Button(NSString *s, id target, SEL action, NSRect frame) {
    NSButton *b=[NSButton buttonWithTitle:s target:target action:action];
    b.frame=frame; b.bezelStyle=NSBezelStyleRounded; return b;
}
static NSArray<BuddieCharacter *> *BuddieCollection(void) {
    NSMutableArray *all=[NSMutableArray new];
    NSURL *root=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"Characters"];
    for(NSString *name in @[@"pip",@"sprout",@"mochi",@"orbit"]) {
        NSError *error=nil; BuddieCharacter *c=[BuddieCharacter loadPack:[root URLByAppendingPathComponent:name] error:&error];
        if(c) [all addObject:c];
    }
    for(BuddieCharacter *c in BuddieCharacter.presets) { c.name=[c.name stringByAppendingString:@" · Classic"]; [all addObject:c]; }
    return all;
}
@interface LabView : NSView
@end
@implementation LabView
- (void)drawRect:(NSRect)rect {
    [[NSColor colorWithSRGBRed:.97 green:.97 blue:.945 alpha:1] setFill]; NSRectFill(self.bounds);
    [[NSColor colorWithSRGBRed:.93 green:.945 blue:.91 alpha:1] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(30,172,634,386) xRadius:22 yRadius:22] fill];
    [[NSColor colorWithSRGBRed:.79 green:.83 blue:.77 alpha:.65] setFill];
    for(int x=52;x<650;x+=22) for(int y=192;y<548;y+=22)
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x,y,1.4,1.4)] fill];
}
@end
@interface Delegate : NSObject <NSApplicationDelegate,NSWindowDelegate> {
    BuddieJourney _journey;
    BuddiePoint _anchor;
    double _nextMove, _releaseAt;
}
@property NSWindow *window;
@property NSWindow *cursor;
@property NSTimer *timer;
@property NSTextField *status;
@property NSPopUpButton *picker;
@property NSButton *playButton;
@property NSButton *reduceButton;
@property NSMutableArray<BuddieCharacter *> *collection;
@property NSMutableDictionary<NSString *,NSSlider *> *sliders;
@property NSMutableDictionary<NSString *,NSTextField *> *settingLabels;
@property NSTextField *settingsHeading;
@property NSTextField *artNote;
@property NSMutableArray<NSView *> *materialControls;
@property BuddieCharacter *character;
@property BOOL playing;
@property BOOL software;
@property NSInteger step;
@end
@implementation Delegate
- (BuddieView *)buddy { return (BuddieView *)self.cursor.contentView; }
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.collection=[BuddieCollection() mutableCopy]; self.character=[self.collection.firstObject copy];
    self.sliders=[NSMutableDictionary new];
    self.settingLabels=[NSMutableDictionary new];
    self.materialControls=[NSMutableArray new];
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,960,700) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"Codex Buddie — Character Studio"; self.window.delegate=self;
    self.window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameAqua];
    LabView *v=[[LabView alloc] initWithFrame:NSMakeRect(0,0,960,700)]; self.window.contentView=v;
    [v addSubview:Label(@"SUTURE  /  BUDDIE STUDIO",11,NSColor.secondaryLabelColor,NSMakeRect(32,658,620,20))];
    [v addSubview:Label(@"A little more character.",32,Ink(),NSMakeRect(30,610,670,44))];
    [v addSubview:Label(@"Pick a buddy. Make it yours. Take it for a walk.",15,Ink(),NSMakeRect(32,577,630,25))];
    [v addSubview:Label(@"YOUR COLLECTION",11,NSColor.secondaryLabelColor,NSMakeRect(700,643,230,20))];
    self.picker=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(696,599,230,34) pullsDown:NO];
    for(BuddieCharacter *c in self.collection) [self.picker addItemWithTitle:c.name];
    self.picker.target=self; self.picker.action=@selector(selectCharacter:); [v addSubview:self.picker];
    [v addSubview:Button(@"Import buddy…",self,@selector(importPack:),NSMakeRect(696,558,230,32))];
    self.settingsHeading=Label(@"SHAPE & EXPRESSION",11,NSColor.secondaryLabelColor,NSMakeRect(700,508,230,20)); [v addSubview:self.settingsHeading];
    NSArray *settings=@[@[@"width",@"Body width",@24,@42],@[@"height",@"Body height",@24,@40],@[@"eyeSpacing",@"Eye spacing",@8,@20],@[@"eyeSize",@"Eye size",@3,@7],@[@"faceY",@"Face position",@(-7),@7],@[@"stride",@"Stride",@16,@40],@[@"footLift",@"Step height",@2,@8],@[@"spriteHeight",@"Size",@32,@96]];
    int row=0;
    for(NSArray *setting in settings) {
        CGFloat y=465-row*43;
        NSTextField *label=Label(setting[1],12,Ink(),NSMakeRect(700,y+6,110,20)); self.settingLabels[setting[0]]=label; [v addSubview:label];
        NSSlider *slider=[NSSlider sliderWithValue:0 minValue:[setting[2] doubleValue] maxValue:[setting[3] doubleValue] target:self action:@selector(tune:)];
        slider.frame=NSMakeRect(809,y+4,115,24); slider.identifier=setting[0]; slider.continuous=YES;
        slider.accessibilityLabel=setting[1]; self.sliders[setting[0]]=slider; [v addSubview:slider]; row++;
    }
    self.artNote=[NSTextField wrappingLabelWithString:@"Pip’s face and outfit belong together. Import another buddy to try a different look."];
    self.artNote.font=[NSFont systemFontOfSize:12]; self.artNote.textColor=NSColor.secondaryLabelColor;
    self.artNote.frame=NSMakeRect(700,315,218,76); [v addSubview:self.artNote];
    self.reduceButton=[NSButton checkboxWithTitle:@"Reduced motion" target:self action:@selector(reduce:)];
    self.reduceButton.frame=NSMakeRect(700,146,225,26); [v addSubview:self.reduceButton];
    [v addSubview:Button(@"Reset character",self,@selector(selectCharacter:),NSMakeRect(696,103,230,32))];
    [v addSubview:Button(@"Save a copy…",self,@selector(savePack:),NSMakeRect(696,65,230,32))];
    NSArray *titles=@[@"Look here",@"Over here",@"One more stop"];
    NSPoint points[]={{116,342},{491,442},{371,250}};
    for(int i=0;i<3;i++) {
        NSButton *b=Button(titles[i],self,@selector(target:),NSMakeRect(points[i].x-53,points[i].y-16,106,32)); b.tag=i; [v addSubview:b];
    }
    self.playButton=Button(@"Take a walk",self,@selector(toggle:),NSMakeRect(30,116,154,34)); [v addSubview:self.playButton];
    [v addSubview:Button(@"Try a click",self,@selector(clickPose:),NSMakeRect(188,116,132,34))];
    [v addSubview:Button(@"Native size",self,@selector(style:),NSMakeRect(324,116,130,34))];
    [v addSubview:Label(@"Tap another stop mid-walk to change direction.",12,NSColor.secondaryLabelColor,NSMakeRect(34,86,620,22))];
    self.status=Label(@"Character preview • live Codex replacement is still under development",11,NSColor.secondaryLabelColor,NSMakeRect(34,34,890,22)); [v addSubview:self.status];
    [self.window center]; [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
    _anchor=(BuddiePoint){250,370}; _journey.end=_anchor;
    [self createCursor]; [self syncSliders];
    __weak Delegate *weak=self;
    self.timer=[NSTimer timerWithTimeInterval:1./60 repeats:YES block:^(NSTimer *t) { [weak tick]; }];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
}
- (void)syncSliders {
    BOOL sprite=self.character.clips.count>0;
    self.settingsHeading.stringValue=sprite ? @"MAKE IT YOURS":@"SHAPE & EXPRESSION";
    self.artNote.hidden=!sprite;
    self.artNote.stringValue=self.character.materials.count ? @"Your colors, with all the original shading. Save a copy to keep this look.":@"The face and outfit belong together. Import another buddy to try a different look.";
    self.artNote.frame=NSMakeRect(700,self.character.materials.count ? 202:315,218,65);
    for(NSView *control in self.materialControls) {
        if([control isKindOfClass:NSColorWell.class]) [(NSColorWell *)control deactivate];
        [control removeFromSuperview];
    }
    [self.materialControls removeAllObjects];
    NSUInteger row=0;
    for(NSDictionary *material in self.character.materials) {
        CGFloat y=369-42*row++;
        NSTextField *label=Label(material[@"name"],12,Ink(),NSMakeRect(700,y+6,130,20));
        NSColorWell *well=[[NSColorWell alloc] initWithFrame:NSMakeRect(858,y,66,30)];
        well.identifier=material[@"id"]; well.accessibilityLabel=material[@"name"];
        well.color=self.character.materialColors[material[@"id"]]; well.target=self; well.action=@selector(paint:); well.continuous=NO;
        [self.materialControls addObjectsFromArray:@[label,well]];
        [self.window.contentView addSubview:label]; [self.window.contentView addSubview:well];
    }
    for(NSString *key in self.sliders) {
        self.sliders[key].doubleValue=[key isEqual:@"width"] ? self.character.bodySize.width : [key isEqual:@"height"] ? self.character.bodySize.height : [[self.character valueForKey:key] doubleValue];
        BOOL supported=sprite ? [@[@"stride",@"spriteHeight"] containsObject:key]:![key isEqual:@"spriteHeight"];
        self.sliders[key].hidden=!supported; self.settingLabels[key].hidden=!supported;
        CGFloat y=[key isEqual:@"stride"] ? (sprite ? 422:250):[key isEqual:@"spriteHeight"] ? 465:self.sliders[key].frame.origin.y-4;
        [self.sliders[key] setFrameOrigin:NSMakePoint(809,y+4)];
        [self.settingLabels[key] setFrameOrigin:NSMakePoint(700,y+6)];
    }
    self.status.stringValue=self.character.clips.count ? @"Complete character poses • motion study • live Codex replacement is still under development":@"Character preview • live Codex replacement is still under development";
}
- (void)paint:(NSColorWell *)sender {
    NSColor *color=[[sender.color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] colorWithAlphaComponent:1];
    NSMutableDictionary *colors=[self.character.materialColors mutableCopy]; colors[sender.identifier]=color;
    self.character.materialColors=colors;
    // Warm every pose before resuming animation, avoiding work at frame changes.
    [self.character prepareAppearance]; self.buddy.needsDisplay=YES;
}
- (void)createCursor {
    if(self.cursor) { [self.window removeChildWindow:self.cursor]; [self.cursor orderOut:nil]; self.cursor.contentView=nil; }
    NSSize size=self.software ? NSMakeSize(20,23):NSMakeSize(300,300);
    self.cursor=[[cursorClass alloc] initWithContentRect:NSMakeRect(0,0,size.width,size.height) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    self.cursor.opaque=NO; self.cursor.backgroundColor=NSColor.clearColor; self.cursor.hasShadow=NO;
    self.cursor.ignoresMouseEvents=YES; self.cursor.releasedWhenClosed=NO;
    self.cursor.contentView=self.software ? [[NSImageView alloc] initWithFrame:NSMakeRect(0,0,size.width,size.height)] : [[fogClass alloc] initWithFrame:NSMakeRect(0,0,size.width,size.height)];
    self.buddy.manualAnimation=YES; self.buddy.character=self.character; self.buddy.characterScale=2;
    self.buddy.reduceMotion=self.reduceButton.state==NSControlStateValueOn;
    [self.window addChildWindow:self.cursor ordered:NSWindowAbove]; [self positionCursor];
    [self.cursor orderFront:nil];
}
- (void)positionCursor {
    NSPoint target=[self.window convertPointToScreen:NSMakePoint(_anchor.x,_anchor.y)];
    NSSize size=self.cursor.frame.size; NSPoint hot=self.buddy.hotspot;
    [self.cursor setFrameOrigin:NSMakePoint(target.x-hot.x,target.y-(size.height-hot.y))];
}
- (void)tick {
    if(self.window.miniaturized || !self.window.visible) return;
    double now=NSProcessInfo.processInfo.systemUptime;
    _anchor=BuddieJourneySample(&_journey,now);
    if(_journey.active && now>=_journey.startedAt+_journey.duration) _journey.active=false;
    if(self.playing && now>=_nextMove) { self.step=(self.step+1)%3; [self moveToStep]; _nextMove=now+1.9; }
    if(_releaseAt>0 && now>=_releaseAt) { [self.buddy press:NO atTime:now]; _releaseAt=0; }
    [self positionCursor];
    CGFloat scale=self.buddy.drawingScale;
    if(scale>0) [self.buddy animateAtTime:now anchor:(BuddiePoint){_anchor.x/scale,-_anchor.y/scale}];
}
- (void)moveToStep {
    BuddiePoint points[]={{116,342},{491,442},{371,250}};
    double now=NSProcessInfo.processInfo.systemUptime;
    _anchor=BuddieJourneySample(&_journey,now);
    if(self.buddy.reduceMotion || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        _anchor=points[self.step%3]; _journey.end=_anchor; _journey.active=false;
    } else BuddieJourneyRetarget(&_journey,_anchor,points[self.step%3],now,.8);
}
- (void)target:(NSButton *)sender { self.step=sender.tag; [self moveToStep]; _nextMove=NSProcessInfo.processInfo.systemUptime+2; }
- (void)toggle:(id)sender { self.playing=!self.playing; self.playButton.title=self.playing ? @"Pause walk":@"Take a walk"; _nextMove=0; }
- (void)style:(NSButton *)sender { self.software=!self.software; sender.title=self.software ? @"Studio size":@"Native size"; [self createCursor]; }
- (void)clickPose:(id)sender { double now=NSProcessInfo.processInfo.systemUptime; [self.buddy press:YES atTime:now]; _releaseAt=now+.15; }
- (void)reduce:(NSButton *)sender { self.buddy.reduceMotion=sender.state==NSControlStateValueOn; }
- (void)selectCharacter:(id)sender {
    self.character=[self.collection[self.picker.indexOfSelectedItem] copy]; self.buddy.character=self.character; [self syncSliders];
}
- (void)tune:(NSSlider *)sender {
    NSString *key=sender.identifier;
    if([key isEqual:@"width"]) self.character.bodySize=NSMakeSize(sender.doubleValue,self.character.bodySize.height);
    else if([key isEqual:@"height"]) self.character.bodySize=NSMakeSize(self.character.bodySize.width,sender.doubleValue);
    else [self.character setValue:@(sender.doubleValue) forKey:key];
}
- (void)importPack:(id)sender {
    NSOpenPanel *panel=[NSOpenPanel openPanel]; panel.canChooseDirectories=YES; panel.canChooseFiles=NO; panel.allowsMultipleSelection=NO;
    panel.message=@"Choose a buddy folder containing buddy.json and its PNG artwork.";
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if(response!=NSModalResponseOK) return;
        NSError *error=nil; BuddieCharacter *c=[BuddieCharacter loadPack:panel.URL error:&error];
        if(!c) { NSAlert *alert=[NSAlert new]; alert.messageText=@"Couldn’t open this buddy"; alert.informativeText=error.localizedDescription; [alert beginSheetModalForWindow:self.window completionHandler:nil]; return; }
        [self.collection addObject:c]; [self.picker addItemWithTitle:c.name]; [self.picker selectItemAtIndex:self.collection.count-1]; [self selectCharacter:nil];
    }];
}
- (void)savePack:(id)sender {
    NSSavePanel *panel=[NSSavePanel savePanel]; panel.canCreateDirectories=YES;
    panel.nameFieldStringValue=[self.character.name stringByAppendingString:@" Custom.buddie"];
    panel.message=@"Save the artwork and your animation settings as a portable buddy folder.";
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if(response!=NSModalResponseOK) return;
        BuddieCharacter *copy=[self.character copy]; copy.identifier=NSUUID.UUID.UUIDString.lowercaseString;
        copy.name=panel.URL.lastPathComponent.stringByDeletingPathExtension;
        NSError *error=nil;
        if(![copy savePack:panel.URL error:&error]) {
            NSAlert *alert=[NSAlert new]; alert.messageText=@"Couldn’t save this buddy"; alert.informativeText=error.localizedDescription ?: @"The artwork could not be encoded."; [alert beginSheetModalForWindow:self.window completionHandler:nil];
        } else {
            [self.collection addObject:copy]; [self.picker addItemWithTitle:copy.name]; [self.picker selectItemAtIndex:self.collection.count-1]; [self selectCharacter:nil];
            self.status.stringValue=@"Buddy saved. Import this folder to use it again or share it with a friend.";
        }
    }];
}
- (void)windowDidMove:(NSNotification *)notification { [self positionCursor]; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
@end

@interface ExportView : BuddieView
@property NSPoint exportHotspot;
@end
@implementation ExportView
- (NSPoint)hotspot { return self.exportHotspot; }
- (void)drawRect:(NSRect)rect {
    [[NSColor colorWithSRGBRed:.97 green:.97 blue:.945 alpha:1] setFill]; NSRectFill(self.bounds);
    [[NSColor colorWithSRGBRed:.80 green:.84 blue:.78 alpha:.7] setFill];
    for(int x=24;x<840;x+=24) for(int y=100;y<460;y+=24) [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x,y,1.5,1.5)] fill];
    [self.character.name drawAtPoint:NSMakePoint(36,28) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:28 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:Ink()}];
    [@"CODEX BUDDIE  /  CHARACTER MOTION STUDY" drawAtPoint:NSMakePoint(38,66) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:10 weight:NSFontWeightMedium],NSForegroundColorAttributeName:Ink()}];
    [super drawRect:rect];
}
@end
static int ExportFrames(NSString *path, NSString *identifier) {
    NSError *error=nil;
    if(![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error]) { fprintf(stderr,"%s\n",error.localizedDescription.UTF8String); return 1; }
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,840,480) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameAqua];
    ExportView *view=[[ExportView alloc] initWithFrame:NSMakeRect(0,0,840,480)]; view.manualAnimation=YES; view.characterScale=2; window.contentView=view;
    NSArray<BuddieCharacter *> *characters=BuddieCollection();
    int frame=0;
    for(NSUInteger index=0;index<characters.count;index++) {
        if(identifier ? ![characters[index].identifier isEqual:identifier]:index>=3) continue;
        view.character=[characters[index] copy];
        BuddiePoint point={95,220}; BuddieJourney journey={0}; journey.end=point;
        for(int i=0;i<240;i++,frame++) {
            double now=100+i/60.;
            if(i==25) BuddieJourneyRetarget(&journey,point,(BuddiePoint){600,180},now,.65);
            if(i==65) BuddieJourneyRetarget(&journey,point,(BuddiePoint){330,285},now,.65);
            point=BuddieJourneySample(&journey,now);
            if(i==175) [view press:YES atTime:now];
            if(i==185) [view press:NO atTime:now];
            view.exportHotspot=NSMakePoint(point.x,point.y);
            [view animateAtTime:now anchor:(BuddiePoint){point.x/2,point.y/2}];
            NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:840 pixelsHigh:480 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
            [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
            NSString *filename=[path stringByAppendingPathComponent:[NSString stringWithFormat:@"frame-%04d.png",frame]];
            if(![[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:filename options:NSDataWritingAtomic error:&error]) { fprintf(stderr,"%s\n",error.localizedDescription.UTF8String); return 1; }
        }
    }
    printf("Exported %d deterministic frames at 60 Hz to %s\n",frame,path.UTF8String); return 0;
}

static int ExportPalettes(NSString *path) {
    NSError *error=nil;
    if(![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error]) return 1;
    NSArray *names=@[@"Cobalt",@"Rose",@"Moss",@"Lilac"];
    // Curated examples; the studio's color wells accept any opaque color.
    unsigned int coats[]={0x0850EF,0xD65378,0x668D4E,0x967AD3};
    unsigned int boots[]={0xFF8000,0x4A6394,0xF1AF46,0xEAD38E};
    NSColor *(^color)(unsigned int)=^NSColor *(unsigned int n) {
        return [NSColor colorWithSRGBRed:((n>>16)&255)/255. green:((n>>8)&255)/255. blue:(n&255)/255. alpha:1];
    };
    for(NSUInteger variant=0;variant<names.count;variant++) {
        BuddieCharacter *c=[BuddieCollection().firstObject copy];
        c.materialColors=@{@"coat":color(coats[variant]),@"boots":color(boots[variant])}; [c prepareAppearance];
        for(NSString *clip in @[@"idle",@"walkRight"]) for(NSUInteger i=0;i<c.clips[clip].frames.count;i++) {
            NSBitmapImageRep *rep=[NSBitmapImageRep imageRepWithData:[c imageForClip:clip frame:i].TIFFRepresentation];
            NSString *file=[path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@-%02lu.png",names[variant],clip,(unsigned long)i]];
            if(![[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:file options:NSDataWritingAtomic error:&error]) return 1;
        }
    }
    printf("Exported four palettes, each with all 14 poses, to %s\n",path.UTF8String); return 0;
}

static int SelfTest(void) {
    NSRect r=NSMakeRect(0,0,20,23);
    NSWindow *plain=[[NSWindow alloc] initWithContentRect:r styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    NSImageView *ordinary=[[NSImageView alloc] initWithFrame:r]; plain.contentView=ordinary;
    NSCAssert(plain.contentView==ordinary,@"Unrelated windows must stay untouched");
    NSWindow *cursor=[[cursorClass alloc] initWithContentRect:r styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    NSImageView *image=[[NSImageView alloc] initWithFrame:r]; cursor.contentView=image;
    NSCAssert([NSStringFromClass(cursor.contentView.class) isEqual:@"BuddieView"],@"Native image must be replaced");
    NSCAssert([((BuddieView *)cursor.contentView).character.identifier isEqual:@"pip"],@"Replacement factory loads the bundled character before studio overrides");
    NSCAssert(NSEqualSizes(cursor.contentView.frame.size,r.size),@"Native dimensions must stay intact");
    NSCAssert(image.superview==nil,@"Original artwork must be detached");
    NSImageView *refresh=[[NSImageView alloc] initWithFrame:r]; cursor.contentView=refresh;
    NSCAssert([NSStringFromClass(cursor.contentView.class) isEqual:@"BuddieView"],@"Replacing native content again must work");
    NSView *unknown=[[NSView alloc] initWithFrame:r]; cursor.contentView=unknown;
    NSCAssert(cursor.contentView==unknown,@"Unknown renderer must fail open");
    NSView *fog=[[fogClass alloc] initWithFrame:r]; cursor.contentView=fog;
    NSCAssert([NSStringFromClass(cursor.contentView.class) isEqual:@"BuddieView"],@"Native fog must be replaced");
    NSWindow *spriteWindow=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,300,300) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    BuddieView *sprite=[[BuddieView alloc] initWithFrame:NSMakeRect(0,0,300,300)];
    sprite.manualAnimation=YES; sprite.characterScale=2; sprite.character=[BuddieCollection().firstObject copy]; spriteWindow.contentView=sprite;
    NSCAssert(sprite.character.clips[@"idle"],@"Sprite integration test needs the bundled Pip pack");
    NSData *(^snapshot)(void)=^NSData *{
        NSBitmapImageRep *rep=[sprite bitmapImageRepForCachingDisplayInRect:sprite.bounds];
        [sprite cacheDisplayInRect:sprite.bounds toBitmapImageRep:rep];
        return [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    };
    NSPoint hotspot=sprite.hotspot;
    [sprite animateAtTime:100 anchor:(BuddiePoint){0,0}]; NSData *open=snapshot();
    [sprite animateAtTime:102.57 anchor:(BuddiePoint){0,0}]; NSData *blink=snapshot();
    if(!NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) NSCAssert(![open isEqual:blink],@"Elapsed idle time must render different blink artwork");
    sprite.reduceMotion=YES;
    [sprite animateAtTime:103 anchor:(BuddiePoint){50,0}]; NSData *still=snapshot();
    [sprite animateAtTime:104 anchor:(BuddiePoint){100,20}]; NSCAssert([still isEqual:snapshot()],@"Reduced Motion renders the same complete pose while moving");
    [sprite press:YES atTime:104]; [sprite animateAtTime:104.1 anchor:(BuddiePoint){100,20}];
    NSCAssert(NSEqualPoints(sprite.hotspot,hotspot),@"Sprite press keeps the native click coordinate");
    if(!NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        sprite.character=[BuddieCollection().firstObject copy]; sprite.reduceMotion=NO;
        [sprite animateAtTime:200 anchor:(BuddiePoint){0,0}]; NSData *rightIdle=snapshot();
        for(int i=1;i<=90;i++) [sprite animateAtTime:200+i/60. anchor:(BuddiePoint){-MIN(i,30),0}];
        NSData *leftIdle=snapshot();
        NSCAssert(![leftIdle isEqual:rightIdle],@"After left travel, directional idle must keep facing left");
        sprite.reduceMotion=YES;
        [sprite animateAtTime:201.6 anchor:(BuddiePoint){-30,0}];
        NSCAssert([leftIdle isEqual:snapshot()],@"Reduced Motion preserves the stopped facing and first pose");
        sprite.character.directionalIdle=NO;
        [sprite animateAtTime:201.7 anchor:(BuddiePoint){-30,0}];
        NSCAssert([rightIdle isEqual:snapshot()],@"Nondirectional packs keep their authored idle orientation");
    }
    puts("PASS: software + fog replacement, unchanged geometry, detached artwork, repeated assignment, unrelated windows, unknown renderer fallback");
    puts("PASS: complete sprite drawing, timed blink, Reduced Motion stability, stopped facing, unchanged sprite hotspot");
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
        if(argc>2 && strcmp(argv[1],"--export-frames")==0) return ExportFrames([NSString stringWithUTF8String:argv[2]],argc>3 ? [NSString stringWithUTF8String:argv[3]]:nil);
        if(argc>2 && strcmp(argv[1],"--export-palettes")==0) return ExportPalettes([NSString stringWithUTF8String:argv[2]]);
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        Delegate *delegate=[Delegate new]; NSApp.delegate=delegate; [NSApp run];
    }
}
