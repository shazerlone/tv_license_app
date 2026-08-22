import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../data/countries.dart';
import '../widgets/phone_field.dart';
import '../services/image_picker_service.dart';
import '../services/auth_api.dart';
import '../services/api_client.dart';
import '../services/phone_auth_service.dart';
import '../state/session.dart';
import 'otp_screen.dart';
import 'home_screen.dart';
import 'email_verify_screen.dart';

class FollowerRegisterScreen extends StatefulWidget {
  const FollowerRegisterScreen({super.key});

  @override
  State<FollowerRegisterScreen> createState() => _FollowerRegisterScreenState();
}

class _FollowerRegisterScreenState extends State<FollowerRegisterScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  bool _obscurePassword = true;

  Country _country = countryByIso('IN');
  Country? _residence;
  String? _photoDataUrl;
  String? _experience;
  final Set<String> _interests = {};
  bool _isLoading = false;
  int _step = 0; // 0 = account, 1 = about you, 2 = interests

  // Sign-up method: 'email' (email+password) or 'phone' (Firebase SMS OTP).
  String _method = 'email';

  // Phone-OTP state.
  final _phoneAuth = PhoneAuthService();
  bool _codeSent = false;
  bool _phoneVerified = false;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  int _resendIn = 0;
  UserProfile? _phoneSession; // session created by Firebase after phone verify

  String get _e164 => '${_country.dialCode}${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';

  // Per-field error text for the stepped flow (validated on Continue).
  String? _emailError, _passwordError, _phoneError, _nameError, _codeError;

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
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final url = await ImagePickerService.pickImageAsDataUrl();
    if (url != null && mounted) setState(() => _photoDataUrl = url);
  }

  /// Password strength 0..4 (length + variety of character classes).
  int get _pwStrength {
    final p = _passwordController.text;
    if (p.length < 8) return p.isEmpty ? 0 : 1;
    var score = 1;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p) || p.length >= 12) score++;
    return score.clamp(0, 4);
  }

  // ── Phone OTP (Firebase) ────────────────────────────────────────────────────
  Future<void> _sendCode({bool resend = false}) async {
    if (_phoneController.text.replaceAll(RegExp(r'\D'), '').length < 6) {
      setState(() => _phoneError = 'Enter a valid phone number');
      return;
    }
    setState(() { _sendingCode = true; _phoneError = null; _codeError = null; });
    await _phoneAuth.start(
      _e164,
      resend: resend,
      onCodeSent: () {
        if (!mounted) return;
        setState(() { _sendingCode = false; _codeSent = true; });
        _startResendCountdown();
      },
      onAutoSignedIn: (profile) {
        // Android instant verification — treat as verified.
        if (!mounted) return;
        setState(() { _sendingCode = false; _codeSent = true; _phoneVerified = true; _phoneSession = profile; });
      },
      onError: (m) {
        if (!mounted) return;
        setState(() { _sendingCode = false; _phoneError = m; });
      },
    );
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length < 6) {
      setState(() => _codeError = 'Enter the 6-digit code');
      return;
    }
    setState(() { _verifyingCode = true; _codeError = null; });
    try {
      final profile = await _phoneAuth.confirm(_codeController.text.trim());
      if (!mounted) return;
      setState(() { _verifyingCode = false; _phoneVerified = true; _phoneSession = profile; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _verifyingCode = false; _codeError = e.toString(); });
    }
  }

  void _startResendCountdown() {
    setState(() => _resendIn = 45);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendIn--);
      return _resendIn > 0;
    });
  }

  // ── Step navigation ───────────────────────────────────────────────────────
  bool _validateAccount() {
    if (_residence == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select your country of residence')));
      return false;
    }
    if (_method == 'phone') {
      if (!_phoneVerified) {
        setState(() => _phoneError = _codeSent ? 'Verify the code to continue' : 'Verify your number to continue');
        return false;
      }
      return true;
    }
    // Email method.
    setState(() {
      _emailError = !_emailController.text.contains('@') ? 'Enter a valid email' : null;
      _passwordError = _passwordController.text.length < 8 ? 'Use at least 8 characters' : null;
    });
    return _emailError == null && _passwordError == null;
  }

  bool _validateAbout() {
    setState(() => _nameError = _nameController.text.trim().isEmpty ? 'Enter your name' : null);
    if (_nameError != null) return false;
    if (_experience == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select your trading experience')));
      return false;
    }
    return true;
  }

  void _next() {
    if (_step == 0 && !_validateAccount()) return;
    if (_step == 1 && !_validateAbout()) return;
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _continue();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _continue() async {
    // Each step was validated before reaching here.
    if (_residence == null || _experience == null) {
      setState(() => _step = 0);
      return;
    }
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    setState(() => _isLoading = true);

    // ── Demo (no backend): keep the legacy OTP screen. ─────────────────────────
    if (!kUseBackend) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpScreen(
          phoneNumber: _e164,
          name: name,
          residenceIso: _residence!.iso,
          residenceCountry: _residence!.name,
        ),
      ));
      return;
    }

    final nav = Navigator.of(context);
    final session = SessionScope.of(context);
    try {
      if (_method == 'phone') {
        // The account already exists (created when the phone was verified via
        // Firebase). Enrich it with the profile details.
        if (_phoneSession != null) session.applyBackendSession(_phoneSession!);
        final user = await AuthApi.updateMe({
          'name': name,
          'residenceIso': _residence!.iso,
          'experience': _experience,
          'interests': _interests.toList(),
          if (_photoDataUrl != null) 'photoUrl': _photoDataUrl,
        });
        if (!mounted) return;
        session.applyBackendSession(user);
        setState(() => _isLoading = false);
        nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
        return;
      }

      // Email method: create the account with email + password.
      final user = await AuthApi.registerFollower(
        name: name,
        residenceIso: _residence!.iso,
        experience: _experience,
        interests: _interests.toList(),
        photoUrl: _photoDataUrl,
        email: email,
        password: password,
      );
      if (!mounted) return;
      session.applyBackendSession(user);
      try {
        final me = await AuthApi.me();
        session.applyBackendSession(me);
      } catch (_) {}
      setState(() => _isLoading = false);
      nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
      // Prompt email verification on top of home (code emailed at registration).
      final dev = await AuthApi.sendEmailCode().catchError((_) => null);
      nav.push(MaterialPageRoute(builder: (_) => EmailVerifyScreen(email: email, devCode: dev)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server')));
    }
  }

  static const _titles = ['Create your account', 'About you', 'Your interests'];
  static const _subtitles = [
    'Secure your account — you\'ll sign in with these.',
    'A little about you so we can tailor your feed.',
    'Pick a few markets — we\'ll personalise your feed.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            children: [
              // Top bar + progress
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: _back,
                    ),
                    Expanded(child: _StepBar(step: _step, total: 3)),
                    const SizedBox(width: 8),
                    Text('${_step + 1}/3', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titles[_step],
                        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.8),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _subtitles[_step],
                        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _stepContent(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom action bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _isLoading ? null : _next,
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_step < 2 ? 'Continue' : 'Create account'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _step != 0
                          ? 'You can change these later in your profile.'
                          : _method == 'phone'
                              ? 'We\'ll text a 6-digit code to verify your number.'
                              : 'We\'ll email a code to verify your address.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepContent() {
    switch (_step) {
      case 0:
        return _accountStep();
      case 1:
        return _aboutStep();
      default:
        return _interestsStep();
    }
  }

  // Step 0 — email + password + phone + country (the account itself).
  Widget _accountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Method chooser: Email or Phone.
        _MethodToggle(
          method: _method,
          onChanged: _phoneVerified || _codeSent
              ? (_) {} // lock while a phone verification is in progress
              : (m) => setState(() { _method = m; _emailError = null; _passwordError = null; _phoneError = null; }),
        ),
        const SizedBox(height: 24),
        if (_method == 'email') ...[
          _Label('Email'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            onChanged: (_) { if (_emailError != null) setState(() => _emailError = null); },
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            decoration: InputDecoration(hintText: 'you@email.com', errorText: _emailError),
          ),
          const SizedBox(height: 20),
          _Label('Password'),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() => _passwordError = null),
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'At least 8 characters',
              errorText: _passwordError,
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: AppColors.textMuted),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          if (_passwordController.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PasswordStrength(strength: _pwStrength),
          ],
        ] else ...[
          // Phone method — verify with an SMS code before continuing.
          _Label('Phone number'),
          const SizedBox(height: 8),
          PhoneField(
            controller: _phoneController,
            country: _country,
            onCountryChanged: (c) => setState(() => _country = c),
            onSubmitted: () => _sendCode(),
          ),
          if (_phoneError != null) ...[
            const SizedBox(height: 6),
            Text(_phoneError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.red)),
          ],
          const SizedBox(height: 12),
          if (!_phoneVerified) ...[
            if (!_codeSent)
              OutlinedButton.icon(
                onPressed: _sendingCode ? null : () => _sendCode(),
                icon: _sendingCode
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sms_outlined, size: 18),
                label: Text(_sendingCode ? 'Sending…' : 'Send code'),
              )
            else ...[
              _Label('Enter the 6-digit code'),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (_) { if (_codeError != null) setState(() => _codeError = null); },
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 6, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
                decoration: InputDecoration(hintText: '••••••', errorText: _codeError),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _verifyingCode ? null : _verifyCode,
                    child: _verifyingCode
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Verify'),
                  ),
                  const SizedBox(width: 12),
                  _resendIn > 0
                      ? Text('Resend in ${_resendIn}s', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))
                      : TextButton(onPressed: () => _sendCode(resend: true), child: const Text('Resend')),
                ],
              ),
            ],
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.green.withOpacity(0.4)),
              ),
              child: Row(children: [
                Icon(Icons.check_circle_rounded, size: 20, color: AppColors.green),
                const SizedBox(width: 10),
                Text('Phone verified', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.green)),
              ]),
            ),
          const SizedBox(height: 8),
          Text('You can add an email later in your profile.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ],
        const SizedBox(height: 20),
        _Label('Country of residence'),
        const SizedBox(height: 8),
        CountryField(
          country: _residence,
          hint: 'Where do you live?',
          onChanged: (c) => setState(() => _residence = c),
        ),
      ],
    );
  }

  // Step 1 — photo + name + experience.
  Widget _aboutStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _PhotoPicker(dataUrl: _photoDataUrl, onTap: _pickPhoto)),
        const SizedBox(height: 28),
        _Label('Full name'),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: (_) { if (_nameError != null) setState(() => _nameError = null); },
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: 'e.g. Alex Morgan', errorText: _nameError),
        ),
        const SizedBox(height: 24),
        _Label('How experienced are you?'),
        const SizedBox(height: 10),
        ..._experienceLevels.map(
          (level) => _RadioRow(
            label: level,
            selected: _experience == level,
            onTap: () => setState(() => _experience = level),
          ),
        ),
      ],
    );
  }

  // Step 2 — interests.
  Widget _interestsStep() {
    return Wrap(
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
    );
  }
}

