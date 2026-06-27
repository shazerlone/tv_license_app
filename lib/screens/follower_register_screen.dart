import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/countries.dart';
import '../widgets/phone_field.dart';
import '../services/image_picker_service.dart';
import 'otp_screen.dart';

class FollowerRegisterScreen extends StatefulWidget {
  const FollowerRegisterScreen({super.key});

  @override
  State<FollowerRegisterScreen> createState() => _FollowerRegisterScreenState();
}

class _FollowerRegisterScreenState extends State<FollowerRegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  Country _country = countryByIso('IN');
  Country? _residence;
  String? _photoDataUrl;
  String? _experience;
  final Set<String> _interests = {};
  bool _isLoading = false;

  final _experienceLevels = const [
    'Brand new to trading',
    'Less than 1 year',
    '1–3 years',
    '3–5 years',
    '5+ years',
  ];
  final _interestOptions = const [
    'Forex',
    'Crypto',
    'Indices',
    'Stocks',
    'Commodities',
    'Options',
  ];

  late final AnimationController _entryController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final url = await ImagePickerService.pickImageAsDataUrl();
    if (url != null && mounted) setState(() => _photoDataUrl = url);
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    if (_residence == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your country of residence')),
      );
      return;
    }
    if (_experience == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your trading experience')),
      );
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          phoneNumber: '${_country.dialCode} ${_phoneController.text.trim()}',
          name: _nameController.text.trim(),
          residenceIso: _residence!.iso,
          residenceCountry: _residence!.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create your account',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Join thousands following the world\'s top traders.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Profile photo
                        Center(child: _PhotoPicker(dataUrl: _photoDataUrl, onTap: _pickPhoto)),
                        const SizedBox(height: 28),

                        _Label('Full name'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                          decoration: const InputDecoration(hintText: 'e.g. Alex Morgan'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: 20),

                        _Label('Phone number'),
                        const SizedBox(height: 8),
                        PhoneField(
                          controller: _phoneController,
                          country: _country,
                          onCountryChanged: (c) => setState(() => _country = c),
                          onSubmitted: _continue,
                        ),
                        const SizedBox(height: 20),

                        _Label('Country of residence'),
                        const SizedBox(height: 8),
                        CountryField(
                          country: _residence,
                          hint: 'Where do you live?',
                          onChanged: (c) => setState(() => _residence = c),
                        ),
                        const SizedBox(height: 20),

                        _Label('How experienced are you?'),
                        const SizedBox(height: 10),
                        ..._experienceLevels.map(
                          (level) => _RadioRow(
                            label: level,
                            selected: _experience == level,
                            onTap: () => setState(() => _experience = level),
                          ),
                        ),
                        const SizedBox(height: 20),

                        _Label('What are you interested in?'),
                        const SizedBox(height: 4),
                        Text(
                          'Pick a few — we\'ll tailor your feed.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _interestOptions.map((opt) {
                            final sel = _interests.contains(opt);
                            return _ChoiceChip(
                              label: opt,
                              selected: sel,
                              onTap: () => setState(() {
                                sel ? _interests.remove(opt) : _interests.add(opt);
                              }),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 32),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _continue,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Continue'),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            'We\'ll text a 6-digit code to verify your number.',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Components ─────────────────────────────────────────────────────────────────

class _PhotoPicker extends StatelessWidget {
  final String? dataUrl;
  final VoidCallback onTap;
  const _PhotoPicker({required this.dataUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5),
                  image: dataUrl != null
                      ? DecorationImage(image: NetworkImage(dataUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: dataUrl == null
                    ? const Icon(Icons.person_rounded, size: 44, color: AppColors.textMuted)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dataUrl == null ? 'Add profile photo (optional)' : 'Change photo',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
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
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RadioRow({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
