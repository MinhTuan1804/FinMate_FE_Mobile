# Glance nhận diện mỗi loại widget bằng CHÍNH lớp GlanceAppWidget (getGlanceIds(javaClass), tên lớp trong
# bảng receiver→provider). R8 ở bản release từng gộp SafeSpendWidget vào DetailWidget (cùng thành một lớp):
# SafeSpendWidget().updateAll() khi đó vẽ giao diện 2×2 đè lên widget 4×4. Giữ nguyên mọi widget Glance để
# không bị gộp/đổi tên.
-keep class * extends androidx.glance.appwidget.GlanceAppWidget { *; }

# Mọi nút bấm của widget là một ActionCallback mà Glance lưu bằng TÊN LỚP rồi tạo lại bằng reflection (getDeclaredConstructor()).
# R8 ở bản release xóa constructor không tham số (không ai gọi trực tiếp) hoặc đổi tên lớp, nên bấm nút nào cũng lỗi
# "NoSuchMethodException: ...OpenQuickCreateCallback.<init> []" và widget không phản hồi.
-keep class * implements androidx.glance.appwidget.action.ActionCallback { *; }
