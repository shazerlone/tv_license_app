import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/image_picker_service.dart';
import 'otp_screen.dart';

enum UserType { trader, follower }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  UserType _selectedType = UserType.follower;
  String? _photoDataUrl;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final url = await ImagePickerService.pickImageAsDataUrl();
    if (url != null && mounted) {
      setState(() => _photoDataUrl = url);
    }
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isLoading = false);

    final phone = '+91 ${_phoneController.text.trim()}';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          phoneNumber: phone,
          name: _nameController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Create account.',
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Join the creator economy for traders',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                Center(child: _PhotoPicker(
                  dataUrl: _photoDataUrl,
                  onTap: _pickPhoto,
                )),
                const SizedBox(height: 28),
                _Label('I am a'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TypeCard(
                        icon: Icons.visibility_outlined,
                        title: 'Follower',
                        subtitle: 'Copy & watch',
                        selected: _selectedType == UserType.follower,
                        onTap: () => setState(
                            () => _selectedType = UserType.follower),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TypeCard(
                        icon: Icons.show_chart_rounded,
                        title: 'Trader',
                        subtitle: 'Stream & earn',
                        selected: _selectedType == UserType.trader,
                        onTap: () => setState(
                            () => _selectedType = UserType.trader),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _Label('Full name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.inter(
                      fontSize: 15, color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Marcus Sterling'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 20),
                _Label('Mobile number'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+91',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _continue(),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: GoogleFonts.inter(
                            fontSize: 15, color: AppColors.textPrimary),
                        decoration:
                            const InputDecoration(hintText: '98765 43210'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your mobile number';
                          }
                          if (v.trim().length < 10) {
                            return 'Enter a valid 10-digit number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'We will send a 6-digit code to verify this number.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isLoading ? null : _continue,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Continue'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'By continuing you agree to our\nTerms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final String? dataUrl;
  final VoidCallback onTap;
  const _PhotoPicker({required this.dataUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border, width: 1.5),
                  image: dataUrl != null
                      ? DecorationImage(
                          image: NetworkImage(dataUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: dataUrl == null
                    ? const Icon(Icons.person_outline_rounded,
                        size: 34, color: AppColors.textMuted)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          dataUrl == null ? 'Add photo (optional)' : 'Change photo',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 22,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }
}
