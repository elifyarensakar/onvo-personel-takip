import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Onvo tasarım diline uygun, etiketli ve ikonlu metin alanı.
/// Odaklandığında amber renkte kenarlık/gölge, hata durumunda ise
/// kırmızı kenarlık ve alt satırda hata mesajı gösterir.
class OnvoTextField extends StatefulWidget {
  const OnvoTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.placeholder,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.suffix,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String? placeholder;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  State<OnvoTextField> createState() => _OnvoTextFieldState();
}

class _OnvoTextFieldState extends State<OnvoTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    final Color borderColor = hasError
        ? AppColors.error
        : _focused
            ? AppColors.amber
            : AppColors.line;

    final Color fillColor = hasError
        ? AppColors.errorTint
        : _focused
            ? AppColors.surface
            : AppColors.surfaceTint;

    final Color iconColor = hasError
        ? AppColors.error
        : _focused
            ? AppColors.amberDark
            : AppColors.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppText.label),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: _focused && !hasError
                ? [
                    BoxShadow(
                      color: AppColors.amber.withOpacity(0.16),
                      blurRadius: 0,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(widget.icon, size: 19, color: iconColor),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  autofillHints: widget.autofillHints,
                  onChanged: widget.onChanged,
                  style: AppText.input,
                  cursorColor: AppColors.amberDark,
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: AppText.input.copyWith(
                      color: AppColors.mutedLight,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                  ),
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(widget.errorText!, style: AppText.errorMsg),
        ],
      ],
    );
  }
}
