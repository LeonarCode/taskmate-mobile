import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// The backend keeps profile pictures at 512x512 at most (Cloudinary `limit`
/// crop), so there is no point in uploading more pixels than that.
const kProfilePhotoMaxSide = 512;

/// Resolves a photo that may be either:
/// - a remote https URL (Cloudinary, or a Google profile picture)
/// - a base64 data URL ("data:image/jpeg;base64,...", which the backend only
///   returns when it has no Cloudinary configured)
/// - null (no photo set)
ImageProvider? resolvePhoto(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;
  if (photoUrl.startsWith('data:image')) {
    try {
      return MemoryImage(base64Decode(photoUrl.split(',').last));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(photoUrl);
}

/// Prepares a picked picture for upload: upright, at most
/// [kProfilePhotoMaxSide] pixels on the longer side, as a JPEG. Runs off the UI
/// thread. Throws if [bytes] isn't an image the app can read.
Future<Uint8List> compressPhoto(Uint8List bytes) async {
  final jpeg = await compute(_toProfileJpeg, bytes);
  if (jpeg == null) {
    throw Exception(
      'That file could not be read as an image. Please choose a different picture.',
    );
  }
  return jpeg;
}

Uint8List? _toProfileJpeg(Uint8List bytes) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // Some decoders throw (rather than return null) on a truncated or odd file.
    return null;
  }
  if (decoded == null) return null;

  // Photos carry their rotation in metadata, which is lost when re-encoding.
  var out = img.bakeOrientation(decoded);

  // JPEG has no transparency; without this a transparent PNG turns black.
  if (out.hasAlpha) {
    final flat = img.Image(width: out.width, height: out.height);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, out);
    out = flat;
  }

  if (out.width > kProfilePhotoMaxSide || out.height > kProfilePhotoMaxSide) {
    out = out.width >= out.height
        ? img.copyResize(out, width: kProfilePhotoMaxSide)
        : img.copyResize(out, height: kProfilePhotoMaxSide);
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: 85));
}
