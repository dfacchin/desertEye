import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import '../constants/map_constants.dart';

class TileCacheService {
  static const String storeName = 'desertEyeMapStore';

  FMTCStore get store => FMTCStore(storeName);

  /// Tile provider per modalità online (cache + network)
  FMTCTileProvider createOnlineTileProvider() {
    return FMTCTileProvider(
      stores: {storeName: BrowseStoreStrategy.readUpdateCreate},
      loadingStrategy: BrowseLoadingStrategy.cacheFirst,
    );
  }

  /// Tile provider per modalità offline (solo cache)
  FMTCTileProvider createOfflineTileProvider() {
    return FMTCTileProvider(
      stores: {storeName: BrowseStoreStrategy.read},
      loadingStrategy: BrowseLoadingStrategy.cacheOnly,
    );
  }

  /// Verifica se ci sono tiles in cache
  Future<bool> hasCachedTiles() async {
    final stats = await store.stats.all;
    return stats.length > 0;
  }

  /// Statistiche cache
  Future<({int tiles, double sizeMB})> getCacheStats() async {
    final stats = await store.stats.all;
    return (
      tiles: stats.length,
      sizeMB: stats.size / (1024 * 1024),
    );
  }

  /// Conta tiles per una regione
  Future<int> countTilesForRegion({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
  }) async {
    final region = RectangleRegion(bounds);

    final downloadableRegion = region.toDownloadable(
      minZoom: minZoom,
      maxZoom: maxZoom,
      options: TileLayer(
        urlTemplate: MapConstants.osmTileUrl,
        userAgentPackageName: MapConstants.userAgent,
      ),
    );

    return await store.download.countTiles(downloadableRegion);
  }

  /// Scarica tiles per una regione
  Future<Stream<DownloadProgress>> downloadRegion({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
  }) async {
    final region = RectangleRegion(bounds);

    final downloadableRegion = region.toDownloadable(
      minZoom: minZoom,
      maxZoom: maxZoom,
      options: TileLayer(
        urlTemplate: MapConstants.osmTileUrl,
        userAgentPackageName: MapConstants.userAgent,
      ),
    );

    return store.download
        .startForeground(region: downloadableRegion)
        .downloadProgress;
  }

  /// Cancella cache
  Future<void> clearCache() async {
    await store.manage.reset();
  }
}
