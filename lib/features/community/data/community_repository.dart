import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finmate/core/network/api_client.dart';
import 'package:finmate/core/network/api_exceptions.dart';
import 'package:finmate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:finmate/features/community/domain/community.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(apiClient: ref.watch(apiClientProvider)),
);

/// Dữ liệu ảnh đã tải về: bytes thật + content-type (luôn "image/jpeg" theo BE).
class CommunityImageContent {
  final Uint8List data;
  final String contentType;

  const CommunityImageContent({required this.data, required this.contentType});
}

class CommunityRepository {
  final ApiClient apiClient;

  static const _path = '/api/v1/community';

  CommunityRepository({required this.apiClient});

  Future<List<CommunityTopicEntity>> getTopics() async {
    final response = await apiClient.get(
      '$_path/topics',
      fromJsonT: (json) => (json as List).map((e) => CommunityTopicEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  Future<List<CommunityProvinceEntity>> getRegions() async {
    final response = await apiClient.get(
      '$_path/regions',
      fromJsonT: (json) =>
          (json as List).map((e) => CommunityProvinceEntity.fromJson(e as Map<String, dynamic>)).toList(),
    );
    return response.data ?? const [];
  }

  Future<CommunityProfileEntity> getProfile() async {
    final response = await apiClient.get(
      '$_path/me',
      fromJsonT: (json) => CommunityProfileEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<CommunityProfileEntity> updateProfile({String? provinceCode, String? areaCode, bool? promptsEnabled}) async {
    final response = await apiClient.patch(
      '$_path/me',
      data: {
        if (provinceCode != null) 'provinceCode': provinceCode,
        if (areaCode != null) 'areaCode': areaCode,
        if (promptsEnabled != null) 'promptsEnabled': promptsEnabled,
      },
      fromJsonT: (json) => CommunityProfileEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<CommunityPlacePageEntity> listPlaces({
    String? provinceCode,
    String? areaCode,
    String? tag,
    BigInt? maxPriceCents,
    String? q,
    String? cursor,
    int limit = 0,
  }) async {
    final response = await apiClient.get(
      '$_path/places',
      queryParameters: {
        if (provinceCode != null) 'provinceCode': provinceCode,
        if (areaCode != null) 'areaCode': areaCode,
        if (tag != null) 'tag': tag,
        if (maxPriceCents != null) 'maxPriceCents': maxPriceCents.toInt(),
        if (q != null) 'q': q,
        if (cursor != null) 'cursor': cursor,
        if (limit > 0) 'limit': limit,
      },
      fromJsonT: (json) => CommunityPlacePageEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<CommunityPlaceDetailEntity> getPlace(String id) async {
    final response = await apiClient.get(
      '$_path/places/$id',
      fromJsonT: (json) => CommunityPlaceDetailEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<CommunityPostPageEntity> listPosts({
    String? topic,
    String? provinceCode,
    String? areaCode,
    String? tag,
    String? sort,
    bool mine = false,
    String? cursor,
    int limit = 0,
  }) async {
    final response = await apiClient.get(
      '$_path/posts',
      queryParameters: {
        if (topic != null) 'topic': topic,
        if (provinceCode != null) 'provinceCode': provinceCode,
        if (areaCode != null) 'areaCode': areaCode,
        if (tag != null) 'tag': tag,
        if (sort != null) 'sort': sort,
        if (mine) 'mine': true,
        if (cursor != null) 'cursor': cursor,
        if (limit > 0) 'limit': limit,
      },
      fromJsonT: (json) => CommunityPostPageEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<CommunityPostEntity> getPost(String id) async {
    final response = await apiClient.get(
      '$_path/posts/$id',
      fromJsonT: (json) => CommunityPostEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Chủ đề `places`: truyền [placeId] (chia sẻ lại quán đã có) HOẶC [placeName]+[provinceCode]+[areaCode] (quán mới).
  /// [body] rỗng với chủ đề `places` = "chạm một lần" (chỉ tính điểm quán, không hiện bảng tin).
  Future<CommunityPostEntity> createPost({
    required String topic,
    String? title,
    String? body,
    bool? isAnonymous,
    List<String>? tags,
    String? placeId,
    String? placeName,
    String? provinceCode,
    String? areaCode,
    String? addressText,
    BigInt? priceCents,
    String? transactionId,
  }) async {
    final response = await apiClient.post(
      '$_path/posts',
      data: {
        'topic': topic,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (isAnonymous != null) 'isAnonymous': isAnonymous,
        if (tags != null) 'tags': tags,
        if (placeId != null) 'placeId': placeId,
        if (placeName != null) 'placeName': placeName,
        if (provinceCode != null) 'provinceCode': provinceCode,
        if (areaCode != null) 'areaCode': areaCode,
        if (addressText != null) 'addressText': addressText,
        if (priceCents != null) 'priceCents': priceCents.toInt(),
        if (transactionId != null) 'transactionId': transactionId,
      },
      fromJsonT: (json) => CommunityPostEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// [priceCents] = 0 để bỏ giá đã đặt (BE coi null là "giữ nguyên", 0 là "xóa giá").
  Future<CommunityPostEntity> updatePost(
    String id, {
    String? title,
    String? body,
    bool? isAnonymous,
    List<String>? tags,
    BigInt? priceCents,
  }) async {
    final response = await apiClient.patch(
      '$_path/posts/$id',
      data: {
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (isAnonymous != null) 'isAnonymous': isAnonymous,
        if (tags != null) 'tags': tags,
        if (priceCents != null) 'priceCents': priceCents.toInt(),
      },
      fromJsonT: (json) => CommunityPostEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<void> deletePost(String id) => apiClient.delete('$_path/posts/$id');

  Future<CommunityVoteEntity> vote(String postId) async {
    final response = await apiClient.put(
      '$_path/posts/$postId/vote',
      fromJsonT: (json) => CommunityVoteEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// `ApiClient.delete` (dùng cho mọi DELETE khác ở đây) không trả dữ liệu, nhưng route này trả lại
  /// {voteCount, votedByMe} sau khi bỏ vote nên gọi thẳng `apiClient.dio` để đọc JSON envelope.
  Future<CommunityVoteEntity> unvote(String postId) async {
    try {
      final response = await apiClient.dio.delete<Map<String, dynamic>>('$_path/posts/$postId/vote');
      final body = response.data!;
      return CommunityVoteEntity.fromJson(body['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _decodeJsonError(e);
    }
  }

  Future<CommunityCommentPageEntity> listComments(String postId, {String? cursor, int limit = 0}) async {
    final response = await apiClient.get(
      '$_path/posts/$postId/comments',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        if (limit > 0) 'limit': limit,
      },
      fromJsonT: (json) => CommunityCommentPageEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<CommunityCommentEntity> createComment(String postId, {required String body, bool? isAnonymous}) async {
    final response = await apiClient.post(
      '$_path/posts/$postId/comments',
      data: {
        'body': body,
        if (isAnonymous != null) 'isAnonymous': isAnonymous,
      },
      fromJsonT: (json) => CommunityCommentEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<CommunityCommentEntity> updateComment(String id, {String? body, bool? isAnonymous}) async {
    final response = await apiClient.patch(
      '$_path/comments/$id',
      data: {
        if (body != null) 'body': body,
        if (isAnonymous != null) 'isAnonymous': isAnonymous,
      },
      fromJsonT: (json) => CommunityCommentEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  Future<void> deleteComment(String id) => apiClient.delete('$_path/comments/$id');

  Future<CommunityImageEntity> uploadImage(String postId, {required String filePath, required String fileName}) async {
    final formData = FormData.fromMap({'file': await MultipartFile.fromFile(filePath, filename: fileName)});
    final response = await apiClient.uploadFile<CommunityImageEntity>(
      '$_path/posts/$postId/images',
      formData: formData,
      fromJsonT: (json) => CommunityImageEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data as CommunityImageEntity;
  }

  Future<void> deleteImage(String postId, String imageId) => apiClient.delete('$_path/posts/$postId/images/$imageId');

  /// Route này KHÔNG bọc trong envelope {success,data,error} — BE trả file ảnh JPEG thô
  /// (`return File(content.Data, "image/jpeg")`), nên gọi trực tiếp `apiClient.dio` với responseType bytes,
  /// giống hệt `SupportRepository.getAttachmentBytes`.
  Future<CommunityImageContent> getImageBytes(String imageId) async {
    try {
      final response = await apiClient.dio.get<List<int>>(
        '$_path/images/$imageId',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? const []);
      final contentType = response.headers.value('content-type') ?? 'application/octet-stream';
      return CommunityImageContent(data: bytes, contentType: contentType);
    } on DioException catch (e) {
      throw _decodeByteError(e);
    }
  }

  /// [reason]: "scam" | "personal_info" | "harassment" | "sexual" | "spam" | "self_harm" | "other" (đúng chuỗi BE nhận, xem docs/community-api.md).
  Future<void> reportPost(String postId, String reason) async {
    await apiClient.post<void>('$_path/posts/$postId/report', data: {'reason': reason}, fromJsonT: (_) {});
  }

  Future<void> reportComment(String commentId, String reason) async {
    await apiClient.post<void>('$_path/comments/$commentId/report', data: {'reason': reason}, fromJsonT: (_) {});
  }

  Future<CommunitySharePromptEntity> sharePrompt(String transactionId) async {
    final response = await apiClient.get(
      '$_path/share-prompt',
      queryParameters: {'transactionId': transactionId},
      fromJsonT: (json) => CommunitySharePromptEntity.fromJson(json as Map<String, dynamic>),
    );
    return response.data!;
  }

  /// Lỗi của route gọi thẳng `apiClient.dio` (không qua `ApiClient._handleError`, private) nhưng response
  /// vẫn là JSON envelope bình thường (không phải bytes) — khác `_decodeByteError` ở dưới.
  ApiException _decodeJsonError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'] as Map<String, dynamic>?;
      if (error != null) {
        return ApiException(
          message: error['message'] as String? ?? 'Đã xảy ra lỗi.',
          code: error['code'] as String?,
          statusCode: e.response?.statusCode,
        );
      }
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return NetworkException();
    }
    return ApiException(message: 'Đã xảy ra lỗi. Vui lòng thử lại.', statusCode: e.response?.statusCode);
  }

  /// Lỗi của route trả bytes vẫn là JSON {error:{code,message}}, nhưng Dio nhận dưới dạng `List<int>` thô
  /// (responseType đã đặt bytes) nên phải tự giải mã, không đi qua `ApiClient._handleError` (private, chỉ xử lý JSON đã parse).
  ApiException _decodeByteError(DioException e) {
    final raw = e.response?.data;
    if (raw is List<int>) {
      try {
        final decoded = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
        final error = decoded['error'] as Map<String, dynamic>?;
        if (error != null) {
          return ApiException(
            message: error['message'] as String? ?? 'Đã xảy ra lỗi.',
            code: error['code'] as String?,
            statusCode: e.response?.statusCode,
          );
        }
      } catch (_) {
        // Không parse được thì rơi xuống thông báo chung ở dưới.
      }
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return NetworkException();
    }
    return ApiException(message: 'Đã xảy ra lỗi. Vui lòng thử lại.', statusCode: e.response?.statusCode);
  }
}
