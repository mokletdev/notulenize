import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:notulenize/audio_to_text.dart';
import 'package:notulenize/splash_screen.dart';
Future<void> main() async {
  // Ensure that widget binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load the .env file
  await dotenv.load(fileName: ".env");

  OpenAI.apiKey = dotenv.env['API_KEY']!;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        // Define your named routes here
        '/audio_to_text': (context) =>
            AudioToTextPage(), // Add the route for AudioToTextPage
        // You can add more routes as needed, for example:
        // '/summary_page': (context) => SummaryPage(),
        // '/another_page': (context) => AnotherPage(),
      },
    );
  }
}
