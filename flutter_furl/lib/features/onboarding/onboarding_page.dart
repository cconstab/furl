import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_furl/features/onboarding/cubit/onboarding_cubit.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<OnboardingCubit, OnboardingState>(
        listener: (context, state) {
          if (state is OnboardingError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        builder: (context, state) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF667eea), // Purple blue
                  Color(0xFF764ba2), // Purple
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),

                    // App Logo/Icon with website styling
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: const Center(child: Text('🔐', style: TextStyle(fontSize: 60))),
                    ),
                    const SizedBox(height: 40),

                    // Welcome text
                    const Text(
                      'Furl',
                      style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Secure File Sharing with atSign authentication.\nShare files privately and securely.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.white, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 60),

                    // White container for onboarding content
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20)),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Features list
                          const Row(
                            children: [
                              Text('🔑', style: TextStyle(fontSize: 24)),
                              SizedBox(width: 12),
                              Expanded(child: Text('Secure atSign authentication', style: TextStyle(fontSize: 16))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Text('📁', style: TextStyle(fontSize: 24)),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text('End-to-end encrypted file sharing', style: TextStyle(fontSize: 16)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Text('🔗', style: TextStyle(fontSize: 24)),
                              SizedBox(width: 12),
                              Expanded(child: Text('Simple URL + PIN sharing', style: TextStyle(fontSize: 16))),
                            ],
                          ),
                          const SizedBox(height: 40),

                          // Onboarding button
                          if (state is OnboardingInProgress)
                            Column(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                                    strokeWidth: 3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Setting up your atSign...',
                                  style: TextStyle(color: Colors.black87, fontSize: 16),
                                ),
                              ],
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  context.read<OnboardingCubit>().startOnboarding();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF667eea),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 2,
                                ),
                                child: const Text(
                                  'Get Started with atSign',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Info text
                          const Text(
                            'By continuing, you agree to set up an atSign for secure authentication and file sharing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
