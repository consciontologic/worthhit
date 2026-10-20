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

void openAboutPage() {
  web.window.open(
    web.URL('about/', web.document.baseURI).href,
    '_blank',
    'noopener,noreferrer',
  );
}
