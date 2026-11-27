import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/profile/data/legal_repository.dart';
import 'package:finmate/features/profile/domain/legal_document.dart';
import 'package:finmate/features/profile/presentation/screens/legal_document_screen.dart';

void main() {
  /// [document] là bản BE trả về; null = BE không có/lỗi, màn hình dùng bản có sẵn trong app.
  Future<void> pump(WidgetTester tester, LegalDocType type, {double width = 390, LegalDocument? document}) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [legalDocumentProvider.overrideWith((ref, kind) async => document)],
      child: MaterialApp(home: LegalDocumentScreen(type: type)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('BE có bản đã xuất bản: hiện nội dung, số phiên bản và ngày cập nhật từ BE', (tester) async {
    final doc = LegalDocument.fromJson({
      'version': 7,
      'updatedAt': '2026-11-14T03:00:00+07:00',
      'sections': [
        {'title': 'Phạm vi', 'body': 'Nội dung phạm vi từ máy chủ.'},
        {'title': 'Nhóm và quỹ chung', 'body': 'Nội dung nhóm từ máy chủ.'},
      ],
    });
    await pump(tester, LegalDocType.terms, document: doc);

    expect(find.text('Phiên bản 7 · cập nhật 14/11/2026'), findsOneWidget);
    expect(find.text('1. Phạm vi'), findsWidgets);
    expect(find.text('Nội dung nhóm từ máy chủ.'), findsOneWidget);
    expect(find.text('MỤC 02'), findsOneWidget);
    expect(find.text('MỤC 03'), findsNothing);
    expect(find.textContaining('Giới thiệu'), findsNothing, reason: 'không trộn với bản có sẵn trong app');
  });

  testWidgets('đang tải: hiện vòng chờ, không hiện bản có sẵn rồi đổi chữ', (tester) async {
    final completer = Completer<LegalDocument?>();
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [legalDocumentProvider.overrideWith((ref, kind) => completer.future)],
      child: const MaterialApp(home: LegalDocumentScreen(type: LegalDocType.terms)),
    ));
    await tester.pump();

    expect(find.byKey(const ValueKey('legal-loading')), findsOneWidget);
    expect(find.text('1. Giới thiệu'), findsNothing);

    completer.complete(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('legal-loading')), findsNothing);
    expect(find.text('1. Giới thiệu'), findsWidgets, reason: 'BE không trả bản nào: dùng bản có sẵn');
  });

  testWidgets('điều khoản: hiện số phiên bản thật từ ConsentVersions và đủ các mục', (tester) async {
    await pump(tester, LegalDocType.terms);

    expect(find.text('Điều khoản dịch vụ'), findsOneWidget);
    expect(find.text('Phiên bản ${ConsentVersions.terms}'), findsOneWidget);
    expect(find.text('1. Giới thiệu'), findsWidgets);
    expect(find.text('MỤC 04'), findsOneWidget);
    expect(find.textContaining('15/10/2026'), findsNothing, reason: 'không còn ngày cập nhật bịa');
  });

  testWidgets('chính sách bảo mật dùng cùng mẫu với nội dung riêng', (tester) async {
    await pump(tester, LegalDocType.privacy);

    expect(find.text('Chính sách bảo mật'), findsOneWidget);
    expect(find.textContaining('KHÔNG BAO GIỜ yêu cầu'), findsOneWidget);
  });

  testWidgets('tìm kiếm lọc mục theo nội dung; không khớp thì báo không tìm thấy', (tester) async {
    await pump(tester, LegalDocType.terms);

    await tester.enterText(find.byKey(const ValueKey('legal-search')), 'xóa vĩnh viễn');
    await tester.pumpAndSettle();
    expect(find.text('MỤC 04'), findsOneWidget);
    expect(find.text('MỤC 01'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('legal-search')), 'zzzz không có');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy mục phù hợp.'), findsOneWidget);
  });

  testWidgets('ở 320dp không tràn bố cục', (tester) async {
    await pump(tester, LegalDocType.terms, width: 320);
    expect(tester.takeException(), isNull);
  });
}
