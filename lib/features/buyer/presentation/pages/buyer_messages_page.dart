import 'package:shophop/features/buyer/presentation/widgets/buyer_icon_tile.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shophop/features/buyer/data/services/buyer_chat_service.dart';
import 'package:shophop/shared/realtime/foreground_refresh.dart';

class BuyerMessagesPage extends StatefulWidget {
  const BuyerMessagesPage({
    super.key,
    required this.token,
    this.onSessionExpired,
  });
  final String token;
  final Future<void> Function()? onSessionExpired;
  @override
  State<BuyerMessagesPage> createState() => _BuyerMessagesPageState();
}

class _BuyerMessagesPageState extends State<BuyerMessagesPage> {
  late final ForegroundRefresh _refresh;
  List<BuyerConversation> _items = [];
  bool _loading = true, _busy = false, _denied = false;
  String? _error;
  String _query = '';
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = ForegroundRefresh(
      refresh: _load,
      interval: const Duration(seconds: 6),
      canRefresh: () =>
          mounted &&
          !_busy &&
          !_denied &&
          (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    _busy = true;
    try {
      final items = await BuyerChatService.conversations(widget.token);
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
          _denied = false;
        });
      }
    } on BuyerChatException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _denied = error.sessionExpired || error.accessDenied;
      });
      if (error.sessionExpired) await widget.onSessionExpired?.call();
    } finally {
      _busy = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();
    final visible = _items
        .where(
          (item) =>
              (!_unreadOnly || item.unread > 0) &&
              (query.isEmpty ||
                  item.name.toLowerCase().contains(query) ||
                  item.last.toLowerCase().contains(query)),
        )
        .toList();
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: _busy ? null : _load,
            icon: const BuyerIconTile(
              icon: Icons.refresh_outlined,
              dimension: 36,
              iconSize: 20,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search chats',
                  prefixIcon: const Icon(Icons.search, size: 21),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: !_unreadOnly,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _unreadOnly = false),
                    shape: const StadiumBorder(),
                    side: BorderSide.none,
                    selectedColor: colors.primaryContainer,
                    backgroundColor: AppColors.surface,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Unread'),
                    selected: _unreadOnly,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _unreadOnly = true),
                    shape: const StadiumBorder(),
                    side: BorderSide.none,
                    selectedColor: colors.primaryContainer,
                    backgroundColor: AppColors.surface,
                  ),
                ],
              ),
            ),
            if (_error != null) _ChatError(message: _error!, onRetry: _load),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: visible.isEmpty
                            ? [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 56,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 48,
                                        color: colors.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _error != null && _items.isEmpty
                                            ? 'Messages unavailable'
                                            : query.isNotEmpty
                                            ? 'No matching chats'
                                            : _unreadOnly
                                            ? 'You?re all caught up'
                                            : 'No conversations yet',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        query.isNotEmpty
                                            ? 'Try another shop name or message.'
                                            : _unreadOnly
                                            ? 'No unread messages right now.'
                                            : _error != null
                                            ? 'Pull down to try again.'
                                            : 'Tap Chat on a product to message its seller.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ]
                            : [
                                for (final item in visible)
                                  Column(
                                    children: [
                                      InkWell(
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) => BuyerChatPage(
                                                token: widget.token,
                                                chatId: item.id,
                                                name: item.name,
                                                onSessionExpired:
                                                    widget.onSessionExpired,
                                              ),
                                            ),
                                          );
                                          if (mounted) await _load();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 20,
                                          ),
                                          child: Row(
                                            children: [
                                              _ShopAvatar(
                                                name: item.name,
                                                size: 52,
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            item.name,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  item.unread >
                                                                      0
                                                                  ? FontWeight
                                                                        .w700
                                                                  : FontWeight
                                                                        .w600,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        ConstrainedBox(
                                                          constraints:
                                                              const BoxConstraints(
                                                                maxWidth: 88,
                                                              ),
                                                          child: Text(
                                                            item.time,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: colors
                                                                  .onSurfaceVariant,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            item.last.isEmpty
                                                                ? 'Start a conversation'
                                                                : item.last,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: colors
                                                                  .onSurfaceVariant,
                                                            ),
                                                          ),
                                                        ),
                                                        if (item.unread >
                                                            0) ...[
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Semantics(
                                                            label:
                                                                '${item.unread} unread messages',
                                                            child: Container(
                                                              width: 8,
                                                              height: 8,
                                                              decoration:
                                                                  BoxDecoration(
                                                                    color: colors
                                                                        .primary,
                                                                    shape: BoxShape
                                                                        .circle,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.only(left: 82),
                                        child: Divider(
                                          height: 1,
                                          thickness: .5,
                                          color: AppColors.border,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopAvatar extends StatelessWidget {
  const _ShopAvatar({required this.name, this.size = 40});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.primary.withValues(alpha: .2)),
      ),
      child: CircleAvatar(
        backgroundColor: colors.primaryContainer,
        child: Text(
          name.isEmpty ? 'S' : name.characters.first.toUpperCase(),
          style: TextStyle(
            color: colors.primary,
            fontSize: size * .4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class BuyerChatPage extends StatefulWidget {
  const BuyerChatPage({
    super.key,
    required this.token,
    required this.name,
    this.chatId,
    this.sellerUserId,
    this.onSessionExpired,
  }) : assert(chatId != null || sellerUserId != null);
  final String token, name;
  final int? chatId, sellerUserId;
  final Future<void> Function()? onSessionExpired;
  @override
  State<BuyerChatPage> createState() => _BuyerChatPageState();
}

class _BuyerChatPageState extends State<BuyerChatPage> {
  late final ForegroundRefresh _refresh;
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  final Map<int, BuyerChatMessage> _messages = {};
  int? _chatId;
  int _cursor = 0;
  bool _loading = true, _busy = false, _sending = false, _denied = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;
    _load();
    _refresh = ForegroundRefresh(
      refresh: _load,
      interval: const Duration(seconds: 3),
      canRefresh: () =>
          mounted &&
          !_busy &&
          !_sending &&
          !_denied &&
          (ModalRoute.of(context)?.isCurrent ?? true),
    );
  }

  @override
  void dispose() {
    _refresh.dispose();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _handle(BuyerChatException error) async {
    if (!mounted) return;
    setState(() {
      _error = error.message;
      _denied = error.sessionExpired || error.accessDenied;
    });
    if (error.sessionExpired) await widget.onSessionExpired?.call();
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
  });

  Future<void> _load() async {
    if (_busy) return;
    _busy = true;
    final atBottom = !_scroll.hasClients || _scroll.offset < 100;
    try {
      _chatId ??= await BuyerChatService.open(
        widget.token,
        widget.sellerUserId!,
      );
      // The web API returns 100 messages per batch. Catch up without skipping
      // messages, and keep the fetch cursor independent of send responses.
      for (var batch = 0; batch < 5; batch++) {
        final previous = _cursor;
        final items = await BuyerChatService.messages(
          widget.token,
          _chatId!,
          after: _cursor,
        );
        if (!mounted) return;
        setState(() {
          for (final message in items) {
            _messages[message.id] = message;
            if (message.id > _cursor) _cursor = message.id;
          }
          _denied = false;
          // Keep a failed-send warning until the user retries sending.
          if (!_sendFailed) _error = null;
        });
        if (items.length < 100 || previous == _cursor) break;
      }
      if (atBottom) _bottom();
    } on BuyerChatException catch (error) {
      await _handle(error);
    } finally {
      _busy = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _sendFailed = false;
  String? _pendingBody, _pendingId;

  Future<void> _chooseEmoji() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose emoji',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final value in [
                    '😊',
                    '👍',
                    '❤️',
                    '🙏',
                    '👋',
                    '🙂',
                    '✅',
                    '🎉',
                    '😍',
                    '📦',
                    '😁',
                    '🤔',
                  ])
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, value),
                        child: Text(
                          value,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (emoji == null || !mounted || _sending) return;
    final selection = _draft.selection;
    final start = selection.isValid ? selection.start : _draft.text.length;
    final end = selection.isValid ? selection.end : _draft.text.length;
    final text = _draft.text.replaceRange(start, end, emoji);
    if (text.length > 1000) return;
    setState(
      () => _draft.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: start + emoji.length),
      ),
    );
  }

  Future<void> _send() async {
    final body = _draft.text.trim();
    if (_sending || _chatId == null || _denied || body.isEmpty) return;
    if (body.characters.length > 1000) return;
    if (_pendingBody != body || _pendingId == null) {
      _pendingBody = body;
      _pendingId = BuyerChatService.newMessageId();
    }
    setState(() {
      _sending = true;
      _error = null;
      _sendFailed = false;
    });
    try {
      final message = await BuyerChatService.send(
        widget.token,
        _chatId!,
        body,
        clientMessageId: _pendingId!,
      );
      if (!mounted) return;
      setState(() {
        _messages[message.id] = message;
        _draft.clear();
        _pendingBody = null;
        _pendingId = null;
      });
      _bottom();
    } on BuyerChatException catch (error) {
      _sendFailed = true;
      await _handle(
        BuyerChatException(
          'Unable to send. ${error.message}',
          statusCode: error.statusCode,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = _messages.values.toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(
          children: [
            _ShopAvatar(name: widget.name, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Shop conversation',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh conversation',
            onPressed: _busy ? null : _load,
            icon: const BuyerIconTile(
              icon: Icons.refresh_outlined,
              dimension: 36,
              iconSize: 20,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_error != null)
              _ChatError(
                message: _error!,
                onRetry: _sendFailed ? _send : _load,
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Say hello to start the conversation.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final message = items[index];
                        return Align(
                          alignment: message.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            key: ValueKey('message-${message.id}'),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * .86,
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: message.mine
                                  ? AppColors.pinkSoft
                                  : AppColors.surface,
                              border: Border.all(
                                color: AppColors.border,
                                width: .5,
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(message.mine ? 14 : 3),
                                topRight: Radius.circular(
                                  message.mine ? 3 : 14,
                                ),
                                bottomLeft: const Radius.circular(14),
                                bottomRight: const Radius.circular(14),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  message.body,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    message.time,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _draft,
                      enabled: !_sending && !_denied && _chatId != null,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.input,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Choose emoji',
                          onPressed: _sending || _denied || _chatId == null
                              ? null
                              : _chooseEmoji,
                          icon: const Icon(
                            Icons.sentiment_satisfied_alt_outlined,
                            size: 23,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed:
                        _sending ||
                            _denied ||
                            _chatId == null ||
                            _draft.text.trim().isEmpty
                        ? null
                        : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: Theme.of(context).colorScheme.errorContainer,
    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
    child: Row(
      children: [
        Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
