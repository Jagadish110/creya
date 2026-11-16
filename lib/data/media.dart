import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Limits for what a user may upload. The storage buckets enforce the same
/// sizes on the server.
abstract final class MediaLimits {
  static const clipLength = Duration(seconds: 20);
  static const clipBytes = 50 * 1024 * 1024;
  static const photoBytes = 5 * 1024 * 1024;
}

/// A photo or clip the user chose from their device.
class PickedMedia {
  const PickedMedia({required this.name, this.path, this.length});

  /// The file's name, for display.
  final String name;

  /// Where the file is on this device. Null for sample media.
  final String? path;

  /// A clip's playing time. Null for photos.
  final Duration? length;
}

/// Thrown when the chosen file can't be used. [message] is shown to the user.
class MediaRejected implements Exception {
  const MediaRejected(this.message);

  final String message;

  @override
  String toString() => 'MediaRejected: $message';
}

/// Lets the user choose media. Both methods return null if the user backs
/// out, and throw [MediaRejected] if the file breaks a limit.
abstract interface class MediaPicker {
  Future<PickedMedia?> pickPhoto();

  Future<PickedMedia?> pickClip();
}

/// Picks from the device's photo library.
class DeviceMediaPicker implements MediaPicker {
  final _picker = ImagePicker();

  @override
  Future<PickedMedia?> pickPhoto() async {
    // Resized on the way in, so a full-resolution camera photo still fits.
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    if (await file.length() > MediaLimits.photoBytes) {
      throw const MediaRejected(
        'That photo is too large. Choose one under 5 MB.',
      );
    }
    return PickedMedia(name: file.name, path: file.path);
  }

  @override
  Future<PickedMedia?> pickClip() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return null;

    final length = await _clipLength(file.path);
    // Half a second of grace, since cameras rarely stop on the exact frame.
    if (length > MediaLimits.clipLength + const Duration(milliseconds: 500)) {
      throw MediaRejected(
        'That clip is ${formatClipLength(length)} long. '
        'Choose one of ${MediaLimits.clipLength.inSeconds} seconds or less.',
      );
    }
    if (await file.length() > MediaLimits.clipBytes) {
      throw const MediaRejected(
        'That clip is too large. Choose one under 50 MB.',
      );
    }
    return PickedMedia(name: file.name, path: file.path, length: length);
  }

  Future<Duration> _clipLength(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      return controller.value.duration;
    } catch (_) {
      throw const MediaRejected(
        "That clip couldn't be read. Try an MP4 or MOV.",
      );
    } finally {
      await controller.dispose();
    }
  }
}

/// Stands in for the photo library with the design's sample files. Used by
/// tests and by previews that have no device to pick from.
class SampleMediaPicker implements MediaPicker {
  const SampleMediaPicker();

  @override
  Future<PickedMedia?> pickPhoto() async =>
      const PickedMedia(name: 'portrait.jpg');

  @override
  Future<PickedMedia?> pickClip() async => const PickedMedia(
    name: 'studio-session.mov',
    length: MediaLimits.clipLength,
  );
}

/// A clip length as `m:ss`, e.g. `0:20`.
String formatClipLength(Duration length) {
  final seconds = (length.inSeconds % 60).toString().padLeft(2, '0');
  return '${length.inMinutes}:$seconds';
}
