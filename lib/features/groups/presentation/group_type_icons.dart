import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/features/groups/domain/group.dart';

/// Icon/màu theo [GroupType] — dùng chung ở I1 (danh sách), I2 (tạo nhóm), I3 (chi tiết).
IconData groupTypeIcon(GroupType type) => switch (type) {
      GroupType.family => LucideIcons.house,
      GroupType.friends => LucideIcons.users,
      GroupType.travel => LucideIcons.plane,
      GroupType.colleagues => LucideIcons.briefcase,
      GroupType.roommates => LucideIcons.bedDouble,
      GroupType.other => LucideIcons.users,
    };

Color groupTypeColor(GroupType type) => type == GroupType.family ? GlassColors.accentSkyBlue : GlassColors.accentDustyRose;

/// Biểu tượng chọn sẵn cho nhóm (khóa gửi lên server ở trường `icon`). Khóa lạ hoặc null thì rơi về biểu tượng theo loại nhóm.
const Map<String, IconData> groupIconChoices = {
  'house': LucideIcons.house,
  'plane': LucideIcons.plane,
  'utensils': LucideIcons.utensils,
  'heart': LucideIcons.heart,
  'car': LucideIcons.car,
  'briefcase': LucideIcons.briefcase,
};

IconData groupIconFor(String? key, GroupType type) => groupIconChoices[key] ?? groupTypeIcon(type);
