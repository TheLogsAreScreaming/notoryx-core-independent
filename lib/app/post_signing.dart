/// Settings for signing channel posts.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';

/// Off when set to '0'. SOS and check-ins are signed unless turned off.
const signSafetySetting = 'sign_safety';

/// On when set to '1'. Ordinary posts aren't signed unless turned on.
const signAllSetting = 'sign_posts';

class PostSigning extends AsyncNotifier<({bool safety, bool all})> {
  @override
  Future<({bool safety, bool all})> build() async {
    final store = ref.read(storeProvider);
    return (
      safety: await store.setting(signSafetySetting) != '0',
      all: await store.setting(signAllSetting) == '1',
    );
  }

  Future<void> set({bool? safety, bool? all}) async {
    final store = ref.read(storeProvider);
    final now = await future;
    final next = (safety: safety ?? now.safety, all: all ?? now.all);
    await store.saveSetting(signSafetySetting, next.safety ? '1' : '0');
    await store.saveSetting(signAllSetting, next.all ? '1' : '0');
    state = AsyncData(next);
  }
}

final postSigningProvider =
    AsyncNotifierProvider<PostSigning, ({bool safety, bool all})>(
      PostSigning.new,
    );
