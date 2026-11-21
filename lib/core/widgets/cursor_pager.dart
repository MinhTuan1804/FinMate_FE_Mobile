import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/widgets/async_action_builder.dart';

/// Một trang dữ liệu phân trang theo cursor; [nextCursor] == null nghĩa là hết.
typedef CursorPageResult<T> = ({List<T> items, String? nextCursor});

/// Danh sách tải dần theo cursor: tự tải trang đầu, [loadMore] nối trang kế.
/// Lỗi trang đầu → state error; lỗi trang sau giữ danh sách cũ và bật [loadMoreFailed] để footer hiện "Thử lại".
class CursorPager<T> extends StateNotifier<AsyncValue<List<T>>> {
  CursorPager(this._fetch) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Future<CursorPageResult<T>> Function(String? cursor) _fetch;
  String? _cursor;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  // Tăng mỗi lần refresh để kết quả loadMore của lượt cũ không ghi đè danh sách mới.
  int _gen = 0;

  bool get hasMore => _cursor != null;
  bool get loadMoreFailed => _loadMoreFailed;

  Future<void> refresh() async {
    final gen = ++_gen;
    _loadMoreFailed = false;
    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final page = await _fetch(null);
      if (!mounted || gen != _gen) return;
      _cursor = page.nextCursor;
      state = AsyncValue.data(page.items);
    } catch (e, st) {
      if (mounted && gen == _gen) state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    final current = state.value;
    if (cursor == null || current == null || _loadingMore) return;
    final gen = _gen;
    _loadingMore = true;
    _loadMoreFailed = false;
    try {
      final page = await _fetch(cursor);
      if (!mounted || gen != _gen) return;
      _cursor = page.nextCursor;
      state = AsyncValue.data([...current, ...page.items]);
    } catch (_) {
      if (!mounted || gen != _gen) return;
      _loadMoreFailed = true;
      state = AsyncValue.data([...current]); // phát lại để footer đổi sang nút "Thử lại"
    } finally {
      _loadingMore = false;
    }
  }
}

/// Dòng cuối danh sách: spinner khi còn trang, nút "Thử lại" khi tải thêm lỗi.
/// [auto] = true chỉ dùng làm item cuối của ListView.builder (chỉ được dựng khi cuộn gần tới) — tự gọi loadMore.
/// Danh sách nằm trong Column (dựng hết một lượt) phải để [auto] = false → hiện nút "Xem thêm".
class CursorPagerFooter extends StatelessWidget {
  const CursorPagerFooter({super.key, required this.pager, this.auto = true});

  final CursorPager<Object?> pager;
  final bool auto;

  @override
  Widget build(BuildContext context) {
    if (!pager.hasMore) return const SizedBox.shrink();
    if (pager.loadMoreFailed) {
      return Center(
        child: TextButton(onPressed: pager.loadMore, child: const Text('Không tải thêm được — Thử lại')),
      );
    }
    if (!auto) {
      return Center(
        child: AsyncActionBuilder(
          onPressed: pager.loadMore,
          builder: (_, onTap, running) => TextButton(
            onPressed: onTap,
            child: running ? const ButtonLoadingIndicator() : const Text('Xem thêm'),
          ),
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => pager.loadMore());
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }
}
