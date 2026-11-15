import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/auth/domain/entities/consent.dart';
import 'package:finmate/features/profile/presentation/screens/legal_document_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, LegalDocType type, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: LegalDocumentScreen(type: type))));
    await tester.pumpAndSettle();
  }

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
