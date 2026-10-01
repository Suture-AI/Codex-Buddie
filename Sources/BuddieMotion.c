#include "BuddieMotion.h"
#include <math.h>
#include <string.h>

static const double pi = 3.14159265358979323846;
static double clamp(double value, double low, double high) { return fmax(low, fmin(high, value)); }
static double mix(double a, double b, double t) { return a + (b-a)*t; }
static double ease(double t) { return t*t*(3-2*t); }
static double settleEase(double t) { return t*t*t*(10+t*(-15+6*t)); }
static BuddiePoint add(BuddiePoint a, BuddiePoint b) { return (BuddiePoint){a.x+b.x,a.y+b.y}; }
static BuddiePoint sub(BuddiePoint a, BuddiePoint b) { return (BuddiePoint){a.x-b.x,a.y-b.y}; }
static BuddiePoint mul(BuddiePoint a, double s) { return (BuddiePoint){a.x*s,a.y*s}; }
static double length(BuddiePoint a) { return hypot(a.x,a.y); }
static BuddiePoint lerp(BuddiePoint a, BuddiePoint b, double t) { return add(a,mul(sub(b,a),t)); }

void BuddieMotionInit(BuddieMotion *s) {
    memset(s,0,sizeof(*s));
    s->direction=(BuddiePoint){1,0}; s->releasedAt=-1000; s->landedAt=-1000;
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
        s->phase=0; s->speed=0; s->walkWeight=0; s->moving=false; s->airborne=false; s->flightPhase=0; s->landedAt=-1000;
        for (int i=0;i<2;i++) {
            s->foot[i]=(BuddiePoint){(i?1:-1)*rig.footSpacing,0};
            s->planted[i]=add(anchor,s->foot[i]); s->swingStart[i]=s->planted[i]; s->stance[i]=true;
            s->settling[i]=false; s->swinging[i]=false; s->flightLanding[i]=false; s->pose.footLift[i]=0; s->swingDistance[i]=0;
        }
        delta=(BuddiePoint){0,0}; distance=0; dt=1./60.;
        s->velocity=(BuddiePoint){0,0};
    }
    double rate=1-exp(-dt/.075);
    BuddiePoint raw=mul(delta,1/fmax(dt,.0001));
    s->velocity=lerp(s->velocity,raw,rate);
    s->speed=mix(s->speed,length(raw),rate);
    // A velocity threshold has the same meaning at 30, 60 and 120 Hz.
    bool traveling=length(raw)>.9;
    if (traveling) {
        s->lastMotion=time;
        s->direction=mul(delta,1/distance);
        s->phase=fmod(s->phase+distance/rig.stride,1);
    }
    bool walking=traveling || (s->moving && time-s->lastMotion<.08);
    s->walkWeight=mix(s->walkWeight,walking?1:0,1-exp(-dt/(walking?.06:.14)));
    // A cursor can cross many body lengths per second. Beyond a readable gait,
    // take both feet off the ground instead of dragging a planted leg forever.
    // Hysteresis prevents alternating walk/flight around the speed threshold.
    bool flight=!reduced && length(raw)>rig.stride*(s->airborne ? 2.5:4);
    if(flight && !s->airborne) s->flightPhase=s->phase;
    if(flight) s->flightPhase=fmod(s->flightPhase+dt*clamp(length(raw)/rig.stride,2.5,5),1);
    if(s->airborne && !flight && !reduced) {
        int lead=s->pose.footLift[1]<s->pose.footLift[0] ? 1:0;
        for(int i=0;i<2;i++) {
            s->settling[i]=true; s->flightLanding[i]=true; s->swinging[i]=false; s->settleAt[i]=time;
            s->settleFrom[i]=add(anchor,s->foot[i]);
            s->settleTo[i]=add(anchor,(BuddiePoint){(i?1:-1)*rig.footSpacing,0});
            s->settleLift[i]=s->pose.footLift[i]; s->settleDuration[i]=i==lead ? .14:.20;
        }
    }
    s->airborne=flight;
    if(!walking && !reduced) {
        if(s->moving) for(int i=0;i<2;i++) { s->planted[i]=add(s->point,s->foot[i]); s->swinging[i]=false; }
        if(!s->settling[0] && !s->settling[1]) {
            int next=-1; double priority=0;
            for(int i=0;i<2;i++) {
                BuddiePoint base={(i?1:-1)*rig.footSpacing,0};
                double distanceToRest=length(sub(base,s->foot[i]));
                // Land an already lifted foot first; otherwise move the most
                // displaced foot. The other contact stays fixed in world space.
                double score=distanceToRest+(s->pose.footLift[i]>.05 ? 1000:0);
                if((distanceToRest>.05 || s->pose.footLift[i]>.05) && score>priority) { next=i; priority=score; }
            }
            if(next>=0) {
                s->settling[next]=true; s->settleAt[next]=time;
                s->settleFrom[next]=add(anchor,s->foot[next]);
                s->settleTo[next]=add(anchor,(BuddiePoint){(next?1:-1)*rig.footSpacing,0});
                s->settleLift[next]=s->pose.footLift[next];
                s->settleDuration[next]=.16+.12*clamp(length(sub(s->settleTo[next],s->settleFrom[next]))/rig.stride,0,1);
            }
        }
    }
    for (int i=0;i<2;i++) {
        BuddiePoint base={(i?1:-1)*rig.footSpacing,0};
        double phase=fmod(s->phase+i*.5,1);
        bool stance=phase<.62;
        if(reduced) {
            s->settling[i]=false; s->flightLanding[i]=false; s->landedAt=-1000; s->swinging[i]=false; s->foot[i]=base; s->pose.footLift[i]=0;
            s->planted[i]=add(anchor,base); stance=true;
        } else if(flight) {
            double cycle=2*pi*(s->flightPhase+i*.5);
            BuddiePoint target=add(base,mul(s->direction,sin(cycle)*rig.stride*.18));
            s->foot[i]=lerp(s->foot[i],target,1-exp(-dt/.045));
            s->pose.footLift[i]=mix(s->pose.footLift[i],rig.footLift*(.8+.5*(1-cos(cycle))),1-exp(-dt/.035));
            s->planted[i]=add(anchor,s->foot[i]); s->settling[i]=false; s->flightLanding[i]=false; s->swinging[i]=false; stance=false;
        } else if(s->settling[i]) {
            // Finish this short landing even when travel resumes. A new stride
            // then starts from the actual landing, not a stale swing origin.
            double u=clamp((time-s->settleAt[i])/s->settleDuration[i],0,1);
            BuddiePoint shift=s->flightLanding[i] ? sub(add(anchor,base),s->settleTo[i]):(BuddiePoint){0,0};
            // Airborne landings follow the moving hips until contact. Ordinary
            // planted-foot settling retains its committed world-space target.
            s->foot[i]=sub(add(lerp(s->settleFrom[i],s->settleTo[i],settleEase(u)),shift),anchor);
            double lift=s->flightLanding[i] ? 0:fmax(0,rig.footLift*.7-s->settleLift[i]);
            s->pose.footLift[i]=s->settleLift[i]*(1-settleEase(u))+lift*pow(sin(pi*u),2);
            stance=false;
            if(u>=1-1e-9) {
                if(s->flightLanding[i] && s->flightLanding[1-i]) s->landedAt=time;
                s->settling[i]=false; s->flightLanding[i]=false; s->planted[i]=add(anchor,s->foot[i]);
                s->pose.footLift[i]=0; stance=true;
            }
        } else if (walking) {
            if(!s->moving) s->stance[i]=true;
            bool beginSwing=!s->swinging[i] && !stance && s->stance[i] && !s->swinging[1-i] && !s->settling[1-i];
            if(beginSwing) {
                s->swinging[i]=true; s->swingDistance[i]=0; s->swingStart[i]=s->planted[i];
                // Commit this step's landing in world space. Reversing the
                // cursor must not teleport an airborne foot to the other side.
                BuddiePoint target=add(add(anchor,base),mul(s->direction,rig.stride*.69));
                BuddiePoint reach=sub(target,s->swingStart[i]); double span=length(reach);
                s->swingTarget[i]=add(s->swingStart[i],mul(reach,span>0 ? fmin(1,rig.stride*1.25/span):0));
            }
            if (!s->swinging[i]) {
                // World-space contact remains fixed while the body advances.
                s->foot[i]=sub(s->planted[i],anchor);
                s->pose.footLift[i]=0; stance=true;
            } else {
                if(!beginSwing) s->swingDistance[i]+=distance;
                // A restarted stride still gets its whole swing interval,
                // instead of being squeezed into a tiny remaining phase.
                double u=clamp(s->swingDistance[i]/(rig.stride*.38),0,1);
                s->foot[i]=sub(lerp(s->swingStart[i],s->swingTarget[i],ease(u)),anchor);
                s->pose.footLift[i]=pow(sin(pi*u),2)*rig.footLift;
                stance=false;
                if(u>=1) { s->swinging[i]=false; s->planted[i]=s->swingTarget[i]; s->pose.footLift[i]=0; stance=true; }
            }
        } else {
            s->foot[i]=sub(s->planted[i],anchor);
            s->pose.footLift[i]=0; stance=true;
        }
        s->stance[i]=stance;
        s->pose.feet[i]=s->foot[i];
    }
    s->point=anchor; s->lastTime=time; s->initialized=true; s->moving=walking;
    s->pose.phase=flight ? s->flightPhase:s->phase; s->pose.walkWeight=s->walkWeight;
    double cycle=2*pi*s->pose.phase;
    double releaseAge=time-s->releasedAt;
    double tap=releaseAge>=0 && releaseAge<.5 ? exp(-releaseAge*12)*sin(releaseAge*22) : 0;
    double blinkClock=fmod(time,4.9);
    double blink=blinkClock<.15 ? pow(sin(pi*blinkClock/.15),2) : 0;
    double landingAge=time-s->landedAt;
    double impact=landingAge>=0 && landingAge<.24 ? exp(-landingAge*18)*fmax(0,sin(landingAge*26)):0;
    double desiredSquash=s->pressed?.91:1+tap*.055-impact*.06;
    s->pose.squash=reduced?(s->pressed?.96:1):mix(s->pose.squash,desiredSquash,1-exp(-dt/.045));
    double bob=flight ? -2.1-fabs(sin(2*pi*s->flightPhase))*.7:-fabs(sin(cycle))*2.1*s->walkWeight+sin(time*2.1)*.45*(1-s->walkWeight);
    if(!flight) bob+=impact*1.5;
    s->pose.bodyY=reduced?0:mix(s->pose.bodyY,bob,1-exp(-dt/.05));
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
