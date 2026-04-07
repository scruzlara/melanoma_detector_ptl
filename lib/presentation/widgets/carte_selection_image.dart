import 'dart:io';
import 'package:flutter/material.dart';

/// Carte de sélection d'image avec aperçu.
///
/// Affiche une zone cliquable permettant de sélectionner une image.
/// Si une image est déjà sélectionnée, elle est affichée en aperçu.
class CarteSelectionImage extends StatelessWidget {
  /// Image actuellement sélectionnée (null si aucune).
  final File? imageSelectionnee;

  /// Callback appelé lorsque l'utilisateur appuie sur la carte.
  final VoidCallback? surAppui;

  /// Indique si l'interaction est désactivée.
  final bool desactive;

  const CarteSelectionImage({
    super.key,
    this.imageSelectionnee,
    this.surAppui,
    this.desactive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: desactive ? null : surAppui,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 260,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                imageSelectionnee != null
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
            width: imageSelectionnee != null ? 2 : 1,
          ),
          image:
              imageSelectionnee != null
                  ? DecorationImage(
                    image: FileImage(imageSelectionnee!),
                    fit: BoxFit.cover,
                  )
                  : null,
        ),
        child:
            imageSelectionnee == null
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Appuyez pour ajouter une image',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
                : null,
      ),
    );
  }
}
