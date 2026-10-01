const hostId = 'buddie-fixture-overlay-root';
const status = document.querySelector('#status'), report = document.querySelector('#report');
let host, root, source, arrow, overlay, adapter, animation, at = {x:innerWidth/2,y:350};
function mount() {
  adapter?.destroy(); host?.remove(); cancelAnimationFrame(animation);
  host = document.createElement('div'); host.id = hostId; host.dataset.codexAgentOverlayRoot = 'true'; document.documentElement.append(host);
  root = host.attachShadow({mode:'closed'});
  overlay = document.createElement('div'); overlay.className = 'codex-agent-overlay'; overlay.style.cssText = 'position:fixed;inset:0;z-index:2147483600;pointer-events:none'; root.append(overlay);
  const layer = document.createElement('div'); layer.style.cssText = 'position:absolute;inset:0;overflow:hidden;pointer-events:none'; overlay.append(layer);
  source = document.createElement('div'); source.dataset.testid = 'browser-agent-cursor'; source.style.cssText = 'position:absolute;left:0;top:0;width:24px;height:24px;transform-origin:12px 12px;opacity:1;filter:blur(0px)'; layer.append(source);
  const inner = document.createElement('div'); inner.style.transform = 'translate3d(12px,-2.5px,0)'; source.append(inner);
  arrow = document.createElement('img'); arrow.width = 23; arrow.height = 24; arrow.dataset.browserAgentCursorAsset = ''; arrow.alt = '';
  arrow.style.cssText = 'display:block;transform:rotate(44deg);transform-origin:0 0;filter:drop-shadow(0 0 6px #88909a)';
  arrow.src = 'data:image/svg+xml,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="23" height="24"><path fill="#777f8b" stroke="white" d="M2 1 L20 13 L12 15 L9 23 Z"/></svg>'); inner.append(arrow);
  position(at.x,at.y,32,1.16);
  start();
}
function start(assetURL = '../assets/bit-atlas.png') {
  adapter = BuddieBrowser.create({rootFor:element=>element===host ? root:null,assetURL,atlas:BuddieBitAtlas,hostId});
  status.textContent = 'Bit follows the simulated cursor. Click another stop while moving to reverse direction.';
}
function position(x,y,angle=0,stretch=1) { at={x,y}; source.style.transform=`translate3d(${x-12}px,${y-12}px,0) rotate(${angle}deg) scale(${stretch},1)`; }
function move(button) {
  cancelAnimationFrame(animation);
  const box=button.getBoundingClientRect(), target={x:box.x+box.width/2,y:box.y+box.height/2}, from={...at}, began=performance.now();
  function tick(now) {
    const u=Math.min(1,(now-began)/650), e=u*u*(3-2*u);
    position(from.x+(target.x-from.x)*e,from.y+(target.y-from.y)*e-Math.sin(u*Math.PI)*70,45*Math.sin(u*Math.PI),1+.2*Math.sin(u*Math.PI));
    if(u<1) animation=requestAnimationFrame(tick);
  }
  animation=requestAnimationFrame(tick);
}
for(const name of ['left','middle','right'])document.getElementById(name).onclick=event=>move(event.currentTarget);
document.querySelector('#hide').onclick=event=>{ const hidden=overlay.style.display==='none'; overlay.style.display=hidden?'':'none'; event.currentTarget.textContent=hidden?'Hide agent':'Show agent'; };
document.querySelector('#recreate').onclick=mount;
document.querySelector('#toggle').onclick=event=>{
  if(adapter){adapter.destroy();adapter=null;event.currentTarget.textContent='Show Bit';status.textContent='Original simulated arrow restored.';}
  else{start();event.currentTarget.textContent='Show original arrow';}
};
const settle=()=>new Promise(resolve=>setTimeout(()=>requestAnimationFrame(resolve),80));
document.querySelector('#checks').onclick=async event=>{
  const button=event.currentTarget; button.disabled=true; report.textContent=''; const results=[];
  const check=(value,label)=>{if(!value)throw new Error(label);results.push('PASS '+label);};
  try {
    mount(); await settle();
    let canvas=root.querySelector('[data-codex-buddie-canvas]');
    check(Boolean(canvas),'Character attaches inside a closed shadow root');
    check(arrow.style.visibility==='hidden','Gray artwork is hidden after Bit is ready');
    for(const [x,y,rotation,stretch] of [[200.25,280.5,70,1.4],[800.75,410.125,-120,.6],[420,340,0,1]]) {
      position(x,y,rotation,stretch);await settle();const matrix=new DOMMatrix(canvas.style.transform);
      check(Math.abs(matrix.e+42*.8-x)<.001&&Math.abs(matrix.f+24*.8-y)<.001,`Exact anchor through rotation/stretch at ${x}, ${y}`);
    }
    check(canvas.style.pointerEvents==='none'&&canvas.getAttribute('aria-hidden')==='true','Artwork does not intercept input or accessibility');
    overlay.style.display='none';await settle();check(canvas.style.opacity==='0','Hidden native cursor hides the buddy');
    overlay.style.display='';await settle();check(canvas.style.opacity==='1','Buddy returns with the native cursor');
    adapter.destroy();check(!root.querySelector('[data-codex-buddie-canvas]')&&arrow.style.visibility==='','Stopping restores the exact original visibility');
    arrow.width=99;start();await settle();check(!root.querySelector('[data-codex-buddie-canvas]')&&arrow.style.visibility==='','Unknown artwork is left intact');
    adapter.destroy();arrow.width=23;start('missing-atlas.png');await settle();check(arrow.style.visibility==='','Failed artwork load keeps the original visible');
    mount();await settle();check(Boolean(root.querySelector('[data-codex-buddie-canvas]')),'Recreated overlay reconnects');
    status.textContent=`${results.length} compatibility checks passed. Live extension installation is still required.`;
  } catch(error) {results.push('FAIL '+error.message);status.textContent='A compatibility check failed.';}
  report.textContent=results.join('\n');button.disabled=false;
};
mount();
