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

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _serverOnline = false;
  bool _checkingServer = true;
  Timer? _healthTimer;

  static const _suggestions = [
    'Bagaimana cara memilah sampah?',
    'Apa manfaat daur ulang?',
    'Sampah plastik harus dibersihkan?',
  ];

  @override
  void initState() {
    super.initState();
    _checkServer();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _checkServer(silent: true),
    );
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkServer({bool silent = false}) async {
    if (!silent && mounted) setState(() => _checkingServer = true);
    try {
      final health = await ApiService().checkChatbotHealth();
      if (!mounted) return;
      setState(() {
        _serverOnline = health.online;
        _checkingServer = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverOnline = false;
        _checkingServer = false;
      });
    }
  }

  Future<void> _sendMessage([String? suggestion]) async {
    final text = (suggestion ?? _controller.text).trim();
    if (text.isEmpty || _isTyping) return;

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
    });
    _scrollToBottom();
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
            _ChatHeader(
              serverOnline: _serverOnline,
              checkingServer: _checkingServer,
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _checkServer(silent: false),
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

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.serverOnline, required this.checkingServer});

  final bool serverOnline;
  final bool checkingServer;

  @override
  Widget build(BuildContext context) {
    final dotColor = checkingServer
        ? AppTheme.warning
        : serverOnline
        ? AppTheme.secondary
        : AppTheme.error;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.cardDecoration(
        color: AppTheme.lightGreen,
        bordered: true,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Status',
            style: TextStyle(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: dotColor.withAlpha(80), blurRadius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatEmptyState extends StatefulWidget {
  const _ChatEmptyState({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  State<_ChatEmptyState> createState() => _ChatEmptyStateState();
}

class _ChatEmptyStateState extends State<_ChatEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: AppTheme.heroGradient,
                borderRadius: BorderRadius.circular(28),
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
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Apa yang ingin kamu tanyakan?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
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
                onTap: () => widget.onSuggestion(suggestion),
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
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primaryContainer,
            foregroundColor: AppTheme.primaryDark,
            child: Icon(Icons.auto_awesome_rounded, size: 15),
          ),
          SizedBox(width: 10),
          _DotsAnimation(),
        ],
      ),
    );
  }
}

class _DotsAnimation extends StatefulWidget {
  const _DotsAnimation();

  @override
  State<_DotsAnimation> createState() => _DotsAnimationState();
}

class _DotsAnimationState extends State<_DotsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final value = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final bounce = value < 0.5
                ? Curves.easeOut.transform(value * 2)
                : Curves.easeIn.transform(1 - (value - 0.5) * 2);
            return Transform.translate(
              offset: Offset(0, -5 * bounce),
              child: Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isTyping,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isTyping;
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
        child: Row(
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
                  enabled: !isTyping,
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
              onPressed: isTyping ? null : onSend,
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
