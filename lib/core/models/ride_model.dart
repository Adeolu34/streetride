class RideMessage {
  final String id;
  final String reqId;
  final String riderPhone;
  final String driverPhone;
  final String sender;
  final String fromLat;
  final String fromLng;
  final String toLat;
  final String toLng;
  final String km;
  final String estimatedTime;
  final String priceByDriver;
  final String confirmStatusDriver;
  final String confirmStatusRider;
  final String movtStatusDriver;  // BK4: 'Started','Arrived','InTransit','Completed','Cancel'
  final String rideStatusRider;   // BK5: 'Accepted','Boarded','Completed','Cancelled','NoShow'
  final String commentRider;
  final String ratingRider;
  final String safetyRider;
  final String redFlagDriver;
  final String commentDriver;
  final String requestTime;
  final String rideEndTimeRider;
  final String rideEndTimeDriver;
  final String fromText;
  final String toText;
  final String otherText;
  final String vehicleType;
  final String fairnessRider;
  final String carConditionRider;
  final String glassBody;
  final String airConditioning;
  final String riderName;   // Rname = the rider's name
  final String driverName;  // Dname = the driver's name
  final double driverNeatness;
  final double driverQualityScore;
  final int issueWithDriver;

  const RideMessage({
    required this.id,
    required this.reqId,
    required this.riderPhone,
    required this.driverPhone,
    required this.sender,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    required this.km,
    required this.estimatedTime,
    required this.priceByDriver,
    required this.confirmStatusDriver,
    required this.confirmStatusRider,
    required this.movtStatusDriver,
    required this.rideStatusRider,
    required this.commentRider,
    required this.ratingRider,
    required this.safetyRider,
    required this.redFlagDriver,
    required this.commentDriver,
    required this.requestTime,
    required this.rideEndTimeRider,
    required this.rideEndTimeDriver,
    required this.fromText,
    required this.toText,
    required this.otherText,
    required this.vehicleType,
    required this.fairnessRider,
    required this.carConditionRider,
    required this.glassBody,
    required this.airConditioning,
    required this.riderName,
    required this.driverName,
    required this.driverNeatness,
    required this.driverQualityScore,
    required this.issueWithDriver,
  });

  factory RideMessage.fromJson(Map<String, dynamic> j) => RideMessage(
        id: (j['id'] ?? '').toString(),
        reqId: (j['reqid'] ?? '').toString(),
        riderPhone: (j['rphone'] ?? '').toString(),
        driverPhone: (j['dphone'] ?? '').toString(),
        sender: (j['sender'] ?? '').toString(),
        fromLat: (j['fromLat'] ?? '').toString(),
        fromLng: (j['fromLong'] ?? '').toString(),
        toLat: (j['toLat'] ?? '').toString(),
        toLng: (j['toLong'] ?? '').toString(),
        km: (j['km'] ?? '').toString(),
        estimatedTime: (j['tm'] ?? '').toString(),
        priceByDriver: (j['Price_D'] ?? '').toString(),
        confirmStatusDriver: (j['ConfirmStatus_D'] ?? '').toString(),
        confirmStatusRider: (j['ConfirmStatus_R'] ?? '').toString(),
        movtStatusDriver: (j['MovtStatus_D'] ?? '').toString(),
        rideStatusRider: (j['RideStatus_R'] ?? '').toString(),
        commentRider: (j['Comment_R'] ?? '').toString(),
        ratingRider: (j['Rate_R'] ?? '').toString(),
        safetyRider: (j['safety_R'] ?? '').toString(),
        redFlagDriver: (j['red_flag_D'] ?? '').toString(),
        commentDriver: (j['commentD'] ?? '').toString(),
        requestTime: (j['Reqtime'] ?? '').toString(),
        rideEndTimeRider: (j['RideEndtime_R'] ?? '').toString(),
        rideEndTimeDriver: (j['RideEndtime_D'] ?? '').toString(),
        fromText: (j['fromText'] ?? '').toString(),
        toText: (j['toText'] ?? '').toString(),
        otherText: (j['othertext'] ?? '').toString(),
        vehicleType: (j['vtype'] ?? '').toString(),
        fairnessRider: (j['fairness_R'] ?? '').toString(),
        carConditionRider: (j['carcondition_R'] ?? '').toString(),
        glassBody: (j['gbody'] ?? '').toString(),
        airConditioning: (j['ac'] ?? '').toString(),
        riderName: (j['Rname'] ?? '').toString(),
        driverName: (j['Dname'] ?? '').toString(),
        driverNeatness: (j['DriverNeatness'] as num? ?? 0).toDouble(),
        driverQualityScore: (j['DriverQualityScore'] as num? ?? 0).toDouble(),
        issueWithDriver: (j['IssueWithDriver'] as num? ?? 0).toInt(),
      );

  RideStatusLabel get statusLabel {
    final s = rideStatusRider.toLowerCase().trim();
    final m = movtStatusDriver.toLowerCase().trim();

    // Driver movement states (BK4) take priority — matched to official API values
    if (m == 'intransit') return RideStatusLabel.inTransit;
    if (m == 'arrived') return RideStatusLabel.arrived;
    if (m == 'started') return RideStatusLabel.pickup;
    if (m == 'completed') return RideStatusLabel.completed;
    if (m.contains('cancel')) return RideStatusLabel.cancelled;
    if (m.contains('reject')) return RideStatusLabel.rejected;
    if (m == 'set price') return RideStatusLabel.offerReceived;

    // Rider status (BK5) — matched to official API values
    if (s == 'boarded') return RideStatusLabel.inTransit;
    if (s == 'accepted') return RideStatusLabel.accepted;
    if (s == 'completed') return RideStatusLabel.completed;
    if (s == 'cancelled' || s == 'withdraw' || s.contains('cancel')) return RideStatusLabel.cancelled;
    if (s.contains('reject')) return RideStatusLabel.rejected;

    // Acceptance via BK3 confirm field (ConfirmStatus_R = 'accept')
    if (confirmStatusRider.toLowerCase() == 'accept') return RideStatusLabel.accepted;

    // Price offered but rider hasn't responded yet
    if (priceByDriver.isNotEmpty && confirmStatusRider.isEmpty) {
      return RideStatusLabel.offerReceived;
    }

    return RideStatusLabel.pending;
  }
}

enum RideStatusLabel {
  pending,
  offerReceived,
  accepted,
  pickup,
  arrived,
  inTransit,
  completed,
  rejected,
  cancelled,
}
