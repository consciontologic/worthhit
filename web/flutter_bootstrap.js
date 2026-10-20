{{flutter_js}}
{{flutter_build_config}}
(() => {
  const entrypoint = new URL('main.dart.js', document.baseURI);
  const showFailure = () => {
    const recovery = document.getElementById('startup-error');
    if (recovery) recovery.hidden = false;
  };
  // Flutter's callback-based loader does not reject on an entrypoint resource
  // error. Limit recovery to that script; analytics failure never gates startup.
  const entrypointFailed = event => {
    if (event.target?.tagName !== 'SCRIPT') return;
    const failed = new URL(event.target.src, document.baseURI);
    if (failed.origin === entrypoint.origin && failed.pathname === entrypoint.pathname) {
      showFailure();
    }
  };
  window.addEventListener('error', entrypointFailed, true);
  try {
    Promise.resolve(_flutter.loader.load({
      onEntrypointLoaded: async function(engineInitializer) {
        try {
          const runner = await engineInitializer.initializeEngine();
          await runner.runApp();
          document.getElementById('startup-error')?.remove();
          window.removeEventListener('error', entrypointFailed, true);
        } catch (_) {
          showFailure();
        }
      }
    })).catch(showFailure);
  } catch (_) {
    showFailure();
  }
})();
