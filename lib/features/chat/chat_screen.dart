import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/ride_api.dart';
import '../../core/services/session_service.dart';
import '../../core/theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String driverName;
  final String driverInitials;
  final String? otherPhotoUrl;
  final String reqId;

  const ChatScreen({
    super.key,
    required this.driverName,
    required this.driverInitials,
    this.otherPhotoUrl,
    this.reqId = '',
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[];
  Timer? _pollTimer;
  bool _sending = false;

  String? _myPhotoUrl;
  String _myInitials = '?';

  final _quickReplies = [
    "I'm on my way",
    'Please hurry',
    "I'm at the gate",
    'Running late',
  ];

  @override
  void initState() {
    super.initState();
    final profile = SessionService.instance.profile;
    _myPhotoUrl = profile?.photoUrl;
    _myInitials = profile?.initials ?? '?';
    if (widget.reqId.isNotEmpty) {
      _loadMessages();
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final phone = SessionService.instance.profile?.phone ?? '';
    if (phone.isEmpty) return;
    try {
      final data = await RideApi.instance.getChatMessages(
        reqId: widget.reqId,
        phone: phone,
      );
      final raw = data['Messages'] ?? data['messages'] ?? data['Chats'] ?? [];
      if (raw is! List) return;

      final loaded = raw.map((m) {
        final text = (m['Message'] ?? m['message'] ?? '').toString();
        final time = (m['DateIn'] ?? m['Time'] ?? m['time'] ?? '').toString();
        final isMe = m['IsMine'] == true;
        return _Msg(text: text, isMe: isMe, time: time);
      }).where((m) => m.text.isNotEmpty).toList();

      if (loaded.isNotEmpty && mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(loaded);
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    final phone = SessionService.instance.profile?.phone ?? '';
    final msg = _Msg(text: text.trim(), isMe: true, time: DateTime.now().toIso8601String());
    setState(() {
      _messages.add(msg);
      _controller.clear();
      _sending = true;
    });
    _scrollToBottom();

    if (widget.reqId.isNotEmpty && phone.isNotEmpty) {
      await RideApi.instance.sendChatMessage(
        reqId: widget.reqId,
        phone: phone,
        message: text.trim(),
      ).catchError((_) => <String, dynamic>{});
    }
    if (mounted) setState(() => _sending = false);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      body: Column(
        children: [
          _ChatHeader(
            driverName: widget.driverName,
            driverInitials: widget.driverInitials,
            otherPhotoUrl: widget.otherPhotoUrl,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: _messages.isEmpty && widget.reqId.isEmpty
                ? const Center(
                    child: Text(
                      'No active ride — chat is available during a trip.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: SRColors.ink500),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _BubbleTile(
                      msg: _messages[i],
                      myPhotoUrl: _myPhotoUrl,
                      myInitials: _myInitials,
                      otherPhotoUrl: widget.otherPhotoUrl,
                      otherInitials: widget.driverInitials,
                    ),
                  ),
          ),
          _QuickReplies(
            chips: _quickReplies,
            onTap: _send,
          ),
          _MessageInput(
            controller: _controller,
            onSend: () => _send(_controller.text),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool isMe;
  final String time;
  const _Msg({required this.text, required this.isMe, required this.time});
}

// ─── Relative time ────────────────────────────────────────────────────────────

String _relativeTime(String raw) {
  if (raw.isEmpty) return '';
  DateTime? dt = DateTime.tryParse(raw);
  if (dt == null) {
    try {
      final parts = raw.trim().split(' ');
      if (parts.length >= 2) {
        final dp = parts[0].split('/');
        final tp = parts[1].split(':');
        if (dp.length == 3 && tp.length >= 2) {
          final isPm = parts.length >= 3 && parts[2].toUpperCase() == 'PM';
          int hour = int.parse(tp[0]);
          if (isPm && hour != 12) hour += 12;
          if (!isPm && hour == 12) hour = 0;
          dt = DateTime(
            int.parse(dp[2]), int.parse(dp[0]), int.parse(dp[1]),
            hour, int.parse(tp[1]),
            tp.length > 2 ? int.parse(tp[2]) : 0,
          );
        }
      }
    } catch (_) {}
  }
  if (dt == null) return raw;
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}';
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String initials;
  const _Avatar({required this.initials, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final url = photoUrl ?? '';
    return Container(
      width: 32, height: 32,
      decoration: const BoxDecoration(
        color: SRColors.lavenderBg,
        shape: BoxShape.circle,
      ),
      child: url.isNotEmpty
          ? ClipOval(
              child: url.startsWith('/')
                  ? Image.file(File(url), fit: BoxFit.cover)
                  : Image.network(
                      url, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _InitialsContent(initials: initials),
                    ),
            )
          : _InitialsContent(initials: initials),
    );
  }
}

class _InitialsContent extends StatelessWidget {
  final String initials;
  const _InitialsContent({required this.initials});
  @override
  Widget build(BuildContext context) => Center(
        child: Text(initials,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SRColors.purple700)),
      );
}

// ─── Bubble ───────────────────────────────────────────────────────────────────

class _BubbleTile extends StatelessWidget {
  final _Msg msg;
  final String? myPhotoUrl;
  final String myInitials;
  final String? otherPhotoUrl;
  final String otherInitials;

  const _BubbleTile({
    required this.msg,
    required this.myPhotoUrl,
    required this.myInitials,
    required this.otherPhotoUrl,
    required this.otherInitials,
  });

  @override
  Widget build(BuildContext context) {
    final relTime = _relativeTime(msg.time);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: msg.isMe ? _meRow(relTime) : _otherRow(relTime),
      ),
    );
  }

  List<Widget> _otherRow(String relTime) => [
        _Avatar(photoUrl: otherPhotoUrl, initials: otherInitials),
        const SizedBox(width: 8),
        _Bubble(
          text: msg.text, isMe: false, relTime: relTime,
          maxWidthFraction: 0.68,
        ),
        const Spacer(),
      ];

  List<Widget> _meRow(String relTime) => [
        const Spacer(),
        _Bubble(
          text: msg.text, isMe: true, relTime: relTime,
          maxWidthFraction: 0.68,
        ),
        const SizedBox(width: 8),
        _Avatar(photoUrl: myPhotoUrl, initials: myInitials),
      ];
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String relTime;
  final double maxWidthFraction;
  const _Bubble({
    required this.text,
    required this.isMe,
    required this.relTime,
    required this.maxWidthFraction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * maxWidthFraction,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? SRColors.purple700 : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: SRColors.indigo900.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isMe ? Colors.white : SRColors.ink900,
              height: 1.4,
            ),
          ),
        ),
        if (relTime.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(relTime,
              style: const TextStyle(fontSize: 10, color: SRColors.ink500)),
        ],
      ],
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final String driverName;
  final String driverInitials;
  final String? otherPhotoUrl;
  final VoidCallback onBack;

  const _ChatHeader({
    required this.driverName,
    required this.driverInitials,
    required this.onBack,
    this.otherPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: SRColors.gradHero,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Builder(builder: (ctx) {
                  final url = otherPhotoUrl ?? '';
                  if (url.isNotEmpty) {
                    return ClipOval(
                      child: Image.network(
                        url, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(driverInitials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: Text(driverInitials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  );
                }),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Your driver · On the way',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Icon(Icons.call_rounded,
                    color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick replies ─────────────────────────────────────────────────────────────

class _QuickReplies extends StatelessWidget {
  final List<String> chips;
  final ValueChanged<String> onTap;
  const _QuickReplies({required this.chips, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: chips
            .map(
              (c) => GestureDetector(
                onTap: () => onTap(c),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: SRColors.border, width: 1.5),
                  ),
                  child: Text(
                    c,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: SRColors.ink700,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Input ─────────────────────────────────────────────────────────────────────

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _MessageInput({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).viewInsets.bottom),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Message your driver…',
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(99),
                  borderSide: const BorderSide(color: SRColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(99),
                  borderSide: const BorderSide(color: SRColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(99),
                  borderSide: const BorderSide(color: SRColors.purple700),
                ),
                hintStyle: const TextStyle(
                    fontSize: 14, color: SRColors.ink500),
                filled: true,
                fillColor: SRColors.lavenderBg,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(
                color: SRColors.purple700,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
