// test/ocr_regex_test.dart
// ------------------------
// Unit tests for Yu-Gi-Oh! set code OCR regex parser.

import 'package:flutter_test/flutter_test.dart';
import 'package:yugioh_collector/core/utils/ocr_regex.dart';

void main() {
  group('OcrRegex Tests', () {
    test('detects classic 3-digit set code (LOB-001)', () {
      const text = 'Dark Magician\nATK/2500 DEF/2100\nLOB-001\n1st Edition';
      final candidates = OcrRegex.extractCandidates(text);

      expect(candidates, contains('LOB-001'));
    });

    test('detects modern regional set code (MP21-EN001)', () {
      const text = 'Blue-Eyes White Dragon\nMP21-EN001\nLimited Edition';
      final candidates = OcrRegex.extractCandidates(text);

      expect(candidates, contains('MP21-EN001'));
    });

    test('normalizes spaces around hyphen (LOB - 001)', () {
      const text = 'Some card text LOB - 001 edition';
      final candidates = OcrRegex.extractCandidates(text);

      expect(candidates, contains('LOB-001'));
    });

    test('ignores non-card numbers such as years or stats', () {
      const text = '1996 - 2024 Kazuki Takahashi ATK/ 2500 - 2100';
      final candidates = OcrRegex.extractCandidates(text);

      expect(candidates, isEmpty);
    });

    test('extracts multiple valid candidates if present', () {
      const text = 'LOB-001 and also SDK-001';
      final candidates = OcrRegex.extractCandidates(text);

      expect(candidates.length, 2);
      expect(candidates, containsAll(['LOB-001', 'SDK-001']));
    });
  });
}
