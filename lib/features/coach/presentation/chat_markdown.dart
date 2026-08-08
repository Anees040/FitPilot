import 'package:flutter/material.dart';

import 'package:fitpilot/core/theme/app_theme.dart';

/// One styled run of text produced by the parser.
class _Span {
  final String text;
  final bool bold;
  final bool italic;
  final bool code;

  const _Span(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
  });
}

/// A tiny, safe markdown renderer for coach replies.
///
/// The coach answers in plain prose with light markdown — **bold**, *italic*,
/// `code`, and "- " bullets. Flutter ships no markdown widget, and a full
/// markdown engine (with its own HTML and URL handling) is a large dependency
/// and a larger attack surface for messages capped at 120 words. This renders
/// exactly the subset the coach uses, so replies read like chat messages
/// instead of raw asterisks.
class ChatMarkdown {
  const ChatMarkdown._();

  /// Converts one message into styled text spans.
  static List<TextSpan> parse(String text, {required ThemeData theme}) {
    final ext = theme.extension<AppColors>()!;
    final base = theme.textTheme.body;
    final bold = base.copyWith(fontWeight: FontWeight.w700);
    final italic = base.copyWith(fontStyle: FontStyle.italic);
    final code = base.copyWith(
      fontFamily: 'monospace',
      fontSize: (base.fontSize ?? 15) - 1,
      color: ext.energy,
      backgroundColor: ext.surfaceRaised,
    );

    return [
      for (final span in _spansOf(text))
        TextSpan(
          text: span.text,
          style: span.code
              ? code
              : span.bold && span.italic
              ? bold.copyWith(fontStyle: FontStyle.italic)
              : span.bold
              ? bold
              : span.italic
              ? italic
              : base,
        ),
    ];
  }

  /// Bullet lines ("- x", "* x", "• x") in order, marker stripped.
  static List<String> bullets(String text) {
    final out = <String>[];
    for (final line in text.split('\n')) {
      final match = RegExp(r'^[-*•]\s+(.*)$').firstMatch(line.trim());
      if (match != null) out.add(match.group(1)!);
    }
    return out;
  }

  /// Whatever precedes the first bullet — usually a lead-in sentence.
  static String leadIn(String text) {
    final out = <String>[];
    for (final line in text.split('\n')) {
      if (RegExp(r'^[-*•]\s+').hasMatch(line.trim())) break;
      out.add(line);
    }
    return out.join('\n');
  }

  static List<_Span> _spansOf(String text) {
    // Bullet markers are stripped here; the widget renders them as glyphs.
    final source = text.replaceAll(RegExp(r'^[-*•]\s+', multiLine: true), '');
    final spans = <_Span>[];
    var i = 0;

    while (i < source.length) {
      final c = source[i];

      if (c == '*' && i + 1 < source.length && source[i + 1] == '*') {
        final end = source.indexOf('**', i + 2);
        if (end != -1) {
          spans.add(_Span(source.substring(i + 2, end), bold: true));
          i = end + 2;
          continue;
        }
      }

      if (c == '*') {
        final end = source.indexOf('*', i + 1);
        if (end != -1) {
          spans.add(_Span(source.substring(i + 1, end), italic: true));
          i = end + 1;
          continue;
        }
      }

      if (c == '`') {
        final end = source.indexOf('`', i + 1);
        if (end != -1) {
          spans.add(_Span(source.substring(i + 1, end), code: true));
          i = end + 1;
          continue;
        }
      }

      // Heading markers add nothing to a short chat reply.
      if (c == '#' && (i == 0 || source[i - 1] == '\n')) {
        i++;
        continue;
      }

      var j = i;
      while (j < source.length) {
        final ch = source[j];
        final isMarker = ch == '*' || ch == '`';
        final isHeading = ch == '#' && (j == 0 || source[j - 1] == '\n');
        if (isMarker || isHeading) break;
        j++;
      }

      if (j > i) {
        spans.add(_Span(source.substring(i, j)));
        i = j;
      } else {
        // An unmatched marker: emit it literally rather than looping forever.
        spans.add(_Span(c));
        i++;
      }
    }

    return spans;
  }
}

/// Renders a message's text, turning bullet lines into a real list.
class ChatMessageBody extends StatelessWidget {
  final String content;

  const ChatMessageBody({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bullets = ChatMarkdown.bullets(content);

    if (bullets.isEmpty) {
      return Text.rich(
        TextSpan(children: ChatMarkdown.parse(content, theme: theme)),
      );
    }

    final lead = ChatMarkdown.leadIn(content).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lead.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(
              TextSpan(children: ChatMarkdown.parse(lead, theme: theme)),
            ),
          ),
        for (var i = 0; i < bullets.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == bullets.length - 1 ? 0 : 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: ChatMarkdown.parse(bullets[i], theme: theme),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
