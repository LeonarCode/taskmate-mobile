import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:taskmate_ui/core/image_utils.dart';
import 'package:taskmate_ui/models/user_model.dart';

// With CLOUDINARY_URL set, the backend stores profile photos on Cloudinary and
// returns an https URL as `photo_url`. The app uploads the picture as a file.
void main() {
  const cloudinaryUrl =
      'https://res.cloudinary.com/demo/image/upload/v1760000000/taskmate/avatars/7.jpg';

  group('showing a photo', () {
    test('an https photo_url is shown as a network image', () {
      expect(resolvePhoto(cloudinaryUrl), isA<NetworkImage>());
      expect((resolvePhoto(cloudinaryUrl)! as NetworkImage).url, cloudinaryUrl);
    });

    test('a data URL (backend without Cloudinary) still works', () {
      // 1x1 transparent PNG
      const dataUrl =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
      expect(resolvePhoto(dataUrl), isA<MemoryImage>());
    });

    test('no photo gives no image', () {
      expect(resolvePhoto(null), isNull);
      expect(resolvePhoto(''), isNull);
    });

    test('a profile with a Cloudinary photo parses and caches', () {
      final user = UserModel.fromJson({
        'id': 7,
        'username': 'leo',
        'email': 'leo@example.com',
        'fullname': 'Leonard Balaba',
        'age': 21,
        'user_type': 'student',
        'photo_url': cloudinaryUrl,
        'average_rating': 0.0,
        'rating_count': 0,
        'created_at': '2026-10-01T00:00:00Z',
      });
      expect(user.photoUrl, cloudinaryUrl);
      expect(user.asPublic.hasPhoto, isTrue);
      // The offline cache keeps the short URL, not image data.
      expect(UserModel.fromJson(user.toJson()).photoUrl, cloudinaryUrl);
    });
  });

  group('preparing a photo for upload', () {
    Uint8List png(int width, int height, {int channels = 3}) {
      final image = img.Image(
        width: width,
        height: height,
        numChannels: channels,
      );
      if (channels == 3) {
        img.fill(image, color: img.ColorRgb8(200, 30, 90));
      }
      return Uint8List.fromList(img.encodePng(image));
    }

    test('a large picture becomes a JPEG of at most 512px', () async {
      final out = await compressPhoto(png(1200, 800));

      expect(out.sublist(0, 3), [0xFF, 0xD8, 0xFF]); // JPEG signature
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 512);
      expect(decoded.height, inInclusiveRange(340, 342)); // keeps the ratio
      expect(out.length, lessThan(200 * 1024));
    });

    test('a tall picture is limited by its height', () async {
      final decoded = img.decodeJpg(await compressPhoto(png(600, 1500)))!;
      expect(decoded.height, 512);
      expect(decoded.width, inInclusiveRange(204, 206));
    });

    test('a small picture is not enlarged', () async {
      final decoded = img.decodeJpg(await compressPhoto(png(100, 80)))!;
      expect(decoded.width, 100);
      expect(decoded.height, 80);
    });

    test('a transparent PNG gets a white background, not black', () async {
      final out = await compressPhoto(png(64, 64, channels: 4));
      final pixel = img.decodeJpg(out)!.getPixel(2, 2);
      expect(pixel.r, greaterThan(240));
      expect(pixel.g, greaterThan(240));
      expect(pixel.b, greaterThan(240));
    });

    test('something that is not an image is rejected', () async {
      await expectLater(
        compressPhoto(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('could not be read as an image'),
          ),
        ),
      );
    });
  });
}
