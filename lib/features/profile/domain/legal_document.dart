/// Một mục của văn bản pháp lý (GET /legal/terms, /legal/privacy).
class LegalSection {
  final String title;
  final String body;

  const LegalSection({required this.title, required this.body});

  factory LegalSection.fromJson(Map<String, dynamic> json) => LegalSection(
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );
}

/// Bản đã xuất bản của Điều khoản hoặc Chính sách. [version] là số phiên bản hiện hành ở server.
class LegalDocument {
  final int version;
  final DateTime? updatedAt;
  final List<LegalSection> sections;

  const LegalDocument({required this.version, required this.updatedAt, required this.sections});

  factory LegalDocument.fromJson(Map<String, dynamic> json) => LegalDocument(
        version: (json['version'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        sections: [
          for (final s in (json['sections'] as List? ?? const [])) LegalSection.fromJson(s as Map<String, dynamic>),
        ],
      );
}
