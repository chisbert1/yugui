// lib/core/utils/ocr_regex.dart
// ----------------------------------------
// Specialized parser for extracting Yu-Gi-Oh! card set codes from OCR text.
// Handles formats like:
//   - LOB-001, LOB - 001
//   - LOB-EN001, LOB-E001, LOB-SP001
//   - MP21-EN001
//   - BLVO-EN012
//   - RA01-EN001

class OcrRegex {
  OcrRegex._();

  // Pattern matching:
  // Prefix: 2-5 chars, must contain at least one letter (e.g. LOB, MP21, SDK)
  // Separator: horizontal space, hyphen, or underscore (NEVER newlines)
  // Suffix: 3-6 chars, must contain at least one digit (e.g. 001, EN001)
  static final RegExp setCodePattern = RegExp(
    r'\b([A-Za-z0-9]*[A-Za-z]+[A-Za-z0-9]*)[ \t\-_]+([A-Za-z0-9]*[0-9]+[A-Za-z0-9]*)\b',
  );

  /// Cleans raw candidate text, removing spaces and standardizing hyphen
  static String normalizeCandidate(String prefix, String suffix) {
    var p = prefix.trim().toUpperCase();
    var s = suffix.trim().toUpperCase();
    return '$p-$s';
  }

  /// Extracts all candidate set codes from raw recognized text blocks.
  /// Returns a sorted list of unique normalized codes, best candidate first.
  static List<String> extractCandidates(String rawText) {
    if (rawText.isEmpty) return [];

    final matches = setCodePattern.allMatches(rawText);
    final candidates = <String>{};

    for (final match in matches) {
      if (match.groupCount >= 2) {
        final prefix = match.group(1)!;
        final suffix = match.group(2)!;

        // Prefix length must be between 2 and 5, suffix between 3 and 6
        if (prefix.length < 2 || prefix.length > 5 || suffix.length < 3 || suffix.length > 6) {
          continue;
        }

        // Must have at least one letter in prefix and at least one digit in suffix
        if (!RegExp(r'[A-Za-z]').hasMatch(prefix) || !RegExp(r'\d').hasMatch(suffix)) {
          continue;
        }

        final normalized = normalizeCandidate(prefix, suffix);
        candidates.add(normalized);
      }
    }

    return candidates.toList();
  }
}
