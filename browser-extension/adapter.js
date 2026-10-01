/* Own artwork only. Observe the existing cursor; never dispatch input or
 * acknowledge its arrival. The official extension owns movement and timing. */
(() => {
  class Motion {
    constructor() { this.reset(); }
    reset() { this.last = null; this.phase = 0; this.turn = 0; this.target = 0; this.speed = 0; this.until = 0; this.pressed = false; this.release = -Infinity; }
    button(down, time) { if (this.pressed && !down) this.release = time; this.pressed = down; }
    sample(x, y, time, reduced) {
      const last = this.last;
      const dt = last ? Math.min(.1, Math.max(0, time - last.time)) : 0;
      const dx = last ? x - last.x : 0, dy = last ? y - last.y : 0;
      const distance = Math.hypot(dx, dy);
      const jump = !last || time - last.time > .25 || distance > 800;
      if (jump) { this.speed = 0; this.until = 0; }
      else if (dt > 0) {
        const velocity = distance / dt;
        this.speed += (velocity - this.speed) * (1 - Math.exp(-dt / .05));
        if (distance > .05) {
          this.until = time + .085;
          if (Math.abs(dx) > .1) this.target = dx < 0 ? 1 : 0;
          this.phase = (this.phase + (velocity > 250 ? dt * 5 : distance / 6.4)) % 1;
        }
      }
      this.turn += Math.max(-dt / .18, Math.min(dt / .18, this.target - this.turn));
      if (reduced) this.turn = this.target;
      this.last = {x, y, time};
      let state = 'idle', progress = 0;
      if (this.pressed) state = 'press';
      else if (!reduced && time - this.release < .38) { state = 'release'; progress = (time - this.release) / .38; }
      else if (!reduced && time < this.until) { state = this.speed > 250 ? 'run' : 'walk'; progress = this.phase; }
      else if (!reduced && time % 4.9 < .15) { state = 'blink'; progress = (time % 4.9) / .15; }
      return {state, progress, direction: Math.round(this.turn * 4)};
    }
  }

  function create({rootFor, assetURL, atlas, hostId = 'codex-agent-overlay-root', alive = () => true}) {
    const motion = new Motion(), image = new Image();
    const reduced = matchMedia('(prefers-reduced-motion: reduce)');
    let stopped = false, loaded = false, attached = null, raf = 0, lastDraw = -1;
    let visibility = 0, point = null;
    image.decoding = 'async';
    function release() {
      if (!attached) return;
      attached.observer.disconnect();
      // Remove only our exact rule, leaving any later third-party edit intact.
      if (attached.asset.style.getPropertyValue('visibility') === 'hidden' && attached.asset.style.getPropertyPriority('visibility') === 'important') {
        if (attached.oldValue) attached.asset.style.setProperty('visibility', attached.oldValue, attached.oldPriority);
        else attached.asset.style.removeProperty('visibility');
      }
      attached.canvas.remove(); attached = null; point = null; visibility = 0;
      motion.reset(); lastDraw = -1;
    }
    function frame(time) {
      raf = 0;
      if (stopped || !attached) return;
      if (!attached.source.isConnected || !attached.asset.isConnected) { release(); discover(); return; }
      try {
        const css = getComputedStyle(attached.source);
        const overlay = getComputedStyle(attached.overlay);
        visibility = Number(css.opacity);
        if (document.hidden || overlay.display === 'none' || css.visibility === 'hidden' || visibility <= .001) {
          attached.canvas.style.opacity = '0'; motion.reset(); point = null; return;
        }
        // The inspected renderer transforms its 24 x 24 box around (12,12).
        // Copy the translated origin; rotation/stretch stay with the arrow.
        const matrix = new DOMMatrixReadOnly(css.transform);
        const origin = css.transformOrigin.split(' ').map(Number.parseFloat);
        if (!matrix.is2D || Math.abs(origin[0] - 12) > .01 || Math.abs(origin[1] - 12) > .01 || parseFloat(css.width) !== 24 || parseFloat(css.height) !== 24) {
          release(); return;
        }
        const x = matrix.e + 12, y = matrix.f + 12;
        if (!Number.isFinite(x) || !Number.isFinite(y)) { release(); return; }
        point = {x,y};
        const unit = atlas.height / atlas.cell;
        attached.canvas.style.transform = `translate3d(${x - atlas.hotspot[0]*unit}px, ${y - atlas.hotspot[1]*unit}px, 0)`;
        attached.canvas.style.opacity = String(visibility);
        const pose = motion.sample(x,y,time/1000,reduced.matches);
        const track = atlas.states[pose.state];
        const index = track.start + pose.direction*track.count + Math.min(track.count-1,Math.floor(pose.progress*track.count));
        if (index !== lastDraw) {
          const ctx = attached.context;
          ctx.clearRect(0,0,atlas.cell,atlas.cell);
          ctx.drawImage(image,(index%atlas.columns)*atlas.cell,Math.floor(index/atlas.columns)*atlas.cell,atlas.cell,atlas.cell,0,0,atlas.cell,atlas.cell);
          lastDraw = index;
        }
        attached.asset.style.setProperty('visibility','hidden','important');
        raf = requestAnimationFrame(frame);
      } catch { release(); }
    }
    function wake() { if (!raf && attached && !stopped) raf = requestAnimationFrame(frame); }
    function discover() {
      if (stopped || !loaded) return;
      if (attached?.source.isConnected && attached.asset.isConnected) return;
      release();
      const host = document.getElementById(hostId);
      if (!host || host.dataset.codexAgentOverlayRoot !== 'true') return;
      let root;
      try { root = rootFor(host); } catch { return; }
      if (!root) return;
      const source = root.querySelector('[data-testid="browser-agent-cursor"]');
      const asset = source?.querySelector('img[data-browser-agent-cursor-asset]');
      const overlay = source?.closest('.codex-agent-overlay');
      if (!asset || !overlay || !source.parentElement || root.querySelector('[data-codex-buddie-canvas]')) return;
      // Require the known 23 x 24 arrow asset; leave unfamiliar renderers alone.
      if (asset.width !== 23 || asset.height !== 24) return;
      const canvas = document.createElement('canvas');
      canvas.dataset.codexBuddieCanvas = 'bit'; canvas.setAttribute('aria-hidden','true');
      canvas.width = atlas.cell; canvas.height = atlas.cell;
      canvas.style.cssText = `position:absolute;left:0;top:0;width:${atlas.height}px;height:${atlas.height}px;pointer-events:none;image-rendering:pixelated;opacity:0;transform-origin:0 0;filter:none;`;
      const context = canvas.getContext('2d'); if (!context) return;
      context.imageSmoothingEnabled = false;
      const observer = new MutationObserver(records => {
        if (records.some(record => record.target === source || record.target === overlay || record.type === 'childList')) wake();
      });
      attached = {source,asset,overlay,canvas,context,observer,oldValue:asset.style.getPropertyValue('visibility'),oldPriority:asset.style.getPropertyPriority('visibility')};
      source.parentElement.appendChild(canvas);
      observer.observe(root,{subtree:true,childList:true,attributes:true,attributeFilter:['style']});
      wake();
    }
    function button(event) {
      if (!point || visibility <= .1 || !event.isTrusted || event.button !== 0) return;
      if (event.type === 'pointerdown' && Math.hypot(event.clientX-point.x,event.clientY-point.y) > 18) return;
      motion.button(event.type === 'pointerdown',performance.now()/1000); wake();
    }
    const documentObserver = new MutationObserver(discover);
    documentObserver.observe(document.documentElement,{childList:true});
    document.addEventListener('pointerdown',button,true);
    document.addEventListener('pointerup',button,true);
    document.addEventListener('visibilitychange',wake);
    const timer = setInterval(() => {
      try { if (!alive()) { destroy(); return; } } catch { destroy(); return; }
      discover();
    },1000);
    function destroy() {
      if (stopped) return;
      stopped = true; cancelAnimationFrame(raf); clearInterval(timer); documentObserver.disconnect();
      document.removeEventListener('pointerdown',button,true); document.removeEventListener('pointerup',button,true); document.removeEventListener('visibilitychange',wake);
      release();
    }
    image.onload = () => { if (!stopped) { loaded = true; discover(); } };
    image.onerror = destroy;
    image.src = assetURL;
    return {destroy};
  }
  globalThis.BuddieBrowser = {create,Motion};
})();
