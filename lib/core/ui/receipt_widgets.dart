import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/theme.dart';

/// A white receipt slip with a perforated (scalloped) bottom edge and a soft
/// shadow, used for every summary in the design.
class Slip extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool darkShadow;

  const Slip({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
    this.color = AppColors.slip,
    this.darkShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SlipPainter(color: color, darkShadow: darkShadow),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SlipPainter extends CustomPainter {
  final Color color;
  final bool darkShadow;

  _SlipPainter({required this.color, required this.darkShadow});

  static const double _period = 12;
  static const double _radius = 4.75;

  Path _path(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0);
    final bottom = size.height;
    path.lineTo(size.width, bottom);
    // Perforation: half-circle bites out of the bottom edge, right to left.
    var x = size.width;
    final count = (size.width / _period).floor();
    final offset = (size.width - count * _period) / 2;
    x = size.width - offset;
    path.lineTo(x, bottom);
    for (var i = 0; i < count; i++) {
      final centre = x - _period / 2;
      path.lineTo(centre + _radius, bottom);
      path.arcToPoint(
        Offset(centre - _radius, bottom),
        radius: const Radius.circular(_radius),
        clockwise: false,
      );
      x -= _period;
      path.lineTo(x, bottom);
    }
    path.lineTo(0, bottom);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    canvas.drawShadow(
      path.shift(const Offset(0, 2)),
      darkShadow ? Colors.black : AppColors.ink.withAlpha(60),
      darkShadow ? 10 : 6,
      false,
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SlipPainter old) =>
      old.color != color || old.darkShadow != darkShadow;
}

/// The dotted line between a label and its amount on a receipt row.
class DottedLeader extends StatelessWidget {
  const DottedLeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: 6, right: 6, top: 12),
        child: CustomPaint(
          size: Size(double.infinity, 2),
          painter: _DotsPainter(),
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.dots;
    for (double x = 1; x < size.width; x += 4) {
      canvas.drawCircle(Offset(x, size.height / 2), 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}

/// A dashed rule separating sections of a slip.
class DashedRule extends StatelessWidget {
  final Color color;

  const DashedRule({super.key, this.color = AppColors.dots});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 2),
      painter: _DashPainter(color),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;

  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + 4).clamp(0, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}

/// One receipt line: label, dotted leader, amount.
class LeaderRow extends StatelessWidget {
  final Widget label;
  final String amount;
  final TextStyle? amountStyle;

  const LeaderRow({
    super.key,
    required this.label,
    required this.amount,
    this.amountStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: label),
        const DottedLeader(),
        Text(amount, style: amountStyle ?? AppFonts.money()),
      ],
    );
  }
}

enum AppButtonKind { primary, outline, dark, ghost, danger }

/// The design's buttons: 54 px primary actions, outlined secondary actions.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final IconData? icon;
  final double height;
  final Widget? trailing;
  final bool onDark;
  final double? fontSize;
  final double horizontalPadding;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.height = 54,
    this.trailing,
    this.onDark = false,
    this.fontSize,
    this.horizontalPadding = 18,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    Color bg;
    Color fg;
    BorderSide side = BorderSide.none;
    switch (kind) {
      case AppButtonKind.primary:
        bg = onDark ? AppColors.mintBright : AppColors.emerald;
        fg = onDark ? AppColors.mintInk : Colors.white;
      case AppButtonKind.dark:
        bg = AppColors.ink;
        fg = AppColors.slip;
      case AppButtonKind.outline:
        bg = onDark ? Colors.transparent : AppColors.slip;
        fg = onDark ? AppColors.nightText : AppColors.ink;
        side = BorderSide(
          color: onDark ? AppColors.nightOutline : AppColors.outline,
        );
      case AppButtonKind.ghost:
        bg = Colors.transparent;
        fg = onDark ? AppColors.nightText : AppColors.ink;
        side = BorderSide(
          color: onDark ? AppColors.nightOutline : AppColors.outline,
        );
      case AppButtonKind.danger:
        bg = Colors.transparent;
        fg = AppColors.red;
        side = const BorderSide(color: AppColors.outline);
    }
    if (!enabled && kind != AppButtonKind.ghost) {
      bg = AppColors.disabled;
      fg = AppColors.mutedStrong;
      side = BorderSide.none;
    }

    return SizedBox(
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: side,
          ),
          textStyle: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: fontSize ?? (height >= 54 ? 16 : 14),
            fontWeight: kind == AppButtonKind.primary && onDark
                ? FontWeight.w700
                : FontWeight.w600,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: trailing != null
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}

/// A pill that is either selected (ink) or not (white with outline).
class PillToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dashedWhenOff;

  const PillToggle({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dashedWhenOff = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? AppColors.ink
            : (dashedWhenOff ? Colors.transparent : AppColors.slip),
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.ink : AppColors.outline),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.slip : AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-option segmented control (design: grey track, white selected tab).
class SegmentTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const SegmentTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.segment,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: Material(
                  color: i == selected ? AppColors.slip : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => onChanged(i),
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: i == selected
                                ? AppColors.ink
                                : AppColors.mutedStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Round avatar with initials.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final Color tint;
  final double size;

  const InitialsAvatar({
    super.key,
    required this.name,
    required this.tint,
    this.size = 34,
  });

  static String initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final chars = trimmed.characters.take(2).toString();
    return chars.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          initials(name),
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// White rounded card with a thin border (member list, history rows).
class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const PaperCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.slip,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Amber notice box (warnings, confirmations).
class AmberNotice extends StatelessWidget {
  final Widget child;

  const AmberNotice({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.amberBg,
        border: Border.all(color: AppColors.amberBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AppColors.amberText,
        ),
        child: child,
      ),
    );
  }
}

/// Header of a bottom sheet: grab handle, title and optional close button.
class SheetHeader extends StatelessWidget {
  final String title;
  final bool showClose;

  const SheetHeader({super.key, required this.title, this.showClose = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.handle,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (showClose)
              IconButton(
                tooltip: 'Zavřít',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.x, color: AppColors.ink),
              ),
          ],
        ),
      ],
    );
  }
}

/// Opens [builder] as a design-style bottom sheet over a dark scrim.
Future<T?> showPaperSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: AppColors.ink.withAlpha(140),
    backgroundColor: AppColors.paper,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: builder(context),
        ),
      ),
    ),
  );
}

/// Small grey caption used above fields and sections.
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    );
  }
}

/// Section heading on paper ("Členové", "Historie výdajů").
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
