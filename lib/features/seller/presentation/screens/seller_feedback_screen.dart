import 'package:flutter/material.dart';
import 'package:shophop/features/seller/data/services/seller_workspace_service.dart';
import 'package:shophop/shared/realtime/foreground_refresh.dart';

class SellerFeedbackScreen extends StatefulWidget {
  const SellerFeedbackScreen({
    super.key,
    required this.token,
    required this.onSessionExpired,
  });
  final String token;
  final Future<void> Function() onSessionExpired;
  @override
  State<SellerFeedbackScreen> createState() => _SellerFeedbackScreenState();
}

class _SellerFeedbackScreenState extends State<SellerFeedbackScreen> {
  final _drafts = <int, TextEditingController>{};
  final _search = TextEditingController();
  late final ForegroundRefresh _refresh;
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true, _busy = false, _dirty = false;
  int _page = 1, _lastPage = 1, _total = 0;
  String _rating = '', _query = '';
  String? _message;
  num _average = 0;

  @override
  void initState() {
    super.initState();
    _refresh = ForegroundRefresh(
      refresh: _load,
      canRefresh: () =>
          mounted &&
          !_busy &&
          !_dirty &&
          (ModalRoute.of(context)?.isCurrent ?? true),
    );
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    final query = Uri(
      queryParameters: {
        'page': '$_page',
        if (_rating.isNotEmpty) 'rating': _rating,
        if (_query.isNotEmpty) 'search': _query,
      },
    ).query;
    final result = await SellerWorkspaceService.get(
      widget.token,
      'feedback?$query',
    );
    if (!mounted) return;
    _busy = false;
    if (result.statusCode == 401 || result.statusCode == 403) {
      await widget.onSessionExpired();
      return;
    }
    setState(() {
      _loading = false;
      if (!result.success) {
        _message = result.message;
        return;
      }
      if (_dirty) return;
      _message = null;
      final pagination = result.data['reviews'] as Map? ?? {};
      _reviews = (pagination['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _lastPage = (pagination['last_page'] as num?)?.toInt() ?? 1;
      _total = (result.data['total'] as num?)?.toInt() ?? 0;
      _average = result.data['average'] as num? ?? 0;
      for (final r in _reviews) {
        final id = (r['id'] as num).toInt();
        (_drafts[id] ??= TextEditingController()).text =
            '${r['seller_reply'] ?? ''}';
      }
    });
  }

  Future<void> _reply(int id) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await SellerWorkspaceService.patch(
      widget.token,
      'feedback/$id/reply',
      {'reply': _drafts[id]!.text},
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.message;
    });
    if (result.statusCode == 401 || result.statusCode == 403) {
      await widget.onSessionExpired();
      return;
    }
    if (result.success) {
      // Keep other unsent drafts intact. Refresh is allowed after every draft is saved.
      final row = _reviews.firstWhere((r) => r['id'] == id);
      row['seller_reply'] = _drafts[id]!.text.trim();
      _dirty = _reviews.any(
        (r) =>
            _drafts[(r['id'] as num).toInt()]?.text.trim() !=
            '${r['seller_reply'] ?? ''}',
      );
    }
  }

  @override
  void dispose() {
    _refresh.dispose();
    _search.dispose();
    for (final d in _drafts.values) {
      d.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customer Feedback')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              if (!_dirty) await _load();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text('$_total product reviews | Average $_average/5'),
                const Text(
                  'Updates every 15 seconds while you are not editing a reply.',
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(_message!),
                  ),
                TextField(
                  controller: _search,
                  enabled: !_dirty && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Search product or comment',
                  ),
                  onSubmitted: (value) {
                    setState(() {
                      _query = value;
                      _page = 1;
                    });
                    _load();
                  },
                ),
                DropdownButton<String>(
                  value: _rating,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All ratings'),
                    ),
                    for (final rating in [5, 4, 3, 2, 1])
                      DropdownMenuItem(
                        value: '$rating',
                        child: Text('$rating stars'),
                      ),
                  ],
                  onChanged: _dirty || _busy
                      ? null
                      : (value) {
                          setState(() {
                            _rating = value ?? '';
                            _page = 1;
                          });
                          _load();
                        },
                ),
                if (_reviews.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No customer reviews found.'),
                  ),
                for (final r in _reviews)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r['product_name']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${r['buyer_name']} | ${r['rating']}/5 | ${r['date']}',
                          ),
                          const SizedBox(height: 8),
                          Text('${r['comment'] ?? ''}'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _drafts[(r['id'] as num).toInt()],
                            maxLength: 2000,
                            minLines: 2,
                            maxLines: 5,
                            enabled: !_busy,
                            decoration: const InputDecoration(
                              labelText: 'Your reply',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              setState(() => _dirty = true);
                            },
                          ),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _reply((r['id'] as num).toInt()),
                            child: const Text('Save reply'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _page > 1 && !_busy && !_dirty
                          ? () {
                              setState(() => _page--);
                              _load();
                            }
                          : null,
                      child: const Text('Previous'),
                    ),
                    Text('Page $_page / $_lastPage'),
                    TextButton(
                      onPressed: _page < _lastPage && !_busy && !_dirty
                          ? () {
                              setState(() => _page++);
                              _load();
                            }
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
                if (_dirty)
                  const Text(
                    'Save your reply drafts before changing filters or pages.',
                  ),
              ],
            ),
          ),
  );
}
