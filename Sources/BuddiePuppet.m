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
static void PixelLeg(BuddieCharacter *c,NSString *role,NSPoint hip,NSPoint cuff,double bendDirection,double elapsed,BOOL reduced) {
    NSDictionary *part=c.puppetParts[role]; BuddieSpriteClip *clip=c.clips[role];
    NSImage *image=[c imageForClip:role frame:reduced ? 0:[clip frameIndexAtTime:elapsed loop:YES]];
    NSPoint pivot=PartPoint(part[@"pivot"]); double scale=[part[@"scale"] doubleValue];
    double span=MIN(image.size.height-pivot.y,MAX(1,[part[@"span"] doubleValue]/scale));
    double dx=cuff.x-hip.x,dy=cuff.y-hip.y,distance=hypot(dx,dy);
    double length=[part[@"span"] doubleValue]*c.legLength;
    double bend=.5*sqrt(MAX(0,length*length-distance*distance))*bendDirection;
    NSPoint knee=NSMakePoint((hip.x+cuff.x)*.5+(distance>1e-8 ? dy/distance:1)*bend,
                            (hip.y+cuff.y)*.5-(distance>1e-8 ? dx/distance:0)*bend);
    NSPoint joints[]={hip,knee,cuff};
    // Two bones fold around a knee when the foot lifts. Sample both halves of
    // the original texture on the pixel grid, keeping the hip and cuff joined.
    for(int bone=0;bone<2;bone++) {
    NSPoint a=NSMakePoint(round(joints[bone].x),round(joints[bone].y)),b=NSMakePoint(round(joints[bone+1].x),round(joints[bone+1].y));
    int steps=MAX(1,(int)ceil(MAX(fabs(b.x-a.x),fabs(b.y-a.y))));
    for(int i=0;i<=steps;i++) {
        double t=(double)i/steps,u=(bone+t)*.5;
        NSPoint p=NSMakePoint(round(a.x+(b.x-a.x)*t),round(a.y+(b.y-a.y)*t));
        // NSImage source rectangles use bottom-left coordinates even when
        // the destination context is flipped for the top-left puppet canvas.
        NSRect source=NSMakeRect(0,image.size.height-1-floor(pivot.y+u*(span-1)),image.size.width,1);
        NSRect target=NSMakeRect(p.x-round(pivot.x*scale),p.y,image.size.width*scale,MAX(1,round(scale)));
        [image drawInRect:target fromRect:source operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    }
    }
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
    double restLeg=([c.puppetParts[@"legNear"][@"span"] doubleValue]+[c.puppetParts[@"legFar"][@"span"] doubleValue])*.5;
    // Lengthen the legs by raising the complete upper body, keeping the neck
    // registration and the world-space soles unchanged.
    double lean=p.lean*.5*facing, bob=p.bodyY*c.puppetMotionScale-restLeg*(c.legLength-1);
    double squash=.75+.25*p.squash, width=c.torsoWidth/sqrt(MAX(.5,squash)),height=c.torsoHeight*squash;
    NSPoint origin=PartPoint(c.puppetParts[@"body"][@"anchor"]);
    NSPoint (^attach)(NSString *)=^NSPoint(NSString *role) {
        return Attachment(PartPoint(c.puppetParts[role][@"anchor"]),origin,width,height,lean,bob);
    };
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *mirror=[NSAffineTransform transform];
    [mirror translateXBy:c.spriteHotspot.x yBy:0]; [mirror scaleXBy:facing yBy:1]; [mirror translateXBy:-c.spriteHotspot.x yBy:0]; [mirror concat];
    BOOL inTurn=turnProgress>1e-8 && turnProgress<1-1e-8;
    BOOL directionalTail=c.clips[@"tailTurn"] && c.clips[@"tailLeft"];
    NSString *tail=directionalTail ? (inTurn ? @"tailTurn":turnProgress>=.5 ? @"tailLeft":@"tail"):@"tail";
    NSPoint tailRoot=PartPoint(c.puppetParts[@"tail"][@"anchor"]);
    // Move the attachment around the back of the hips. Authored perspective
    // changes the curl while the tail remains behind the torso in every view.
    if(directionalTail) tailRoot.x=origin.x+(tailRoot.x-origin.x)*(1-2*turnProgress);
    tailRoot=Attachment(tailRoot,origin,width,height,lean,bob);
    double tailTime=directionalTail && inTurn ? MIN(1-1e-9,turnProgress)*c.clips[tail].duration:elapsed;
    Part(c,tail,tailRoot,lean+sin(p.phase*2*M_PI)*.04*p.walkWeight,1,1,tailTime,directionalTail && inTurn ? NO:reduced);
    // World-space feet counter the artwork's mirror. The contacts cannot inherit
    // torso stretch, bob, lean or click squash.
    for(int i=1;i>=0;i--) {
        NSString *leg=i ? @"legFar":@"legNear",*boot=i ? @"bootFar":@"bootNear";
        NSPoint foot=BuddiePuppetSole(c,p,i); foot.x=c.spriteHotspot.x+facing*(foot.x-c.spriteHotspot.x);
        NSPoint hip=attach(leg),cuff=PartPoint(c.puppetParts[leg][@"cuff"]);
        cuff.x*=c.bootWidth;
        hip.x=c.spriteHotspot.x+facing*(hip.x-c.spriteHotspot.x);
        double dx=foot.x+cuff.x-hip.x,dy=foot.y+cuff.y-hip.y;
        double stretch=MAX(.5,hypot(dx,dy)/[c.puppetParts[leg][@"span"] doubleValue]);
        if(c.pixelArt) PixelLeg(c,leg,hip,NSMakePoint(foot.x+cuff.x,foot.y+cuff.y),1-2*turnProgress,elapsed,reduced);
        else Part(c,leg,hip,-atan2(dx,dy),1,stretch,elapsed,reduced);
        Part(c,boot,foot,0,c.bootWidth,1,elapsed,reduced);
    }
    double swing=sin(p.phase*2*M_PI)*.18*p.walkWeight;
    Part(c,@"pawFar",attach(@"pawFar"),lean-swing,1,c.armLength,elapsed,reduced);
    NSString *body=directionalBody ? (inTurn ? @"bodyTurn":turnProgress>=.5 ? @"bodyLeft":@"body"):@"body";
    Part(c,body,NSMakePoint(origin.x,origin.y+bob),lean,width,height,[body isEqual:@"bodyTurn"] ? turnProgress*c.clips[body].duration:elapsed,reduced);
    Part(c,@"pawNear",attach(@"pawNear"),lean+swing,1,c.armLength,elapsed,reduced);
    BOOL turning=c.clips[@"headTurn"] && inTurn;
    BOOL leftHead=c.clips[@"headTurn"] ? turnProgress>=.5:facingLeft;
    NSString *head=turning ? @"headTurn":leftHead && c.clips[@"headLeft"] ? @"headLeft":@"head";
    NSString *expression=p.face==BuddieFacePress ? @"headPress":p.face==BuddieFaceRelease ? @"headRelease":p.face==BuddieFaceFocus ? @"headFocus":nil;
    if(!expression && !reduced) {
        NSUInteger blink=[c.clips[@"head"] frameIndexAtTime:elapsed loop:YES];
        if(blink==1 || blink==3) expression=@"headHalf";
        else if(blink==2) expression=@"headClosed";
    }
    BOOL expressionHead=expression && c.clips[expression];
    if(expressionHead) head=expression;
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
    // Clamp the normalized endpoint below duration: Part loops ordinary clips,
    // but the last left-facing pose must never wrap to the right-facing pose.
    double headTime=turning || expressionHead ? MIN(1-1e-9,turnProgress)*c.clips[head].duration:elapsed;
    Part(c,head,neck,lean*.6,c.headScale,c.headScale,headTime,expressionHead ? NO:reduced);
    [NSGraphicsContext restoreGraphicsState];
    [NSGraphicsContext restoreGraphicsState];
}
