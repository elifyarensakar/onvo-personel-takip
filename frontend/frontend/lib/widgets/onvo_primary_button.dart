import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Onvo'nun tek vurgu rengini (amber) taşıyan ana aksiyon butonu.
/// [isLoading] true olduğunda etiketin yerine dönen bir gösterge çizer.
class OnvoPrimaryButton extends StatelessWidget {
  const OnvoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          disabledBackgroundColor: AppColors.amber,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ).copyWith(
          overlayColor: MaterialStateProperty.all(
            AppColors.amberDark.withOpacity(0.15),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2B1B04)),
                ),
              )
            : Text(label, style: AppText.button),
      ),
    );
  }
}
