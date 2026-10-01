#import "BuddieView.h"
#import <objc/runtime.h>

static void Oval(NSRect r, NSColor *c) { [c setFill]; [[NSBezierPath bezierPathWithOvalInRect:r] fill]; }
static void Stroke(NSBezierPath *p, NSColor *c, CGFloat width) {
    p.lineWidth=width; p.lineCapStyle=NSLineCapStyleRound; [c setStroke]; [p stroke];
}
@interface BuddieView () {
    BuddieMotion _motion;
    double _spriteEpoch, _spriteEventAt;
    BOOL _spriteFacingLeft, _spriteReleasing;
}
@property NSTimer *animationTimer;
@property NSString *spriteClipName;
@property NSUInteger spriteFrame;
@end
@implementation BuddieView
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])) {
        _character=[BuddieCharacter new]; _characterScale=1;
        BuddieMotionInit(&_motion);
    } return self;
}
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (NSView *)hitTest:(NSPoint)p { return nil; }
- (void)dealloc { [_animationTimer invalidate]; }
- (void)setCharacter:(BuddieCharacter *)character {
    _character=character ?: [BuddieCharacter new]; BuddieMotionInit(&_motion);
    _spriteFacingLeft=NO; _spriteReleasing=NO; _spriteEpoch=NAN;
    self.spriteClipName=@"idle"; self.spriteFrame=0; self.needsDisplay=YES;
}
- (void)setManualAnimation:(BOOL)value { _manualAnimation=value; [self configureTimer]; }
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [self configureTimer]; }
- (void)configureTimer {
    [self.animationTimer invalidate]; self.animationTimer=nil;
    if(!self.window || self.manualAnimation) return;
    __weak BuddieView *weak=self;
    self.animationTimer=[NSTimer timerWithTimeInterval:1./60 repeats:YES block:^(NSTimer *timer) {
        BuddieView *s=weak; if(!s || !s.window.visible || s.window.miniaturized) return;
        NSPoint anchor=[s.window convertPointToScreen:[s convertPoint:s.hotspot toView:nil]];
        CGFloat scale=s.drawingScale;
        if(scale>0) [s animateAtTime:NSProcessInfo.processInfo.systemUptime anchor:(BuddiePoint){anchor.x/scale,-anchor.y/scale}];
    }];
    [NSRunLoop.mainRunLoop addTimer:self.animationTimer forMode:NSRunLoopCommonModes];
}
- (NSPoint)hotspot { return self.softwareStyle ? NSMakePoint(4,4) : NSMakePoint(NSMidX(self.bounds),NSMidY(self.bounds)); }
- (CGFloat)drawingScale {
    NSPoint h=self.hotspot;
    if(self.character.clips.count) {
        BuddieCharacter *c=self.character; double unit=c.spriteHeight/c.spriteCanvas.height;
        // Reserve both horizontal extents so a mirrored turn cannot resize the pet.
        double side=MAX(c.spriteHotspot.x,c.spriteCanvas.width-c.spriteHotspot.x)*unit;
        double top=c.spriteHotspot.y*unit, bottom=(c.spriteCanvas.height-c.spriteHotspot.y)*unit;
        double scale=MIN(self.characterScale,MIN(h.x/side,(NSWidth(self.bounds)-h.x)/side));
        if(top>0) scale=MIN(scale,h.y/top);
        if(bottom>0) scale=MIN(scale,(NSHeight(self.bounds)-h.y)/bottom);
        return MAX(0,scale);
    }
    return MAX(0,MIN(self.characterScale,MIN((NSWidth(self.bounds)-h.x)/64.,(NSHeight(self.bounds)-h.y)/66.)));
}
- (void)animateAtTime:(double)time anchor:(BuddiePoint)anchor {
    BuddieCharacter *c=self.character;
    BOOL reduced=self.reduceMotion || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
    BuddieMotionUpdate(&_motion,anchor,time,(BuddieRig){c.stride,c.footSpacing,c.footLift},reduced);
    if(c.clips.count && isfinite(time)) {
        if(!isfinite(_spriteEpoch) || time<_spriteEpoch) _spriteEpoch=time;
        if(_motion.moving && fabs(_motion.velocity.x)>3) _spriteFacingLeft=_motion.velocity.x<0;
        NSString *name=@"idle"; double elapsed=time-_spriteEpoch; BOOL loop=YES;
        if(_motion.pressed && c.clips[@"press"]) { name=@"press"; elapsed=time-_spriteEventAt; loop=NO; }
        else if(_spriteReleasing && c.clips[@"release"] && time-_spriteEventAt<c.clips[@"release"].duration) { name=@"release"; elapsed=time-_spriteEventAt; loop=NO; }
        else if(!reduced && _motion.pose.walkWeight>.1) {
            NSString *walk=_spriteFacingLeft && c.clips[@"walkLeft"] ? @"walkLeft":@"walkRight";
            if(c.clips[walk]) { name=walk; elapsed=_motion.pose.phase*c.clips[walk].duration; }
        }
        if(![name isEqual:self.spriteClipName] && [name isEqual:@"idle"]) { _spriteEpoch=time; elapsed=0; }
        self.spriteClipName=name;
        self.spriteFrame=reduced ? 0:[c.clips[name] frameIndexAtTime:elapsed loop:loop];
    }
    self.needsDisplay=YES;
}
- (void)press:(BOOL)down atTime:(double)time {
    if(_motion.pressed!=down) { _spriteEventAt=time; _spriteReleasing=!down; }
    BuddieMotionPress(&_motion,down,time);
}
- (void)drawSpriteWithScale:(CGFloat)scale {
    BuddieCharacter *c=self.character;
    BuddieSpriteClip *clip=c.clips[self.spriteClipName] ?: c.clips[@"idle"];
    if(!clip.frames.count) return;
    BOOL mirror=_spriteFacingLeft && [self.spriteClipName isEqual:@"walkRight"] && c.mirrorWalk;
    double unit=scale*c.spriteHeight/c.spriteCanvas.height;
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext.imageInterpolation=NSImageInterpolationHigh;
    NSAffineTransform *t=[NSAffineTransform transform];
    [t translateXBy:self.hotspot.x yBy:self.hotspot.y];
    // A small fallback press response, around the exact hotspot, when no clip exists.
    double press=c.clips[@"press"] ? 1:.75+.25*MIN(1,_motion.pose.squash);
    [t scaleXBy:(mirror ? -unit:unit)*press yBy:unit*press]; [t concat];
    NSRect rect=NSMakeRect(-c.spriteHotspot.x,-c.spriteHotspot.y,c.spriteCanvas.width,c.spriteCanvas.height);
    [clip.frames[MIN(self.spriteFrame,clip.frames.count-1)] drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    [NSGraphicsContext restoreGraphicsState];
}
- (void)drawRect:(NSRect)dirty {
    CGFloat scale=self.drawingScale; if(scale<=0) return;
    if(self.character.clips.count) { [self drawSpriteWithScale:scale]; return; }
    BuddieCharacter *c=self.character; BuddiePose p=_motion.pose;
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext.imageInterpolation=NSImageInterpolationHigh;
    NSAffineTransform *t=[NSAffineTransform transform];
    [t translateXBy:self.hotspot.x-8*scale yBy:self.hotspot.y-8*scale]; [t scaleBy:scale]; [t concat];
    // This marker and the actual window never inherit gait, squash or lean.
    CGFloat top=54-c.bodySize.height;
    NSBezierPath *tether=[NSBezierPath bezierPath]; [tether moveToPoint:NSMakePoint(8,8)];
    [tether curveToPoint:NSMakePoint(28,top+8+p.bodyY) controlPoint1:NSMakePoint(9,top+2) controlPoint2:NSMakePoint(19,top+4)];
    Stroke(tether,[c.inkColor colorWithAlphaComponent:.72],1.5);
    Oval(NSMakeRect(5.6,5.6,4.8,4.8),c.inkColor); Oval(NSMakeRect(6.8,6.8,2.4,2.4),c.bodyColor);
    // Feet are world-planted. Do not include them in the body's bob transform.
    for(int i=0;i<2;i++) {
        double x=34+p.feet[i].x, y=55+p.feet[i].y;
        if(!_motion.initialized) x=34+(i ? c.footSpacing:-c.footSpacing);
        NSBezierPath *leg=[NSBezierPath bezierPath];
        [leg moveToPoint:NSMakePoint(34+(i?1:-1)*c.footSpacing*.65,51+p.bodyY)];
        [leg curveToPoint:NSMakePoint(x,y-p.footLift[i]) controlPoint1:NSMakePoint(x,52+p.bodyY) controlPoint2:NSMakePoint(x,y-2-p.footLift[i])];
        Stroke(leg,c.inkColor,2.2);
        Oval(NSMakeRect(x-c.footSize*.55,y+1,c.footSize*1.1,2),[c.inkColor colorWithAlphaComponent:.10*(1-p.footLift[i]/12)]);
        NSRect foot=NSMakeRect(x-c.footSize/2,y-2.5-p.footLift[i],c.footSize,5);
        if(c.footImage) [c.footImage drawInRect:foot fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
        else {
            Oval(foot,c.inkColor);
            Oval(NSMakeRect(foot.origin.x+1,foot.origin.y+.5,foot.size.width-2,1.5),[NSColor.whiteColor colorWithAlphaComponent:.16]);
        }
    }
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *bodyTransform=[NSAffineTransform transform];
    [bodyTransform translateXBy:34 yBy:54+p.bodyY]; [bodyTransform rotateByRadians:p.lean];
    [bodyTransform scaleXBy:1/sqrt(MAX(.5,p.squash)) yBy:p.squash]; [bodyTransform translateXBy:-34 yBy:-54]; [bodyTransform concat];
    NSRect body=NSMakeRect(34-c.bodySize.width/2,top,c.bodySize.width,c.bodySize.height);
    if(c.bodyImage) [c.bodyImage drawInRect:body fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    else {
        NSBezierPath *shape=[NSBezierPath bezierPathWithRoundedRect:body xRadius:c.cornerRadius yRadius:c.cornerRadius];
        NSColor *light=[c.bodyColor blendedColorWithFraction:.2 ofColor:NSColor.whiteColor];
        NSColor *dark=[c.bodyColor blendedColorWithFraction:.1 ofColor:c.inkColor];
        [[[NSGradient alloc] initWithStartingColor:light endingColor:dark] drawInBezierPath:shape angle:90];
        Stroke(shape,[c.inkColor colorWithAlphaComponent:.65],1.2);
    }
    CGFloat faceY=38+c.faceY;
    for(int i=0;i<2;i++) {
        CGFloat x=34+(i ? c.eyeSpacing/2:-c.eyeSpacing/2)+p.gazeX;
        CGFloat height=MAX(.65,c.eyeSize*1.25*p.eyeOpen);
        Oval(NSMakeRect(x-c.eyeSize/2,faceY+p.gazeY-height/2,c.eyeSize,height),c.inkColor);
        if(p.eyeOpen>.55) Oval(NSMakeRect(x-c.eyeSize*.17,faceY+p.gazeY-height*.35,c.eyeSize*.23,height*.25),[NSColor.whiteColor colorWithAlphaComponent:.85]);
        Oval(NSMakeRect(x-3.5,faceY+5,7,3),[c.accentColor colorWithAlphaComponent:.35]);
    }
    NSBezierPath *smile=[NSBezierPath bezierPath];
    [smile moveToPoint:NSMakePoint(31,faceY+6)];
    [smile curveToPoint:NSMakePoint(37,faceY+6) controlPoint1:NSMakePoint(32,faceY+6+4*p.smile) controlPoint2:NSMakePoint(36,faceY+6+4*p.smile)];
    Stroke(smile,c.inkColor,1.25);
    [NSGraphicsContext restoreGraphicsState];
    [NSGraphicsContext restoreGraphicsState];
}
@end

static const char originalKey, replacementKey;

BOOL BuddieIsCursorWindow(NSWindow *window) {
    NSString *name = NSStringFromClass(window.class);
    return [name isEqualToString:@"ComputerUse.ComputerUseCursor.Window"] ||
           [name isEqualToString:@"_TtCC11ComputerUse17ComputerUseCursor6Window"];
}

BOOL BuddieReplaceContent(NSWindow *window, NSView *original) {
    if (!BuddieIsCursorWindow(window) || !original || [original isKindOfClass:BuddieView.class]) return NO;
    NSString *name = NSStringFromClass(original.class);
    BOOL software = [original isKindOfClass:NSImageView.class];
    BOOL fog = [name containsString:@"NSHostingView"] && [name containsString:@"CursorView"];
    if (!software && !fog) {
        fprintf(stderr, "[Buddie] Unsupported cursor content; leaving original renderer intact.\n");
        return NO;
    }
    BuddieView *replacement = [[BuddieView alloc] initWithFrame:original.frame];
    replacement.softwareStyle = software;
    replacement.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [replacement setAccessibilityElement:NO];
    // Keep the original view alive: native Style retains/queries it for geometry.
    // It is detached, not layered under the new character.
    objc_setAssociatedObject(window, &originalKey, original, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(window, &replacementKey, replacement, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    window.contentView = replacement;
    fprintf(stderr, "[Buddie] Replaced native %s cursor artwork.\n", software ? "software" : "fog");
    return YES;
}
