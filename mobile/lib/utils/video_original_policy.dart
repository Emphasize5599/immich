import 'package:immich_mobile/extensions/network_capability_extensions.dart';
import 'package:immich_mobile/platform/connectivity_api.g.dart';

/// Compares a resolved server endpoint against the saved local-network endpoint
/// by host and port only, since [serverEndpoint] may carry a resolved API path
/// (e.g. the `/api` suffix added by `/.well-known/immich` discovery) that the
/// user-entered [localEndpoint] preference does not.
bool isLocalEndpoint(String serverEndpoint, String? localEndpoint) {
  if (localEndpoint == null) {
    return false;
  }

  final server = Uri.tryParse(serverEndpoint);
  final local = Uri.tryParse(localEndpoint);
  if (server == null || local == null || server.host.isEmpty || local.host.isEmpty) {
    return false;
  }

  return server.host.toLowerCase() == local.host.toLowerCase() && _port(server) == _port(local);
}

int _port(Uri uri) => uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

bool shouldUseOriginalVideo({
  required bool forceOriginalVideo,
  required bool originalOnWifi,
  required bool originalOnCellular,
  required bool requireLan,
  required List<NetworkCapability> capabilities,
  required bool isLocalConnection,
}) {
  if (!forceOriginalVideo) {
    return false;
  }
  if (capabilities.hasWifi) {
    return originalOnWifi && (!requireLan || isLocalConnection);
  }
  if (capabilities.hasCellular) {
    return originalOnCellular;
  }
  // Unknown/other transport (e.g. ethernet, no active network): be conservative.
  return false;
}
