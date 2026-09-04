class UserProfile {
  final String phone;
  final String firstName;
  final String surname;
  final String email;
  final String city;
  final String? photoUrl;
  final bool isDriver;
  final bool kycVerified;
  final bool suspended;
  final String walletBalance;
  final String bankno;
  final String vType;
  final String vMake;
  final String vModel;
  final String vYear;
  final String vColor;

  const UserProfile({
    required this.phone,
    required this.firstName,
    required this.surname,
    required this.email,
    required this.city,
    this.photoUrl,
    required this.isDriver,
    required this.kycVerified,
    required this.suspended,
    required this.walletBalance,
    this.bankno = '',
    this.vType = '',
    this.vMake = '',
    this.vModel = '',
    this.vYear = '',
    this.vColor = '',
  });

  String get fullName => '$firstName $surname'.trim();

  String get initials {
    final parts = fullName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      phone: (json['phone'] ?? json['Phone'] ?? '').toString(),
      firstName: (json['FirstName'] ?? json['firstname'] ?? '').toString(),
      surname: (json['Surname'] ?? json['surname'] ?? '').toString(),
      email: (json['Email'] ?? json['email'] ?? '').toString(),
      city: (json['City'] ?? json['city'] ?? '').toString(),
      photoUrl: (json['Photo'] ?? json['image'] ?? json['Image'])?.toString(),
      isDriver: json['IsDriver'] == true ||
          json['isdriver'] == true ||
          json['IsDriver'].toString() == '1' ||
          json['isdriver'].toString() == '1',
      kycVerified: json['kyc'] == true || json['Kyc'] == true,
      suspended: json['Suspended'] == true,
      walletBalance: (json['Tobalance'] ?? json['tobalance'] ?? '0').toString(),
      bankno: (json['bankno'] ?? json['Bankno'] ?? '').toString(),
      vType: (json['VType'] ?? json['vtype'] ?? '').toString(),
      vMake: (json['VMake'] ?? json['vmake'] ?? '').toString(),
      vModel: (json['VModel'] ?? json['vmodel'] ?? '').toString(),
      vYear: (json['VYear'] ?? json['vyear'] ?? '').toString(),
      vColor: (json['VColor'] ?? json['vcolor'] ?? '').toString(),
    );
  }

  UserProfile copyWith({
    String? phone,
    String? firstName,
    String? surname,
    String? email,
    String? city,
    String? photoUrl,
    String? bankno,
    String? vType,
    String? vMake,
    String? vModel,
    String? vYear,
    String? vColor,
  }) =>
      UserProfile(
        phone: phone ?? this.phone,
        firstName: firstName ?? this.firstName,
        surname: surname ?? this.surname,
        email: email ?? this.email,
        city: city ?? this.city,
        photoUrl: photoUrl ?? this.photoUrl,
        isDriver: isDriver,
        kycVerified: kycVerified,
        suspended: suspended,
        walletBalance: walletBalance,
        bankno: bankno ?? this.bankno,
        vType: vType ?? this.vType,
        vMake: vMake ?? this.vMake,
        vModel: vModel ?? this.vModel,
        vYear: vYear ?? this.vYear,
        vColor: vColor ?? this.vColor,
      );

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'FirstName': firstName,
        'Surname': surname,
        'Email': email,
        'City': city,
        'Photo': photoUrl,
        'IsDriver': isDriver,
        'kyc': kycVerified,
        'Suspended': suspended,
        'Tobalance': walletBalance,
        'bankno': bankno,
        'VType': vType,
        'VMake': vMake,
        'VModel': vModel,
        'VYear': vYear,
        'VColor': vColor,
      };
}
