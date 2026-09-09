import 'package:flutter/material.dart';

/// A custom TextEditingController that automatically highlights time keywords and phrases
/// in real-time as the user types (e.g. 9:00am, around 10:00 am, ng 11:00am, in the morning).
class TimeHighlightingTextEditingController extends TextEditingController {
  final Color? customHighlightColor;
  final FontWeight highlightFontWeight;

  TimeHighlightingTextEditingController({
    super.text,
    this.customHighlightColor,
    this.highlightFontWeight = FontWeight.w600,
  });

  static final RegExp timeRegex = RegExp(
    r'(?:\b(?:around|about|at|by|bago\s+mag|bago|hanggang|ng|sa|magsimula\s+ng|simulan\s+ng|start\s+at|start\s+around|start\s+ng|starts\s+at|starts\s+around|start)\s+)?'
    r'(?:'
      r'(?:[0-2]?\d:[0-5]\d(?:\s*(?:am|pm|a\.m\.|p\.m\.|ng\s+umaga|ng\s+hapon|ng\s+gabi|in\s+the\s+morning|in\s+the\s+afternoon|in\s+the\s+evening))?)'
      r'|'
      r'(?:[0-2]?\d\s*(?:am|pm|a\.m\.|p\.m\.|ng\s+umaga|ng\s+hapon|ng\s+gabi|in\s+the\s+morning|in\s+the\s+afternoon|in\s+the\s+evening))'
      r'|'
      r'(?:alas[-\s]?(?:isa|dos|tres|kwatro|singko|sais|siyete|otso|nuwebe|diyes|onse|dose|\d+)(?:\s*(?:am|pm|ng\s+umaga|ng\s+hapon|ng\s+gabi|in\s+the\s+morning|in\s+the\s+afternoon|in\s+the\s+evening))?)'
    r')',
    caseSensitive: false,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: style);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorToUse = customHighlightColor ?? (isDark ? const Color(0xFFF59E0B) : const Color(0xFFB45309));

    final matches = timeRegex.allMatches(text);
    if (matches.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final spans = <TextSpan>[];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: (style ?? const TextStyle()).copyWith(
          color: colorToUse,
          fontWeight: highlightFontWeight,
        ),
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ));
    }

    return TextSpan(children: spans, style: style);
  }
}

/// Helper function to build a Text / RichText widget with highlighted time keywords.
Widget buildTimeHighlightedText(
  String text, {
  required TextStyle baseStyle,
  required Color highlightColor,
  FontWeight highlightWeight = FontWeight.w600,
}) {
  if (text.isEmpty) {
    return Text('', style: baseStyle);
  }
  final matches = TimeHighlightingTextEditingController.timeRegex.allMatches(text);
  if (matches.isEmpty) {
    return Text(text, style: baseStyle);
  }

  final spans = <TextSpan>[];
  int lastMatchEnd = 0;

  for (final match in matches) {
    if (match.start > lastMatchEnd) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd, match.start),
        style: baseStyle,
      ));
    }
    spans.add(TextSpan(
      text: text.substring(match.start, match.end),
      style: baseStyle.copyWith(
        color: highlightColor,
        fontWeight: highlightWeight,
      ),
    ));
    lastMatchEnd = match.end;
  }

  if (lastMatchEnd < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastMatchEnd),
      style: baseStyle,
    ));
  }

  return RichText(
    text: TextSpan(children: spans),
  );
}
