import 'package:web/web.dart' as web;

void updateDocumentPreferences({
  required String languageCode,
  required bool dark,
}) {
  const supported = {'en', 'tr', 'de', 'fr', 'es', 'pt', 'ar', 'zh'};
  final language = supported.contains(languageCode) ? languageCode : 'en';
  web.document.documentElement?.setAttribute('lang', language);
  web.document.documentElement?.setAttribute(
    'dir',
    language == 'ar' ? 'rtl' : 'ltr',
  );
  web.document.documentElement?.setAttribute(
    'data-theme',
    dark ? 'dark' : 'light',
  );
  web.document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute('content', dark ? '#161A18' : '#ECEDE5');
  web.document
      .querySelector('link[rel="icon"]')
      ?.setAttribute('href', dark ? 'favicon-dark.svg' : 'favicon-light.svg');
}

Uri resolvePage(String destination) =>
    Uri.parse(web.URL(destination, web.document.baseURI).href);

/// Dispatch a final URL without depending on access to a newly opened window.
/// A successful dispatch cannot prove that browser popup policy allowed a tab.
bool openPage(Uri uri) {
  if (uri.scheme != 'https' && uri.scheme != 'http') return false;
  final body = web.document.body;
  if (body == null) return false;
  final anchor = web.HTMLAnchorElement()
    ..href = '$uri'
    ..target = '_blank'
    ..rel = 'noopener noreferrer'
    ..referrerPolicy = 'no-referrer';
  try {
    body.appendChild(anchor);
    // Give Android browsers the destination in the original gesture. Opening
    // about:blank first requires a child WindowProxy that some hosts withhold.
    anchor.click();
    return true;
  } catch (_) {
    return false;
  } finally {
    anchor.remove();
  }
}
