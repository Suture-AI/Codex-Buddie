(() => {
  if (!chrome.dom?.openOrClosedShadowRoot) return;
  globalThis.BuddieBrowser.create({
    rootFor: host => chrome.dom.openOrClosedShadowRoot(host),
    assetURL: chrome.runtime.getURL('assets/bit-atlas.png'),
    atlas: globalThis.BuddieBitAtlas,
    alive: () => { chrome.runtime.getManifest(); return Boolean(chrome.runtime.id); }
  });
})();
