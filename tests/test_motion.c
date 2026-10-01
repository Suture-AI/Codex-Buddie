#include "../Sources/BuddieMotion.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>

static BuddieRig rig={26,14,6};
static double run(double fps) {
    BuddieMotion s; BuddieMotionInit(&s);
    for (int i=0;i<=(int)fps;i++) BuddieMotionUpdate(&s,(BuddiePoint){52*i/fps,0},10+i/fps,rig,false);
    return s.phase;
}
int main(void) {
    assert(fabs(run(30)-run(60))<1e-8 || fabs(fabs(run(30)-run(60))-1)<1e-8);
    assert(fabs(run(60)-run(120))<1e-8 || fabs(fabs(run(60)-run(120))-1)<1e-8);
    BuddieMotion s; BuddieMotionInit(&s);
    BuddieMotionUpdate(&s,(BuddiePoint){0,0},10,rig,false);
    BuddieMotionUpdate(&s,(BuddiePoint){1,0},10.02,rig,false);
    double planted=s.pose.feet[0].x+1;
    for (int i=2;i<8;i++) {
        BuddieMotionUpdate(&s,(BuddiePoint){i,0},10+i*.02,rig,false);
        assert(fabs(s.pose.feet[0].x+i-planted)<1e-9);
    }
    BuddiePoint anchor=s.point;
    BuddieMotionPress(&s,true,10.2);
    BuddieMotionUpdate(&s,anchor,10.22,rig,false);
    assert(s.point.x==anchor.x && s.point.y==anchor.y && s.pose.squash<1);
    BuddieMotionPress(&s,false,10.23);
    BuddieMotionUpdate(&s,anchor,10.27,rig,true);
    assert(s.pose.eyeOpen==1 && s.pose.bodyY==0 && s.pose.lean==0);
    assert(s.pose.feet[0].x==-14 && s.pose.footLift[0]==0);
    BuddieMotionUpdate(&s,(BuddiePoint){2000,2000},11,rig,false);
    assert(s.pose.phase==0 && s.pose.walkWeight==0);
    BuddieJourney j={0};
    BuddieJourneyRetarget(&j,(BuddiePoint){10,20},(BuddiePoint){400,300},0,1);
    BuddiePoint first=BuddieJourneySample(&j,0), last=BuddieJourneySample(&j,2);
    assert(fabs(first.x-10)<1e-9 && fabs(first.y-20)<1e-9);
    assert(fabs(last.x-400)<1e-9 && fabs(last.y-300)<1e-9);
    BuddiePoint mid=BuddieJourneySample(&j,.3), velocity=BuddieJourneyVelocity(&j,.3);
    BuddieJourneyRetarget(&j,mid,(BuddiePoint){-100,400},.3,1);
    BuddiePoint after=BuddieJourneySample(&j,.3), afterVelocity=BuddieJourneyVelocity(&j,.3);
    assert(hypot(after.x-mid.x,after.y-mid.y)<1e-9);
    assert(hypot(afterVelocity.x-velocity.x,afterVelocity.y-velocity.y)<1e-9);
    assert(hypot(BuddieJourneyVelocity(&j,10).x,BuddieJourneyVelocity(&j,10).y)==0);
    puts("PASS: distance-driven gait at 30/60/120 Hz; planted feet; fixed click anchor; reduced motion; teleport reset; curved arrival; C1 retarget continuity");
}
