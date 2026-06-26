import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/countries.dart';
import '../data/markets.dart';
import '../widgets/phone_field.dart';
import '../services/image_picker_service.dart';
import '../state/session.dart';
import 'home_screen.dart';

class TraderRegisterScreen extends StatefulWidget {
  const TraderRegisterScreen({super.key});

  @override
  State<TraderRegisterScreen> createState() => _TraderRegisterScreenState();
}

class _TraderRegisterScreenState extends State<TraderRegisterScreen>
    with TickerProviderStateMixin {
  // 0=intro 1=personal 2=market 3=platform+verify 4=pending
  int _step = 0;

  late final AnimationController _stepController;
  late Animation<Offset> _stepSlide;
  late Animation<double> _stepFade;

  // Personal
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  Country _country = countryByIso('IN');
  final _formKey1 = GlobalKey<FormState>();

  // Market & platform
  TradingMarket? _market;
  TradingPlatform? _platform;

  // Verify
  final _serverController = TextEditingController();
  final _accountController = TextEditingController();
  final _investorPwController = TextEditingController();
  String? _uploadedFileName;
  bool _confirm = false;
  final _formKey2 = GlobalKey<FormState>();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _setAnims();
    _stepController.forward();
  }

  void _setAnims() {
    _stepSlide = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _stepController, curve: Curves.easeOutCubic));
    _stepFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _stepController, curve: Curves.easeOut));
  }

  Future<void> _go(int next) async {
    await _stepController.reverse();
    setState(() => _step = next);
    _setAnims();
    _stepController.forward();
  }

  void _next() {
    switch (_step) {
      case 1:
        if (!_formKey1.currentState!.validate()) return;
        _go(2);
        break;
      case 2:
        if (_market == null) {
          _toast('Please choose a market');
          return;
        }
        _go(3);
        break;
      case 3:
        if (_platform == null) {
          _toast('Please choose your platform');
          return;
        }
        if (_platform!.usesInvestorPassword) {
          if (!_formKey2.currentState!.validate()) return;
        } else if (_uploadedFileName == null) {
          _toast('Please upload your verified P&L statement');
          return;
        }
        if (!_confirm) {
          _toast('Please confirm the account is real & live');
          return;
        }
        _submit();
        break;
      default:
        _go(_step + 1);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    setState(() => _isLoading = false);
    _go(4);
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    if (_step == 4) return;
    _go(_step - 1);
  }

  void _finish() {
    SessionScope.of(context).signInAsCreator(
      name: _nameController.text.trim().isEmpty ? 'Creator' : _nameController.text.trim(),
      market: _market?.name,
      platform: _platform?.name,
      status: CreatorStatus.pending,
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _stepController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _serverController.dispose();
    _accountController.dispose();
    _investorPwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  if (_step != 4)
                    IconButton(
                      icon: Icon(_step == 0 ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: _back,
                    )
                  else
                    const SizedBox(width: 48),
                  if (_step >= 1 && _step <= 3) ...[
                    Expanded(child: _StepProgress(current: _step, total: 3)),
                    const SizedBox(width: 12),
                    Text('Step $_step of 3',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                  ] else
                    const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SlideTransition(
                position: _stepSlide,
                child: FadeTransition(opacity: _stepFade, child: _content()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    switch (_step) {
      case 0:
        return _StepIntro(onContinue: _next);
      case 1:
        return _StepPersonal(
          formKey: _formKey1,
          nameController: _nameController,
          phoneController: _phoneController,
          country: _country,
          onCountryChanged: (c) => setState(() => _country = c),
          onContinue: _next,
        );
      case 2:
        return _StepMarket(
          selected: _market,
          onSelect: (m) => setState(() {
            _market = m;
            _platform = null; // reset platform when market changes
          }),
          onContinue: _next,
        );
      case 3:
        return _StepPlatform(
          market: _market!,
          platform: _platform,
          onPlatform: (p) => setState(() => _platform = p),
          formKey: _formKey2,
          serverController: _serverController,
          accountController: _accountController,
          investorPwController: _investorPwController,
          uploadedFileName: _uploadedFileName,
          onUpload: () async {
            final f = await ImagePickerService.pickImageAsDataUrl();
            if (f != null && mounted) setState(() => _uploadedFileName = 'verified_pnl_statement');
          },
          confirm: _confirm,
          onConfirm: (v) => setState(() => _confirm = v),
          isLoading: _isLoading,
          onSubmit: _next,
        );
      case 4:
        return _StepPending(onGoHome: _finish);
      default:
        return const SizedBox();
    }
  }
}

// ── Progress ───────────────────────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  final int current;
  final int total;
  const _StepProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < current;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 4),
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
        );
      }),
    );
  }
}

// ── Step 0: Intro ──────────────────────────────────────────────────────────────

