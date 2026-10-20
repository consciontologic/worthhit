/* Static-shell registration. API requests and private content are never cached. */
(() => {
  const release = '__BUILD_ID__';
  if (!('serviceWorker' in navigator)) return;
  const identify = () => navigator.serviceWorker.controller?.postMessage({
    type: 'CLIENT_RELEASE', release
  });
  navigator.serviceWorker.addEventListener('controllerchange', identify);
  // Pin already-controlled clients immediately; this does not install anything.
  identify();
  let registration;
  let inFlight = false;
  let nextCheck = 0;
  let timer;
  let stopped = true;
  let firstFrame = false;
  let pageActive = true;

  // Checking only `waiting` cannot discover a remote release in a long-lived
  // tab. Ask the browser for the worker script while online and visible.
  // A shared cooldown bounds focus/online bursts, and the actual promise keeps
  // its lock until settlement: a slow browser request is never overlapped.
  const check = async () => {
    if (stopped || inFlight || navigator.onLine === false ||
        document.visibilityState === 'hidden' || Date.now() < nextCheck) return;
    inFlight = true;
    nextCheck = Date.now() + 30_000;
    try {
      if (!registration) {
        registration = await navigator.serviceWorker.register(
          'service_worker.js', {updateViaCache: 'none'});
        delete document.documentElement.dataset.pwaUnavailable;
        identify();
      }
      if (!stopped) await registration.update();
      // Discovery never activates an update or reloads an unfinished form.
    } catch (_) {
      // Offline/unsupported installation must not gate the app. A later visible
      // connection check may recover, with no credentials or content involved.
      if (!registration) document.documentElement.dataset.pwaUnavailable = 'true';
    } finally {
      inFlight = false;
    }
  };
  const start = () => {
    if (!firstFrame || !pageActive || !stopped) return;
    stopped = false;
    window.addEventListener('focus', check);
    window.addEventListener('online', check);
    document.addEventListener('visibilitychange', check);
    timer = setInterval(check, 5 * 60_000);
    void check();
  };
  const stop = () => {
    pageActive = false;
    stopped = true;
    clearInterval(timer);
    window.removeEventListener('focus', check);
    window.removeEventListener('online', check);
    document.removeEventListener('visibilitychange', check);
  };
  window.addEventListener('pagehide', stop);
  window.addEventListener('pageshow', () => {
    pageActive = true;
    start();
  });
  // Flutter 3.47.3 dispatches this from its first-frame rendering callback,
  // specifically so offline installation does not compete with startup assets.
  const rendered = () => {
    firstFrame = true;
    window.removeEventListener('flutter-first-frame', rendered);
    start();
  };
  window.addEventListener('flutter-first-frame', rendered);
})();
