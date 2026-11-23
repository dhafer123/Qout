import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/core/photos/label_photo_picker.dart' show PhotoSource;
import 'package:qout/features/profile/data/profile_photo_picker.dart';
import 'package:qout/features/profile/data/profile_repository.dart';

/// How a profile photo file is drawn (tests draw one from memory).
final profilePhotoImageProvider = Provider<ImageProvider Function(File)>(
  (ref) => FileImage.new,
);

/// The profile photo in a circle (T43c); without one (or when it can't be
/// drawn), the first name's initial, or a person icon without a name.
/// Decorative: the name is always written next to it.
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({
    required this.size,
    required this.firstName,
    required this.background,
    required this.foreground,
    this.border,
    super.key,
  });

  final double size;
  final String? firstName;
  final Color background;
  final Color foreground;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(profilePhotoProvider).valueOrNull;
    final name = firstName;
    final fallback = Center(
      child: name == null
          ? Icon(PhosphorIconsRegular.user, color: foreground)
          : Text(
              name.characters.first.toUpperCase(),
              style: TextStyle(
                color: foreground,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
            border: border,
          ),
          child: photo == null
              ? fallback
              : ClipOval(
                  child: Image(
                    key: const ValueKey('profile-photo'),
                    image: ref.watch(profilePhotoImageProvider)(photo),
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => fallback,
                  ),
                ),
        ),
      ),
    );
  }
}

enum _PhotoChoice { camera, gallery, remove }

/// The Profile header's avatar: tapping it takes or picks a new photo, or
/// removes the current one.
class EditableProfileAvatar extends ConsumerWidget {
  const EditableProfileAvatar({
    required this.firstName,
    required this.background,
    required this.foreground,
    required this.badgeBackground,
    required this.badgeForeground,
    this.border,
    super.key,
  });

  final String? firstName;
  final Color background;
  final Color foreground;
  final Color badgeBackground;
  final Color badgeForeground;
  final BoxBorder? border;

  static const _size = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPhoto = ref.watch(profilePhotoProvider).valueOrNull != null;
    void open() => unawaited(_choose(context, ref, hasPhoto: hasPhoto));
    return Semantics(
      container: true,
      button: true,
      label: hasPhoto ? 'Change profile photo' : 'Add a profile photo',
      onTap: open,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('profile-photo-button'),
        customBorder: const CircleBorder(),
        onTap: open,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ProfileAvatar(
              size: _size,
              firstName: firstName,
              background: background,
              foreground: foreground,
              border: border,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeBackground,
                  border: Border.all(color: background, width: 1.5),
                ),
                child: Icon(
                  PhosphorIconsFill.camera,
                  size: 12,
                  color: badgeForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref, {
    required bool hasPhoto,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => _PhotoSheet(hasPhoto: hasPhoto),
    );
    if (choice == null) return;
    final repository = ref.read(profileRepositoryProvider);
    try {
      switch (choice) {
        case _PhotoChoice.remove:
          await repository.removePhoto();
        case _PhotoChoice.camera || _PhotoChoice.gallery:
          final path = await ref.read(profilePhotoPickerProvider)(
            choice == _PhotoChoice.camera
                ? PhotoSource.camera
                : PhotoSource.gallery,
          );
          if (path == null) return; // cancelled
          await repository.setPhoto(path);
      }
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('The photo could not be changed')),
      );
    }
  }
}

class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet({required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    void pick(_PhotoChoice choice) => Navigator.of(context).pop(choice);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                'Profile photo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'It stays on this phone.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.camera),
              title: const Text('Take a photo'),
              onTap: () => pick(_PhotoChoice.camera),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.image),
              title: const Text('Choose from gallery'),
              onTap: () => pick(_PhotoChoice.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(PhosphorIconsRegular.trash, color: error),
                title: Text('Remove photo', style: TextStyle(color: error)),
                onTap: () => pick(_PhotoChoice.remove),
              ),
          ],
        ),
      ),
    );
  }
}
