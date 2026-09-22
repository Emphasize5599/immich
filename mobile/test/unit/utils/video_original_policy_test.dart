import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/platform/connectivity_api.g.dart';
import 'package:immich_mobile/utils/video_original_policy.dart';

void main() {
  group('shouldUseOriginalVideo', () {
    bool decide({
      bool forceOriginalVideo = true,
      bool originalOnWifi = true,
      bool originalOnCellular = false,
      bool requireLan = false,
      List<NetworkCapability> capabilities = const [NetworkCapability.wifi],
      bool isLocalConnection = false,
    }) {
      return shouldUseOriginalVideo(
        forceOriginalVideo: forceOriginalVideo,
        originalOnWifi: originalOnWifi,
        originalOnCellular: originalOnCellular,
        requireLan: requireLan,
        capabilities: capabilities,
        isLocalConnection: isLocalConnection,
      );
    }

    test('always false when the master toggle is off, regardless of other flags', () {
      expect(
        decide(
          forceOriginalVideo: false,
          originalOnWifi: true,
          originalOnCellular: true,
          requireLan: false,
          capabilities: const [NetworkCapability.wifi, NetworkCapability.cellular],
          isLocalConnection: true,
        ),
        isFalse,
      );
    });

    test('Wi-Fi + originalOnWifi true + requireLan false -> true', () {
      expect(
        decide(capabilities: const [NetworkCapability.wifi], originalOnWifi: true, requireLan: false),
        isTrue,
      );
    });

    test('Wi-Fi + originalOnWifi false -> false', () {
      expect(decide(capabilities: const [NetworkCapability.wifi], originalOnWifi: false), isFalse);
    });

    test('Wi-Fi + requireLan true + isLocalConnection true -> true', () {
      expect(
        decide(
          capabilities: const [NetworkCapability.wifi],
          originalOnWifi: true,
          requireLan: true,
          isLocalConnection: true,
        ),
        isTrue,
      );
    });

    test('Wi-Fi + requireLan true + isLocalConnection false -> false', () {
      expect(
        decide(
          capabilities: const [NetworkCapability.wifi],
          originalOnWifi: true,
          requireLan: true,
          isLocalConnection: false,
        ),
        isFalse,
      );
    });

    test('cellular + originalOnCellular true -> true', () {
      expect(
        decide(capabilities: const [NetworkCapability.cellular], originalOnCellular: true),
        isTrue,
      );
    });

    test('cellular + originalOnCellular false (default) -> false', () {
      expect(
        decide(capabilities: const [NetworkCapability.cellular], originalOnCellular: false),
        isFalse,
      );
    });

    test('no wifi or cellular capability -> false', () {
      expect(decide(capabilities: const []), isFalse);
      expect(decide(capabilities: const [NetworkCapability.vpn]), isFalse);
    });

    test('when both wifi and cellular are reported, the Wi-Fi rule takes precedence', () {
      expect(
        decide(
          capabilities: const [NetworkCapability.wifi, NetworkCapability.cellular],
          originalOnWifi: true,
          originalOnCellular: false,
        ),
        isTrue,
      );
      expect(
        decide(
          capabilities: const [NetworkCapability.wifi, NetworkCapability.cellular],
          originalOnWifi: false,
          originalOnCellular: true,
        ),
        isFalse,
      );
    });
  });

  group('isLocalEndpoint', () {
    test('matches when the resolved server endpoint carries an /api suffix the saved endpoint lacks', () {
      // Regression: /.well-known/immich discovery resolves the stored server
      // endpoint to <host>:<port>/api, while the user-entered local network
      // preference is saved as the bare <host>:<port> they typed.
      expect(isLocalEndpoint('http://192.168.0.52:2283/api', 'http://192.168.0.52:2283'), isTrue);
    });

    test('matches identical host and port', () {
      expect(isLocalEndpoint('http://192.168.0.52:2283', 'http://192.168.0.52:2283'), isTrue);
    });

    test('matches regardless of host case', () {
      expect(isLocalEndpoint('http://MyServer.local:2283/api', 'http://myserver.local:2283'), isTrue);
    });

    test('does not match a different host', () {
      expect(isLocalEndpoint('http://192.168.0.52:2283/api', 'http://192.168.0.53:2283'), isFalse);
    });

    test('does not match a different port', () {
      expect(isLocalEndpoint('http://192.168.0.52:2283/api', 'http://192.168.0.52:2284'), isFalse);
    });

    test('falls back to scheme default port when none is specified', () {
      expect(isLocalEndpoint('https://immich.local/api', 'https://immich.local:443'), isTrue);
      expect(isLocalEndpoint('http://immich.local/api', 'http://immich.local:443'), isFalse);
    });

    test('false when no local endpoint is saved', () {
      expect(isLocalEndpoint('http://192.168.0.52:2283/api', null), isFalse);
    });

    test('false for an unparsable endpoint', () {
      expect(isLocalEndpoint('not a url', 'http://192.168.0.52:2283'), isFalse);
      expect(isLocalEndpoint('http://192.168.0.52:2283/api', 'not a url'), isFalse);
    });
  });
}