class _StepIntro extends StatelessWidget {
  final VoidCallback onContinue;
  const _StepIntro({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1120),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 13, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text('VERIFIED CREATOR',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Turn your track\nrecord into income',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Stream live, share verified trades, and earn from followers who copy you.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('What you\'ll need',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _Req(icon: Icons.history_rounded, title: '6+ months of live history', sub: 'A real money account — demo results aren\'t accepted.'),
          _Req(icon: Icons.shield_outlined, title: 'Read-only verification', sub: 'MetaTrader-style platforms connect via investor password. Others upload a verified P&L.'),
          _Req(icon: Icons.badge_outlined, title: 'Basic identity check', sub: 'Light KYC so followers can trust your track record.', last: true),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onContinue, child: const Text('Start Application')),
          const SizedBox(height: 12),
          Center(child: Text('Review takes 24–48 hours.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
        ],
      ),
    );
  }
}

class _Req extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool last;
  const _Req({required this.icon, required this.title, required this.sub, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(sub, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Personal ───────────────────────────────────────────────────────────

class _StepPersonal extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final Country country;
  final ValueChanged<Country> onCountryChanged;
  final VoidCallback onContinue;

  const _StepPersonal({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.country,
    required this.onCountryChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About you',
              style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.6)),
          const SizedBox(height: 6),
          Text('This appears on your public creator profile.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 28),
          Form(
            key: formKey,
            child: Column(
              children: [
                _FieldLabel('Full name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'e.g. Marcus Sterling'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 20),
                _FieldLabel('Phone number'),
                const SizedBox(height: 8),
                PhoneField(
                  controller: phoneController,
                  country: country,
                  onCountryChanged: onCountryChanged,
                  onSubmitted: onContinue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: onContinue, child: const Text('Continue')),
        ],
      ),
    );
  }
}

// ── Step 2: Market ──────────────────────────────────────────────────────────────

class _StepMarket extends StatelessWidget {
  final TradingMarket? selected;
  final ValueChanged<TradingMarket> onSelect;
  final VoidCallback onContinue;

  const _StepMarket({required this.selected, required this.onSelect, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Which market\ndo you trade?',
                    style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.6, height: 1.15)),
                const SizedBox(height: 6),
                Text('We support traders across markets — pick where you have your verified track record.',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted, height: 1.4)),
                const SizedBox(height: 24),
                ...kMarkets.map((m) => _MarketTile(
                      market: m,
                      selected: selected?.id == m.id,
                      onTap: () => onSelect(m),
                    )),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: AnimatedOpacity(
            opacity: selected != null ? 1 : 0.4,
            duration: const Duration(milliseconds: 180),
            child: ElevatedButton(
              onPressed: selected != null ? onContinue : null,
              child: const Text('Continue'),
            ),
          ),
        ),
      ],
    );
  }
}

