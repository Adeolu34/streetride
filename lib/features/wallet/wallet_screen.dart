import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/session_service.dart';
import '../../core/api/ride_api.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  List<_Transaction> _transactions = [];
  bool _loading = true;
  int _balance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = SessionService.instance.profile;
    if (profile == null) {
      setState(() => _loading = false);
      return;
    }

    // Load wallet balance via BK11
    try {
      final walletRes = await RideApi.instance.getWalletStatus(profile.phone);
      final bal = walletRes['ToBalance'] ?? walletRes['TotalBalance'] ?? '0';
      final parsed = double.tryParse(bal.toString()) ?? 0;
      if (mounted) setState(() => _balance = parsed.toInt());
    } catch (_) {
      final fromProfile = double.tryParse(profile.walletBalance) ?? 0;
      if (mounted) setState(() => _balance = fromProfile.toInt());
    }

    // Load transaction history via R11.6
    try {
      final res = await RideApi.instance.getPaymentHistory(profile.phone);
      final history = res['History'];
      if (history is List && mounted) {
        setState(() {
          _transactions = history
              .whereType<Map<String, dynamic>>()
              .map(_txFromJson)
              .toList();
        });
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  static _Transaction _txFromJson(Map<String, dynamic> j) {
    final to = (j['toText'] ?? j['ToText'] ?? '').toString();
    final from = (j['fromText'] ?? j['FromText'] ?? '').toString();
    final label = to.isNotEmpty
        ? 'Trip to $to'
        : from.isNotEmpty
            ? 'Trip from $from'
            : 'Trip';
    final time = (j['Reqtime'] ?? j['reqtime'] ?? j['date'] ?? '').toString();
    final rawAmount = j['Price_D'] ?? j['amount'] ?? j['Amount'] ?? '0';
    final amount = int.tryParse(rawAmount.toString()) ?? 0;
    final status = (j['RideStatus_R'] ?? j['status'] ?? '').toString().toLowerCase();
    final type = status.contains('cancel') || status.contains('reject')
        ? _TxType.cancel
        : _TxType.ride;
    return _Transaction(label: label, date: time, amount: amount, type: type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WalletHeader(balance: _balance),
                const SizedBox(height: 20),
                _StreeplusPromo(),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'Recent activity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: SRColors.ink900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 32),
                    child: Center(
                      child: Text(
                        'No transactions yet',
                        style: TextStyle(color: SRColors.ink500, fontSize: 14),
                      ),
                    ),
                  )
                else
                  ..._transactions.map((t) => _TransactionTile(tx: t)),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _TxType { ride, topup, bonus, cancel }

class _Transaction {
  final String label;
  final String date;
  final int amount;
  final _TxType type;
  const _Transaction({
    required this.label,
    required this.date,
    required this.amount,
    required this.type,
  });
}

class _WalletHeader extends StatelessWidget {
  final int balance;
  const _WalletHeader({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: SRColors.gradWallet,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: SRColors.purple700.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'StreetRide Wallet',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₦${_fmt(balance)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Available balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _WalletAction(
                icon: Icons.add_rounded,
                label: 'Add funds',
                onTap: () {},
              ),
              const SizedBox(width: 10),
              _WalletAction(
                icon: Icons.send_rounded,
                label: 'Transfer',
                onTap: () {},
              ),
              const SizedBox(width: 10),
              _WalletAction(
                icon: Icons.history_rounded,
                label: 'History',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _WalletAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _WalletAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreeplusPromo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SRColors.indigo900,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SRColors.amber500.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, color: SRColors.amber500, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'StreetRide Plus',
                  style: TextStyle(
                    color: SRColors.amber500,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Unlock priority matching & exclusive deals.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: SRColors.amber500,
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(
                color: SRColors.ink900,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final _Transaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.type == _TxType.topup || tx.type == _TxType.bonus;
    final icon = switch (tx.type) {
      _TxType.ride => Icons.directions_car_rounded,
      _TxType.topup => Icons.account_balance_wallet_rounded,
      _TxType.bonus => Icons.card_giftcard_rounded,
      _TxType.cancel => Icons.cancel_outlined,
    };
    final iconBg = switch (tx.type) {
      _TxType.ride => SRColors.purple100,
      _TxType.topup => SRColors.green100,
      _TxType.bonus => SRColors.amber100,
      _TxType.cancel => SRColors.coral100,
    };
    final iconColor = switch (tx.type) {
      _TxType.ride => SRColors.purple700,
      _TxType.topup => SRColors.green500,
      _TxType.bonus => SRColors.amber600,
      _TxType.cancel => SRColors.coral500,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SRColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SRColors.ink900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.date,
                  style: const TextStyle(fontSize: 11, color: SRColors.ink500),
                ),
              ],
            ),
          ),
          Text(
            tx.amount > 0
                ? '${isCredit ? '+' : '-'}₦${tx.amount}'
                : tx.type == _TxType.cancel
                    ? 'Cancelled'
                    : '₦0',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isCredit
                  ? SRColors.green500
                  : tx.type == _TxType.cancel
                      ? SRColors.ink500
                      : SRColors.ink900,
            ),
          ),
        ],
      ),
    );
  }
}
