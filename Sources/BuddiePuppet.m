#import "BuddiePuppet.h"

static NSPoint PartPoint(NSArray *pair) { return NSMakePoint([pair[0] doubleValue],[pair[1] doubleValue]); }
static NSPoint Attachment(NSPoint anchor, NSPoint origin, double width, double height, double lean, double bob) {
    double x=(anchor.x-origin.x)*width,y=(anchor.y-origin.y)*height;
    return NSMakePoint(origin.x+x*cos(lean)-y*sin(lean),origin.y+bob+x*sin(lean)+y*cos(lean));
}
static void Part(BuddieCharacter *c, NSString *role, NSPoint target, double angle, double sx, double sy, double elapsed, BOOL reduced) {
    NSDictionary *part=c.puppetParts[role]; BuddieSpriteClip *clip=c.clips[role];
    NSImage *image=[c imageForClip:role frame:reduced ? 0:[clip frameIndexAtTime:elapsed loop:YES]];
    NSPoint pivot=PartPoint(part[@"pivot"]); double scale=[part[@"scale"] doubleValue];
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *t=[NSAffineTransform transform];
    [t translateXBy:target.x yBy:target.y]; [t rotateByRadians:angle]; [t scaleXBy:scale*sx yBy:scale*sy];
    [t translateXBy:-pivot.x yBy:-pivot.y]; [t concat];
    [image drawInRect:(NSRect){NSZeroPoint,image.size} fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    [NSGraphicsContext restoreGraphicsState];
}
NSPoint BuddiePuppetSole(BuddieCharacter *c, BuddiePose p, NSUInteger foot) {
    NSPoint base=PartPoint(c.puppetParts[foot ? @"bootFar":@"bootNear"][@"anchor"]);
    return NSMakePoint(base.x+p.feet[foot].x*c.puppetMotionScale,base.y+(p.feet[foot].y-p.footLift[foot])*c.puppetMotionScale);
}
void BuddieDrawPuppet(BuddieCharacter *c, BuddiePose p, BOOL facingLeft, double elapsed, BOOL reduced) {
    double facing=facingLeft && c.mirrorWalk ? -1:1;
    double lean=p.lean*.5*facing, bob=p.bodyY*c.puppetMotionScale;
    double squash=.75+.25*p.squash, width=c.torsoWidth/sqrt(MAX(.5,squash)),height=c.torsoHeight*squash;
    NSPoint origin=PartPoint(c.puppetParts[@"body"][@"anchor"]);
    NSPoint (^attach)(NSString *)=^NSPoint(NSString *role) {
        return Attachment(PartPoint(c.puppetParts[role][@"anchor"]),origin,width,height,lean,bob);
    };
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *mirror=[NSAffineTransform transform];
    [mirror translateXBy:c.spriteHotspot.x yBy:0]; [mirror scaleXBy:facing yBy:1]; [mirror translateXBy:-c.spriteHotspot.x yBy:0]; [mirror concat];
    Part(c,@"tail",attach(@"tail"),lean+sin(p.phase*2*M_PI)*.04*p.walkWeight,1,1,elapsed,reduced);
    // World-space feet counter the artwork's mirror. The contacts cannot inherit
    // torso stretch, bob, lean or click squash.
    for(int i=1;i>=0;i--) {
        NSString *leg=i ? @"legFar":@"legNear",*boot=i ? @"bootFar":@"bootNear";
        NSPoint foot=BuddiePuppetSole(c,p,i); foot.x=c.spriteHotspot.x+facing*(foot.x-c.spriteHotspot.x);
        NSPoint hip=attach(leg),cuff=PartPoint(c.puppetParts[leg][@"cuff"]);
        hip.x=c.spriteHotspot.x+facing*(hip.x-c.spriteHotspot.x);
        double dx=foot.x+cuff.x-hip.x,dy=foot.y+cuff.y-hip.y;
        double stretch=MAX(.5,hypot(dx,dy)/[c.puppetParts[leg][@"span"] doubleValue]);
        Part(c,leg,hip,-atan2(dx,dy),1,stretch,elapsed,reduced);
        Part(c,boot,foot,0,1,1,elapsed,reduced);
    }
    double swing=sin(p.phase*2*M_PI)*.18*p.walkWeight;
    Part(c,@"pawFar",attach(@"pawFar"),lean-swing,1,1,elapsed,reduced);
    Part(c,@"body",NSMakePoint(origin.x,origin.y+bob),lean,width,height,elapsed,reduced);
    Part(c,@"pawNear",attach(@"pawNear"),lean+swing,1,1,elapsed,reduced);
    Part(c,@"head",attach(@"head"),lean*.6,c.headScale,c.headScale,elapsed,reduced);
    [NSGraphicsContext restoreGraphicsState];
}
