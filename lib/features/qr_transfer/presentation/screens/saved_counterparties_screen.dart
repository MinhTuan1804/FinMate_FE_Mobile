import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_colors.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/core/widgets/glass/liquid_glass.dart';
import 'package:finmate/features/qr_transfer/domain/vietqr_parser.dart';

class SavedCounterparty {
  final String id;
  final String name;
  final String accountNumber;
  final String bankName;
  final String nickname;

  const SavedCounterparty({
    required this.id,
    required this.name,
    required this.accountNumber,
    required this.bankName,
    required this.nickname,
  });
}

/// Màn C4 & C5: Danh sách người nhận chuyển khoản VietQR đã lưu (Saved Counterparties Screen)
class SavedCounterpartiesScreen extends ConsumerStatefulWidget {
  const SavedCounterpartiesScreen({super.key});

  @override
  ConsumerState<SavedCounterpartiesScreen> createState() => _SavedCounterpartiesScreenState();
}

class _SavedCounterpartiesScreenState extends ConsumerState<SavedCounterpartiesScreen> {
  final List<SavedCounterparty> _recipients = [
    const SavedCounterparty(
      id: 'cp1',
      name: 'NGUYEN VAN AN',
      accountNumber: '19034567891011',
      bankName: 'Techcombank',
      nickname: 'Bạn An (Tiền phòng)',
    ),
    const SavedCounterparty(
      id: 'cp2',
      name: 'CONG TY CP THUC PHAM',
      accountNumber: '0451000345678',
      bankName: 'Vietcombank',
      nickname: 'Tiệm tạp hóa cô Ba',
    ),
    const SavedCounterparty(
      id: 'cp3',
      name: 'TRAN THI MAI',
      accountNumber: '10287654321',
      bankName: 'MBBank',
      nickname: 'Mai (Quỹ nhóm)',
    ),
  ];

  void _editNickname(SavedCounterparty item) {
    final controller = TextEditingController(text: item.nickname);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi biệt danh người nhận'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Biệt danh gợi nhớ'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã cập nhật biệt danh người nhận!')),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Người nhận đã lưu'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('DANH SÁCH TÀI KHOẢN VIETQR THƯỜNG DÙNG', style: AppTypography.sectionLabel(context)),
              const SizedBox(height: 12),

              for (final r in _recipients) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LiquidGlassCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () {
                      context.push(
                        '/qr-transfer',
                        extra: VietQrData(
                          bankBin: '970407',
                          accountNumber: r.accountNumber,
                          beneficiaryName: r.name,
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(LucideIcons.send, size: 20, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.nickname,
                                style: AppTypography.body(context).copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${r.name} • ${r.bankName}',
                                style: AppTypography.caption(context).copyWith(fontSize: 12.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.accountNumber,
                                style: AppTypography.tabular(
                                  AppTypography.caption(context).copyWith(
                                    color: AppColors.textMuted(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.pencil, size: 16),
                          tooltip: 'Sửa biệt danh',
                          onPressed: () => _editNickname(r),
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
