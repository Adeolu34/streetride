import 'package:dio/dio.dart';
import 'api_client.dart';

String _toIntl(String phone) {
  final p = phone.trim();
  if (p.startsWith('234')) return p;
  if (p.startsWith('0')) return '234${p.substring(1)}';
  return '234$p';
}

class RideApi {
  RideApi._();
  static final RideApi instance = RideApi._();

  final _client = ApiClient.instance;

  // Rider creates a ride request targeting a specific driver
  Future<Map<String, dynamic>> bookRide({
    required String riderPhone,
    required String driverPhone,
    required String fromLat,
    required String fromLong,
    required String toLat,
    required String toLong,
    required String fromText,
    required String toText,
    required String km,
    required String eta,
    String otherText = '',
  }) =>
      _client.post({
        'theKey': 'BK1',
        'rphone': _toIntl(riderPhone),
        'dphone': _toIntl(driverPhone),
        'fromLat': fromLat,
        'fromLong': fromLong,
        'toLat': toLat,
        'toLong': toLong,
        'fromText': fromText,
        'toText': toText,
        'km': km,
        'tm': eta,
        'OtherText': otherText,
      });

  // Rider polls for active ride messages (BK8)
  Future<Map<String, dynamic>> pollMessages(String phone) =>
      _client.post({'theKey': 'BK8', 'phone': _toIntl(phone)});

  // Rider accepts driver's quoted price (BK3)
  Future<Map<String, dynamic>> acceptPrice(String reqId) =>
      _client.post({'theKey': 'BK3', 'reqid': reqId, 'status': 'accept'});

  // Rider rejects driver's price (BK3)
  Future<Map<String, dynamic>> rejectPrice(String reqId) =>
      _client.post({'theKey': 'BK3', 'reqid': reqId, 'status': 'reject'});

  // Rider sets ride status (BK5): 'Accepted','Boarded','Completed','Cancelled','NoShow','Reject Price','Awaiting Response'
  Future<Map<String, dynamic>> setRiderStatus(String reqId, String status) =>
      _client.post({'theKey': 'BK5', 'reqid': reqId, 'status': status});

  // Driver sets initial price for a ride request (BK2)
  Future<Map<String, dynamic>> setPrice({
    required String reqId,
    required String price,
  }) =>
      _client.post({'theKey': 'BK2', 'reqid': reqId, 'price': price});

  // Driver adjusts/reduces price after rider rejects (BK2.1)
  Future<Map<String, dynamic>> adjustPrice({
    required String reqId,
    required String price,
  }) =>
      _client.post({'theKey': 'BK2.1', 'reqid': reqId, 'price': price});

  // Driver fetches their open/pending ride requests (BK2.2)
  Future<Map<String, dynamic>> getOpenRides(String driverPhone) =>
      _client.post({'theKey': 'BK2.2', 'driverphone': _toIntl(driverPhone)});

  // Driver sets movement status (BK4): 'New Request','Set Price','Accepted','Started','Arrived','InTransit','Completed','Cancel','Reject Price'
  Future<Map<String, dynamic>> setDriverMovementStatus(String reqId, String status) =>
      _client.post({'theKey': 'BK4', 'reqid': reqId, 'status': status});

  // Rider rates driver after trip (BK6)
  Future<Map<String, dynamic>> rateDriver({
    required String reqId,
    required String rate,
    required String comment,
    String carCondition = 'Good',
    String safety = 'Good',
    String fairness = 'Good',
  }) =>
      _client.post({
        'theKey': 'BK6',
        'reqid': reqId,
        'rate': rate,
        'comment': comment,
        'carcondition': carCondition,
        'safety': safety,
        'fairness': fairness,
      });

  // Rider/driver flags an issue (BK7): flag = 'Red' | 'Yellow' | 'Green'
  Future<Map<String, dynamic>> flagRide({
    required String reqId,
    required String flag,
    required String comment,
  }) =>
      _client.post({
        'theKey': 'BK7',
        'reqid': reqId,
        'flag': flag,
        'comment': comment,
      });

  // Get nearby available drivers
  Future<Map<String, dynamic>> getNearbyDrivers({
    required String lat,
    required String long,
  }) =>
      _client.post({'theKey': 'R11.3', 'FromLat': lat, 'FromLong': long});

  // Search address autocomplete
  Future<Map<String, dynamic>> searchAddress(String query) =>
      _client.post({'theKey': 'RR1', 'Address': query});

  // Resolve PlaceId to lat/long
  Future<Map<String, dynamic>> getPlaceDetail(String placeId) =>
      _client.post({'theKey': 'RR2', 'PlaceId': placeId});

  // Reverse geocode lat/long to address
  Future<Map<String, dynamic>> reverseGeocode({
    required String lat,
    required String long,
  }) =>
      _client.post({'theKey': 'RR3', 'Latitude': lat, 'Longitude': long});

