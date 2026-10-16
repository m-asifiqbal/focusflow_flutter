/// ============================================================
/// PROFILE PHOTO PICKER — gallery / camera picture for the avatar
/// ============================================================
///
/// Returns small JPEG bytes (≤ 512 px) for the local profile picture on
/// Account & profile (screen 36). The picture never leaves the device.
/// Behind a provider so widget tests can fake it.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

abstract interface class ProfilePhotoPicker {
  /// Picked picture bytes, or null when cancelled.
  Future<Uint8List?> pick({required bool camera});
}

class DeviceProfilePhotoPicker implements ProfilePhotoPicker {
  DeviceProfilePhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// The avatar is at most 96 pt (@3x ≈ 288 px); 512 leaves headroom.
  static const double maxDimension = 512;

  @override
  Future<Uint8List?> pick({required bool camera}) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }
}

final profilePhotoPickerProvider = Provider<ProfilePhotoPicker>(
  (ref) => DeviceProfilePhotoPicker(),
);
