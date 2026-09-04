class WalletStatus {
  final bool isExpired;
  final String balance;     // TotalBalance — current wallet balance
  final String amountOwed;  // ToBalance — amount driver must pay to reactivate
  final String noofdays;    // number of subscription days to pay for
  final String rawStatus;

  const WalletStatus({
    required this.isExpired,
    required this.balance,
    required this.amountOwed,
    required this.noofdays,
    required this.rawStatus,
  });

  factory WalletStatus.fromJson(Map<String, dynamic> j) {
    final status = (j['Status'] ?? j['status'] ?? 'active').toString().trim();
    final expired = status == 'ExpiredWallet' ||
        status.toLowerCase() == 'expired' ||
        status.toLowerCase() == 'suspended' ||
        status.toLowerCase() == 'inactive';
    final days = (j['noofdays'] ?? j['Noofdays'] ?? j['NoOfDays'] ?? '').toString().trim();
    return WalletStatus(
      isExpired: expired,
      balance: (j['TotalBalance'] ?? j['Balance'] ?? '0').toString(),
      amountOwed: (j['ToBalance'] ?? j['AmountOwed'] ?? '0').toString(),
      noofdays: days.isEmpty ? '30' : days,
      rawStatus: status,
    );
  }

  factory WalletStatus.active() => const WalletStatus(
        isExpired: false,
        balance: '0',
        amountOwed: '0',
        noofdays: '30',
        rawStatus: 'active',
      );

  double get amountOwedDouble => double.tryParse(amountOwed) ?? 0;
  bool get hasAmountOwed => amountOwedDouble > 0;
}
