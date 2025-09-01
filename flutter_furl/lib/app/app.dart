import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_furl/core/theme/app_theme.dart';
import 'package:flutter_furl/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:flutter_furl/features/onboarding/onboarding_page.dart';
import 'package:flutter_furl/features/file_share/file_share_page.dart';

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
