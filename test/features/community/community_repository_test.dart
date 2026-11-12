import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/community/data/community_repository.dart';
import '../../fixtures/fixture.dart';

void main() {
  group('CommunityRepository', () {
    test('getTopics trả đúng danh sách chủ đề', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_topics'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final topics = await repo.getTopics();

      expect(adapter.to('/api/v1/community/topics').single.method, 'GET');
      expect(topics, hasLength(4));
      expect(topics[0].code, 'places');
      expect(topics[0].requiresPlace, isTrue);
      expect(topics[1].requiresPlace, isFalse);
    });

    test('getRegions trả đúng tỉnh/khu vực', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_regions'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final regions = await repo.getRegions();

      expect(regions, hasLength(2));
      expect(regions[0].code, 'HCM');
      expect(regions[0].areas, hasLength(2));
      expect(regions[0].areas[0].code, 'Q1');
    });

    test('getProfile trả đúng hồ sơ cộng đồng', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_profile'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final profile = await repo.getProfile();

      expect(profile.provinceCode, 'HCM');
      expect(profile.consentGranted, isTrue);
      expect(profile.isMuted, isFalse);
    });

    test('updateProfile chỉ gửi field được truyền', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_profile_updated'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final updated = await repo.updateProfile(provinceCode: 'HN', areaCode: 'HK', promptsEnabled: false);

      final req = adapter.to('/api/v1/community/me').single;
      expect(req.method, 'PATCH');
      expect(req.data, {'provinceCode': 'HN', 'areaCode': 'HK', 'promptsEnabled': false});
      expect(updated.provinceCode, 'HN');
      expect(updated.promptsEnabled, isFalse);
    });

    test('listPlaces trả đúng danh sách quán, giá BigInt, ngày không toLocal', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_places'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final page = await repo.listPlaces();

      expect(page.items, hasLength(1));
      expect(page.items[0].name, 'Bún bò Huế Cô Ba');
      expect(page.items[0].typicalPriceCents, BigInt.from(3500));
      expect(page.items[0].lastSharedOn, DateTime.parse('2026-10-28'));
    });

    test('getPlace trả đúng chi tiết quán + bài liên quan', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_place_detail'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final detail = await repo.getPlace('33333333-3333-3333-3333-333333333333');

      expect(detail.place.name, 'Bún bò Huế Cô Ba');
      expect(detail.posts, hasLength(1));
      expect(detail.posts[0].spentHereVerified, isTrue);
    });

    test('listPosts gửi đúng query và parse status chỉ có khi isMine', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_posts'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final page = await repo.listPosts(topic: 'experience', sort: 'new', mine: true);

      final req = adapter.to('/api/v1/community/posts').single;
      expect(req.queryParameters, {'topic': 'experience', 'sort': 'new', 'mine': true});
      expect(page.items, hasLength(2));
      expect(page.items[0].isMine, isTrue);
      expect(page.items[0].status, 'visible');
      expect(page.items[1].isMine, isFalse);
      expect(page.items[1].status, isNull);
      expect(page.items[1].place?.name, 'Bún bò Huế Cô Ba');
    });

    test('listPosts rỗng trả danh sách rỗng', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_posts_empty'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      expect((await repo.listPosts()).items, isEmpty);
    });

    test('getPost trả đúng chi tiết 1 bài', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_post_detail'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final post = await repo.getPost('11111111-1111-1111-1111-111111111111');

      expect(post.title, 'Tiết kiệm 2 triệu/tháng nhờ nấu cơm mang đi làm');
      expect(post.images, hasLength(1));
      expect(post.images[0].status, 'pending');
      expect(post.images[0].isApproved, isFalse);
    });

    test('createPost gửi đúng body và trả bài vừa tạo', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_post_created'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final post = await repo.createPost(topic: 'question', body: 'Có ai biết app nào theo dõi chi tiêu tốt không?');

      final req = adapter.to('/api/v1/community/posts').where((r) => r.method == 'POST').single;
      expect(req.data, {'topic': 'question', 'body': 'Có ai biết app nào theo dõi chi tiêu tốt không?'});
      expect(post.id, '66666666-6666-6666-6666-666666666666');
      expect(post.isMine, isTrue);
    });

    test('deletePost gọi đúng DELETE', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null, 'error': null, 'meta': null}));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      await repo.deletePost('11111111-1111-1111-1111-111111111111');

      final req = adapter.to('/api/v1/community/posts/11111111-1111-1111-1111-111111111111').single;
      expect(req.method, 'DELETE');
    });

    test('vote gọi PUT và trả voteCount/votedByMe mới', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_vote'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final result = await repo.vote('11111111-1111-1111-1111-111111111111');

      expect(adapter.to('/vote').single.method, 'PUT');
      expect(result.voteCount, 13);
      expect(result.votedByMe, isTrue);
    });

    test('unvote gọi DELETE và đọc lại voteCount/votedByMe từ envelope (ApiClient.delete bỏ data)', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_unvote'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final result = await repo.unvote('11111111-1111-1111-1111-111111111111');

      expect(adapter.to('/vote').single.method, 'DELETE');
      expect(result.voteCount, 12);
      expect(result.votedByMe, isFalse);
    });

    test('unvote lỗi thì parse đúng ApiException từ envelope JSON', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_error_consent_required', status: 400));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      await expectLater(
        repo.unvote('11111111-1111-1111-1111-111111111111'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'COMMUNITY_CONSENT_REQUIRED')),
      );
    });

    test('listComments trả đúng danh sách bình luận', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_comments'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final page = await repo.listComments('11111111-1111-1111-1111-111111111111');

      expect(page.items, hasLength(1));
      expect(page.items[0].body, 'Hay quá, cảm ơn bạn chia sẻ!');
    });

    test('createComment gửi đúng body và trả bình luận vừa tạo', () async {
      final adapter = RouteAdapter((o) => respondFixture('community_comment_created'));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final comment = await repo.createComment('11111111-1111-1111-1111-111111111111',
          body: 'Mình cũng vậy, tiết kiệm được nhiều.');

      final req = adapter.to('/comments').where((r) => r.method == 'POST').single;
      expect(req.data, {'body': 'Mình cũng vậy, tiết kiệm được nhiều.'});
      expect(comment.isMine, isTrue);
    });

    test('deleteComment gọi đúng DELETE', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null, 'error': null, 'meta': null}));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      await repo.deleteComment('77777777-7777-7777-7777-777777777777');

      expect(adapter.to('/comments/77777777-7777-7777-7777-777777777777').single.method, 'DELETE');
    });

    test('deleteImage gọi đúng DELETE theo đúng path', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null, 'error': null, 'meta': null}));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      await repo.deleteImage('11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555555');

      final req = adapter.to('/images/55555555-5555-5555-5555-555555555555').single;
      expect(req.method, 'DELETE');
    });

    test('reportPost gửi đúng reason', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null, 'error': null, 'meta': null}));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      await repo.reportPost('11111111-1111-1111-1111-111111111111', 'spam');

      final req = adapter.to('/report').single;
      expect(req.method, 'POST');
      expect(req.data, {'reason': 'spam'});
    });

    test('reportComment gửi đúng reason', () async {
      final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': null, 'error': null, 'meta': null}));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      await repo.reportComment('77777777-7777-7777-7777-777777777777', 'harassment');

      final req = adapter.to('/comments/77777777-7777-7777-7777-777777777777/report').single;
      expect(req.data, {'reason': 'harassment'});
    });

    test('sharePrompt gửi đúng transactionId và trả gợi ý chia sẻ', () async {
      final adapter = RouteAdapter((o) => respondJson({
            'success': true,
            'data': {
              'shouldPrompt': true,
              'suggestedPlaceName': 'Bún bò Huế Cô Ba',
              'suggestedPriceCents': 3500,
              'existingPlaces': [],
            },
            'error': null,
            'meta': null,
          }));
      final repo = CommunityRepository(apiClient: testApiClient(adapter));

      final prompt = await repo.sharePrompt('tx-1');

      final req = adapter.to('/share-prompt').single;
      expect(req.queryParameters, {'transactionId': 'tx-1'});
      expect(prompt.shouldPrompt, isTrue);
      expect(prompt.suggestedPriceCents, BigInt.from(3500));
    });
  });
}
