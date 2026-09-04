import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ride_api.dart';
import '../../../core/models/wallet_model.dart';
import '../../../core/services/session_service.dart';

class WalletNotifier extends AsyncNotifier<WalletStatus> {
  @override
  Future<WalletStatus> build() => _fetch();

  Future<WalletStatus> _fetch() async {
    final phone = SessionService.instance.profile?.phone ?? '';
    if (phone.isEmpty) return WalletStatus.active();
    try {
      final data = await RideApi.instance.getWalletStatus(phone);
      return WalletStatus.fromJson(data);
    } catch (_) {
      return WalletStatus.active();
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetch());
  }

  // Returns (paymentUrl, errorMessage) — one will be null
  Future<(String?, String?)> getPaymentUrl({required String amount}) async {
    final profile = SessionService.instance.profile;
    final phone = profile?.phone ?? '';
    if (phone.isEmpty) return (null, 'No phone number found. Please log in again.');
    try {
      final wallet = state.valueOrNull;
      final result = await RideApi.instance.makeSubscriptionPayment(
        phone: phone,
        name: profile?.fullName ?? '',
        email: profile?.email ?? '',
        amount: amount,
        nodays: wallet?.noofdays ?? '30',
      );
      // Walk the nested response: { data: { data: { link: "..." } } }
      String? link = _extractLink(result);
      if (link != null && link.isNotEmpty) return (link, null);

      // Surface whatever the API said
      final msg = result['message']?.toString() ??
          result['Message']?.toString() ??
          'No payment link returned (response: $result)';
      return (null, msg);
    } catch (e) {
      return (null, e.toString());
    }
  }

  static String? _extractLink(Map<String, dynamic> r) {
    // Try depth-2: data.data.link
    final d1 = r['data'];
    if (d1 is Map) {
      final d2 = d1['data'];
      if (d2 is Map) {
        final link = d2['link']?.toString();
        if (link != null && link.isNotEmpty) return link;
      }
      // Try depth-1: data.link
      final link = d1['link']?.toString();
      if (link != null && link.isNotEmpty) return link;
    }
    // Try top-level link
    return r['link']?.toString();
  }
}

final walletProvider =
    AsyncNotifierProvider<WalletNotifier, WalletStatus>(WalletNotifier.new);