class _MarketTile extends StatelessWidget {
  final TradingMarket market;
  final bool selected;
  final VoidCallback onTap;
  const _MarketTile({required this.market, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (selected ? AppColors.primary : AppColors.textMuted).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(market.icon, size: 24, color: selected ? AppColors.primary : AppColors.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(market.name, style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(market.subtitle, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Platform + verify ────────────────────────────────────────────────────

class _StepPlatform extends StatelessWidget {
  final TradingMarket market;
  final TradingPlatform? platform;
  final ValueChanged<TradingPlatform> onPlatform;
  final GlobalKey<FormState> formKey;
  final TextEditingController serverController;
  final TextEditingController accountController;
  final TextEditingController investorPwController;
  final String? uploadedFileName;
  final VoidCallback onUpload;
  final bool confirm;
  final ValueChanged<bool> onConfirm;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _StepPlatform({
    required this.market,
    required this.platform,
    required this.onPlatform,
    required this.formKey,
    required this.serverController,
    required this.accountController,
    required this.investorPwController,
    required this.uploadedFileName,
    required this.onUpload,
    required this.confirm,
    required this.onConfirm,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final platforms = platformsFor(market.id);
    final usesCreds = platform?.usesInvestorPassword ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect your\nplatform',
              style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.6, height: 1.15)),
          const SizedBox(height: 6),
          Text('Platforms available for ${market.name}.',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: platforms.map((p) {
              final sel = platform?.name == p.name;
              return GestureDetector(
                onTap: () => onPlatform(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(p.name,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppColors.textPrimary,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          if (platform == null)
            _InfoNote(icon: Icons.info_outline_rounded, text: 'Select your platform to see how to verify your results.')
          else if (usesCreds)
            _CredentialFields(
              formKey: formKey,
              platform: platform!.name,
              serverController: serverController,
              accountController: accountController,
              investorPwController: investorPwController,
            )
          else
            _UploadFields(platform: platform!.name, uploadedFileName: uploadedFileName, onUpload: onUpload),
          if (platform != null) ...[
            const SizedBox(height: 20),
            _ConfirmCheck(value: confirm, onChanged: onConfirm),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Application'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CredentialFields extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String platform;
  final TextEditingController serverController;
  final TextEditingController accountController;
  final TextEditingController investorPwController;

  const _CredentialFields({
    required this.formKey,
    required this.platform,
    required this.serverController,
    required this.accountController,
    required this.investorPwController,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('$platform server'),
          const SizedBox(height: 8),
          TextFormField(
            controller: serverController,
            textInputAction: TextInputAction.next,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'e.g. ICMarkets-Live12'),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter your server' : null,
          ),
          const SizedBox(height: 16),
          _FieldLabel('Account / Login number'),
          const SizedBox(height: 8),
          TextFormField(
            controller: accountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'e.g. 50231487'),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter your account number' : null,
          ),
          const SizedBox(height: 16),
          _FieldLabel('Investor (read-only) password'),
          const SizedBox(height: 8),
          TextFormField(
            controller: investorPwController,
            obscureText: true,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Read-only password'),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter your investor password' : null,
          ),
          const SizedBox(height: 14),
          _InfoNote(
            icon: Icons.lock_outline_rounded,
            text:
                'The investor password is read-only. It lets us verify your results — it can never place trades or withdraw funds, and is different from your master password.',
          ),
        ],
      ),
    );
  }
}

class _UploadFields extends StatelessWidget {
  final String platform;
  final String? uploadedFileName;
  final VoidCallback onUpload;
  const _UploadFields({required this.platform, required this.uploadedFileName, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final done = uploadedFileName != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Verified P&L statement'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onUpload,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: done ? AppColors.green.withOpacity(0.05) : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: done ? AppColors.green : AppColors.border, width: done ? 1.5 : 1),
            ),
            child: Column(
              children: [
                Icon(done ? Icons.check_circle_outline_rounded : Icons.cloud_upload_outlined,
                    size: 30, color: done ? AppColors.green : AppColors.textMuted),
                const SizedBox(height: 10),
                Text(done ? 'Statement uploaded' : 'Tap to upload',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: done ? AppColors.green : AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(done ? 'Tap again to replace' : 'PDF or screenshot • last 6 months',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _InfoNote(
          icon: Icons.privacy_tip_outlined,
          text:
              'For $platform, upload an official P&L / tradebook statement or a clear screenshot. Never share your login password or OTP — we will never ask for it.',
        ),
      ],
    );
  }
}

class _ConfirmCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ConfirmCheck({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: value ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: value ? AppColors.primary : AppColors.border, width: 1.5),
            ),
            child: value ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('I confirm this is a real, live account with at least 6 months of trading history.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

// ── Step 4: Pending ──────────────────────────────────────────────────────────────

class _StepPending extends StatelessWidget {
  final VoidCallback onGoHome;
  const _StepPending({required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          SizedBox(height: 130, child: CustomPaint(painter: _PendingPainter())),
          const SizedBox(height: 28),
          Text('Application submitted',
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Text(
            'We\'re verifying your trading data. You\'ll get an email and an in-app alert within 24–48 hours.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.55),
          ),
          const SizedBox(height: 28),
          _Timeline(icon: Icons.search_rounded, title: 'Under review', sub: 'Verifying your account & PnL', color: AppColors.primary),
          _Timeline(icon: Icons.notifications_active_outlined, title: 'You\'ll be notified', sub: 'Email + in-app when approved', color: AppColors.green),
          _Timeline(icon: Icons.live_tv_rounded, title: 'Go live', sub: 'Stream, share trades & earn', color: AppColors.textMuted, muted: true, last: true),
          const SizedBox(height: 28),
          ElevatedButton(onPressed: onGoHome, child: const Text('Explore millimore')),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final Color color;
  final bool muted;
  final bool last;
  const _Timeline({required this.icon, required this.title, required this.sub, required this.color, this.muted = false, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: muted ? 0.45 : 1,
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(sub, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared ───────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
  }
}

class _InfoNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5))),
        ],
      ),
    );
  }
}

class _PendingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.85;
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = AppColors.primary.withOpacity(0.08));
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = AppColors.primary.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 2);
    final hand = Paint()..color = AppColors.primary..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy), Offset(cx, cy - r * 0.45), hand);
    canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.35, cy + 0.1 * r), hand);
    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = AppColors.primary);
    for (int i = 0; i < 12; i++) {
      final a = i * 30 * math.pi / 180;
      canvas.drawLine(
        Offset(cx + r * 0.82 * math.cos(a), cy + r * 0.82 * math.sin(a)),
        Offset(cx + r * 0.95 * math.cos(a), cy + r * 0.95 * math.sin(a)),
        Paint()..color = AppColors.primary.withOpacity(0.3)..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_PendingPainter old) => false;
}
