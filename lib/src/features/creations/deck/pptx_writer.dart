import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart' show XmlText;

import 'package:finn_ai/src/features/creations/spec/deck_spec.dart';

/// Writes a [DeckSpec] to a real `.pptx` (OOXML) package.
///
/// The static parts of the package are held as constants because they never
/// vary, while every piece of model-authored text is escaped through
/// [XmlText] — hand-concatenating titles and bullets is how exporters break on
/// an `&` or a `<`.
abstract final class PptxWriter {
  static const String _nsA =
      'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const String _nsP =
      'http://schemas.openxmlformats.org/presentationml/2006/main';
  static const String _nsR =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  /// 13.333in x 7.5in, the standard 16:9 slide size, in EMU.
  static const int _slideWidth = 12192000;
  static const int _slideHeight = 6858000;

  /// Builds the zipped package.
  static Uint8List build(DeckSpec deck, {DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final slides = deck.slides;
    final archive = Archive();

    void add(String path, String xml) {
      final bytes = utf8.encode(xml);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes(slides.length));
    add('_rels/.rels', _packageRels());
    add('docProps/core.xml', _coreProperties(deck.title, timestamp));
    add('docProps/app.xml', _appProperties(slides.length));
    add('ppt/presentation.xml', _presentation(slides.length));
    add('ppt/_rels/presentation.xml.rels', _presentationRels(slides.length));
    add('ppt/presProps.xml', _presProps());
    add('ppt/theme/theme1.xml', _theme());
    add('ppt/slideMasters/slideMaster1.xml', _slideMaster());
    add('ppt/slideMasters/_rels/slideMaster1.xml.rels', _slideMasterRels());
    add('ppt/slideLayouts/slideLayout1.xml', _slideLayout());
    add('ppt/slideLayouts/_rels/slideLayout1.xml.rels', _slideLayoutRels());
    for (var index = 0; index < slides.length; index++) {
      add(
        'ppt/slides/slide${index + 1}.xml',
        _slide(slides[index], index == 0),
      );
      add('ppt/slides/_rels/slide${index + 1}.xml.rels', _slideRels());
    }

    return ZipEncoder().encodeBytes(archive);
  }

  /// Turns a title into a filesystem-safe base name.
  static String slugify(String title, {String fallback = 'presentation'}) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) return fallback;
    final capped = slug.length <= 48 ? slug : slug.substring(0, 48);
    return capped.replaceAll(RegExp(r'-+$'), '');
  }

  static String _escape(String value) => XmlText(value).toXmlString();

  static String _contentTypes(int slideCount) {
    final slides = StringBuffer();
    for (var index = 1; index <= slideCount; index++) {
      slides.writeln(
        '<Override PartName="/ppt/slides/slide$index.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.'
        'presentationml.slide+xml"/>',
      );
    }
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
<Override PartName="/ppt/presProps.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presProps+xml"/>
<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
$slides</Types>''';
  }

  static String _packageRels() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="$_nsR/officeDocument" Target="ppt/presentation.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId3" Type="$_nsR/extended-properties" Target="docProps/app.xml"/>
</Relationships>''';

  static String _coreProperties(String title, DateTime timestamp) {
    final stamp = timestamp.toIso8601String().split('.').first;
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<dc:title>${_escape(title)}</dc:title>
<dc:creator>Finn AI</dc:creator>
<cp:lastModifiedBy>Finn AI</cp:lastModifiedBy>
<dcterms:created xsi:type="dcterms:W3CDTF">${stamp}Z</dcterms:created>
<dcterms:modified xsi:type="dcterms:W3CDTF">${stamp}Z</dcterms:modified>
</cp:coreProperties>''';
  }

  static String _appProperties(int slideCount) =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
<Application>Finn AI</Application>
<PresentationFormat>Widescreen</PresentationFormat>
<Slides>$slideCount</Slides>
</Properties>''';

  static String _presentation(int slideCount) {
    final ids = StringBuffer();
    for (var index = 0; index < slideCount; index++) {
      ids.writeln('<p:sldId id="${256 + index}" r:id="rId${index + 2}"/>');
    }
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="$_nsA" xmlns:r="$_nsR" xmlns:p="$_nsP" saveSubsetFonts="1">
<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
<p:sldIdLst>$ids</p:sldIdLst>
<p:sldSz cx="$_slideWidth" cy="$_slideHeight"/>
<p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>''';
  }

  static String _presentationRels(int slideCount) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..writeln(
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
      )
      ..writeln(
        '<Relationship Id="rId1" Type="$_nsR/slideMaster" Target="slideMasters/slideMaster1.xml"/>',
      );
    for (var index = 0; index < slideCount; index++) {
      buffer.writeln(
        '<Relationship Id="rId${index + 2}" Type="$_nsR/slide" '
        'Target="slides/slide${index + 1}.xml"/>',
      );
    }
    final presPropsId = slideCount + 2;
    buffer
      ..writeln(
        '<Relationship Id="rId$presPropsId" Type="$_nsR/presProps" Target="presProps.xml"/>',
      )
      ..writeln(
        '<Relationship Id="rId${presPropsId + 1}" Type="$_nsR/theme" Target="theme/theme1.xml"/>',
      )
      ..writeln('</Relationships>');
    return buffer.toString();
  }

  static String _presProps() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentationPr xmlns:a="$_nsA" xmlns:r="$_nsR" xmlns:p="$_nsP"/>''';

  static String _slideMaster() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldMaster xmlns:a="$_nsA" xmlns:r="$_nsR" xmlns:p="$_nsP">
<p:cSld>
<p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>
<p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr/>
</p:spTree>
</p:cSld>
<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
<p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles>
</p:sldMaster>''';

  static String _slideMasterRels() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="$_nsR/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
<Relationship Id="rId2" Type="$_nsR/theme" Target="../theme/theme1.xml"/>
</Relationships>''';

  static String _slideLayout() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sldLayout xmlns:a="$_nsA" xmlns:r="$_nsR" xmlns:p="$_nsP" type="blank" preserve="1">
<p:cSld name="Blank">
<p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr/>
</p:spTree>
</p:cSld>
<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sldLayout>''';

  static String _slideLayoutRels() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="$_nsR/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>''';

  static String _slideRels() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="$_nsR/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>''';

  static String _slide(DeckSlide slide, bool isTitleSlide) {
    final body = StringBuffer();
    for (final bullet in slide.bullets) {
      body.writeln(
        '<a:p><a:pPr marL="342900" indent="-342900"><a:buChar char="\u2022"/></a:pPr>'
        '<a:r><a:rPr lang="en-US" sz="1800" dirty="0"/>'
        '<a:t>${_escape(bullet)}</a:t></a:r></a:p>',
      );
    }
    final titleSize = isTitleSlide ? 4000 : 3200;
    final titleHeight = isTitleSlide ? 1600200 : 1143000;
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="$_nsA" xmlns:r="$_nsR" xmlns:p="$_nsP">
<p:cSld>
<p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr/>
<p:sp>
<p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>
<p:spPr><a:xfrm><a:off x="838200" y="${isTitleSlide ? 2286000 : 685800}"/><a:ext cx="10515600" cy="$titleHeight"/></a:xfrm><a:noFill/></p:spPr>
<p:txBody><a:bodyPr wrap="square" rtlCol="0"/><a:lstStyle/>
<a:p><a:r><a:rPr lang="en-US" sz="$titleSize" b="1" dirty="0"/><a:t>${_escape(slide.title)}</a:t></a:r></a:p>
</p:txBody>
</p:sp>
<p:sp>
<p:nvSpPr><p:cNvPr id="3" name="Body"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>
<p:spPr><a:xfrm><a:off x="838200" y="${isTitleSlide ? 4114800 : 2057400}"/><a:ext cx="10515600" cy="3886200"/></a:xfrm><a:noFill/></p:spPr>
<p:txBody><a:bodyPr wrap="square" rtlCol="0"/><a:lstStyle/>
$body</p:txBody>
</p:sp>
</p:spTree>
</p:cSld>
<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
</p:sld>''';
  }

  static String _theme() =>
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<a:theme xmlns:a="$_nsA" name="Finn AI Theme">
<a:themeElements>
<a:clrScheme name="Finn AI">
<a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1>
<a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
<a:dk2><a:srgbClr val="121212"/></a:dk2>
<a:lt2><a:srgbClr val="F8F8F8"/></a:lt2>
<a:accent1><a:srgbClr val="7DFFCD"/></a:accent1>
<a:accent2><a:srgbClr val="3E86F7"/></a:accent2>
<a:accent3><a:srgbClr val="D6FF7D"/></a:accent3>
<a:accent4><a:srgbClr val="F59E0B"/></a:accent4>
<a:accent5><a:srgbClr val="E5D4F5"/></a:accent5>
<a:accent6><a:srgbClr val="B9DFF1"/></a:accent6>
<a:hlink><a:srgbClr val="0563C1"/></a:hlink>
<a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
</a:clrScheme>
<a:fontScheme name="Finn AI">
<a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
</a:fontScheme>
<a:fmtScheme name="Finn AI">
<a:fillStyleLst>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
</a:fillStyleLst>
<a:lnStyleLst>
<a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
<a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
<a:ln w="19050"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>
</a:lnStyleLst>
<a:effectStyleLst>
<a:effectStyle><a:effectLst/></a:effectStyle>
<a:effectStyle><a:effectLst/></a:effectStyle>
<a:effectStyle><a:effectLst/></a:effectStyle>
</a:effectStyleLst>
<a:bgFillStyleLst>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>
</a:bgFillStyleLst>
</a:fmtScheme>
</a:themeElements>
<a:objectDefaults/>
<a:extraClrSchemeLst/>
</a:theme>''';
}
