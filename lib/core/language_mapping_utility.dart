/// Utility class for language ID and name mapping
/// This eliminates code duplication across the app
class LanguageMappingUtility {
  // Private constructor to prevent instantiation
  LanguageMappingUtility._();

  /// Static map for language name to ID conversion
  static const Map<String, int> _languageNameToIdMap = {
    'Afrikaans': 1,
    'Albanian': 2,
    'Amharic': 3,
    'Arabic': 4,
    'Egyptian Arabic': 5,
    'Moroccan Arabic': 6,
    'Levantine Arabic': 7,
    'Gulf Arabic': 8,
    'Tunisian Arabic': 9,
    'Sudanese Arabic': 10,
    'Iraqi Arabic': 11,
    'Algerian Arabic': 12,
    'Armenian': 13,
    'Assamese': 14,
    'Azerbaijani': 15,
    'Basque': 16,
    'Belarusian': 17,
    'Bengali': 18,
    'Bosnian': 19,
    'Bulgarian': 20,
    'Burmese': 21,
    'Catalan': 22,
    'Cebuano': 23,
    'Chichewa': 24,
    'Chinese (Simplified)': 25,
    'Chinese (Traditional)': 26,
    'Corsican': 27,
    'Croatian': 28,
    'Czech': 29,
    'Danish': 30,
    'Dutch': 31,
    'English': 32,
    'Esperanto': 33,
    'Estonian': 34,
    'Farsi': 35,
    'Filipino': 36,
    'Finnish': 37,
    'French': 38,
    'Frisian': 39,
    'Galician': 40,
    'Georgian': 41,
    'German': 42,
    'Greek': 43,
    'Gujarati': 44,
    'Haitian Creole': 45,
    'Hausa': 46,
    'Hawaiian': 47,
    'Hebrew': 48,
    'Hindi': 49,
    'Hmong': 50,
    'Hungarian': 51,
    'Icelandic': 52,
    'Igbo': 53,
    'Indonesian': 54,
    'Irish': 55,
    'Italian': 56,
    'Japanese': 57,
    'Javanese': 58,
    'Kannada': 59,
    'Kazakh': 60,
    'Khmer': 61,
    'Kinyarwanda': 62,
    'Korean': 63,
    'Kurdish (Kurmanji)': 64,
    'Kyrgyz': 65,
    'Lao': 66,
    'Latin': 67,
    'Latvian': 68,
    'Lithuanian': 69,
    'Luxembourgish': 70,
    'Macedonian': 71,
    'Malagasy': 72,
    'Malay': 73,
    'Malayalam': 74,
    'Maltese': 75,
    'Maori': 76,
    'Marathi': 77,
    'Mongolian': 78,
    'Nepali': 79,
    'Norwegian': 80,
    'Nyanja': 81,
    'Odia': 82,
    'Pashto': 83,
    'Persian': 84,
    'Polish': 85,
    'Portuguese': 86,
    'Punjabi': 87,
    'Romanian': 88,
    'Russian': 89,
    'Samoan': 90,
    'Scots Gaelic': 91,
    'Serbian': 92,
    'Sesotho': 93,
    'Shona': 94,
    'Sindhi': 95,
    'Sinhala': 96,
    'Slovak': 97,
    'Slovenian': 98,
    'Somali': 99,
    'Spanish': 100,
    'Sundanese': 101,
    'Swahili': 102,
    'Swedish': 103,
    'Tajik': 104,
    'Tamil': 105,
    'Tatar': 106,
    'Telugu': 107,
    'Thai': 108,
    'Tigrinya': 109,
    'Turkish': 110,
    'Turkmen': 111,
    'Ukrainian': 112,
    'Urdu': 113,
    'Uyghur': 114,
    'Uzbek': 115,
    'Vietnamese': 116,
    'Welsh': 117,
    'Western Frisian': 118,
    'Xhosa': 119,
    'Yiddish': 120,
    'Yoruba': 121,
    'Zulu': 122,
  };

  /// Get language ID from language name
  /// Returns 0 if language name is not found
  static int getLanguageId(String languageName) {
    return _languageNameToIdMap[languageName] ?? 0;
  }

  /// Get language name from language ID
  /// Returns empty string if language ID is not found
  static String getLanguageName(int languageId) {
    // Find the key (language name) for the given value (language ID)
    for (final entry in _languageNameToIdMap.entries) {
      if (entry.value == languageId) {
        return entry.key;
      }
    }
    return '';
  }

  /// Get all available language names
  static List<String> getAllLanguageNames() {
    return _languageNameToIdMap.keys.toList();
  }

  /// Get all available language IDs
  static List<int> getAllLanguageIds() {
    return _languageNameToIdMap.values.toList();
  }

  /// Check if a language name exists
  static bool hasLanguageName(String languageName) {
    return _languageNameToIdMap.containsKey(languageName);
  }

  /// Check if a language ID exists
  static bool hasLanguageId(int languageId) {
    return _languageNameToIdMap.values.contains(languageId);
  }

  /// Convert list of language IDs to language names
  static List<String> convertIdsToNames(List<int> languageIds) {
    return languageIds
        .map((id) => getLanguageName(id))
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Convert list of language names to language IDs
  static List<int> convertNamesToIds(List<String> languageNames) {
    return languageNames
        .map((name) => getLanguageId(name))
        .where((id) => id > 0)
        .toList();
  }
}