/// Email / Phone sign-up method chooser.
class _MethodToggle extends StatelessWidget {
  final String method;
  final ValueChanged<String> onChanged;
  const _MethodToggle({required this.method, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          _seg('email', 'Email', Icons.mail_outline_rounded),
          _seg('phone', 'Phone', Icons.smartphone_rounded),
        ],
      ),
    );
  }

  Widget _seg(String value, String label, IconData icon) {
    final on = method == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(color: on ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(9)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: on ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 7),
              Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: on ? Colors.white : AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented progress bar across the registration steps.
class _StepBar extends StatelessWidget {
  final int step;
  final int total;
  const _StepBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final done = i <= step;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 4,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: done ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

/// Password strength meter (4 bars + label).
class _PasswordStrength extends StatelessWidget {
  final int strength; // 0..4
  const _PasswordStrength({required this.strength});

  @override
  Widget build(BuildContext context) {
    const labels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [AppColors.red, AppColors.red, Colors.orange, AppColors.green, AppColors.green];
    final c = colors[strength];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final on = i < strength;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                decoration: BoxDecoration(
                  color: on ? c : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(labels[strength], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
      ],
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
                    ? Icon(Icons.person_rounded, size: 44, color: AppColors.textMuted)
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
                        decoration: BoxDecoration(
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
