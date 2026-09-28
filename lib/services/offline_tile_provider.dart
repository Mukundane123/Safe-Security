import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

/// Tile provider that caches every downloaded OpenStreetMap tile to the device
/// so previously viewed areas keep working while offline. While online it
/// behaves like the network provider; once a tile has been fetched once it is
/// served from disk on every later visit (and can be used with no connection).
class OfflineTileProvider extends TileProvider {
  OfflineTileProvider._(this._cacheDir);

  final Directory _cacheDir;

  /// Resolves the on-device cache directory before any tiles are requested,
  /// so `getImage` can always read files synchronously.
  static Future<OfflineTileProvider> create() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(
        '${base.path}${Platform.pathSeparator}safeguard_tiles');
    if (!await dir.exists()) await dir.create(recursive: true);
    return OfflineTileProvider._(dir);
  }

  static Future<void> clearCache() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(
        '${base.path}${Platform.pathSeparator}safeguard_tiles');
    if (!await dir.exists()) return;
    for (final f in await dir.list().toList()) {
      try {
        await f.delete(recursive: true);
      } catch (_) {}
    }
  }

  File _fileFor(TileCoordinates c) =>
      File('${_cacheDir.path}${Platform.pathSeparator}'
          '${c.z}_${c.x}_${c.y}.png');

  String _tileUrl(TileCoordinates c, TileLayer options) {
    var url = (options.urlTemplate ?? '')
        .replaceAll('{z}', '${c.z}')
        .replaceAll('{x}', '${c.x}')
        .replaceAll('{y}', '${c.y}');
    if (options.subdomains.isNotEmpty) {
      final sub = options.subdomains[c.x % options.subdomains.length];
      url = url.replaceAll('{s}', sub);
    }
    return url;
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final file = _fileFor(coordinates);
    if (file.existsSync()) {
      return FileImage(file);
    }
    final url = _tileUrl(coordinates, options);
    // Download on demand while persisting a copy for later offline use.
    unawaited(_persist(coordinates, url));
    return NetworkImage(url);
  }

  Future<void> _persist(TileCoordinates c, String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        client.close();
        return;
      }
      final builder = BytesBuilder();
      await for (final chunk in response) {
        builder.add(chunk);
      }
      client.close();
      if (builder.length > 0) {
        await _fileFor(c).writeAsBytes(builder.toBytes(), flush: true);
      }
    } catch (_) {
      // Offline or transient error - the network provider handles the display.
    }
  }
}