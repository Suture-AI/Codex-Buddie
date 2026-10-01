#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "BuddieView.h"
#import "BuddiePuppet.h"

static Class cursorClass, fogClass;
static NSColor *Ink(void) { return [NSColor colorWithSRGBRed:.16 green:.22 blue:.19 alpha:1]; }
static NSString *ColorHex(NSColor *color) {
    color=[color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    return [NSString stringWithFormat:@"#%02X%02X%02X",(int)round(color.redComponent*255),(int)round(color.greenComponent*255),(int)round(color.blueComponent*255)];
}
static NSColor *ColorFromHex(NSString *text) {
    NSString *hex=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if([hex hasPrefix:@"#"]) hex=[hex substringFromIndex:1];
    if(hex.length!=6 || [hex rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet]].location!=NSNotFound) return nil;
    unsigned int n=0; [[NSScanner scannerWithString:hex] scanHexInt:&n];
    return [NSColor colorWithSRGBRed:((n>>16)&255)/255. green:((n>>8)&255)/255. blue:(n&255)/255. alpha:1];
}
static NSTextField *Label(NSString *s, CGFloat size, NSColor *color, NSRect frame) {
    NSTextField *l=[NSTextField labelWithString:s];
    l.font=[NSFont systemFontOfSize:size weight:size>24 ? NSFontWeightSemibold:NSFontWeightMedium];
    l.textColor=color; l.frame=frame; return l;
}
static NSButton *Button(NSString *s, id target, SEL action, NSRect frame) {
    NSButton *b=[NSButton buttonWithTitle:s target:target action:action];
    b.frame=frame; b.bezelStyle=NSBezelStyleRounded; return b;
}
static void InstallMenus(void) {
    NSMenu *bar=[NSMenu new];
    NSMenuItem *appItem=[NSMenuItem new]; [bar addItem:appItem];
    NSMenu *appMenu=[[NSMenu alloc] initWithTitle:@"Codex Buddie Lab"]; appItem.submenu=appMenu;
    [appMenu addItemWithTitle:@"Hide Codex Buddie Lab" action:@selector(hide:) keyEquivalent:@"h"];
    [appMenu addItem:NSMenuItem.separatorItem];
    [appMenu addItemWithTitle:@"Quit Codex Buddie Lab" action:@selector(terminate:) keyEquivalent:@"q"];
    NSMenuItem *editItem=[NSMenuItem new]; [bar addItem:editItem];
    NSMenu *editMenu=[[NSMenu alloc] initWithTitle:@"Edit"]; editItem.submenu=editMenu;
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    NSApp.mainMenu=bar;
}
static NSArray<BuddieCharacter *> *BuddieCollection(void) {
    NSMutableArray *all=[NSMutableArray new];
    NSURL *root=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"Characters"];
    for(NSString *name in @[@"pip",@"pip-articulated",@"bit",@"miso",@"sprout",@"mochi",@"orbit"]) {
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
@interface Delegate : NSObject <NSApplicationDelegate,NSWindowDelegate,NSTextFieldDelegate> {
    BuddieJourney _journey;
    BuddiePoint _anchor;
    double _nextMove, _releaseAt;
    BOOL _syncingControls;
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
@property NSMutableDictionary<NSString *,NSTextField *> *materialFields;
@property NSMutableDictionary<NSString *,NSColorWell *> *materialWells;
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
    self.materialFields=[NSMutableDictionary new]; self.materialWells=[NSMutableDictionary new];
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
    for(NSUInteger i=0;i<self.collection.count;i++) if([self.collection[i].identifier isEqual:@"bit"]) {
        [self.picker selectItemAtIndex:i]; self.character=[self.collection[i] copy]; break;
    }
    self.picker.target=self; self.picker.action=@selector(selectCharacter:); [v addSubview:self.picker];
    [v addSubview:Button(@"Import buddy…",self,@selector(importPack:),NSMakeRect(696,558,230,32))];
    self.settingsHeading=Label(@"SHAPE & EXPRESSION",11,NSColor.secondaryLabelColor,NSMakeRect(700,508,230,20)); [v addSubview:self.settingsHeading];
    NSArray *settings=@[@[@"width",@"Body width",@24,@42],@[@"height",@"Body height",@24,@40],@[@"eyeSpacing",@"Eye spacing",@8,@20],@[@"eyeSize",@"Eye size",@3,@7],@[@"faceY",@"Face position",@(-7),@7],@[@"stride",@"Stride",@8,@40],@[@"footLift",@"Step height",@2,@8],@[@"spriteHeight",@"Size",@32,@96],@[@"torsoWidth",@"Body width",@.85,@1.22],@[@"torsoHeight",@"Body height",@.85,@1.18],@[@"headScale",@"Head size",@.85,@1.15]];
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
    _syncingControls=YES;
    BOOL sprite=self.character.clips.count>0,puppet=self.character.puppetParts.count>0;
    self.settingsHeading.stringValue=sprite ? @"MAKE IT YOURS":@"SHAPE & EXPRESSION";
    self.artNote.hidden=!sprite || puppet;
    self.artNote.stringValue=self.character.materials.count ? @"Your colors, with all the original shading. Save a copy to keep this look.":@"The face and outfit belong together. Import another buddy to try a different look.";
    self.artNote.frame=NSMakeRect(700,self.character.materials.count ? 202:315,218,65);
    for(NSView *control in self.materialControls) {
        if([control isKindOfClass:NSTextField.class]) [(NSTextField *)control setDelegate:nil];
        if([control isKindOfClass:NSColorWell.class]) [(NSColorWell *)control deactivate];
        [control removeFromSuperview];
    }
    [self.materialControls removeAllObjects];
    [self.materialFields removeAllObjects]; [self.materialWells removeAllObjects];
    NSUInteger row=0;
    for(NSDictionary *material in self.character.materials) {
        CGFloat y=puppet ? 247-35*row++:369-42*row++;
        NSTextField *label=Label(material[@"name"],12,Ink(),NSMakeRect(700,y+6,81,20));
        NSColorWell *well=[[NSColorWell alloc] initWithFrame:NSMakeRect(858,y,66,30)];
        well.identifier=material[@"id"]; well.accessibilityLabel=material[@"name"];
        // A color well has no separate Apply step. Deliver panel changes as
        // they happen so the swatch, renderer and exported pack stay in sync.
        well.color=self.character.materialColors[material[@"id"]]; well.target=self; well.action=@selector(paint:); well.continuous=YES;
        NSTextField *hex=[[NSTextField alloc] initWithFrame:NSMakeRect(782,y+4,72,23)];
        hex.font=[NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
        hex.stringValue=ColorHex(well.color); hex.identifier=well.identifier; hex.delegate=self;
        hex.accessibilityLabel=[material[@"name"] stringByAppendingString:@" hex color"];
        hex.toolTip=@"Enter a color as #RRGGBB.";
        self.materialFields[well.identifier]=hex; self.materialWells[well.identifier]=well;
        [self.materialControls addObjectsFromArray:@[label,hex,well]];
        [self.window.contentView addSubview:label]; [self.window.contentView addSubview:hex]; [self.window.contentView addSubview:well];
    }
    NSArray *visible=puppet ? @[@"spriteHeight",@"torsoWidth",@"torsoHeight",@"headScale",@"stride",@"footLift"]:sprite ? @[@"spriteHeight",@"stride"]:@[@"width",@"height",@"eyeSpacing",@"eyeSize",@"faceY",@"stride",@"footLift"];
    for(NSString *key in self.sliders) {
        if([key isEqual:@"stride"]) self.sliders[key].maxValue=self.character.pixelArt ? MAX(16,self.character.stride):40;
        self.sliders[key].doubleValue=[key isEqual:@"width"] ? self.character.bodySize.width : [key isEqual:@"height"] ? self.character.bodySize.height : [[self.character valueForKey:key] doubleValue];
        BOOL supported=[visible containsObject:key];
        self.sliders[key].hidden=!supported; self.settingLabels[key].hidden=!supported;
        if(!supported) continue;
        CGFloat y=465-[visible indexOfObject:key]*(puppet ? 35:43);
        [self.sliders[key] setFrameOrigin:NSMakePoint(809,y+4)];
        [self.settingLabels[key] setFrameOrigin:NSMakePoint(700,y+6)];
    }
    self.status.stringValue=puppet ? @"Articulated character study • live Codex replacement is still under development":sprite ? @"Complete character poses • motion study • live Codex replacement is still under development":@"Character preview • live Codex replacement is still under development";
    _syncingControls=NO;
}
- (void)paint:(NSColorWell *)sender {
    if(_syncingControls || self.materialWells[sender.identifier]!=sender) return;
    NSColor *color=[[sender.color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] colorWithAlphaComponent:1];
    NSTextField *hex=self.materialFields[sender.identifier];
    if(!hex.currentEditor) hex.stringValue=ColorHex(color);
    if([ColorHex(self.character.materialColors[sender.identifier]) isEqual:ColorHex(color)]) return;
    NSMutableDictionary *colors=[self.character.materialColors mutableCopy]; colors[sender.identifier]=color;
    self.character.materialColors=colors;
    // Warm every pose before resuming animation, avoiding work at frame changes.
    [self.character prepareAppearance]; self.buddy.needsDisplay=YES;
}
- (void)controlTextDidChange:(NSNotification *)notification {
    NSTextField *field=notification.object;
    if(_syncingControls || self.materialFields[field.identifier]!=field) return;
    NSColor *color=ColorFromHex(field.stringValue);
    NSColorWell *well=self.materialWells[field.identifier];
    if(color && well) { well.color=color; [self paint:well]; }
}
- (void)controlTextDidEndEditing:(NSNotification *)notification {
    NSTextField *field=notification.object; NSColorWell *well=self.materialWells[field.identifier];
    if(_syncingControls || self.materialFields[field.identifier]!=field) return;
    if(well) { [self controlTextDidChange:notification]; field.stringValue=ColorHex(well.color); }
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
    // Commit an active color edit while it still belongs to the old buddy.
    // Removing that field after replacing the model can otherwise repaint the
    // new buddy when both packs use the same material id (e.g. "shell").
    [self.window makeFirstResponder:nil];
    self.character=[self.collection[self.picker.indexOfSelectedItem] copy]; self.buddy.character=self.character; [self syncSliders];
}
- (void)tune:(NSSlider *)sender {
    NSString *key=sender.identifier;
    if([key isEqual:@"width"]) self.character.bodySize=NSMakeSize(sender.doubleValue,self.character.bodySize.height);
    else if([key isEqual:@"height"]) self.character.bodySize=NSMakeSize(self.character.bodySize.width,sender.doubleValue);
    else [self.character setValue:@(sender.doubleValue) forKey:key];
}
- (void)addCharacterToCollection:(BuddieCharacter *)character {
    NSUInteger index=[self.collection indexOfObjectPassingTest:^BOOL(BuddieCharacter *item,NSUInteger i,BOOL *stop) {
        return [item.identifier isEqual:character.identifier];
    }];
    if(index==NSNotFound) {
        index=self.collection.count; [self.collection addObject:character];
        // addItemWithTitle: removes an existing item with the same title.
        // Different portable packs may legitimately share a display name.
        [self.picker.menu addItem:[[NSMenuItem alloc] initWithTitle:character.name action:nil keyEquivalent:@""]];
    } else {
        self.collection[index]=character; [self.picker itemAtIndex:index].title=character.name;
    }
    [self.picker selectItemAtIndex:index]; [self selectCharacter:nil];
}
- (void)importPack:(id)sender {
    NSOpenPanel *panel=[NSOpenPanel openPanel]; panel.canChooseDirectories=YES; panel.canChooseFiles=NO; panel.allowsMultipleSelection=NO;
    panel.message=@"Choose a buddy folder containing buddy.json and its PNG artwork.";
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if(response!=NSModalResponseOK) return;
        NSError *error=nil; BuddieCharacter *c=[BuddieCharacter loadPack:panel.URL error:&error];
        if(!c) { NSAlert *alert=[NSAlert new]; alert.messageText=@"Couldn’t open this buddy"; alert.informativeText=error.localizedDescription; [alert beginSheetModalForWindow:self.window completionHandler:nil]; return; }
        [self addCharacterToCollection:c];
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
            [self addCharacterToCollection:copy];
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
            double scale=view.drawingScale;
            [view animateAtTime:now anchor:(BuddiePoint){point.x/scale,point.y/scale}];
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

static BuddieCharacter *ArticulatedNamed(NSString *identifier) {
    for(BuddieCharacter *c in BuddieCollection()) if([c.identifier isEqual:identifier]) return [c copy];
    return nil;
}
static BOOL SaveView(NSView *view, NSString *path) {
    NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:view.bounds.size.width pixelsHigh:view.bounds.size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
    return [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}
static NSBitmapImageRep *PuppetImageAtTime(BuddieCharacter *character,BuddiePose pose,double progress,BOOL desiredLeft,double elapsed,BOOL reduced) {
    NSImage *image=[NSImage imageWithSize:NSMakeSize(320,320) flipped:YES drawingHandler:^BOOL(NSRect rect) {
        NSGraphicsContext.currentContext.imageInterpolation=NSImageInterpolationNone;
        NSAffineTransform *scale=[NSAffineTransform transform]; [scale scaleBy:4]; [scale concat];
        BuddieDrawPuppet(character,pose,desiredLeft,progress,elapsed,reduced); return YES;
    }];
    return [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
}
static NSBitmapImageRep *PuppetImage(BuddieCharacter *character,BuddiePose pose,double progress,BOOL desiredLeft) {
    return PuppetImageAtTime(character,pose,progress,desiredLeft,0,NO);
}
static int ExportFaces(NSString *path,NSString *identifier) {
    if(![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]) return 1;
    BuddieView *view=[[BuddieView alloc] initWithFrame:NSMakeRect(0,0,240,240)];
    view.manualAnimation=YES; view.character=ArticulatedNamed(identifier); if(!view.character) return 1;
    double x=0;
    for(int i=0;i<420;i++) {
        double t=i/60.;
        if(i==54 || i==78 || i==300) [view press:YES atTime:100+t];
        if(i==71 || i==87 || i==321) [view press:NO atTime:100+t];
        if(i>=132 && i<192) x+=80/60.;
        if(i>=228 && i<276) x-=80/60.;
        double unit=view.character.spriteHeight/view.character.spriteCanvas.height*view.character.puppetMotionScale;
        [view animateAtTime:100+t anchor:(BuddiePoint){x*unit,0}];
        NSBitmapImageRep *rep=PuppetImageAtTime(view.character,view.motionPose,view.facingProgress,i>=228,t,NO);
        NSString *file=[path stringByAppendingPathComponent:[NSString stringWithFormat:@"face-%04d.png",i]];
        if(![[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:file atomically:YES]) return 1;
    }
    puts("Exported actual Cocoa face reactions: click, interrupted release, travel, turn and blink."); return 0;
}
static NSBitmapImageRep *TurnImage(BuddieCharacter *character,double progress,BOOL desiredLeft) {
    BuddiePose pose={0}; pose.squash=1;
    pose.feet[0].x=-character.footSpacing; pose.feet[1].x=character.footSpacing;
    return PuppetImage(character,pose,progress,desiredLeft);
}
static int ExportGait(NSString *path,NSString *identifier) {
    if(![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]) return 1;
    BuddieView *view=[[BuddieView alloc] initWithFrame:NSMakeRect(0,0,240,240)];
    view.manualAnimation=YES; view.character=ArticulatedNamed(identifier); if(!view.character) return 1;
    for(int i=0;i<300;i++) {
        double t=i/60.,x=t<.25 ? 0:t<1.25 ? (t-.25)*24:t<1.75 ? 24+(t-1.25)*80:t<2.15 ? 64+(t-1.75)*16:t<2.8 ? 70.4:t<3.8 ? 70.4-(t-2.8)*24:46.4;
        double unit=view.character.spriteHeight/view.character.spriteCanvas.height*view.character.puppetMotionScale;
        [view animateAtTime:100+t anchor:(BuddiePoint){x*unit,0}];
        NSBitmapImageRep *rep=PuppetImage(view.character,view.motionPose,view.facingProgress,t>=2.8);
        NSString *file=[path stringByAppendingPathComponent:[NSString stringWithFormat:@"gait-%04d.png",i]];
        if(![[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:file atomically:YES]) return 1;
    }
    puts("Exported close-up Cocoa gait: walk, flight, moving landing, stop and reversal."); return 0;
}
static int ExportTurn(NSString *path,NSString *identifier) {
    if(![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]) return 1;
    BuddieCharacter *bit=ArticulatedNamed(identifier); if(!bit) return 1;
    for(int i=0;i<96;i++) {
        double p=i<18 ? 0:i<36 ? (i-18)/18.:i<54 ? 1:i<72 ? 1-(i-54)/18.:0;
        NSBitmapImageRep *rep=TurnImage(bit,p,i<54);
        NSString *file=[path stringByAppendingPathComponent:[NSString stringWithFormat:@"turn-%04d.png",i]];
        if(![[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:file atomically:YES]) return 1;
    }
    puts("Exported actual Cocoa puppet turn, with fixed planted feet, in both directions."); return 0;
}
static int ExportPuppet(NSString *path, NSString *identifier) {
    if(![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]) return 1;
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,840,480) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    ExportView *view=[[ExportView alloc] initWithFrame:NSMakeRect(0,0,840,480)]; view.manualAnimation=YES; view.characterScale=2; window.contentView=view;
    view.character=ArticulatedNamed(identifier); if(!view.character) return 1;
    BOOL pixel=view.character.pixelArt;
    for(int i=0;i<420;i++) {
        double time=i/60.,x=time<.5 ? 0:time<3.5 ? (time-.5)*24:time<4 ? 72:time<5.5 ? 72-(time-4)*24:36;
        double physical=2*view.character.spriteHeight/view.character.spriteCanvas.height*view.character.puppetMotionScale;
        view.exportHotspot=NSMakePoint(260+x*physical,190);
        [view animateAtTime:100+time anchor:(BuddiePoint){view.exportHotspot.x/view.drawingScale,190/view.drawingScale}];
        if(!SaveView(view,[path stringByAppendingPathComponent:[NSString stringWithFormat:@"slow-%04d.png",i]])) return 1;
    }
    BuddieView *still=[[BuddieView alloc] initWithFrame:NSMakeRect(0,0,448,448)]; still.manualAnimation=YES; still.reduceMotion=YES; still.characterScale=pixel ? 5:3.3; window.contentView=still;
    NSArray *variants=@[@[@"Original",@1,@1,@1],@[@"Round",@1.22,@.94,@1],@[@"Tall",@.92,@1.18,@.96],@[pixel ? @"Big-head":@"Big-hood",@1,@1,@1.15]];
    for(NSArray *variant in variants) {
        still.character=ArticulatedNamed(identifier); still.character.torsoWidth=[variant[1] doubleValue]; still.character.torsoHeight=[variant[2] doubleValue]; still.character.headScale=[variant[3] doubleValue];
        [still animateAtTime:100 anchor:(BuddiePoint){0,0}];
        if(!SaveView(still,[path stringByAppendingPathComponent:[variant[0] stringByAppendingString:@".png"]])) return 1;
    }
    unsigned int coats[]={0xD65378,0x668D4E,0x967AD3},boots[]={0x4A6394,0xF1AF46,0xEAD38E};
    NSArray *names=@[@"Rose",@"Moss",@"Lilac"];
    BOOL miso=[identifier isEqual:@"miso"];
    if(miso) {
        unsigned int shells[]={0xF5ECDD,0xE8DFF3,0x52617E},suits[]={0x7C9A80,0x9C80B5,0xD88472};
        memcpy(coats,shells,sizeof(coats)); memcpy(boots,suits,sizeof(boots)); names=@[@"Sage",@"Lilac",@"Midnight"];
    }
    NSColor *(^color)(unsigned int)=^NSColor *(unsigned int n) { return [NSColor colorWithSRGBRed:((n>>16)&255)/255. green:((n>>8)&255)/255. blue:(n&255)/255. alpha:1]; };
    for(int i=0;i<3;i++) {
        still.character=ArticulatedNamed(identifier);
        NSMutableDictionary *colors=[still.character.materialColors mutableCopy];
        colors[still.character.materials[0][@"id"]]=color(coats[i]);
        if(!pixel || miso) colors[still.character.materials[1][@"id"]]=color(boots[i]);
        still.character.materialColors=colors; [still.character prepareAppearance];
        [still animateAtTime:100 anchor:(BuddiePoint){0,0}];
        if(!SaveView(still,[path stringByAppendingPathComponent:[names[i] stringByAppendingString:@".png"]])) return 1;
    }
    for(int i=0;i<8;i++) {
        still.character=ArticulatedNamed(identifier); still.character.torsoWidth=i&1 ? 1.22:.85; still.character.torsoHeight=i&2 ? 1.18:.85; still.character.headScale=i&4 ? 1.15:.85;
        [still animateAtTime:100 anchor:(BuddiePoint){0,0}];
        if(!SaveView(still,[path stringByAppendingPathComponent:[NSString stringWithFormat:@"limit-%d.png",i]])) return 1;
    }
    puts("Exported articulated Cocoa slow gait, proportion variants, palettes and all eight proportion corners."); return 0;
}

static void TestPuppet(BuddieView *view) {
    BuddieCharacter *pip=ArticulatedNamed(@"pip-articulated"); NSCAssert(pip,@"Bundled articulated Pip loads");
    for(int height=32;height<=96;height+=32) for(int zoom=1;zoom<=2;zoom++) {
        view.character=[pip copy]; view.character.spriteHeight=height; view.characterScale=zoom; view.reduceMotion=NO;
        double scale=view.drawingScale,unit=scale*height/pip.spriteCanvas.height;
        [view animateAtTime:300 anchor:(BuddiePoint){0,0}];
        for(int i=1;i<=120;i++) {
            BuddiePose before=view.motionPose; double oldX=(i-1)*.3*unit*pip.puppetMotionScale,x=i*.3*unit*pip.puppetMotionScale;
            [view animateAtTime:300+i/60. anchor:(BuddiePoint){x/scale,0}]; BuddiePose after=view.motionPose;
            for(int f=0;f<2;f++) if(before.footLift[f]<1e-8 && after.footLift[f]<1e-8 && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
                NSPoint a=BuddiePuppetSole(view.character,before,f),b=BuddiePuppetSole(view.character,after,f);
                NSCAssert(fabs(oldX+a.x*unit-x-b.x*unit)<1e-7,@"Rendered soles stay planted at every display size and zoom");
            }
        }
    }
    view.character=[pip copy]; view.characterScale=2; view.reduceMotion=YES;
    NSData *(^snapshot)(void)=^NSData *{
        NSBitmapImageRep *rep=[view bitmapImageRepForCachingDisplayInRect:view.bounds]; [view cacheDisplayInRect:view.bounds toBitmapImageRep:rep];
        return [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    };
    [view animateAtTime:400 anchor:(BuddiePoint){0,0}]; NSData *original=snapshot(); NSPoint hotspot=view.hotspot;
    [view animateAtTime:401 anchor:(BuddiePoint){30,0}]; NSCAssert([original isEqual:snapshot()],@"Articulated Reduced Motion is stable");
    view.character.torsoWidth=1.22; view.character.torsoHeight=1.18; view.character.headScale=1.15;
    [view animateAtTime:402 anchor:(BuddiePoint){30,0}]; NSCAssert(![original isEqual:snapshot()],@"Live proportions change actual rendered pixels");
    [view press:YES atTime:402]; [view animateAtTime:402.1 anchor:(BuddiePoint){30,0}];
    NSCAssert(NSEqualPoints(hotspot,view.hotspot),@"Proportions and clicks never change the native hotspot");
    puts("PASS: articulated Cocoa rendering; live proportions; Reduced Motion; six size/zoom combinations preserve planted contacts; exact hotspot");
    view.character=ArticulatedNamed(@"bit"); view.reduceMotion=NO;
    NSCAssert(view.character.pixelArt && view.character.clips[@"headTurn"].frames.count==5,@"Bit has crisp pixels and an authored turn");
    [view animateAtTime:500 anchor:(BuddiePoint){0,0}];
    if(!NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        for(int i=1;i<=7;i++) [view animateAtTime:500+i/60. anchor:(BuddiePoint){-i,0}];
        NSCAssert(view.facingProgress>0 && view.facingProgress<1,@"A turn passes through intermediate authored heads");
        double previous=view.facingProgress; BOOL reversed=NO;
        for(int i=8;i<=23;i++) {
            [view animateAtTime:500+i/60. anchor:(BuddiePoint){-7+(i-7)*2,0}];
            NSCAssert(fabs(view.facingProgress-previous)<.08,@"Interrupted turn cannot snap or restart");
            if(view.facingProgress<previous) reversed=YES;
            previous=view.facingProgress;
        }
        NSCAssert(reversed && view.facingProgress==0,@"Direction reversal returns through the same turn sequence");
    }
    view.reduceMotion=YES; [view animateAtTime:501 anchor:(BuddiePoint){50,0}]; NSData *bitStill=snapshot();
    [view animateAtTime:502 anchor:(BuddiePoint){100,0}]; NSCAssert([bitStill isEqual:snapshot()],@"Pixel Reduced Motion stays still");
    puts("PASS: pixel bot rendering; authored turn traversal and reversal without restart; Reduced Motion");
    BuddieCharacter *bit=ArticulatedNamed(@"bit"); NSMutableSet *torsos=[NSMutableSet new]; NSData *feet=nil;
    for(int i=0;i<5;i++) {
        NSBitmapImageRep *a=TurnImage(bit,i/4.,YES),*b=TurnImage(bit,i/4.,NO);
        NSCAssert([[a representationUsingType:NSBitmapImageFileTypePNG properties:@{}] isEqual:[b representationUsingType:NSBitmapImageFileTypePNG properties:@{}]],@"Changing the desired direction mid-turn cannot mirror any part");
        NSMutableData *chest=[NSMutableData new],*sole=[NSMutableData new];
        for(int y=212;y<280;y++) for(int x=120;x<224;x++) {
            NSUInteger pixel[4]; [a getPixel:pixel atX:x y:y];
            if(y<240 && x>=144 && x<192) [chest appendBytes:pixel length:sizeof(pixel)];
            if(y>=252) [sole appendBytes:pixel length:sizeof(pixel)];
        }
        [torsos addObject:chest]; if(feet) NSCAssert([feet isEqual:sole],@"Turning in place preserves actual boot pixels"); else feet=sole;
    }
    NSCAssert(torsos.count==5,@"Torso visibly passes through five different authored perspectives");
    puts("PASS: five rendered torso directions; direction-independent intermediate poses; stable boot pixels through turns");
    for(int direction=0;direction<5;direction++) {
        BuddiePose neutral={0}; neutral.squash=1; neutral.feet[0].x=-5; neutral.feet[1].x=5;
        NSBitmapImageRep *base=PuppetImage(bit,neutral,direction/4.,NO);
        NSMutableSet *expressions=[NSMutableSet new];
        for(int state=1;state<=5;state++) {
            BuddiePose pose=neutral; pose.face=state<=3 ? state:BuddieFaceIdle;
            double elapsed=state==4 ? 2.325:state==5 ? 2.40:0;
            NSBitmapImageRep *a=PuppetImageAtTime(bit,pose,direction/4.,NO,elapsed,NO);
            NSBitmapImageRep *b=PuppetImageAtTime(bit,pose,direction/4.,YES,elapsed,NO);
            NSData *pixels=[a representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            NSCAssert([pixels isEqual:[b representationUsingType:NSBitmapImageFileTypePNG properties:@{}]],@"Reversing a face mid-turn preserves perspective");
            [expressions addObject:pixels]; NSUInteger changes=0;
            for(int y=0;y<320;y++) for(int x=0;x<320;x++) {
                NSUInteger p[4],q[4]; [base getPixel:p atX:x y:y]; [a getPixel:q atX:x y:y];
                NSCAssert(p[3]==q[3],@"Face reactions preserve actual rendered silhouette and registration");
                if(memcmp(p,q,sizeof(p))) { NSCAssert(x>=76 && x<240 && y>=140 && y<176,@"Only the rendered eyes change"); changes++; }
            }
            NSCAssert(changes>0,@"Each expression is visible in real Cocoa output");
        }
        NSCAssert(expressions.count==5,@"All five expressions remain distinct at every perspective");
    }
    puts("PASS: 25 Cocoa face poses preserve silhouette, body and feet; reverse without mirroring; left endpoints do not wrap");
    BuddieCharacter *legs=[bit copy];
    for(int foot=0;foot<2;foot++) {
    NSString *role=foot ? @"legFar":@"legNear"; legs.clips=@{role:bit.clips[role]};
    for(int x=-12;x<=8;x+=4) for(int lift=0;lift<=8;lift+=2) {
        BuddiePose pose={0}; pose.squash=1; pose.feet[foot].x=x; pose.footLift[foot]=lift;
        NSBitmapImageRep *rep=PuppetImage(legs,pose,0,NO);
        NSUInteger pixel[4]; [rep getPixel:pixel atX:(foot ? 45:37)*4+2 y:59*4+2];
        NSCAssert(pixel[3]>0,@"Pixel calf reaches its hip in actual Cocoa output");
        [rep getPixel:pixel atX:(42+x)*4+2 y:(63-lift)*4+2];
        NSCAssert(pixel[3]>0,@"Pixel calf reaches its boot cuff at every extension/lift");
        // All visible calf pixels must form one connected shape, not isolated
        // islands produced by rotating sparse cutouts.
        NSUInteger w=rep.pixelsWide,h=rep.pixelsHigh,total=0,start=0;
        NSMutableData *mask=[NSMutableData dataWithLength:w*h]; unsigned char *bits=mask.mutableBytes;
        for(NSUInteger y=0;y<h;y++) for(NSUInteger x=0;x<w;x++) {
            [rep getPixel:pixel atX:x y:y]; if(pixel[3]) { bits[y*w+x]=1; start=y*w+x; total++; }
        }
        NSMutableData *queue=[NSMutableData dataWithLength:w*h*sizeof(NSUInteger)]; NSUInteger *q=queue.mutableBytes,read=0,write=0;
        q[write++]=start; bits[start]=0;
        while(read<write) {
            NSUInteger v=q[read++],x=v%w,y=v/w;
            NSInteger offsets[]={-1,1,-(NSInteger)w,(NSInteger)w};
            for(int d=0;d<4;d++) {
                if((d==0 && x==0)||(d==1 && x==w-1)||(d==2 && y==0)||(d==3 && y==h-1)) continue;
                NSUInteger next=v+offsets[d]; if(bits[next]) { bits[next]=0; q[write++]=next; }
            }
        }
        NSCAssert(total==write,@"Every rendered calf pixel stays connected");
    }
    }
    puts("PASS: 60 actual raster calf extensions/lifts connect both hips to boots without detached pixels");
    BuddieCharacter *miso=ArticulatedNamed(@"miso"); NSCAssert(miso,@"Miso is installed in the bundled collection");
    BuddiePose neutral={0}; neutral.squash=1; neutral.feet[0].x=-5; neutral.feet[1].x=5;
    for(int direction=0;direction<5;direction++) {
        NSBitmapImageRep *base=PuppetImage(miso,neutral,direction/4.,NO); NSMutableSet *faces=[NSMutableSet new];
        for(int face=0;face<=3;face++) {
            BuddiePose pose=neutral; pose.face=face;
            NSBitmapImageRep *a=PuppetImage(miso,pose,direction/4.,NO),*b=PuppetImage(miso,pose,direction/4.,YES);
            NSData *data=[a representationUsingType:NSBitmapImageFileTypePNG properties:@{}]; [faces addObject:data];
            NSCAssert([data isEqual:[b representationUsingType:NSBitmapImageFileTypePNG properties:@{}]],@"Miso keeps its current perspective when direction reverses");
            for(int y=0;y<320;y++) for(int x=0;x<320;x++) {
                NSUInteger p[4],q[4]; [base getPixel:p atX:x y:y]; [a getPixel:q atX:x y:y];
                NSCAssert(p[3]==q[3],@"Miso expressions preserve actual silhouette, ears and collar");
                if(memcmp(p,q,sizeof(p))) NSCAssert(x>=100 && x<240 && y>=140 && y<156,@"Only Miso's rendered eyes change");
            }
        }
        NSCAssert(faces.count==4,@"Idle, travel, press and release remain distinct across Miso's five directions");
    }
    NSMutableSet *tails=[NSMutableSet new]; NSBitmapImageRep *tailBase=PuppetImage(miso,neutral,0,NO);
    for(NSNumber *time in @[@0,@1.1,@1.55]) {
        NSBitmapImageRep *rep=PuppetImageAtTime(miso,neutral,0,NO,time.doubleValue,NO);
        [tails addObject:[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}]];
        for(int y=0;y<320;y++) for(int x=0;x<320;x++) {
            NSUInteger p[4],q[4]; [tailBase getPixel:p atX:x y:y]; [rep getPixel:q atX:x y:y];
            if(memcmp(p,q,sizeof(p))) NSCAssert(x>=60 && x<120 && y>=180 && y<236,@"Tail motion leaves head, body and foot contact unchanged");
        }
    }
    NSCAssert(tails.count==3,@"Miso's tail has three visibly distinct positions");
    NSData *stillA=[PuppetImageAtTime(miso,neutral,0,NO,0,YES) representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSData *stillB=[PuppetImageAtTime(miso,neutral,0,NO,2.2,YES) representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSCAssert([stillA isEqual:stillB],@"Reduced Motion holds Miso's tail and eyes still");
    puts("PASS: Miso collection entry; 20 directional Cocoa faces preserve all non-eye pixels; tail moves locally; Reduced Motion stays still");
}

static void TestCollection(void) {
    Delegate *studio=[Delegate new]; studio.collection=[NSMutableArray new];
    studio.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,960,700) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    studio.materialControls=[NSMutableArray new]; studio.materialFields=[NSMutableDictionary new]; studio.materialWells=[NSMutableDictionary new];
    studio.picker=[[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    BuddieCharacter *first=ArticulatedNamed(@"bit"); [studio addCharacterToCollection:first];
    BuddieCharacter *reload=[first copy]; reload.torsoWidth=1.22; [studio addCharacterToCollection:reload];
    NSCAssert(studio.collection.count==1 && studio.picker.numberOfItems==1 && studio.character.torsoWidth==1.22,@"Reimport reloads an identity without breaking selection");
    BuddieCharacter *sameName=[first copy]; sameName.identifier=@"another-bit"; [studio addCharacterToCollection:sameName];
    NSCAssert(studio.collection.count==2 && studio.picker.numberOfItems==2 && studio.picker.indexOfSelectedItem==1,@"Distinct packs with the same title keep separate menu entries");
    [studio addCharacterToCollection:reload];
    NSCAssert(studio.picker.indexOfSelectedItem==0 && [studio.picker.titleOfSelectedItem isEqual:reload.name],@"Repeated imports select the matching identity");
    puts("PASS: repeated imports and duplicate display names preserve collection/menu identity");
    NSTextField *oldField=studio.materialFields[@"shell"]; NSColorWell *oldWell=studio.materialWells[@"shell"];
    oldField.stringValue=@"#EB504D";
    NSNotification *change=[NSNotification notificationWithName:NSControlTextDidChangeNotification object:oldField];
    [studio controlTextDidChange:change]; NSCAssert([ColorHex(studio.character.materialColors[@"shell"]) isEqual:@"#EB504D"],@"Current field edits its own buddy");
    [studio.window makeFirstResponder:oldField];
    [studio addCharacterToCollection:ArticulatedNamed(@"miso")];
    [studio controlTextDidChange:change];
    [studio controlTextDidEndEditing:[NSNotification notificationWithName:NSControlTextDidEndEditingNotification object:oldField]];
    oldWell.color=NSColor.redColor; [studio paint:oldWell];
    NSCAssert([ColorHex(studio.character.materialColors[@"shell"]) isEqual:@"#FCEFD5"],@"Old color callbacks cannot repaint the newly selected buddy");
    NSCAssert([studio.materialFields[@"shell"].stringValue isEqual:@"#FCEFD5"],@"Field, swatch and new character agree after an edited selection");
    puts("PASS: switching buddies commits the old edit without copying its color; obsolete fields and wells cannot repaint the new selection");
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
    TestPuppet(sprite);
    TestCollection();
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
        if(argc>2 && strcmp(argv[1],"--export-puppet")==0) return ExportPuppet([NSString stringWithUTF8String:argv[2]],argc>3 ? [NSString stringWithUTF8String:argv[3]]:@"pip-articulated");
        if(argc>2 && strcmp(argv[1],"--export-turn")==0) return ExportTurn([NSString stringWithUTF8String:argv[2]],argc>3 ? [NSString stringWithUTF8String:argv[3]]:@"bit");
        if(argc>2 && strcmp(argv[1],"--export-gait")==0) return ExportGait([NSString stringWithUTF8String:argv[2]],argc>3 ? [NSString stringWithUTF8String:argv[3]]:@"bit");
        if(argc>2 && strcmp(argv[1],"--export-faces")==0) return ExportFaces([NSString stringWithUTF8String:argv[2]],argc>3 ? [NSString stringWithUTF8String:argv[3]]:@"bit");
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        InstallMenus();
        Delegate *delegate=[Delegate new]; NSApp.delegate=delegate; [NSApp run];
    }
}
