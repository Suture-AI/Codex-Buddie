#include "../Sources/BuddieMotion.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>

static BuddieRig rig={26,14,6};
static double run(double fps,double speed) {
    BuddieMotion s; BuddieMotionInit(&s);
    for (int i=0;i<=(int)fps;i++) BuddieMotionUpdate(&s,(BuddiePoint){speed*i/fps,0},10+i/fps,rig,false);
    return s.phase;
}
static void stopAndResume(double fps,int offset) {
    BuddieMotion m; BuddieMotionInit(&m);
    double dt=1/fps,time=20,x=0;
    for(int i=0;i<60+offset;i++) {
        x+=23*dt; time+=dt;
        BuddieMotionUpdate(&m,(BuddiePoint){x,0},time,rig,false);
    }
    double phase=m.phase;
    bool lifted=false;
    for(int i=0;i<(int)fps;i++) {
        BuddiePoint previous[2]; double lift[2];
        for(int f=0;f<2;f++) { previous[f]=(BuddiePoint){m.point.x+m.pose.feet[f].x,m.point.y+m.pose.feet[f].y}; lift[f]=m.pose.footLift[f]; }
        time+=dt; BuddieMotionUpdate(&m,(BuddiePoint){x,0},time,rig,false);
        assert(m.phase==phase && m.point.x==x); // Settling cannot move the pointer or run a walk loop.
        assert(!(m.settling[0] && m.settling[1]));
        for(int f=0;f<2;f++) {
            if(lift[f]<1e-8 && m.pose.footLift[f]<1e-8)
                assert(hypot(m.point.x+m.pose.feet[f].x-previous[f].x,m.point.y+m.pose.feet[f].y-previous[f].y)<1e-7);
            if(m.settling[f] && m.pose.footLift[f]>.1) lifted=true;
        }
    }
    assert(lifted);
    for(int f=0;f<2;f++) {
        double restError=fabs(m.pose.feet[f].x-(f?1:-1)*rig.footSpacing);
        if(restError>.05) fprintf(stderr,"Rest error %.9f at %.0f Hz, offset %d, foot %d\n",restError,fps,offset,f);
        assert(restError<=.05); assert(m.pose.footLift[f]==0);
    }
    // Interrupt a subsequent landing by reversing. Check finite, bounded foot
    // displacement and exact preservation of the caller's pointer coordinates.
    for(int i=0;i<(int)(fps*.36);i++) { x+=23*dt; time+=dt; BuddieMotionUpdate(&m,(BuddiePoint){x,0},time,rig,false); }
    for(int i=0;i<(int)(fps*.14);i++) { time+=dt; BuddieMotionUpdate(&m,(BuddiePoint){x,0},time,rig,false); }
    for(int i=0;i<(int)fps;i++) {
        double old[2]; for(int f=0;f<2;f++) old[f]=m.point.x+m.pose.feet[f].x;
        x-=23*dt; time+=dt; BuddieMotionUpdate(&m,(BuddiePoint){x,0},time,rig,false);
        assert(m.point.x==x);
        for(int f=0;f<2;f++) { double world=m.point.x+m.pose.feet[f].x; assert(isfinite(world));
            if(fabs(world-old[f])>=5) fprintf(stderr,"Resume delta %.4f, %.0f Hz offset %d frame %d foot %d phase %.3f swingDistance %.3f settling %d\n",world-old[f],fps,offset,i,f,m.phase,m.swingDistance[f],m.settling[f]);
            assert(fabs(world-old[f])<5); }
    }
    time+=dt; BuddieMotionUpdate(&m,(BuddiePoint){x,0},time,rig,true);
    assert(!m.settling[0] && !m.settling[1] && m.pose.footLift[0]==0 && m.pose.footLift[1]==0);
}
static void fastTravel(double fps,double speed) {
    BuddieMotion s; BuddieMotionInit(&s);
    BuddieRig small={16,6,3}; double x=0,y=0,time=40,dt=1/fps;
    BuddieMotionUpdate(&s,(BuddiePoint){x,y},time,small,false);
    for(int i=0;i<(int)(fps*2);i++) {
        x+=(i<fps ? 1:-1)*speed*dt; y+=speed*.15*dt; time+=dt;
        BuddieMotionUpdate(&s,(BuddiePoint){x,y},time,small,false);
        assert(s.airborne && s.point.x==x && s.point.y==y);
        for(int f=0;f<2;f++) {
            assert(!s.stance[f] && s.pose.footLift[f]>0);
            assert(hypot(s.pose.feet[f].x-(f?1:-1)*small.footSpacing,s.pose.feet[f].y)<small.stride*.19);
        }
    }
    for(int i=0;i<(int)fps;i++) {
        time+=dt; BuddieMotionUpdate(&s,(BuddiePoint){x,y},time,small,false);
        assert(!s.airborne && s.point.x==x && s.point.y==y);
    }
    for(int f=0;f<2;f++) {
        assert(s.pose.footLift[f]==0 && !s.settling[f]);
        assert(fabs(s.pose.feet[f].x-(f?1:-1)*small.footSpacing)<1e-8);
    }
    time+=dt; x+=speed*dt; BuddieMotionUpdate(&s,(BuddiePoint){x,y},time,small,true);
    assert(!s.airborne && s.pose.footLift[0]==0 && s.pose.bodyY==0);
}
int main(void) {
    for(int rate=30;rate<=120;rate*=2) for(int speed=100;speed<=1600;speed*=2) fastTravel(rate,speed);
    for(int rate=30;rate<=120;rate*=2) for(int offset=0;offset<20;offset++) stopAndResume(rate,offset);
    rig=(BuddieRig){16,6,3};
    for(int rate=30;rate<=120;rate*=2) for(int offset=0;offset<20;offset++) stopAndResume(rate,offset);
    rig=(BuddieRig){26,14,6};
    assert(fabs(run(30,52)-run(60,52))<1e-8 || fabs(fabs(run(30,52)-run(60,52))-1)<1e-8);
    assert(fabs(run(60,52)-run(120,52))<1e-8 || fabs(fabs(run(60,52)-run(120,52))-1)<1e-8);
    assert(fabs(run(30,1.2)-run(60,1.2))<1e-8 && fabs(run(60,1.2)-run(120,1.2))<1e-8);
    assert(run(120,1.2)>.04); // Slow travel must not disappear at high refresh rates.
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
    assert(!s.settling[0] && !s.settling[1] && !s.swinging[0] && !s.swinging[1]);
    assert(s.pose.footLift[0]==0 && s.pose.footLift[1]==0);
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
    puts("PASS: distance-driven gait at 30/60/120 Hz; planted feet; lifted sequential settling across stop phases; interrupted landing/reversal; bounded fast travel and landing; fixed click anchor; reduced motion; teleport reset; curved arrival; C1 retarget continuity");
}
