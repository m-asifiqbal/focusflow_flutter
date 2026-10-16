/// ============================================================
/// NOTE IMAGE PICKER — gallery / camera for the editor's image button
/// ============================================================
///
/// Thin wrapper over image_picker so widget tests can fake it. Returns the
/// picked file's temporary path; the editor controller copies it into the
/// note's attachments (NoteFileStore) and embeds the *relative* path.
/// ============================================================
library;

import 'package:image_picker/image_picker.dart';

/// Where the editor's image comes from.
enum NoteImageSource { gallery, camera }

abstract interface class NoteImagePicker {
  /// The picked image's temporary path, or null when cancelled.
  Future<String?> pick(NoteImageSource source);
}

class DeviceNoteImagePicker implements NoteImagePicker {
  DeviceNoteImagePicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Long edge cap — keeps attachments (and backups) small.
  static const double maxDimension = 2048;

  @override
  Future<String?> pick(NoteImageSource source) async {
    final file = await _picker.pickImage(
      source: switch (source) {
        NoteImageSource.gallery => ImageSource.gallery,
        NoteImageSource.camera => ImageSource.camera,
      },
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: 85,
    );
    return file?.path;
  }
}
