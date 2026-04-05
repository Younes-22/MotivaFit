import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
      
  bool _isGoogleLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      // 1. Use the new v7 Singleton instance
      final googleSignIn = GoogleSignIn.instance;
      
      // 2. Explicit initialization is now required
      await googleSignIn.initialize();

      // 3. authenticate() replaces the old signIn() method
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser != null) {
        // 4. authentication is now synchronous, no await needed
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        // 5. Firebase only needs the idToken!
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: null, 
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
        
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FDF8),
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              _buildInputField(
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.email_outlined,
                controller: _emailController,
              ),

              const SizedBox(height: 16),

              _buildInputField(
                label: 'Password',
                hint: 'Create a password',
                icon: Icons.lock_outline,
                controller: _passwordController,
                obscure: true,
              ),

              const SizedBox(height: 16),

              _buildInputField(
                label: 'Confirm Password',
                hint: 'Re-enter your password',
                icon: Icons.lock_outline,
                controller: _confirmPasswordController,
                obscure: true,
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_passwordController.text !=
                        _confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Passwords do not match')),
                      );
                      return;
                    }

                    try {
                      final auth = AuthService();

                      await auth.signUp(
                        email: _emailController.text.trim(),
                        password: _passwordController.text.trim(),
                      );

                      if (!mounted) return;

                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              
              _isGoogleLoading 
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton.icon(
                    icon: Image.network(
                      'https://img.icons8.com/color/48/000000/google-logo.png',
                      height: 24,
                      ),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52), 
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _signInWithGoogle,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}