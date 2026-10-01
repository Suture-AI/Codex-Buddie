#include "BuddieMotion.h"
#include <math.h>
#include <string.h>

static const double pi = 3.14159265358979323846;
static double clamp(double value, double low, double high) { return fmax(low, fmin(high, value)); }
static double mix(double a, double b, double t) { return a + (b-a)*t; }
static double ease(double t) { return t*t*(3-2*t); }
static BuddiePoint add(BuddiePoint a, BuddiePoint b) { return (BuddiePoint){a.x+b.x,a.y+b.y}; }
static BuddiePoint sub(BuddiePoint a, BuddiePoint b) { return (BuddiePoint){a.x-b.x,a.y-b.y}; }
static BuddiePoint mul(BuddiePoint a, double s) { return (BuddiePoint){a.x*s,a.y*s}; }
static double length(BuddiePoint a) { return hypot(a.x,a.y); }
static BuddiePoint lerp(BuddiePoint a, BuddiePoint b, double t) { return add(a,mul(sub(b,a),t)); }

void BuddieMotionInit(BuddieMotion *s) {
    memset(s,0,sizeof(*s));
    s->direction=(BuddiePoint){1,0}; s->releasedAt=-1000;
    s->pose.eyeOpen=1; s->pose.squash=1;
}

void BuddieMotionPress(BuddieMotion *s, bool down, double time) {
    if (s->pressed && !down) s->releasedAt=time;
    s->pressed=down;
}

void BuddieMotionUpdate(BuddieMotion *s, BuddiePoint anchor, double time, BuddieRig rig, bool reduced) {
    if (!isfinite(time) || !isfinite(anchor.x) || !isfinite(anchor.y)) return;
    rig.stride=clamp(rig.stride,8,80);
    rig.footSpacing=clamp(rig.footSpacing,2,40);
    rig.footLift=clamp(rig.footLift,0,20);
    double dt=s->initialized ? time-s->lastTime : 0;
    if (s->initialized && dt<=0) return;
    BuddiePoint delta=sub(anchor,s->point);
    double distance=length(delta);
    bool discontinuity=!s->initialized || dt>.25 || distance>180;
    if (discontinuity) {
        s->phase=0; s->speed=0; s->walkWeight=0; s->moving=false;
        for (int i=0;i<2;i++) {
            s->foot[i]=(BuddiePoint){(i?1:-1)*rig.footSpacing,0};
            s->planted[i]=add(anchor,s->foot[i]); s->swingStart[i]=s->planted[i]; s->stance[i]=true;
        }
        delta=(BuddiePoint){0,0}; distance=0; dt=1./60.;
        s->velocity=(BuddiePoint){0,0};
    }
    double rate=1-exp(-dt/.075);
    BuddiePoint raw=mul(delta,1/fmax(dt,.0001));
    s->velocity=lerp(s->velocity,raw,rate);
    s->speed=mix(s->speed,length(raw),rate);
    bool traveling=distance>.015;
    if (traveling) {
        s->lastMotion=time;
        s->direction=mul(delta,1/distance);
        s->phase=fmod(s->phase+distance/rig.stride,1);
    }
    bool walking=traveling || (s->moving && time-s->lastMotion<.08);
    s->walkWeight=mix(s->walkWeight,walking?1:0,1-exp(-dt/(walking?.06:.14)));
    for (int i=0;i<2;i++) {
        BuddiePoint base={(i?1:-1)*rig.footSpacing,0};
        double phase=fmod(s->phase+i*.5,1);
        bool stance=phase<.62;
        if (walking && !reduced) {
            if (!s->moving || (stance && !s->stance[i])) s->planted[i]=add(anchor,s->foot[i]);
            if (!stance && s->stance[i]) s->swingStart[i]=add(anchor,s->foot[i]);
            if (stance) {
                // World-space contact remains fixed while the body advances.
                s->foot[i]=sub(s->planted[i],anchor);
                s->pose.footLift[i]=0;
            } else {
                double u=(phase-.62)/.38;
                BuddiePoint landing=add(add(anchor,base),mul(s->direction,rig.stride*.31));
                s->foot[i]=sub(lerp(s->swingStart[i],landing,ease(u)),anchor);
                s->pose.footLift[i]=sin(pi*u)*rig.footLift;
            }
        } else {
            s->foot[i]=lerp(s->foot[i],base,reduced?1:1-exp(-dt/.1));
            s->pose.footLift[i]=mix(s->pose.footLift[i],0,reduced?1:1-exp(-dt/.065));
            s->planted[i]=add(anchor,s->foot[i]);
        }
        s->stance[i]=stance;
        s->pose.feet[i]=s->foot[i];
    }
    s->point=anchor; s->lastTime=time; s->initialized=true; s->moving=walking;
    s->pose.phase=s->phase; s->pose.walkWeight=s->walkWeight;
    double cycle=2*pi*s->phase;
    double releaseAge=time-s->releasedAt;
    double tap=releaseAge>=0 && releaseAge<.5 ? exp(-releaseAge*12)*sin(releaseAge*22) : 0;
    double blinkClock=fmod(time,4.9);
    double blink=blinkClock<.15 ? pow(sin(pi*blinkClock/.15),2) : 0;
    double desiredSquash=s->pressed?.91:1+tap*.055;
    s->pose.squash=reduced?(s->pressed?.96:1):mix(s->pose.squash,desiredSquash,1-exp(-dt/.045));
    s->pose.bodyY=reduced?0:-fabs(sin(cycle))*2.1*s->walkWeight+sin(time*2.1)*.45*(1-s->walkWeight);
    s->pose.lean=reduced?0:clamp(s->velocity.x/700,-.1,.1)*s->walkWeight;
    s->pose.eyeOpen=reduced?1:clamp((1-blink)*(s->pressed?.65:1),.07,1);
    double gazeX=walking?s->direction.x*2.3:sin(time*.57)*.7;
    double gazeY=walking?s->direction.y*1.7:sin(time*.31)*.35;
    s->pose.gazeX=reduced?0:mix(s->pose.gazeX,gazeX,1-exp(-dt/.085));
    s->pose.gazeY=reduced?0:mix(s->pose.gazeY,gazeY,1-exp(-dt/.085));
    s->pose.smile=s->pressed?.35:.75;
    s->pose.tap=reduced?0:fmax(0,tap);
}

