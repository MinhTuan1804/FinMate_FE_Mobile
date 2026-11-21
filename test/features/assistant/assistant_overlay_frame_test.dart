import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finmate/features/assistant/data/assistant_bubble_bridge.dart';
import 'package:finmate/features/assistant/presentation/widgets/assistant_overlay_frame.dart';

void main() {
  const channel = MethodChannel('com.example.finmate/assistant_bubble');

  testWidgets('khung chat nằm ngay dưới bong bóng, bỏ padding trên; chạm vùng trống phía trên thì thu khung', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    const statusBar = 24.0;
    double? innerTopPadding;
    await tester.pumpWidget(ProviderScope(
      overrides: [assistantBubbleBridgeProvider.overrideWithValue(AssistantBubbleBridge(channel))],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(top: statusBar)),
          child: AssistantOverlayFrame(
            child: Builder(builder: (context) {
              innerTopPadding = MediaQuery.paddingOf(context).top;
              return const ColoredBox(key: ValueKey('panel'), color: Colors.white);
            }),
          ),
        ),
        home: const SizedBox.shrink(),
      ),
    ));

    final panelTop = tester.getTopLeft(find.byKey(const ValueKey('panel'))).dy;
    expect(panelTop, greaterThan(statusBar + kBubbleExpandedTop + kBubbleSize));
    expect(innerTopPadding, 0);

    await tester.tapAt(const Offset(20, statusBar + 10)); // vùng trống phía trên khung
    await tester.pump();
    expect(calls, ['closePanel']);

    calls.clear();
    await tester.tap(find.byKey(const ValueKey('panel')));
    await tester.pump();
    expect(calls, isEmpty); // chạm trong khung không thu khung
  });
}
