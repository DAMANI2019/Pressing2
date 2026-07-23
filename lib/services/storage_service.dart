import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';

class StorageService {
  StorageService(this._client);
  final SupabaseClient _client;
  final _uuid = const Uuid();

  Future<String> uploaderPhotoHabit({
    required String pressingId,
    required String prestationId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final nom = '${_uuid.v4()}.jpg';
    final chemin = '$pressingId/$prestationId/$nom';

    await _client.storage.from(bucketPhotosHabits).uploadBinary(
          chemin,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return _client.storage.from(bucketPhotosHabits).getPublicUrl(chemin);
  }
}
