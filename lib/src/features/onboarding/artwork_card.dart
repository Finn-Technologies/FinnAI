import 'package:flutter/material.dart';

/// The step's photographic card: the artwork fills it, the title sits in the
/// bottom-left corner over the artwork's own dark wash.
class OnboardingArtworkCard extends StatelessWidget {
  const OnboardingArtworkCard({
    super.key,
    required this.artwork,
    required this.title,
    this.twoLineTitle = false,
    this.radius,
  });

  final String artwork;
  final String title;
  final bool twoLineTitle;

  /// One radius for every corner, for a wide window where the card is a pane
  /// that sits in the window's own rounding. Null keeps the phone design's
  /// 25 / 25 / 10 / 10 corners and stretches the bitmap to the card.
  final double? radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: radius != null
            ? BorderRadius.circular(radius!)
            : const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              // The design's card photo: the source bitmap is already cropped to
              // the card's crop region, so filling it reproduces the design's
              // exact stretch rather than a BoxFit.cover re-crop.
              Image.asset(
                artwork,
                fit: radius != null ? BoxFit.cover : BoxFit.fill,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
              // The design washes the photo with a 35% black-to-transparent
              // gradient so the white title reads over any part of it.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x59000000), Color(0x00666666)],
                  ),
                ),
              ),
              Positioned(
                left: 25,
                right: 25,
                bottom: twoLineTitle ? 21 : 30,
                child: Text(
                  title,
                  // The card clips, and the title is laid out from the bottom
                  // with no height of its own, so the line count has to be
                  // capped here: an uncapped title wraps upward out of a card
                  // that shrank on a landscape screen and loses its ascenders.
                  maxLines: twoLineTitle ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 24,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
