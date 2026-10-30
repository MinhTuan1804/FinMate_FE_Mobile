import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/app_spacing.dart';
import 'package:finmate/core/theme/app_typography.dart';
import 'package:finmate/features/qr_transfer/domain/qr_models.dart';

/// Hộp chọn ngân hàng có ô tìm kiếm (danh sách dài ~30 ngân hàng). Trả về ngân hàng được chọn, null nếu đóng. Ngân hàng FinMate đọc được thông báo có nhãn riêng để người dùng biết chọn nó làm ngân hàng
/// GỬI thì giao dịch sau đó tự khớp.
Future<QrBank?> showBankPicker(
  BuildContext context, {
  required List<QrBank> banks,
  required String title,
  String? selectedBin,
  bool showMatchHint = false,
}) {
  return showModalBottomSheet<QrBank>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _BankPickerSheet(banks: banks, title: title, selectedBin: selectedBin, showMatchHint: showMatchHint),
  );
}

class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet({required this.banks, required this.title, required this.selectedBin, required this.showMatchHint});

  final List<QrBank> banks;
  final String title;
  final String? selectedBin;
  final bool showMatchHint;

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.banks.where((b) => b.name.toLowerCase().contains(_query.toLowerCase())).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(widget.title, style: AppTypography.h3(context)),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Tìm ngân hàng', prefixIcon: Icon(LucideIcons.search, size: 18)),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('Không có ngân hàng nào khớp.', style: AppTypography.caption(context)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final bank = filtered[index];
                          final selected = bank.bin == widget.selectedBin;
                          return ListTile(
                            minTileHeight: 56,
                            leading: Icon(selected ? LucideIcons.check : LucideIcons.landmark, size: 20, color: selected ? theme.colorScheme.primary : null),
                            title: Text(bank.name),
                            subtitle: widget.showMatchHint && bank.canMatchNotifications ? const Text('Tự khớp giao dịch với thông báo') : null,
                            selected: selected,
                            onTap: () => Navigator.of(context).pop(bank),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
