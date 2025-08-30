import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_furl/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:flutter_furl/features/file_share/cubit/file_share_cubit.dart';
import 'package:flutter_furl/core/theme/app_theme.dart';
import 'package:flutter_furl/features/onboarding/onboarding_page.dart';
import 'package:flutter_furl/features/file_share/file_share_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FurlApp());
}

class FurlApp extends StatelessWidget {
  const FurlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<OnboardingCubit>(create: (_) => OnboardingCubit()),
        BlocProvider<FileShareCubit>(create: (_) => FileShareCubit()),
      ],
      child: const App(),
    );
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Furl - Secure File Sharing',
      theme: AppTheme.lightTheme,
      home: BlocBuilder<OnboardingCubit, OnboardingState>(
        builder: (context, state) {
          if (state is OnboardingCompleted) {
            return const FileSharePage();
          }
          return const OnboardingPage();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
