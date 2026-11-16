import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:finmate/core/theme/glass/glass_colors.dart';
import 'package:finmate/features/groups/domain/group.dart';

/// Icon/màu theo [GroupType] — dùng chung ở I1 (danh sách), I2 (tạo nhóm), I3 (chi tiết).
IconData groupTypeIcon(GroupType type) => type == GroupType.family ? LucideIcons.house : LucideIcons.users;

Color groupTypeColor(GroupType type) => type == GroupType.family ? GlassColors.accentSkyBlue : GlassColors.accentDustyRose;
