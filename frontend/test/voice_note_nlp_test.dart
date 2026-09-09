import 'package:flutter_test/flutter_test.dart';
import 'package:remell/shared/utils/nlp_parser.dart';

void main() {
  group('voice note intelligence', () {
    test('derives a concise title from a continuous Taglish note', () {
      final title = NlpParser.deriveTitleFromNote(
        'Kailangan kong bumili ng gamot tomorrow before 5 pm. Then call Mama.',
      );

      expect(title, 'Bumili ng gamot tomorrow before 5 pm');
    });

    test('detects Taglish without a language selector', () {
      expect(
        NlpParser.detectLanguage('Kailangan ko to submit the report tomorrow'),
        'Taglish detected',
      );
    });

    test('detects Tagalog and English notes', () {
      expect(NlpParser.detectLanguage('Kailangan ko bumili ng gamot bukas'),
          'Tagalog detected');
      expect(NlpParser.detectLanguage('I need to send the report tomorrow'),
          'English detected');
    });
  });
}