static void journeyTerms(const BuddieJourney *j, double time, double *t, BuddiePoint *normal) {
    *t=clamp((time-j->startedAt)/fmax(.001,j->duration),0,1);
    BuddiePoint d=sub(j->end,j->start);
    double len=length(d);
    *normal=len>0?(BuddiePoint){-d.y/len,d.x/len}:(BuddiePoint){0,0};
}
BuddiePoint BuddieJourneySample(const BuddieJourney *j, double time) {
    if (!j->active) return j->end;
    double t; BuddiePoint n; journeyTerms(j,time,&t,&n);
    double t2=t*t,t3=t2*t,t4=t3*t,t5=t4*t;
    double position=10*t3-15*t4+6*t5;
    double initialVelocity=t-6*t3+8*t4-3*t5;
    double arc=64*t3*pow(1-t,3);
    return add(add(lerp(j->start,j->end,position),mul(j->velocity,j->duration*initialVelocity)),mul(n,j->bend*arc));
}
BuddiePoint BuddieJourneyVelocity(const BuddieJourney *j, double time) {
    if (!j->active || time>=j->startedAt+j->duration) return (BuddiePoint){0,0};
    double t; BuddiePoint n; journeyTerms(j,time,&t,&n);
    double dp=30*t*t-60*t*t*t+30*t*t*t*t;
    double dv=1-18*t*t+32*t*t*t-15*t*t*t*t;
    double da=192*t*t*pow(1-t,2)*(1-2*t);
    return add(add(mul(sub(j->end,j->start),dp/j->duration),mul(j->velocity,dv)),mul(n,j->bend*da/j->duration));
}
void BuddieJourneyRetarget(BuddieJourney *j, BuddiePoint current, BuddiePoint destination, double time, double speed) {
    BuddiePoint velocity=j->active?BuddieJourneyVelocity(j,time):(BuddiePoint){0,0};
    double distance=length(sub(destination,current));
    j->start=current; j->end=destination; j->velocity=velocity;
    j->startedAt=time; j->duration=clamp(.35+distance/650,.38,1.15)/clamp(speed,.4,2);
    j->bend=clamp(distance*.15,0,72)*(destination.x>=current.x?-1:1);
    j->active=true;
}
