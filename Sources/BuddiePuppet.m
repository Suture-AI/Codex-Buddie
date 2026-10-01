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
    if(c.pixelArt) {
        if([role hasPrefix:@"paw"]) target.y+=round(sin(angle)*5);
        target.x=round(target.x); target.y=round(target.y);
        if(![role hasPrefix:@"leg"]) angle=0;
    }
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
void BuddieDrawPuppet(BuddieCharacter *c, BuddiePose p, BOOL facingLeft, double turnProgress, double elapsed, BOOL reduced) {
    BOOL directionalBody=c.clips[@"bodyTurn"] && c.clips[@"bodyLeft"];
    // Authored torso perspective changes while physical limbs keep their
    // screen-side attachments and lighting. Contacts never swap on reversal.
    double facing=!directionalBody && facingLeft && c.mirrorWalk ? -1:1;
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
    BOOL inTurn=turnProgress>1e-8 && turnProgress<1-1e-8;
    NSString *body=directionalBody ? (inTurn ? @"bodyTurn":turnProgress>=.5 ? @"bodyLeft":@"body"):@"body";
    Part(c,body,NSMakePoint(origin.x,origin.y+bob),lean,width,height,[body isEqual:@"bodyTurn"] ? turnProgress*c.clips[body].duration:elapsed,reduced);
    Part(c,@"pawNear",attach(@"pawNear"),lean+swing,1,1,elapsed,reduced);
    BOOL turning=c.clips[@"headTurn"] && inTurn;
    BOOL leftHead=c.clips[@"headTurn"] ? turnProgress>=.5:facingLeft;
    NSString *head=turning ? @"headTurn":leftHead && c.clips[@"headLeft"] ? @"headLeft":@"head";
    NSPoint neck=attach(head);
    if(c.clips[@"headTurn"]) {
        double worldX=c.spriteHotspot.x+(neck.x-c.spriteHotspot.x)*(1-2*turnProgress);
        neck.x=c.spriteHotspot.x+facing*(worldX-c.spriteHotspot.x);
    }
    if(c.pixelArt) { neck.x=round(neck.x); neck.y=round(neck.y); }
    [NSGraphicsContext saveGraphicsState];
    if(![head isEqual:@"head"]) {
        // Authored directional heads already carry their own perspective.
        NSAffineTransform *counter=[NSAffineTransform transform];
        [counter translateXBy:neck.x yBy:0]; [counter scaleXBy:facing yBy:1]; [counter translateXBy:-neck.x yBy:0]; [counter concat];
    }
    Part(c,head,neck,lean*.6,c.headScale,c.headScale,turning ? turnProgress*c.clips[@"headTurn"].duration:elapsed,reduced);
    [NSGraphicsContext restoreGraphicsState];
    [NSGraphicsContext restoreGraphicsState];
}
