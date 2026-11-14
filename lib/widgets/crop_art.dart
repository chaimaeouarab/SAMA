import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/crops_catalog.dart';

/// Bundled illustration used whenever a crop photo is missing (ported from docs/prototype.html).
String cropArtSvg(String kind, String c1, String c2) {
  const leaf = '#4C9A34';
  final s = StringBuffer();
  switch (kind) {
    case 'cereal':
      for (var i = 0; i < 9; i++) {
        final x = 12 + i * 11;
        s.write('<path d="M$x 100V46" stroke="$c2" stroke-width="2"/>');
        for (var j = 0; j < 4; j++) {
          final y = 44 + j * 7;
          s.write(
            '<ellipse cx="${x - 3}" cy="$y" rx="2.6" ry="5" fill="$c2" transform="rotate(-25 ${x - 3} $y)"/>'
            '<ellipse cx="${x + 3}" cy="${y + 3}" rx="2.6" ry="5" fill="$c2" transform="rotate(25 ${x + 3} ${y + 3})"/>',
          );
        }
      }
    case 'corn':
      for (var i = 0; i < 4; i++) {
        final x = 16 + i * 27;
        s.write(
          '<path d="M$x 100V30" stroke="#4C9A34" stroke-width="4"/>'
          '<path d="M$x 70Q${x - 18} 60 ${x - 24} 44M$x 56Q${x + 18} 46 ${x + 24} 30" stroke="#4C9A34" stroke-width="3" fill="none"/>'
          '<ellipse cx="${x + 5}" cy="62" rx="5" ry="12" fill="$c2"/>',
        );
      }
    case 'bean':
      for (var i = 0; i < 5; i++) {
        final x = 16 + i * 20;
        s.write(
          '<path d="M$x 100V50" stroke="$c2" stroke-width="3"/>'
          '<ellipse cx="${x - 7}" cy="62" rx="8" ry="4.5" fill="$c2" transform="rotate(-30 ${x - 7} 62)"/>'
          '<ellipse cx="${x + 7}" cy="74" rx="8" ry="4.5" fill="$c2" transform="rotate(30 ${x + 7} 74)"/>'
          '<ellipse cx="${x - 6}" cy="86" rx="7" ry="4" fill="$c2" transform="rotate(-30 ${x - 6} 86)"/>',
        );
      }
    case 'root':
      for (var i = 0; i < 4; i++) {
        final x = 18 + i * 26;
        s.write(
          '<path d="M$x 78V48M${x - 6} 78L${x - 12} 54M${x + 6} 78L${x + 12} 54" stroke="$leaf" stroke-width="3" stroke-linecap="round"/>'
          '<circle cx="$x" cy="86" r="12" fill="$c2"/>',
        );
      }
    case 'fruitveg':
      for (var i = 0; i < 3; i++) {
        final x = 22 + i * 38;
        s.write(
          '<path d="M$x 100V36" stroke="$leaf" stroke-width="3"/>'
          '<path d="M$x 50Q${x - 16} 44 ${x - 18} 34M$x 66Q${x + 16} 60 ${x + 18} 50" stroke="$leaf" stroke-width="3" fill="none"/>'
          '<circle cx="${x - 9}" cy="72" r="8" fill="$c2"/><circle cx="${x + 9}" cy="84" r="8" fill="$c2"/>',
        );
      }
    case 'leaf':
      for (var i = 0; i < 3; i++) {
        final x = 24 + i * 36;
        s.write(
          '<circle cx="$x" cy="76" r="17" fill="$c2"/><circle cx="$x" cy="76" r="11" fill="#fff" opacity=".25"/>'
          '<path d="M${x - 14} 80Q$x 60 ${x + 14} 80" stroke="#fff" stroke-width="2" fill="none" opacity=".6"/>',
        );
      }
    case 'melon':
      const xs = [28, 70, 98], ys = [78, 88, 72], rs = [18, 14, 12];
      for (var i = 0; i < 3; i++) {
        s.write(
          '<circle cx="${xs[i]}" cy="${ys[i]}" r="${rs[i]}" fill="$c2"/>'
          '<path d="M${xs[i] - rs[i] + 4} ${ys[i]}Q${xs[i]} ${ys[i] - rs[i]} ${xs[i] + rs[i] - 4} ${ys[i]}" stroke="#fff" stroke-width="2" fill="none" opacity=".5"/>',
        );
      }
    case 'sun':
      for (var i = 0; i < 3; i++) {
        final x = 22 + i * 38, y = 44 + (i % 2) * 10;
        s.write('<path d="M$x 100V$y" stroke="$leaf" stroke-width="3"/>');
        for (var k = 0; k < 10; k++) {
          s.write(
            '<ellipse cx="$x" cy="${y - 12}" rx="3" ry="8" fill="$c2" transform="rotate(${k * 36} $x $y)"/>',
          );
        }
        s.write('<circle cx="$x" cy="$y" r="7" fill="#6B3F1A"/>');
      }
    case 'forage':
      for (var i = 0; i < 16; i++) {
        final x = 6 + i * 7;
        s.write(
          '<path d="M$x 100Q${x + (i % 3 - 1) * 5} 70 ${x + (i % 4 - 2) * 3} ${52 + (i % 5) * 5}" stroke="$c2" stroke-width="3" fill="none" stroke-linecap="round"/>',
        );
      }
    default: // tree, vine
      final xs = kind == 'vine' ? [30, 90] : [60];
      for (final x in xs) {
        final big = kind != 'vine';
        s.write(
          '<rect x="${x - 4}" y="64" width="8" height="36" fill="#7A5A2B"/>'
          '<circle cx="$x" cy="48" r="${big ? 28 : 20}" fill="#5FA24A"/>'
          '<circle cx="${x - 10}" cy="54" r="${big ? 20 : 14}" fill="#4C9A34"/>',
        );
        for (var k = 0; k < 7; k++) {
          s.write(
            '<circle cx="${x + (k * 13 % 27) - 13}" cy="${40 + (k * 17 % 30)}" r="3.6" fill="$c2"/>',
          );
        }
      }
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 100" preserveAspectRatio="xMidYMid slice">'
      '<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#EAF3EC"/><stop offset="1" stop-color="$c1"/></linearGradient></defs>'
      '<rect width="120" height="100" fill="url(#g)"/><path d="M0 88Q30 80 60 86T120 82V100H0z" fill="$c2" opacity=".3"/>$s</svg>';
}

/// Photo from `assets/images/crops/ID.jpg`, with the illustration when the file is missing.
class CropImage extends StatelessWidget {
  const CropImage(this.crop, {super.key, this.fit = BoxFit.cover});
  final Crop crop;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      crop.photo,
      fit: fit,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) =>
          SvgPicture.string(cropArtSvg(crop.kind, crop.c1, crop.c2), fit: fit),
    );
  }
}

String wheatArtSvg(String c2) => cropArtSvg('cereal', '#EAF3EC', c2);
