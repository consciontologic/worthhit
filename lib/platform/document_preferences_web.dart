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

bool openPage(Uri uri) {
  if (uri.scheme != 'https' && uri.scheme != 'http') return false;
  // noopener on window.open returns null even on success. Open an empty page,
  // clear its opener before navigation and set its referrer policy instead, so
  // a null return reliably identifies a blocked popup.
  final page = web.window.open('about:blank', '_blank');
  if (page == null) return false;
  try {
    page.opener = null;
    final policy = web.HTMLMetaElement()
      ..name = 'referrer'
      ..content = 'no-referrer';
    page.document.head?.appendChild(policy);
    page.location.replace('$uri');
    return true;
  } catch (_) {
    page.close();
    return false;
  }
}
