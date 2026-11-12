import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';

class CommunityPost {
  final String id;
  final String authorName;
  final String authorBadge;
  final String content;
  final String tag;
  final DateTime createdAt;
  int likeCount;
  int commentCount;
  bool isLiked;

  CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorBadge,
    required this.content,
    required this.tag,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    this.isLiked = false,
  });
}

/// Màn J1 - J6: Diễn đàn Cộng đồng FinMate (Community Feed Screen)
class CommunityFeedScreen extends ConsumerStatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  ConsumerState<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends ConsumerState<CommunityFeedScreen> {
  final List<CommunityPost> _posts = [
    CommunityPost(
      id: 'p1',
      authorName: 'Hoàng Linh',
      authorBadge: 'Tiết kiệm kỳ cựu',
      content:
          'Kinh nghiệm của mình sau 6 tháng áp dụng quy tắc 50/30/20 với FinMate: Đừng cắt giảm quá đà ở hũ hưởng thụ (PLAY), hãy giữ đúng 10-15% để có động lực duy trì lâu dài!',
      tag: 'Kinh nghiệm',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      likeCount: 42,
      commentCount: 8,
    ),
    CommunityPost(
      id: 'p2',
      authorName: 'Trần Minh Đức',
      authorBadge: 'Thành viên mới',
      content:
          'Mọi người cho mình hỏi nếu tháng này tiền thưởng về đột xuất thì nên cho vào quỹ đầu tư tự do tài chính hay nạp hết vào trả nợ trước hạn vậy?',
      tag: 'Hỏi đáp',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      likeCount: 19,
      commentCount: 14,
    ),
    CommunityPost(
      id: 'p3',
      authorName: 'Nguyễn Thảo',
      authorBadge: 'Chuyên gia tối ưu',
      content:
          'Gợi ý quán cà phê làm việc yên tĩnh khu vực Cầu Giấy, đồ uống chỉ 35-45k mà wifi cực khỏe, rất hợp với các bạn freelancer muốn tối ưu chi phí!',
      tag: 'Địa điểm',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      likeCount: 65,
      commentCount: 22,
    ),
  ];

  void _toggleLike(CommunityPost post) {
    setState(() {
      post.isLiked = !post.isLiked;
      post.likeCount += post.isLiked ? 1 : -1;
    });
  }

  void _createPostDialog() {
    final contentController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng bài chia sẻ'),
        content: TextField(
          controller: contentController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Chia sẻ mẹo tài chính hoặc câu hỏi của bạn với cộng đồng...',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (contentController.text.trim().isNotEmpty) {
                setState(() {
                  _posts.insert(
                    0,
                    CommunityPost(
                      id: 'p-${DateTime.now().millisecondsSinceEpoch}',
                      authorName: 'Bạn (Tôi)',
                      authorBadge: 'Thành viên',
                      content: contentController.text.trim(),
                      tag: 'Chia sẻ',
                      createdAt: DateTime.now(),
                      likeCount: 0,
                      commentCount: 0,
                    ),
                  );
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã đăng bài lên cộng đồng!')),
                );
              }
            },
            child: const Text('Đăng bài'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cộng đồng tài chính'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPostDialog,
        backgroundColor: AppColors.primaryAction(context),
        foregroundColor: AppColors.onPrimaryAction(context),
        icon: const Icon(LucideIcons.penLine, size: 18),
        label: const Text('Viết bài mới'),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Community Banner
              ZenvestHeroDeck(
                peekBadgeText: 'COMMUNITY',
                child: LiquidGlassCard(
                  variant: LiquidGlassVariant.iridescentHero,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DIỄN ĐÀN NGƯỜI DÙNG FINMATE',
                        style: AppTypography.caption(context).copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cùng nhau làm chủ tài chính',
                        style: AppTypography.h1(context).copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Trao đổi kinh nghiệm tiết kiệm, hỏi đáp mẹo chi tiêu thông minh và khám phá các địa điểm dịch vụ giá tốt.',
                        style: AppTypography.caption(context).copyWith(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text('BÀI VIẾT MỚI NHẤT', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              for (final post in _posts) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: LiquidGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                              child: Text(
                                post.authorName[0],
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.authorName,
                                    style: AppTypography.body(context).copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${post.authorBadge} • ${DateFormat('HH:mm - dd/MM').format(post.createdAt)}',
                                    style: AppTypography.caption(context).copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.15),
                                borderRadius: AppSpacing.roundedPill,
                              ),
                              child: Text(
                                post.tag,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          post.content,
                          style: AppTypography.body(context).copyWith(
                            fontSize: 13.5,
                            height: 1.45,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _toggleLike(post),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.heart,
                                      size: 16,
                                      color: post.isLiked ? AppColors.danger : AppColors.textMuted(context),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${post.likeCount}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: post.isLiked ? AppColors.danger : AppColors.textMuted(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Row(
                              children: [
                                Icon(LucideIcons.messageSquare, size: 16, color: AppColors.textMuted(context)),
                                const SizedBox(width: 6),
                                Text(
                                  '${post.commentCount}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
