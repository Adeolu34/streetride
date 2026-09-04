import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/services/session_service.dart';

class RideState {
  final List<RideMessage> messages;
  final bool isLoading;
  final bool notifVisible;
  final String notifMessage;
  final String notifDetail;
  final int nearbyDriverCount;

  const RideState({
    this.messages = const [],
    this.isLoading = false,
    this.notifVisible = false,
    this.notifMessage = '',
    this.notifDetail = '',
    this.nearbyDriverCount = 0,
  });

  RideState copyWith({
    List<RideMessage>? messages,
    bool? isLoading,
    bool? notifVisible,
    String? notifMessage,
    String? notifDetail,
    int? nearbyDriverCount,
  }) => RideState(
    messages: messages ?? this.messages,
    isLoading: isLoading ?? this.isLoading,
    notifVisible: notifVisible ?? this.notifVisible,
    notifMessage: notifMessage ?? this.notifMessage,
    notifDetail: notifDetail ?? this.notifDetail,
    nearbyDriverCount: nearbyDriverCount ?? this.nearbyDriverCount,
  );

  RideMessage? get activeOffer {
    try {
      return messages.firstWhere(
        (m) => m.statusLabel == RideStatusLabel.offerReceived,
      );
    } catch (_) {
      return null;
    }
  }

  RideMessage? get activeRide {
    try {
      return messages.firstWhere(
        (m) =>
            m.statusLabel == RideStatusLabel.accepted ||
            m.statusLabel == RideStatusLabel.pickup ||
            m.statusLabel == RideStatusLabel.arrived ||
            m.statusLabel == RideStatusLabel.inTransit,
      );
    } catch (_) {
      return null;
    }
  }

  // Pending requests visible to the driver on their home screen (no price sent yet)
  List<RideMessage> pendingForDriver(String normalizedDriverPhone) {
    return messages.where((m) {
      if (m.driverPhone != normalizedDriverPhone) return false;
      if (m.priceByDriver.trim().isNotEmpty) return false;
      final movt = m.movtStatusDriver.toLowerCase();
      final ride = m.rideStatusRider.toLowerCase();
      if (movt.contains('cancel') || movt.contains('complet') || movt.contains('reject')) return false;
      if (ride.contains('cancel') || ride.contains('complet') || ride.contains('withdraw')) return false;
      return true;
    }).toList();
  }

  // Rides for rider's Trips tab — any ride with meaningful status
  List<RideMessage> historyForRider(String normalizedRiderPhone) {
    return messages.where((m) {
      if (m.riderPhone != normalizedRiderPhone) return false;
      final ride = m.rideStatusRider.toLowerCase().trim();
      final movt = m.movtStatusDriver.toLowerCase().trim();
      final hasPrice = m.priceByDriver.trim().isNotEmpty;
      final hasConfirm = m.confirmStatusRider.toLowerCase() == 'accept';
      return ride.isNotEmpty || movt.isNotEmpty || hasPrice || hasConfirm;
    }).toList();
  }

  // Rides for "My Rides" tab — driver has taken action (sent price or beyond)
  List<RideMessage> historyForDriver(String normalizedDriverPhone) {
    return messages.where((m) {
      if (m.driverPhone != normalizedDriverPhone) return false;
      final hasSentPrice = m.priceByDriver.trim().isNotEmpty;
      final movt = m.movtStatusDriver.toLowerCase().trim();
      final hasAdvancedMovt = movt.isNotEmpty && movt != 'new request';
      return hasSentPrice || hasAdvancedMovt;
    }).toList();
  }

  // Active pending requests the rider is waiting on (no price yet, not cancelled)
  List<RideMessage> get pendingRides => messages.where((m) {
    if (m.statusLabel != RideStatusLabel.pending) return false;
    final movt = m.movtStatusDriver.toLowerCase().trim();
    final ride = m.rideStatusRider.toLowerCase().trim();
    // Exclude anything that's truly finished but mapped to pending by statusLabel
    return movt.isEmpty || movt == 'new request';
  }).toList();
}

class RideNotifier extends Notifier<RideState> {
  Timer? _pollTimer;
  Timer? _nearbyTimer;
  // reqId → {movt, ride, price} — used to detect status changes between polls
  final Map<String, Map<String, String>> _lastStatus = {};

  @override
  RideState build() => const RideState();

