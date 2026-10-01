#include "../Sources/BuddieMotion.h"
#include <stdio.h>

// Deterministic walk / stop / reverse trace using the actual native motion core.
// A hard stop intentionally exposes planted-foot and settling defects.
int main(void) {
    BuddieMotion motion; BuddieMotionInit(&motion);
    puts("[");
    for(int i=0;i<420;i++) {
        double t=i/60.,x=t<.5 ? 0:t<3.5 ? (t-.5)*24:t<4 ? 72:t<5.5 ? 72-(t-4)*24:36;
        BuddieMotionUpdate(&motion,(BuddiePoint){x,0},100+t,(BuddieRig){16,6,3},false);
        BuddiePose p=motion.pose;
        printf("%s{\"time\":%.9f,\"x\":%.9f,\"phase\":%.9f,\"bodyY\":%.9f,\"lean\":%.9f,\"walkWeight\":%.9f,\"feet\":[[%.9f,%.9f,%.9f],[%.9f,%.9f,%.9f]]}",i ? ",\n":"",t,x,p.phase,p.bodyY,p.lean,p.walkWeight,p.feet[0].x,p.feet[0].y,p.footLift[0],p.feet[1].x,p.feet[1].y,p.footLift[1]);
    }
    puts("\n]");
}
