import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class TraderRegisterScreen extends StatefulWidget {
  const TraderRegisterScreen({super.key});

  @override
  State<TraderRegisterScreen> createState() => _TraderRegisterScreenState();
}

class _TraderRegisterScreenState extends State<TraderRegisterScreen>
    with TickerProviderStateMixin {
  int _step = 0;

  late final AnimationController _stepController;
  late Animation<Offset> _stepSlide;
  late Animation<double> _stepFade;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey1 = GlobalKey<FormState>();

  String? _selectedBroker;
  final _accountIdController = TextEditingController();
  final _formKey2 = GlobalKey<FormState>();

  String? _uploadedFileName;
  bool _hasMinData = false;
  bool _isLoading = false;

  final _brokers = ['MetaTrader 5 (MT5)', 'MetaTrader 4 (MT4)', 'cTrader', 'Interactive Brokers', 'Zerodha', 'Other'];

  @override
  void initState() {
    super.initState();
    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _updateStepAnimations();
    _stepController.forward();
  }

  void _updateStepAnimations() {
    _stepSlide = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _stepController, curve: Curves.easeOutCubic));
    _stepFade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _stepController, curve: Curves.easeOut));
  }

  Future<void> _nextStep() async {
    if (_step == 1 && !_formKey1.currentState!.validate()) return;
    if (_step == 2 && !_formKey2.currentState!.validate()) return;
    await _stepController.reverse();
    setState(() => _step++);
    _updateStepAnimations();
    _stepController.forward();
  }

  Future<void> _prevStep() async {
    if (_step == 0) { Navigator.pop(context); return; }
    await _stepController.reverse();
    setState(() => _step--);
    _updateStepAnimations();
    _stepController.forward();
  }

  Future<void> _submitApplication() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _isLoading = false);
    await _stepController.reverse();
    setState(() => _step = 4);
    _updateStepAnimations();
    _stepController.forward();
  }

  @override
  void dispose() {
    _stepController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _accountIdController.dispose();
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_step == 0 ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _prevStep,
                  ),
                  const SizedBox(width: 12),
                  if (_step > 0 && _step < 4) ...
                    [
                      Expanded(child: _StepProgress(current: _step, total: 3)),
                      const SizedBox(width: 12),
                      Text('Step $_step of 3',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                    ]
                  else
                    const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SlideTransition(
                position: _stepSlide,
                child: FadeTransition(
                  opacity: _stepFade,
                  child: _buildStep(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _StepIntro(onContinue: _nextStep);
      case 1: return _StepPersonal(
        formKey: _formKey1,
        nameController: _nameController,
        phoneController: _phoneController,
        onContinue: _nextStep,
      );
      case 2: return _StepBroker(
        formKey: _formKey2,
        brokers: _brokers,
        selectedBroker: _selectedBroker,
        accountIdController: _accountIdController,
        onBrokerSelected: (v) => setState(() => _selectedBroker = v),
        onContinue: _nextStep,
      );
      case 3: return _StepPnl(
        uploadedFileName: _uploadedFileName,
        hasMinData: _hasMinData,
        isLoading: _isLoading,
        onUpload: () => setState(() => _uploadedFileName = 'trading_statement_6mo.xlsx'),
        onToggleConfirm: (v) => setState(() => _hasMinData = v ?? false),
        onSubmit: _uploadedFileName != null && _hasMinData ? _submitApplication : null,
      );
      case 4: return _StepPending(
        onGoHome: () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        ),
      );
      default: return const SizedBox();
    }
  }
}

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
          child: Container(
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

class _StepIntro extends StatelessWidget {
  final VoidCallback onContinue;
  const _StepIntro({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                SizedBox(height: 120, child: CustomPaint(painter: _VerifiedChartPainter())),
                const SizedBox(height: 16),
                Text(
                  'Become a verified trader on millimore',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'We verify every creator\'s real account data to maintain trust on the platform.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.55),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('What you\'ll need', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          _RequirementRow(icon: Icons.history_rounded, title: '6+ months of real account history', sub: 'Live trading account — no demo data accepted'),
          const SizedBox(height: 10),
          _RequirementRow(icon: Icons.show_chart_rounded, title: 'Positive verified PnL', sub: 'Statement from MT5, MT4, cTrader or equivalent'),
          const SizedBox(height: 10),
          _RequirementRow(icon: Icons.verified_outlined, title: 'Identity verification', sub: 'Basic KYC to comply with regulations'),
          const Spacer(),
          ElevatedButton(onPressed: onContinue, child: const Text('Start Application')),
          const SizedBox(height: 12),
          Center(child: Text('Review takes 24–48 hours. You\'ll be notified by email.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _RequirementRow({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(sub, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepPersonal extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final VoidCallback onContinue;
  const _StepPersonal({required this.formKey, required this.nameController, required this.phoneController, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('Personal info', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.6)),
          const SizedBox(height: 6),
          Text('This will appear on your public profile.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 28),
          Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: AppColors.textMuted),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Mobile number',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: AppColors.textMuted),
                    prefixText: '+91  ',
                    prefixStyle: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your mobile';
                    if (v.length < 10) return 'Enter a valid 10-digit number';
                    return null;
                  },
                ),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(onPressed: onContinue, child: const Text('Continue')),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _StepBroker extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<String> brokers;
  final String? selectedBroker;
  final TextEditingController accountIdController;
  final ValueChanged<String?> onBrokerSelected;
  final VoidCallback onContinue;
  const _StepBroker({required this.formKey, required this.brokers, required this.selectedBroker, required this.accountIdController, required this.onBrokerSelected, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('Connect your\nbroker', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.6, height: 1.15)),
          const SizedBox(height: 6),
          Text('We verify data directly from your broker.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 28),
          Form(
            key: formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedBroker,
                  items: brokers.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: onBrokerSelected,
                  style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Select your broker',
                    prefixIcon: Icon(Icons.account_balance_outlined, size: 20, color: AppColors.textMuted),
                  ),
                  validator: (v) => v == null ? 'Select a broker' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: accountIdController,
                  textInputAction: TextInputAction.done,
                  style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Account / Login ID',
                    prefixIcon: Icon(Icons.tag_rounded, size: 20, color: AppColors.textMuted),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your account ID' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Read-only access only. We never trade on your behalf.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(onPressed: onContinue, child: const Text('Continue')),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _StepPnl extends StatelessWidget {
  final String? uploadedFileName;
  final bool hasMinData;
  final bool isLoading;
  final VoidCallback onUpload;
  final ValueChanged<bool?> onToggleConfirm;
  final VoidCallback? onSubmit;
  const _StepPnl({required this.uploadedFileName, required this.hasMinData, required this.isLoading, required this.onUpload, required this.onToggleConfirm, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('Upload trading\nstatement', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.6, height: 1.15)),
          const SizedBox(height: 6),
          Text('Minimum 6 months of real account history required.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onUpload,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: uploadedFileName != null ? AppColors.green.withOpacity(0.05) : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: uploadedFileName != null ? AppColors.green : AppColors.border, width: uploadedFileName != null ? 1.5 : 1),
              ),
              child: Column(
                children: [
                  Icon(
                    uploadedFileName != null ? Icons.check_circle_outline_rounded : Icons.upload_file_outlined,
                    size: 32,
                    color: uploadedFileName != null ? AppColors.green : AppColors.textMuted,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    uploadedFileName ?? 'Tap to upload statement',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: uploadedFileName != null ? AppColors.green : AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    uploadedFileName != null ? 'Statement uploaded successfully' : 'PDF, XLS or CSV • Max 20 MB',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: ['MT5 Report', 'MT4 Report', 'cTrader PDF', 'Bank CSV'].map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
              child: Text(f, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            )).toList(),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => onToggleConfirm(!hasMinData),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: hasMinData ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: hasMinData ? AppColors.primary : AppColors.border, width: 1.5),
                  ),
                  child: hasMinData ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'I confirm this is from a real live account with at least 6 months of history',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          AnimatedOpacity(
            opacity: onSubmit != null ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Application'),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _StepPending extends StatelessWidget {
  final VoidCallback onGoHome;
  const _StepPending({required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          SizedBox(height: 140, child: CustomPaint(painter: _PendingPainter())),
          const SizedBox(height: 32),
          Text('Application submitted!', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.6)),
          const SizedBox(height: 10),
          Text(
            'Our team will review your trading data and PnL within 24–48 hours. You\'ll get an email once approved.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 32),
          _PendingStep(icon: Icons.pending_outlined, title: 'Under review', sub: 'PnL data & account history being verified', color: AppColors.primary),
          const SizedBox(height: 12),
          _PendingStep(icon: Icons.notifications_outlined, title: 'We\'ll notify you', sub: 'Email + in-app notification when approved', color: AppColors.green),
          const SizedBox(height: 12),
          _PendingStep(icon: Icons.live_tv_outlined, title: 'Go live', sub: 'Stream, share trades, and earn from followers', color: AppColors.textMuted, muted: true),
          const Spacer(),
          ElevatedButton(onPressed: onGoHome, child: const Text('Browse the app')),
          const SizedBox(height: 12),
          Center(child: Text('Track your application in Profile → Creator Status', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _PendingStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final Color color;
  final bool muted;
  const _PendingStep({required this.icon, required this.title, required this.sub, required this.color, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: muted ? 0.4 : 1.0,
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
              Text(sub, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerifiedChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(5);
    const count = 8;
    final w = size.width / count;
    double price = size.height * 0.6;
    final pts = <Offset>[];
    for (int i = 0; i < count; i++) {
      final x = w * i + w / 2;
      price = (price + (rng.nextDouble() - 0.38) * size.height * 0.12).clamp(size.height * 0.1, size.height * 0.9);
      pts.add(Offset(x, price));
    }
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      final cx = (pts[i - 1].dx + pts[i].dx) / 2;
      path.cubicTo(cx, pts[i - 1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, Paint()..color = AppColors.primary..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    final fill = Path.from(path)..lineTo(pts.last.dx, size.height)..lineTo(pts.first.dx, size.height)..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primary.withOpacity(0.2), Colors.transparent]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawCircle(pts.last, 7, Paint()..color = AppColors.primary);
    canvas.drawCircle(pts.last, 5, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(_VerifiedChartPainter old) => false;
}

class _PendingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.85;
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = AppColors.primary.withOpacity(0.08));
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = AppColors.primary.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 2);
    final handPaint = Paint()..color = AppColors.primary..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy), Offset(cx, cy - r * 0.45), handPaint);
    canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.35, cy + 0.1 * r), handPaint);
    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = AppColors.primary);
    for (int i = 0; i < 12; i++) {
      final angle = i * 30 * math.pi / 180;
      canvas.drawLine(
        Offset(cx + r * 0.82 * math.cos(angle), cy + r * 0.82 * math.sin(angle)),
        Offset(cx + r * 0.95 * math.cos(angle), cy + r * 0.95 * math.sin(angle)),
        Paint()..color = AppColors.primary.withOpacity(0.3)..strokeWidth = 1.5,
      );
    }
  }
  @override
  bool shouldRepaint(_PendingPainter old) => false;
}
