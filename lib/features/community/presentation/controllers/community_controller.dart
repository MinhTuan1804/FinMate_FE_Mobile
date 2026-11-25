import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/widgets/cursor_pager.dart';
import 'package:finmate/features/community/data/community_image_source.dart';
import 'package:finmate/features/community/data/community_repository.dart';
import 'package:finmate/features/community/domain/community.dart';

final communityTopicsProvider = FutureProvider.autoDispose<List<CommunityTopicEntity>>(
  (ref) => ref.watch(communityRepositoryProvider).getTopics(),
);

final communityRegionsProvider = FutureProvider.autoDispose<List<CommunityProvinceEntity>>(
  (ref) => ref.watch(communityRepositoryProvider).getRegions(),
);

final communityProfileProvider = FutureProvider.autoDispose<CommunityProfileEntity>(
  (ref) => ref.watch(communityRepositoryProvider).getProfile(),
);

final communityPlacesProvider =
    StateNotifierProvider.autoDispose<CursorPager<CommunityPlaceSummaryEntity>, AsyncValue<List<CommunityPlaceSummaryEntity>>>((ref) {
  final repo = ref.watch(communityRepositoryProvider);
  return CursorPager((cursor) async {
    final page = await repo.listPlaces(cursor: cursor);
    return (items: page.items, nextCursor: page.nextCursor);
  });
});

final communityPlaceDetailProvider = FutureProvider.autoDispose.family<CommunityPlaceDetailEntity, String>(
  (ref, placeId) => ref.watch(communityRepositoryProvider).getPlace(placeId),
);

/// Bộ lọc bảng tin. Dùng `record` làm family key vì so sánh bằng cấu trúc (Riverpod cần `==`/`hashCode` đúng).
typedef CommunityFeedFilter = ({String? topic, String? sort, bool mine});

const defaultFeedFilter = (topic: null, sort: null, mine: false);

/// Bảng tin cuộn vô hạn theo cursor.
final communityFeedProvider = StateNotifierProvider.autoDispose
    .family<CursorPager<CommunityPostEntity>, AsyncValue<List<CommunityPostEntity>>, CommunityFeedFilter>((ref, filter) {
  final repo = ref.watch(communityRepositoryProvider);
  return CursorPager((cursor) async {
    final page = await repo.listPosts(topic: filter.topic, sort: filter.sort, mine: filter.mine, cursor: cursor);
    return (items: page.items, nextCursor: page.nextCursor);
  });
});

/// Chi tiết 1 bài + bình luận (trang đầu) + các thao tác: vote, bình luận, ảnh, báo cáo, xóa.
/// Mỗi lần gọi BE đều nhận entity MỚI (parse lại JSON) nên không gặp bẫy Riverpod so sánh bằng-giá-trị
/// (đã rút ra ở Survey/Support: không có chỗ nào emit lại CÙNG MỘT instance cũ).
class CommunityPostDetailState {
  final CommunityPostEntity post;
  final List<CommunityCommentEntity> comments;
  final String? commentsCursor;

  const CommunityPostDetailState({required this.post, required this.comments, this.commentsCursor});

  bool get hasMoreComments => commentsCursor != null;
}

final communityPostDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<CommunityPostDetailController, AsyncValue<CommunityPostDetailState>, String>(
  (ref, postId) => CommunityPostDetailController(ref.watch(communityRepositoryProvider), postId)..load(),
);

class CommunityPostDetailController extends StateNotifier<AsyncValue<CommunityPostDetailState>> {
  CommunityPostDetailController(this.repository, this.postId) : super(const AsyncValue.loading());

  final CommunityRepository repository;
  final String postId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final post = await repository.getPost(postId);
      final comments = await repository.listComments(postId);
      state = AsyncValue.data(CommunityPostDetailState(post: post, comments: comments.items, commentsCursor: comments.nextCursor));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Nối trang bình luận kế tiếp; lỗi ném ra cho nút gọi tự báo.
  Future<void> loadMoreComments() async {
    final current = state.value;
    final cursor = current?.commentsCursor;
    if (current == null || cursor == null) return;
    final page = await repository.listComments(postId, cursor: cursor);
    if (!mounted || state.value != current) return;
    state = AsyncValue.data(CommunityPostDetailState(
      post: current.post,
      comments: [...current.comments, ...page.items],
      commentsCursor: page.nextCursor,
    ));
  }

  Future<void> vote() async {
    final current = state.value;
    if (current == null) return;
    await repository.vote(postId);
    await load();
  }

  Future<void> unvote() async {
    final current = state.value;
    if (current == null) return;
    await repository.unvote(postId);
    await load();
  }

  Future<void> addComment(String body, {bool? isAnonymous}) async {
    await repository.createComment(postId, body: body, isAnonymous: isAnonymous);
    await load();
  }

  Future<void> deleteComment(String commentId) async {
    await repository.deleteComment(commentId);
    await load();
  }

  Future<void> uploadImage(String filePath, String fileName) async {
    await repository.uploadImage(postId, filePath: filePath, fileName: fileName);
    await load();
  }

  Future<void> deleteImage(String imageId) async {
    await repository.deleteImage(postId, imageId);
    await load();
  }

  Future<void> reportPost(String reason) => repository.reportPost(postId, reason);

  Future<void> reportComment(String commentId, String reason) => repository.reportComment(commentId, reason);

  Future<void> deletePost() => repository.deletePost(postId);
}

final communitySharePromptActionProvider =
    Provider.autoDispose<Future<CommunitySharePromptEntity> Function(String transactionId)>(
  (ref) => (transactionId) => ref.read(communityRepositoryProvider).sharePrompt(transactionId),
);

final communityCreatePostActionProvider = Provider.autoDispose<
    Future<CommunityPostEntity> Function({
      required String topic,
      String? title,
      String? body,
      bool? isAnonymous,
      List<String>? tags,
      String? placeId,
      String? placeName,
      String? provinceCode,
      String? areaCode,
    })>(
  (ref) => ({
    required topic,
    title,
    body,
    isAnonymous,
    tags,
    placeId,
    placeName,
    provinceCode,
    areaCode,
  }) =>
      ref.read(communityRepositoryProvider).createPost(
            topic: topic,
            title: title,
            body: body,
            isAnonymous: isAnonymous,
            tags: tags,
            placeId: placeId,
            placeName: placeName,
            provinceCode: provinceCode,
            areaCode: areaCode,
          ),
);

final communityUpdateProfileActionProvider = Provider.autoDispose<
    Future<CommunityProfileEntity> Function({String? provinceCode, String? areaCode, bool? promptsEnabled})>(
  (ref) => ({provinceCode, areaCode, promptsEnabled}) => ref
      .read(communityRepositoryProvider)
      .updateProfile(provinceCode: provinceCode, areaCode: areaCode, promptsEnabled: promptsEnabled),
);

final pickCommunityImageProvider = Provider.autoDispose<Future<PickedImage?> Function()>(
  (ref) => () => ref.read(communityImageSourceProvider).pickFromGallery(),
);
