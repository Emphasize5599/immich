import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/infrastructure/loaders/remote_image_fetch_scheduler.dart';
import 'package:immich_mobile/platform/remote_image_api.g.dart';
import 'package:immich_mobile/presentation/widgets/images/remote_image_provider.dart';

void main() {
  const api = 'dev.flutter.pigeon.immich_mobile.RemoteImageApi';
  const requestImage = BasicMessageChannel<Object?>('$api.requestImage', RemoteImageApi.pigeonChannelCodec);
  const cancelRequest = BasicMessageChannel<Object?>('$api.cancelRequest', RemoteImageApi.pigeonChannelCodec);

  // These tests deliberately leave a fetch in flight to assert on its
  // pending/not-cancelled state, which would otherwise leave the scheduler's
  // real safety-net Timer scheduled 20 seconds past the test's own end.
  // Shrinking it lets a pump of that same duration resolve it within the test.
  setUp(() => RemoteImageFetchScheduler.fetchTimeoutForTesting = const Duration(milliseconds: 10));
  tearDown(RemoteImageFetchScheduler.resetFetchTimeoutForTesting);

  testWidgets('a face url that changes while the avatar animates keeps both loads in flight', (tester) async {
    // Regression guard for a deliberate fork divergence: RemoteImageRequest
    // never calls the native cancelRequest for an already-dispatched fetch -
    // cancelling in-flight Cronet requests has been observed to crash the
    // native HTTP engine outright, so a superseded load is left to run to
    // completion and its stale result is discarded by isCancelled checks
    // instead. So changing the URL must not remove the earlier request here.
    final inFlight = <Object?, Object?>{};
    tester.binding.defaultBinaryMessenger
      ..setMockDecodedMessageHandler<Object?>(requestImage, (message) {
        final [url, id, ...] = message! as List<Object?>;
        inFlight[id] = url;
        return Completer<Object?>().future;
      })
      ..setMockDecodedMessageHandler<Object?>(cancelRequest, (message) async {
        inFlight.remove((message! as List<Object?>).first);
        return const <Object?>[null];
      });
    Widget avatar(String url) => MaterialApp(
      home: CircleAvatar(backgroundImage: RemoteImageProvider(url: url)),
    );

    await tester.pumpWidget(avatar('https://example.test/before'));
    await tester.pumpWidget(avatar('https://example.test/after'));
    // Lets the scheduler's shrunk safety-net timeout resolve every fetch (to
    // null, same as a real native timeout) so none leak past the test, even
    // across however many waves it takes to settle.
    await tester.pumpAndSettle(const Duration(milliseconds: 10));

    // Order/count of 'before' requests isn't the point here - what matters is
    // that neither URL's requests are ever removed via a cancelRequest call.
    expect(inFlight.values.toSet(), {'https://example.test/before', 'https://example.test/after'});
  });

  testWidgets('a cancelled load that fails late keeps the next load of the same image', (tester) async {
    final replies = <Completer<Object?>>[];
    tester.binding.defaultBinaryMessenger
      ..setMockDecodedMessageHandler<Object?>(requestImage, (_) {
        final reply = Completer<Object?>();
        replies.add(reply);
        return reply.future;
      })
      ..setMockDecodedMessageHandler<Object?>(cancelRequest, (_) async => const <Object?>[null]);
    const provider = RemoteImageProvider(url: 'https://example.test/face');
    final listener = ImageStreamListener((_, _) {});

    // Show the image and hide it again before it loads, which cancels the first load
    final first = provider.resolve(ImageConfiguration.empty)..addListener(listener);
    await tester.pump();
    first.removeListener(listener);
    // Showing the same image again has to start a second load
    provider.resolve(ImageConfiguration.empty);
    await tester.pump();
    expect(replies, hasLength(2));
    // The cancelled request only fails now, and that must not throw away the second load
    replies.first.complete(const <Object?>['error', 'late failure', null]);
    await tester.pump();

    expect(PaintingBinding.instance.imageCache.statusForKey(provider).pending, isTrue);

    // The second load was deliberately left pending above to assert that; let
    // the scheduler's shrunk safety-net timeout resolve it so it doesn't leak
    // a real Timer past this test's end.
    await tester.pump(const Duration(milliseconds: 50));
  });
}
