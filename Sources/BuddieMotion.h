#ifndef BUDDIE_MOTION_H
#define BUDDIE_MOTION_H
#include <stdbool.h>

typedef struct { double x, y; } BuddiePoint;
typedef struct {
    double stride, footSpacing, footLift;
} BuddieRig;
typedef struct {
    BuddiePoint feet[2];
    double footLift[2], phase, walkWeight;
    double bodyY, lean, squash, eyeOpen, gazeX, gazeY, smile, tap;
} BuddiePose;
typedef struct {
    bool initialized, pressed, moving, stance[2];
    double lastTime, lastMotion, phase, speed, walkWeight, releasedAt;
    BuddiePoint point, velocity, direction, planted[2], swingStart[2], foot[2];
    bool settling[2], swinging[2];
    double settleAt[2], settleDuration[2], settleLift[2], swingDistance[2];
    BuddiePoint settleFrom[2], settleTo[2], swingTarget[2];
    BuddiePose pose;
} BuddieMotion;

void BuddieMotionInit(BuddieMotion *motion);
void BuddieMotionUpdate(BuddieMotion *motion, BuddiePoint anchor, double time, BuddieRig rig, bool reducedMotion);
void BuddieMotionPress(BuddieMotion *motion, bool down, double time);

typedef struct {
    BuddiePoint start, end, velocity;
    double startedAt, duration, bend;
    bool active;
} BuddieJourney;
// Retargeting preserves the current position and velocity.
void BuddieJourneyRetarget(BuddieJourney *journey, BuddiePoint current, BuddiePoint destination, double time, double speed);
BuddiePoint BuddieJourneySample(const BuddieJourney *journey, double time);
BuddiePoint BuddieJourneyVelocity(const BuddieJourney *journey, double time);
#endif
