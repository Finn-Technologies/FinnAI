import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:finn_ai/src/features/creations/deck/pptx_writer.dart';
import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';

const _deck = DeckSpec(
  title: 'Quarterly Review',
  slides: [
    DeckSlide(
      title: 'Quarterly Review',
      bullets: ['Revenue and churn'],
      notes: 'Welcome everyone.',
    ),
    DeckSlide(
      title: 'R&D <spend> & "growth"',
      bullets: ['Up 12% & rising', 'Churn < 3%'],
    ),
    DeckSlide(title: 'Next Steps', bullets: ['Ship the fix']),
  ],
);

Archive _open(DeckSpec deck) =>
    ZipDecoder().decodeBytes(PptxWriter.build(deck, now: DateTime.utc(2026)));

ArchiveFile _part(Archive archive, String name) => archive.files.firstWhere(
      (file) => file.name == name,
      orElse: () => throw StateError('missing part: $name'),
    );

void main() {
  group('PptxWriter package structure', () {
    test('contains every part an OOXML presentation requires', () {
      final archive = _open(_deck);
      final names = archive.files.map((file) => file.name).toSet();

      expect(
        names,
        containsAll(<String>[
          '[Content_Types].xml',
          '_rels/.rels',
          'docProps/core.xml',
          'docProps/app.xml',
          'ppt/presentation.xml',
          'ppt/_rels/presentation.xml.rels',
          'ppt/presProps.xml',
          'ppt/theme/theme1.xml',
          'ppt/slideMasters/slideMaster1.xml',
          'ppt/slideMasters/_rels/slideMaster1.xml.rels',
          'ppt/slideLayouts/slideLayout1.xml',
          'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
        ]),
      );
      for (var index = 1; index <= _deck.slides.length; index++) {
        expect(names, contains('ppt/slides/slide$index.xml'));
        expect(names, contains('ppt/slides/_rels/slide$index.xml.rels'));
      }
    });

    test('every XML part is well-formed', () {
      for (final file in _open(_deck).files) {
        if (!file.name.endsWith('.xml') && !file.name.endsWith('.rels')) {
          continue;
        }
        final text = utf8.decode(file.readBytes()!);
        expect(
          () => XmlDocument.parse(text),
          returnsNormally,
          reason: '${file.name} is not well-formed XML',
        );
      }
    });

    test('content types declare an override for each slide', () {
      final contentTypes = utf8.decode(
        _part(_open(_deck), '[Content_Types].xml').readBytes()!,
      );
      expect(
        contentTypes,
        contains(
          'PartName="/ppt/slides/slide3.xml"',
        ),
      );
      expect(contentTypes, contains('presentationml.presentation.main+xml'));
    });

    test('presentation relationships point at each slide', () {
      final rels = utf8.decode(
        _part(_open(_deck), 'ppt/_rels/presentation.xml.rels').readBytes()!,
      );
      expect(rels, contains('Target="slides/slide1.xml"'));
      expect(rels, contains('Target="slides/slide3.xml"'));
      expect(rels,
          contains('/slideMaster" Target="slideMasters/slideMaster1.xml"'));
    });

    test('slide ids in presentation.xml match the slide count', () {
      final presentation = utf8.decode(
        _part(_open(_deck), 'ppt/presentation.xml').readBytes()!,
      );
      expect(presentation, contains('<p:sldId id="256" r:id="rId2"/>'));
      expect(presentation, contains('<p:sldId id="258" r:id="rId4"/>'));
      expect(presentation, contains('cx="12192000" cy="6858000"'));
    });
  });

  group('PptxWriter text handling', () {
    test('round-trips characters that would otherwise break the XML', () {
      final slide = utf8.decode(
        _part(_open(_deck), 'ppt/slides/slide2.xml').readBytes()!,
      );
      // Assert on decoded text rather than the escaped form: what matters is
      // that a title or bullet containing &, < or quotes survives the trip
      // through the writer and back intact.
      final texts = XmlDocument.parse(slide)
          .findAllElements('a:t')
          .map((element) => element.innerText)
          .toList();
      expect(texts, contains('R&D <spend> & "growth"'));
      expect(texts, contains('Up 12% & rising'));
      expect(texts, contains('Churn < 3%'));
    });

    test('escapes ampersands and angle brackets in the raw part', () {
      final slide = utf8.decode(
        _part(_open(_deck), 'ppt/slides/slide2.xml').readBytes()!,
      );
      // The unescaped forms must not appear, or the part would be unparseable.
      expect(slide, contains('Up 12% &amp; rising'));
      expect(slide, contains('Churn &lt; 3%'));
      expect(slide.contains('12% & rising'), isFalse);
    });

    test('writes each bullet as its own paragraph', () {
      final slide = utf8.decode(
        _part(_open(_deck), 'ppt/slides/slide2.xml').readBytes()!,
      );
      expect('<a:t>'.allMatches(slide).length, 3);
    });

    test('the title slide gets a larger title than content slides', () {
      final archive = _open(_deck);
      final titleSlide = utf8.decode(
        _part(archive, 'ppt/slides/slide1.xml').readBytes()!,
      );
      final bodySlide = utf8.decode(
        _part(archive, 'ppt/slides/slide3.xml').readBytes()!,
      );
      expect(titleSlide, contains('sz="4000"'));
      expect(bodySlide, contains('sz="3200"'));
    });
  });

  group('PptxWriter.slugify', () {
    test('produces a filesystem-safe name', () {
      expect(PptxWriter.slugify('Quarterly Review'), 'quarterly-review');
      expect(PptxWriter.slugify('R&D / Growth!'), 'r-d-growth');
    });

    test('falls back when the title has no usable characters', () {
      expect(PptxWriter.slugify('!!!'), 'presentation');
      expect(PptxWriter.slugify(''), 'presentation');
    });

    test('caps the length', () {
      final slug = PptxWriter.slugify('a' * 200);
      expect(slug.length, lessThanOrEqualTo(48));
    });
  });
}
