void updateDocumentPreferences({
  required String languageCode,
  required bool dark,
}) {}

Uri resolvePage(String destination) =>
    Uri.parse('https://worthhit.com/').resolve(destination);

bool openPage(Uri uri) => false;
