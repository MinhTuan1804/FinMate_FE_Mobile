import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/community/presentation/screens/community_post_detail_screen.dart';
import '../../fixtures/fixture.dart';

const _postId = '11111111-1111-1111-1111-111111111111';

Future<void> _pump(WidgetTester tester, RouteAdapter adapter) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(testApiClient(adapter))],
    child: const MaterialApp(home: CommunityPostDetailScreen(postId: _postId)),
  ));
  await tester.pumpAndSettle();
}

RouteAdapter _baseAdapter({ResponseBody? Function(RequestOptions o)? extra}) => RouteAdapter((o) {
      final e = extra?.call(o);
      if (e != null) return e;
      if (o.path.contains('/comments')) return respondFixture('community_comments');
      return respondFixture('community_post_detail');
    });

void main() {
  group('CommunityPostDetailScreen', () {
    testWidgets('hiện nội dung bài, trạng thái, ảnh và bình luận', (tester) async {
      await _pump(tester, _baseAdapter());

      expect(find.text('Tiết kiệm 2 triệu/tháng nhờ nấu cơm mang đi làm'), findsOneWidget);
      expect(find.byKey(const ValueKey('community-post-status')), findsOneWidget);
      expect(find.byKey(const ValueKey('community-image-55555555-5555-5555-5555-555555555555')), findsOneWidget);
      expect(find.byKey(const ValueKey('community-comment-77777777-7777-7777-7777-777777777777')), findsOneWidget);
    });

    testWidgets('bấm vote thì gọi PUT rồi tải lại, hiện voteCount mới', (tester) async {
      var voted = false;
      final adapter = _baseAdapter(extra: (o) {
        if (o.path.contains('/vote') && o.method == 'PUT') {
          voted = true;
          return respondFixture('community_vote');
        }
        if (voted && o.path.endsWith('/posts/$_postId')) return respondFixture('community_post_detail');
        return null;
      });
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('community-post-vote')));
      await tester.pumpAndSettle();

      expect(adapter.to('/vote').single.method, 'PUT');
    });

    testWidgets('thêm bình luận gửi đúng body', (tester) async {
      final adapter = _baseAdapter(extra: (o) {
        if (o.path.contains('/comments') && o.method == 'POST') return respondFixture('community_comment_created');
        return null;
      });
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('community-add-comment')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('community-comment-body')), 'Mình cũng vậy, tiết kiệm được nhiều.');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gửi'));
      await tester.pumpAndSettle();

      final req = adapter.requests.firstWhere((r) => r.path.contains('/comments') && r.method == 'POST');
      expect(req.data, {'body': 'Mình cũng vậy, tiết kiệm được nhiều.'});
    });

    testWidgets('báo cáo bài chọn lý do rồi gửi đúng reason', (tester) async {
      final adapter = _baseAdapter(extra: (o) {
        if (o.path.contains('/report')) return respondJson({'success': true, 'data': null, 'error': null, 'meta': null});
        return null;
      });
      await _pump(tester, adapter);

      await tester.tap(find.byKey(const ValueKey('community-post-report')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('community-report-reason-spam')));
      await tester.pumpAndSettle();

      final req = adapter.requests.firstWhere((r) => r.path.contains('/report'));
      expect(req.data, {'reason': 'spam'});
      expect(find.text('Đã gửi báo cáo.'), findsOneWidget);
    });
  });
}
