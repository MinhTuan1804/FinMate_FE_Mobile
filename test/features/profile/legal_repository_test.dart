import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/profile/data/legal_repository.dart';
import '../../fixtures/fixture.dart';

void main() {
  test('getDocument gọi GET /legal/{kind} và đọc phiên bản, ngày, các mục', () async {
    final adapter = RouteAdapter((o) => respondJson({
          'success': true,
          'data': {
            'version': 5,
            'updatedAt': '2026-11-13T10:00:00+07:00',
            'sections': [
              {'title': 'A', 'body': 'a'},
              {'title': 'B', 'body': 'b'},
            ],
          },
        }));
    final repo = LegalRepository(apiClient: testApiClient(adapter));

    final doc = await repo.getDocument('privacy');

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/api/v1/legal/privacy');
    expect(doc.version, 5);
    expect(doc.updatedAt, isNotNull);
    expect(doc.sections.map((s) => s.title), ['A', 'B']);
  });

  test('thiếu trường: không ném, các mục rỗng', () async {
    final adapter = RouteAdapter((o) => respondJson({'success': true, 'data': <String, dynamic>{}}));
    final repo = LegalRepository(apiClient: testApiClient(adapter));

    final doc = await repo.getDocument('terms');

    expect(doc.sections, isEmpty);
    expect(doc.updatedAt, isNull);
  });
}