  // Get wallet balance
  Future<Map<String, dynamic>> getWalletStatus(String phone) =>
      _client.post({'theKey': 'BK11', 'phone': _toIntl(phone)});

  // Get payment/trip history
  Future<Map<String, dynamic>> getPaymentHistory(String phone) =>
      _client.post({'theKey': 'R11.6', 'phone': _toIntl(phone)});

  // Save or update GPS location
  Future<Map<String, dynamic>> updateLocation({
    required String phone,
    required String lat,
    required String long,
    required bool isDriver,
  }) =>
      _client.post({
        'theKey': 'R11.2',
        'phone': _toIntl(phone),
        'latitude': lat,
        'longitude': long,
        'isdriver': isDriver ? '1' : '0',
      });

  // Get last known location of a phone
  Future<Map<String, dynamic>> getLocation(String phone) =>
      _client.post({'theKey': 'R11.2B', 'phone': _toIntl(phone)});

  // Get ride profile (rider + driver) for a trip
  Future<Map<String, dynamic>> getRideProfile(String reqId) =>
      _client.post({'theKey': 'M7', 'ReqID': reqId});

  // Get user detail by phone
  Future<Map<String, dynamic>> getUserDetail(String phone) =>
      _client.post({'theKey': 'M3', 'Phone': _toIntl(phone)});

  // Get reports/comments about a driver
  Future<Map<String, dynamic>> getDriverReports(String driverPhone) =>
      _client.post({'theKey': 'R11.9', 'dphone': _toIntl(driverPhone)});

  // Read trip chat messages
  Future<Map<String, dynamic>> getChatMessages({
    required String reqId,
    required String phone,
  }) =>
      _client.post({'theKey': 'M2', 'ReqId': reqId, 'Phone': _toIntl(phone)});

  // Send trip chat message
  Future<Map<String, dynamic>> sendChatMessage({
    required String reqId,
    required String phone,
    required String message,
  }) =>
      _client.post({
        'theKey': 'M1',
        'ReqId': reqId,
        'Phone': _toIntl(phone),
        'Message': message,
      });

  // Update driver online/offline status
  Future<Map<String, dynamic>> setDriverOnlineStatus({
    required String phone,
    required bool online,
  }) =>
      _client.post({
        'theKey': 'DS1',
        'phone': _toIntl(phone),
        'status': online ? 'online' : 'offline',
      });

  // Driver sets availability status (BK9): 'Free', 'Busy', etc.
  Future<Map<String, dynamic>> setDriverAvailability({
    required String phone,
    required String status,
  }) =>
      _client.post({'theKey': 'BK9', 'phone': _toIntl(phone), 'status': status});

  // Get driver subscription/charge history (BK12)
  Future<Map<String, dynamic>> getChargeHistory(String phone) =>
      _client.post({'theKey': 'BK12', 'phone': _toIntl(phone)});

  // Initialise Flutterwave payment to top up driver wallet (Pay)
  Future<Map<String, dynamic>> makeSubscriptionPayment({
    required String phone,
    required String name,
    required String email,
    required String amount,
    String nodays = '30',
  }) =>
      _client.post({
        'theKey': 'Pay',
        'phone': _toIntl(phone),
        'name': name,
        'email': email,
        'amount': amount,
        'nodays': nodays,
      });

  // Get pending KYC documents for driver
  Future<Map<String, dynamic>> getPendingDocuments({
    required String phone,
    required String city,
  }) =>
      _client.post({'theKey': 'R16', 'Phone': _toIntl(phone), 'City': city});

  // Get KYC document templates for a city (R15)
  Future<Map<String, dynamic>> getKycTemplates({
    required String phone,
    required String city,
  }) =>
      _client.post({'theKey': 'R15', 'Phone': _toIntl(phone), 'City': city});

  // Update user profile (PROFILE) — multipart, Image is optional file upload
  Future<Map<String, dynamic>> updateProfile({
    required String phone,
    required String firstName,
    required String surname,
    required String email,
    required String city,
    required bool isDriver,
    String status = '',
    String vType = '',
    String vMake = '',
    String vModel = '',
    String vYear = '',
    String vColor = '',
    String bankno = '',
    String? imagePath,
  }) async {
    final body = <String, dynamic>{
      'theKey': 'PROFILE',
      'Phone': _toIntl(phone),
      'FirstName': firstName,
      'Surname': surname,
      'Email': email,
      'City': city,
      'IsDriver': isDriver ? '1' : '0',
      'Status': status,
      'VType': vType,
      'VMake': vMake,
      'VModel': vModel,
      'VYear': vYear,
      'VColor': vColor,
      'bankno': bankno,
    };
    if (imagePath != null && imagePath.isNotEmpty) {
      body['Image'] = await MultipartFile.fromFile(
        imagePath,
        filename: 'profile.jpg',
      );
    }
    return _client.post(body, multipart: true);
  }
}
