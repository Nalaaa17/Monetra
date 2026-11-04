import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

class AnimatedCurrency extends StatefulWidget {
  final int amount;
  final TextStyle style;
  final Duration duration;
  final bool enableFlash;

  const AnimatedCurrency({
    super.key,
    required this.amount,
    required this.style,
    this.duration = const Duration(milliseconds: 650),
    this.enableFlash = true,
  });

  @override
  State<AnimatedCurrency> createState() => _AnimatedCurrencyState();
}

class _AnimatedCurrencyState extends State<AnimatedCurrency> {
  int _prevAmount = 0;
  Color? _flashColor;

  @override
  void initState() {
    super.initState();
    _prevAmount = widget.amount;
  }

  @override
  void didUpdateWidget(covariant AnimatedCurrency oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) {
      if (widget.enableFlash) {
        if (widget.amount > oldWidget.amount) {
          _flashColor = const Color(0xFF059669); // Hijau naik
        } else {
          _flashColor = AppColors.danger; // Merah turun
        }
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _flashColor = null);
        });
      }
      _prevAmount = oldWidget.amount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _prevAmount.toDouble(),
        end: widget.amount.toDouble(),
      ),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final currentStyle = _flashColor != null
            ? widget.style.copyWith(color: _flashColor)
            : widget.style;

        return Text(
          CurrencyFormatter.format(value.round()),
          style: currentStyle,
        );
      },
    );
  }
}

