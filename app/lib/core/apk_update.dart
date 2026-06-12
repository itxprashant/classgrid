import 'dart:io';

import 'package:apk_sideload/install_apk.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads a release APK and launches the Android package installer.
class ApkUpdateService {
  ApkUpdateService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 10),
            ));

  final Dio _dio;

  Future<String> downloadApk({
    required String url,
    int? cacheBustBuild,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw ApkUpdateException('Invalid download URL.');
    }

    final downloadUri = cacheBustBuild == null
        ? uri
        : uri.replace(
            queryParameters: {
              ...uri.queryParameters,
              'build': '$cacheBustBuild',
            },
          );

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/classgrid-update.apk';
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }

    try {
      await _dio.download(
        downloadUri.toString(),
        path,
        options: Options(
          headers: const {'Cache-Control': 'no-cache'},
        ),
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw ApkUpdateException('Download cancelled.');
      }
      throw ApkUpdateException(
        e.message?.isNotEmpty == true ? e.message! : 'Download failed.',
      );
    }

    if (!await file.exists() || await file.length() < 1024) {
      throw ApkUpdateException('Downloaded file is missing or too small.');
    }

    return path;
  }

  Future<void> installApk(String path) async {
    if (!Platform.isAndroid) {
      throw ApkUpdateException('In-app install is only supported on Android.');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw ApkUpdateException('Update file not found. Download again.');
    }

    try {
      await InstallApk().installApk(path);
    } on Exception catch (e) {
      throw ApkUpdateException(
        e.toString().contains('INSTALL_ERROR')
            ? 'Allow ClassGrid to install updates, then try again.'
            : 'Could not open the installer.',
      );
    }
  }
}

class ApkUpdateException implements Exception {
  ApkUpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}
