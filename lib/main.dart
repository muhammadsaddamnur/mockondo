import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/features/home/presentation/pages/home_page.dart';
import 'package:window_size/window_size.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    const minSize = Size(1000, 600);
    const initialSize = Size(1000, 600);

    setWindowMinSize(minSize);
    setWindowMaxSize(Size.infinite);

    // Dapatkan ukuran layar utama
    final screen = await getCurrentScreen();
    if (screen != null) {
      final screenFrame = screen.visibleFrame;
      final centerX =
          screenFrame.left + (screenFrame.width - initialSize.width) / 2;
      final centerY =
          screenFrame.top + (screenFrame.height - initialSize.height) / 2;

      final frame = Rect.fromLTWH(
        centerX,
        centerY,
        initialSize.width,
        initialSize.height,
      );
      setWindowFrame(frame);
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: getAppTheme(context, ThemeModeType.dark),
      home: const HomePage(),
    );
  }
}
