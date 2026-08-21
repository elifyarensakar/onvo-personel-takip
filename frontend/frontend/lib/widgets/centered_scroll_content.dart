import 'package:flutter/material.dart';

/// Ekran kartının içeriğini sarmalamak için kullanılır. İçerik, mevcut
/// alandan kısaysa (örn. tablet gibi uzun ekranlarda login formu) dikeyde
/// ortalanır; alandan uzunsa (örn. klavye açıldığında ya da küçük bir
/// telefonda) normal şekilde kaydırılabilir hale gelir.
///
/// Önceki tasarımda kart her zaman Expanded ile tam yüksekliği
/// kaplıyordu ama içindeki Column üstte kalıyordu — kısa içerikli
/// ekranlarda (özellikle tabletlerde) altta büyük bir boşluk oluşuyordu.
class CenteredScrollContent extends StatelessWidget {
  const CenteredScrollContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}