/// All locale codes supported by the iNaturalist API for species common names.
/// Each entry maps a locale code to its English name and native name.
class LocaleEntry {
  final String code;
  final String name;
  final String nativeName;

  const LocaleEntry({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  @override
  String toString() => '$nativeName — $name ($code)';
}

const supportedLocales = <LocaleEntry>[
  LocaleEntry(code: 'af', name: 'Afrikaans', nativeName: 'Afrikaans'),
  LocaleEntry(code: 'ar', name: 'Arabic', nativeName: 'العربية'),
  LocaleEntry(code: 'be', name: 'Belarusian', nativeName: 'Беларуская'),
  LocaleEntry(code: 'bg', name: 'Bulgarian', nativeName: 'Български'),
  LocaleEntry(code: 'br', name: 'Breton', nativeName: 'Brezhoneg'),
  LocaleEntry(code: 'ca', name: 'Catalan', nativeName: 'Català'),
  LocaleEntry(code: 'cs', name: 'Czech', nativeName: 'Čeština'),
  LocaleEntry(code: 'da', name: 'Danish', nativeName: 'Dansk'),
  LocaleEntry(code: 'de', name: 'German', nativeName: 'Deutsch'),
  LocaleEntry(code: 'el', name: 'Greek', nativeName: 'Ελληνικά'),
  LocaleEntry(code: 'en', name: 'English', nativeName: 'English'),
  LocaleEntry(code: 'en-GB', name: 'English (UK)', nativeName: 'English (UK)'),
  LocaleEntry(code: 'en-US', name: 'English (US)', nativeName: 'English (US)'),
  LocaleEntry(code: 'eo', name: 'Esperanto', nativeName: 'Esperanto'),
  LocaleEntry(code: 'es', name: 'Spanish', nativeName: 'Español'),
  LocaleEntry(code: 'es-AR', name: 'Spanish (Argentina)', nativeName: 'Español (Argentina)'),
  LocaleEntry(code: 'es-CO', name: 'Spanish (Colombia)', nativeName: 'Español (Colombia)'),
  LocaleEntry(code: 'es-CR', name: 'Spanish (Costa Rica)', nativeName: 'Español (Costa Rica)'),
  LocaleEntry(code: 'es-MX', name: 'Spanish (Mexico)', nativeName: 'Español (México)'),
  LocaleEntry(code: 'et', name: 'Estonian', nativeName: 'Eesti'),
  LocaleEntry(code: 'eu', name: 'Basque', nativeName: 'Euskara'),
  LocaleEntry(code: 'fa', name: 'Persian', nativeName: 'فارسی'),
  LocaleEntry(code: 'fi', name: 'Finnish', nativeName: 'Suomi'),
  LocaleEntry(code: 'fil', name: 'Filipino', nativeName: 'Filipino'),
  LocaleEntry(code: 'fo', name: 'Faroese', nativeName: 'Føroyskt'),
  LocaleEntry(code: 'fr', name: 'French', nativeName: 'Français'),
  LocaleEntry(code: 'fr-CA', name: 'French (Canada)', nativeName: 'Français (Canada)'),
  LocaleEntry(code: 'gd', name: 'Scottish Gaelic', nativeName: 'Gàidhlig'),
  LocaleEntry(code: 'gl', name: 'Galician', nativeName: 'Galego'),
  LocaleEntry(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી'),
  LocaleEntry(code: 'he', name: 'Hebrew', nativeName: 'עברית'),
  LocaleEntry(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
  LocaleEntry(code: 'hr', name: 'Croatian', nativeName: 'Hrvatski'),
  LocaleEntry(code: 'hu', name: 'Hungarian', nativeName: 'Magyar'),
  LocaleEntry(code: 'hy', name: 'Armenian', nativeName: 'Հայերեն'),
  LocaleEntry(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia'),
  LocaleEntry(code: 'it', name: 'Italian', nativeName: 'Italiano'),
  LocaleEntry(code: 'ja', name: 'Japanese', nativeName: '日本語'),
  LocaleEntry(code: 'ka', name: 'Georgian', nativeName: 'ქართული'),
  LocaleEntry(code: 'kk', name: 'Kazakh', nativeName: 'Қазақша'),
  LocaleEntry(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
  LocaleEntry(code: 'ko', name: 'Korean', nativeName: '한국어'),
  LocaleEntry(code: 'lb', name: 'Luxembourgish', nativeName: 'Lëtzebuergesch'),
  LocaleEntry(code: 'lt', name: 'Lithuanian', nativeName: 'Lietuvių'),
  LocaleEntry(code: 'lv', name: 'Latvian', nativeName: 'Latviešu'),
  LocaleEntry(code: 'mi', name: 'Maori', nativeName: 'Te Reo Māori'),
  LocaleEntry(code: 'mk', name: 'Macedonian', nativeName: 'Македонски'),
  LocaleEntry(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം'),
  LocaleEntry(code: 'mr', name: 'Marathi', nativeName: 'मराठी'),
  LocaleEntry(code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu'),
  LocaleEntry(code: 'nb', name: 'Norwegian Bokmål', nativeName: 'Norsk bokmål'),
  LocaleEntry(code: 'nl', name: 'Dutch', nativeName: 'Nederlands'),
  LocaleEntry(code: 'nn', name: 'Norwegian Nynorsk', nativeName: 'Norsk nynorsk'),
  LocaleEntry(code: 'oc', name: 'Occitan', nativeName: 'Occitan'),
  LocaleEntry(code: 'pl', name: 'Polish', nativeName: 'Polski'),
  LocaleEntry(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
  LocaleEntry(code: 'pt-BR', name: 'Portuguese (Brazil)', nativeName: 'Português (Brasil)'),
  LocaleEntry(code: 'ro', name: 'Romanian', nativeName: 'Română'),
  LocaleEntry(code: 'ru', name: 'Russian', nativeName: 'Русский'),
  LocaleEntry(code: 'sat', name: 'Santali', nativeName: 'ᱥᱟᱱᱛᱟᱲᱤ'),
  LocaleEntry(code: 'si', name: 'Sinhala', nativeName: 'සිංහල'),
  LocaleEntry(code: 'sk', name: 'Slovak', nativeName: 'Slovenčina'),
  LocaleEntry(code: 'sl', name: 'Slovenian', nativeName: 'Slovenščina'),
  LocaleEntry(code: 'sq', name: 'Albanian', nativeName: 'Shqip'),
  LocaleEntry(code: 'sr', name: 'Serbian', nativeName: 'Српски'),
  LocaleEntry(code: 'sv', name: 'Swedish', nativeName: 'Svenska'),
  LocaleEntry(code: 'sw', name: 'Swahili', nativeName: 'Kiswahili'),
  LocaleEntry(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
  LocaleEntry(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
  LocaleEntry(code: 'th', name: 'Thai', nativeName: 'ไทย'),
  LocaleEntry(code: 'tr', name: 'Turkish', nativeName: 'Türkçe'),
  LocaleEntry(code: 'uk', name: 'Ukrainian', nativeName: 'Українська'),
  LocaleEntry(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt'),
  LocaleEntry(code: 'zh-CN', name: 'Chinese (Simplified)', nativeName: '简体中文'),
  LocaleEntry(code: 'zh-HK', name: 'Chinese (Hong Kong)', nativeName: '繁體中文 (香港)'),
  LocaleEntry(code: 'zh-TW', name: 'Chinese (Traditional)', nativeName: '繁體中文 (臺灣)'),
];

/// Lookup a locale entry by code.
LocaleEntry? localeByCode(String code) {
  for (final entry in supportedLocales) {
    if (entry.code == code) return entry;
  }
  return null;
}