  Future<void> poll() async {
    _pollTimer?.cancel();
    _nearbyTimer?.cancel();
    await _fetch();
    _fetchNearbyCount(); // fire and forget — don't block polling
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetch());
    _nearbyTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchNearbyCount());
  }

  Future<void> _fetchNearbyCount() async {
    try {
      double lat = 6.5244, lng = 3.3792; // Lagos default
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) { lat = pos.latitude; lng = pos.longitude; }
      } catch (_) {}

      final data = await ApiClient.instance.post({
        'theKey': 'R11.3',
        'FromLat': lat.toString(),
        'FromLong': lng.toString(),
      });
      final count = (data['Count'] as num?)?.toInt();
      if (count != null) state = state.copyWith(nearbyDriverCount: count);
    } catch (_) {}
  }

  Future<void> _fetch() async {
    final session = SessionService.instance;
    if (!session.isLoggedIn) return;
    final intlPhone = _toIntl(session.profile!.phone);
    final isDriver = session.isDriver;

    try {
      final data = await ApiClient.instance.post({
        'theKey': 'BK8',
        'phone': intlPhone,
      });

      final raw = data['Messages'];
      if (raw is! List) return;

      final messages = raw
          .whereType<Map<String, dynamic>>()
          .map(RideMessage.fromJson)
          .toList();

      // Detect status changes and build notification if needed
      String? notifMsg;
      String? notifDetail;

      for (final m in messages) {
        final newMovt = m.movtStatusDriver;
        final newRide = m.rideStatusRider;
        final newPrice = m.priceByDriver;
        final last = _lastStatus[m.reqId];

        if (last == null) {
          _lastStatus[m.reqId] = {'movt': newMovt, 'ride': newRide, 'price': newPrice};

          // Driver: new request appeared that is genuinely pending
          if (isDriver &&
              m.driverPhone == intlPhone &&
              newMovt.isEmpty &&
              newRide.isEmpty &&
              newPrice.isEmpty) {
            notifMsg = 'New ride request!';
            notifDetail = '${m.fromText} → ${m.toText}';
          }
        } else {
          final lastMovt = last['movt'] ?? '';
          final lastRide = last['ride'] ?? '';
          final lastPrice = last['price'] ?? '';
          _lastStatus[m.reqId] = {'movt': newMovt, 'ride': newRide, 'price': newPrice};

          if (!isDriver) {
            // Rider watching driver movement
            if (newMovt != lastMovt && newMovt.isNotEmpty) {
              final n = _riderNotifForMovt(newMovt, m);
              if (n != null) { notifMsg = n.$1; notifDetail = n.$2; }
            }
            // New price quoted
            if (newPrice != lastPrice && newPrice.isNotEmpty && lastPrice.isEmpty) {
              final name = m.driverName.isNotEmpty ? m.driverName : 'A driver';
              notifMsg = 'Price received!';
              notifDetail = '$name quoted ₦$newPrice for your trip';
            }
          } else {
            // Driver watching rider response
            if (newRide != lastRide && newRide.isNotEmpty) {
              // If movt also changed to a cancel/reject simultaneously, the driver
              // initiated this — don't show "rider cancelled" for the driver's own action.
              final driverInitiated = newMovt != lastMovt &&
                  (newMovt.toLowerCase().contains('cancel') ||
                   newMovt.toLowerCase().contains('reject'));
              if (!driverInitiated) {
                final n = _driverNotifForRide(newRide, m);
                if (n != null) { notifMsg = n.$1; notifDetail = n.$2; }
              }
            }
          }
        }
      }

      state = state.copyWith(
        messages: messages,
        notifVisible: notifMsg != null ? true : state.notifVisible,
        notifMessage: notifMsg ?? state.notifMessage,
        notifDetail: notifDetail ?? state.notifDetail,
      );
    } catch (_) {}
  }

  // Rider sees these when BK4 (MovtStatus_D) changes
  static (String, String)? _riderNotifForMovt(String movt, RideMessage m) {
    final from = m.fromText.isNotEmpty ? m.fromText : 'your location';
    switch (movt.toLowerCase().trim()) {
      case 'started':
        return ('Driver is on the way!', 'Heading to $from');
      case 'arrived':
        return ('Your driver has arrived!', 'Head out — they are waiting');
      case 'intransit':
        return ('Trip started', 'Enjoy your ride to ${m.toText}');
      case 'completed':
        return ('Trip completed', 'Rate your driver when ready');
      case 'cancel':
        return ('Driver cancelled', 'Look for another driver');
      case 'reject price':
        return ('Price rejected', 'The driver declined your counter-offer');
    }
    return null;
  }

  // Driver sees these when BK5 (RideStatus_R) changes
  static (String, String)? _driverNotifForRide(String ride, RideMessage m) {
    final dest = m.toText.isNotEmpty ? m.toText : 'destination';
    switch (ride.toLowerCase().trim()) {
      case 'accepted':
        return ('Rider accepted your price!', 'Head to pickup — going to $dest');
      case 'reject price':
      case 'reject ride':
        return ('Price rejected', 'The rider rejected your price');
      case 'cancelled':
      case 'withdraw':
        return ('Ride cancelled', 'The rider cancelled this request');
      case 'completed':
        return ('Trip completed', 'Great job! Check your earnings');
    }
    return null;
  }

  void dismissNotif() {
    state = state.copyWith(notifVisible: false);
  }

  // Rider accepts driver's price — BK3 confirms, BK4+BK5 sync both sides to Accepted
  Future<void> acceptOffer(RideMessage ride) async {
    try {
      await ApiClient.instance.post({'theKey': 'BK3', 'reqid': ride.reqId, 'status': 'accept'});
      await Future.wait([
        ApiClient.instance.post({'theKey': 'BK5', 'reqid': ride.reqId, 'status': 'Accepted'}),
        ApiClient.instance.post({'theKey': 'BK4', 'reqid': ride.reqId, 'status': 'Accepted'}),
      ]);
      await _fetch();
    } catch (_) {}
  }

  // Rider declines price — BK3 rejects, BK4+BK5 sync both sides to Reject Price
  Future<void> declineOffer(RideMessage ride) async {
    try {
      await ApiClient.instance.post({'theKey': 'BK3', 'reqid': ride.reqId, 'status': 'reject'});
      await Future.wait([
        ApiClient.instance.post({'theKey': 'BK5', 'reqid': ride.reqId, 'status': 'Reject Price'}),
        ApiClient.instance.post({'theKey': 'BK4', 'reqid': ride.reqId, 'status': 'Reject Price'}),
      ]);
      await _fetch();
    } catch (_) {}
  }

  // Rider withdraws/cancels — status-aware (matches FlutterFlow riderRejectOrCancelRide)
  Future<void> riderCancelRide(RideMessage ride) async {
    final movtStatus = ride.movtStatusDriver.trim();
    final rideStatus = ride.rideStatusRider.trim();
    final String bk5Status;
    final String bk4Status;

    if (rideStatus.isEmpty && movtStatus.isEmpty) {
      bk5Status = 'Withdraw';
      bk4Status = 'Cancel';
    } else if (movtStatus.toLowerCase() == 'set price' || ride.priceByDriver.isNotEmpty) {
      bk5Status = 'Reject Price';
      bk4Status = 'Reject Price';
    } else {
      bk5Status = 'Cancelled';
      bk4Status = 'Cancel';
    }

    try {
      await ApiClient.instance.post({'theKey': 'BK5', 'reqid': ride.reqId, 'status': bk5Status});
      await ApiClient.instance.post({'theKey': 'BK4', 'reqid': ride.reqId, 'status': bk4Status});
      await _fetch();
    } catch (_) {}
  }

  // Driver rejects/cancels — status-aware (matches FlutterFlow driverCancelOrRejectRide)
  Future<void> driverCancelRide(RideMessage ride) async {
    final isNewRequest = ride.movtStatusDriver.isEmpty || ride.movtStatusDriver == 'New Request';
    final bk4Status = isNewRequest ? 'Reject Price' : 'Cancel';
    final bk5Status = isNewRequest ? 'Reject Ride' : 'Cancelled';

    try {
      await ApiClient.instance.post({'theKey': 'BK4', 'reqid': ride.reqId, 'status': bk4Status});
      await ApiClient.instance.post({'theKey': 'BK5', 'reqid': ride.reqId, 'status': bk5Status});
      await _fetch();
    } catch (_) {}
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _nearbyTimer?.cancel();
  }
}

final rideProvider = NotifierProvider<RideNotifier, RideState>(RideNotifier.new);

String _toIntl(String phone) {
  final p = phone.trim();
  if (p.startsWith('234')) return p;
  if (p.startsWith('0')) return '234${p.substring(1)}';
  return '234$p';
}
