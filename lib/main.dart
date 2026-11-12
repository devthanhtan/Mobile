import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';
import 'ui/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Đặt hướng màn hình nằm ngang (Landscape) chuẩn action survival top-down
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Chế độ toàn màn hình tối ưu không gian chơi
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const HuitDeadlineApp());
}

class HuitDeadlineApp extends StatelessWidget {
  const HuitDeadlineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinh Viên HUIT Đánh Quái Deadline',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: GameConstants.primaryColor,
        scaffoldBackgroundColor: GameConstants.backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: GameConstants.primaryColor,
          brightness: Brightness.dark,
          primary: GameConstants.primaryColor,
          secondary: GameConstants.accentColor,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
