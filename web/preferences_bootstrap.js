/* Match the saved theme before Flutter paints. Never read an API credential. */
(() => {
  try {
    const raw = localStorage.getItem('worthhit.preferences.v1');
    if (!raw || raw.length > 1024) return;
    const preferences = JSON.parse(raw);
    if (preferences && ['light', 'dark'].includes(preferences.theme)) {
      document.documentElement.dataset.theme = preferences.theme;
      const dark = preferences.theme === 'dark';
      document.querySelector('meta[name="theme-color"]')?.setAttribute('content', dark ? '#161A18' : '#ECEDE5');
      document.querySelector('link[rel="icon"]')?.setAttribute('href', `${document.querySelector('base') ? '' : '../'}favicon-${dark ? 'dark' : 'light'}.svg`);
    }
  } catch (_) {
    // Storage can be unavailable; the operating-system preference remains usable.
  }
})();
