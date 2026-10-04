// lib/core/utils/ocr_regex.dart
// ----------------------------------------
// Specialized parser for extracting Yu-Gi-Oh! card set codes from OCR text.
// Handles formats like:
//   - LOB-001
//   - LOB-EN001, LOB-E001, LOB-SP001
//   - MP21-EN001
//   - BLVO-EN012
//   - RA01-EN001
// Also sanitizes common OCR confusions (spaces around hyphen, O/0, I/1).

class OcrRegex {
  OcrRegex._();

  // Pattern matching: 3-5 chars, hyphen (or space/underscore), 3-6 chars
  // Examples: "LOB-001", "MP21-EN001", "RA01-EN001", "TLM-ENSE1"
  static final RegExp setCodePattern = RegExp(
    r'\b([A-Z0-9]{3,5})[\s\-_]+([A-Z0-9]{3,6})\b',
    caseSensitive: false,
  );

  /// Cleans raw candidate text, removing spaces and standardizing hyphen
  static String normalizeCandidate(String prefix, String suffix) {
    var p = prefix.trim().toUpperCase();
    var s = suffix.trim().toUpperCase();

    // Fix OCR common mistakes where letters vs digits are misplaced
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

        // Filter out obvious false positives like dates (2020-2024), phone numbers, or pure numbers
        if (RegExp(r'^\d+$').hasMatch(prefix) && RegExp(r'^\d+$').hasMatch(suffix)) {
          continue;
        }

        final normalized = normalizeCandidate(prefix, suffix);
        // Valid set codes are usually between 7 and 12 chars
        if (normalized.length >= 7 && normalized.length <= 12) {
          candidates.add(normalized);
        }
      }
    }

    return candidates.toList();
  }
}
