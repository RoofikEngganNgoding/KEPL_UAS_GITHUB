import 'dart:async';

import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_theme.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _checkingConnection = true;
  ServiceHealth? _health;
  Timer? _healthTimer;
  bool _healthCheckInFlight = false;

  bool get _online => _health?.online == true;

  static const _suggestions = [
    'Bagaimana cara memilah sampah?',
    'Apa manfaat daur ulang?',
    'Sampah plastik harus dibersihkan?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshHealth();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshHealth(silent: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _healthTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshHealth(silent: false);
    }
  }

  Future<void> _sendMessage([String? suggestion]) async {
    final text = (suggestion ?? _controller.text).trim();
    if (text.isEmpty || _isTyping) return;

    if (!_online) {
      await _refreshHealth();
      if (!_online || !mounted) return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    final result = await ApiService().askChatbotResult(text);
    if (!mounted) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: result.data ?? result.message,
          isUser: false,
          failed: !result.success,
        ),
      );
      _isTyping = false;
      if (!result.success) {
        _health = ServiceHealth(
          online: false,
          message: 'Chatbot tidak terhubung',
          checkedAt: DateTime.now(),
        );
      }
    });
    _scrollToBottom();
  }

  Future<void> _refreshHealth({bool silent = false}) async {
    if (_healthCheckInFlight) return;
    _healthCheckInFlight = true;
    if (!silent && mounted) setState(() => _checkingConnection = true);
    try {
      final health = await ApiService().checkChatbotHealth();
      if (!mounted) return;
      setState(() {
        _health = health;
        _checkingConnection = false;
      });
    } finally {
      _healthCheckInFlight = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: !widget.embedded,
      child: Column(
        children: [
          if (widget.embedded)
            _EmbeddedChatHeader(health: _health, checking: _checkingConnection),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refreshHealth(silent: false),
              color: AppTheme.primary,
              child: _messages.isEmpty
                  ? _ChatEmptyState(onSuggestion: _sendMessage)
                  : _messageList(),
            ),
          ),
          if (_isTyping) const _TypingIndicator(),
          _MessageComposer(
            controller: _controller,
            isTyping: _isTyping,
            online: _online,
            checking: _checkingConnection,
            onSend: _sendMessage,
          ),
        ],
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('Asisten AI')),
      body: content,
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _MessageBubble(message: message);
      },
    );
  }
}

class _EmbeddedChatHeader extends StatelessWidget {
  const _EmbeddedChatHeader({required this.health, required this.checking});

  final ServiceHealth? health;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final online = health?.online == true;
    final statusColor = checking
        ? AppTheme.warning
        : online
        ? AppTheme.secondary
        : AppTheme.error;
    final statusLabel = checking
        ? 'Memeriksa'
        : online
        ? 'Terhubung'
        : 'Terputus';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(
        color: AppTheme.lightGreen,
        bordered: true,
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 23,
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            child: Icon(Icons.auto_awesome_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Asisten Bank Sampah',
                  style: TextStyle(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  checking
                      ? 'Memeriksa layanan chatbot...'
                      : health?.message ?? 'Status belum diperiksa',
                  style: const TextStyle(
                    color: AppTheme.greyText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ConnectionBadge(
            label: statusLabel,
            color: statusColor,
            loading: checking,
          ),
        ],
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({
    required this.label,
    required this.color,
    required this.loading,
  });

  final String label;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.7, color: color),
            )
          else
            CircleAvatar(radius: 4, backgroundColor: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withAlpha(38),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Apa yang ingin kamu tanyakan?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Asisten dapat membantu menjawab pertanyaan tentang pemilahan, daur ulang, dan pengelolaan sampah.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.greyText, height: 1.5),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'COBA TANYAKAN',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ..._ChatPageState._suggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: InkWell(
                onTap: () => onSuggestion(suggestion),
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                child: Ink(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    border: Border.all(color: AppTheme.outline),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: const TextStyle(
                            color: AppTheme.darkText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.greyText,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 17,
              backgroundColor: AppTheme.primaryContainer,
              foregroundColor: AppTheme.primaryDark,
              child: Icon(Icons.auto_awesome_rounded, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.74,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primary
                    : message.failed
                    ? AppTheme.error.withAlpha(16)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: message.failed
                            ? AppTheme.error.withAlpha(90)
                            : AppTheme.outline,
                      ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : message.failed
                      ? AppTheme.error
                      : AppTheme.darkText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Asisten sedang menyiapkan jawaban...',
            style: TextStyle(color: AppTheme.greyText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isTyping,
    required this.online,
    required this.checking,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isTyping;
  final bool online;
  final bool checking;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!online && !checking)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      color: AppTheme.error,
                      size: 17,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chatbot tidak terhubung. Tarik halaman ke bawah untuk memeriksa ulang.',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.outline),
                    ),
                    child: TextField(
                      controller: controller,
                      enabled: online && !isTyping,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Tulis pertanyaanmu...',
                        prefixIcon: Icon(Icons.eco_outlined),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: online && !isTyping ? onSend : null,
                  tooltip: 'Kirim pesan',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.outline,
                    minimumSize: const Size(52, 52),
                  ),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.failed = false,
  });

  final String text;
  final bool isUser;
  final bool failed;
}
