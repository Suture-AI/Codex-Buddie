const assert=require('node:assert/strict');
require('../browser-extension/adapter.js');
const Motion=globalThis.BuddieBrowser.Motion;
for(const hz of [30,60,120]) {
  const motion=new Motion();
  motion.sample(0,0,0,false);
  let pose;
  for(let i=1;i<=hz;i++)pose=motion.sample(i*40/hz,0,i/hz,false);
  assert.equal(pose.state,'walk');assert.equal(pose.direction,0);
  for(let i=1;i<=hz;i++)pose=motion.sample(40-i*40/hz,0,1+i/hz,false);
  assert.equal(pose.direction,4);
  pose=motion.sample(0,0,3,false);assert.equal(pose.state,'idle');
  motion.button(true,3);pose=motion.sample(0,0,3.02,false);assert.equal(pose.state,'press');
  motion.button(false,3.03);pose=motion.sample(0,0,3.1,false);assert.equal(pose.state,'release');
  pose=motion.sample(0,0,3.5,false);assert.equal(pose.state,'idle');
  pose=motion.sample(30,0,3.52,true);assert.equal(pose.state,'idle');
  motion.button(true,3.53);pose=motion.sample(30,0,3.54,true);assert.equal(pose.state,'press');
}
console.log('PASS: browser motion at 30/60/120 Hz, reversal, stopped facing, press/release interruption and Reduced Motion');
