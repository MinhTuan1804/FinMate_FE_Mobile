# Glance nhận diện mỗi loại widget bằng CHÍNH lớp GlanceAppWidget (getGlanceIds(javaClass), tên lớp trong
# bảng receiver→provider). R8 ở bản release từng gộp SafeSpendWidget vào DetailWidget (cùng thành một lớp):
# SafeSpendWidget().updateAll() khi đó vẽ giao diện 2×2 đè lên widget 4×4. Giữ nguyên mọi widget Glance để
# không bị gộp/đổi tên.
-keep class * extends androidx.glance.appwidget.GlanceAppWidget { *; }
