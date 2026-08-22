import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';
import '../widgets/phone_field.dart';
import '../data/countries.dart';
import '../config.dart';
import '../state/session.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';
import '../services/image_picker_service.dart';

/// Identity verification (KYC) — a proper manual funnel:
///   1. Personal details (name, date of birth, country)
///   2. Document (type, number, front / back photo)
///   3. Selfie
///   4. Review → submit (uploads the images, then POST /kyc/submit)
/// When already pending/verified/rejected it shows the status instead.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  String _status = 'none';
  bool _loading = true;
  bool _submitting = false;
  bool _init = false;
  int _step = 0;

  // Step 1
  final _fullName = TextEditingController();
  DateTime? _dob;
  Country? _country;

  // Step 2
  String _docType = 'passport';
  final _docNumber = TextEditingController();
  String? _frontData, _backData;

  // Step 3
  String? _selfieData;

  bool get _needsBack => _docType != 'passport';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final u = SessionScope.of(context).user;
    _status = u?.kycStatus ?? 'none';
    _fullName.text = u?.name ?? '';
    if (u?.residenceIso != null) _country = countryByIso(u!.residenceIso!);
    if (kUseBackend) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _docNumber.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await BackendApi.kycStatus();
      if (!mounted) return;
      setState(() {
        _status = (r['status'] ?? r['kycStatus'] ?? _status).toString();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(void Function(String) assign, {bool crop = false}) async {
    final url = await ImagePickerService.pickImageAsDataUrl(cropSquare: crop);
    if (url != null && mounted) setState(() => assign(url));
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        if (_fullName.text.trim().isEmpty) return _err('Enter your full legal name');
        if (_dob == null) return _err('Select your date of birth');
        if (_country == null) return _err('Select your country');
        return true;
      case 1:
        if (_docNumber.text.trim().isEmpty) return _err('Enter your document number');
        if (_frontData == null) return _err('Add a photo of the document front');
        if (_needsBack && _backData == null) return _err('Add a photo of the document back');
        return true;
      case 2:
        if (_selfieData == null) return _err('Add a selfie');
        return true;
      default:
        return true;
    }
  }

  bool _err(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    return false;
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  Future<String> _upload(String dataUrl) async {
    final comma = dataUrl.indexOf(',');
    final contentType = dataUrl.substring(5, comma).split(';').first;
    final data = dataUrl.substring(comma + 1);
    return BackendApi.uploadMedia(contentType: contentType, data: data, kind: 'kyc');
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final frontUrl = await _upload(_frontData!);
      final backUrl = _needsBack && _backData != null ? await _upload(_backData!) : null;
      final selfieUrl = await _upload(_selfieData!);
      final r = await BackendApi.submitKyc({
        'fullName': _fullName.text.trim(),
        'dob': _dob!.toIso8601String().split('T').first,
        'country': _country!.iso,
        'docType': _docType,
        'docNumber': _docNumber.text.trim(),
        'frontUrl': frontUrl,
        if (backUrl != null) 'backUrl': backUrl,
        'selfieUrl': selfieUrl,
      });
      if (!mounted) return;
      final status = (r['kycStatus'] ?? 'pending').toString();
      final u = SessionScope.of(context).user;
      if (u != null) SessionScope.of(context).applyBackendSession(u.copyWith(kycStatus: status));
      setState(() { _submitting = false; _status = status; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted — your identity is under review.')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Identity verification', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (_showFunnel && _step > 0) {
              setState(() => _step--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _loading ? const AppLoader() : (_showFunnel ? _funnel() : _statusView()),
    );
  }

  bool get _showFunnel => _status == 'none' || _status == 'rejected';

  // ── Funnel ──────────────────────────────────────────────────────────────────
  static const _titles = ['Your details', 'Your document', 'Selfie check', 'Review & submit'];

  Widget _funnel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                  decoration: BoxDecoration(color: i <= _step ? AppColors.primary : AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              );
            }),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_titles[_step], style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
                const SizedBox(height: 20),
                _stepBody(),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _next,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_step < 3 ? 'Continue' : 'Submit for review'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Full legal name'),
            const SizedBox(height: 8),
            TextField(controller: _fullName, textCapitalization: TextCapitalization.words,
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'As printed on your ID')),
            const SizedBox(height: 18),
            _label('Date of birth'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDob,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 12),
                  Text(_dob == null ? 'Select date' : _dob!.toIso8601String().split('T').first,
                      style: GoogleFonts.inter(fontSize: 15, color: _dob == null ? AppColors.textMuted : AppColors.textPrimary)),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            _label('Country'),
            const SizedBox(height: 8),
            CountryField(country: _country, hint: 'Select country', onChanged: (c) => setState(() => _country = c)),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Document type'),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _docChip('passport', 'Passport'),
              _docChip('id_card', 'ID card'),
              _docChip('drivers_license', 'Driver\'s license'),
            ]),
            const SizedBox(height: 18),
            _label('Document number'),
            const SizedBox(height: 8),
            TextField(controller: _docNumber,
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'e.g. X1234567')),
            const SizedBox(height: 18),
            _uploadTile('Front of document', _frontData, () => _pick((v) => _frontData = v)),
            if (_needsBack) ...[
              const SizedBox(height: 12),
              _uploadTile('Back of document', _backData, () => _pick((v) => _backData = v)),
            ],
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Take or choose a clear selfie. Make sure your face is fully visible and well lit.',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 18),
            _uploadTile('Selfie', _selfieData, () => _pick((v) => _selfieData = v, crop: true)),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reviewRow('Name', _fullName.text.trim()),
            _reviewRow('Date of birth', _dob?.toIso8601String().split('T').first ?? '—'),
            _reviewRow('Country', _country?.name ?? '—'),
            _reviewRow('Document', '${_docLabel(_docType)} · ${_docNumber.text.trim()}'),
            const SizedBox(height: 16),
            Row(children: [
              _thumb(_frontData),
              if (_needsBack) ...[const SizedBox(width: 10), _thumb(_backData)],
              const SizedBox(width: 10),
              _thumb(_selfieData),
            ]),
            const SizedBox(height: 18),
            Text('By submitting you confirm these documents are genuine and belong to you.',
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted, height: 1.5)),
          ],
        );
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Select date of birth',
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  Widget _docChip(String value, String label) {
    final on = _docType == value;
    return GestureDetector(
      onTap: () => setState(() => _docType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: on ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: on ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: on ? Colors.white : AppColors.textPrimary)),
      ),
    );
  }

  String _docLabel(String t) => t == 'passport' ? 'Passport' : t == 'id_card' ? 'ID card' : 'Driver\'s license';

  Widget _uploadTile(String label, String? data, VoidCallback onTap) {
    final done = data != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: done ? AppColors.green.withOpacity(0.05) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: done ? AppColors.green : AppColors.border, width: done ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(done ? Icons.check_circle_rounded : Icons.add_a_photo_outlined, size: 26, color: done ? AppColors.green : AppColors.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(done ? 'Added — tap to replace' : 'Tap to add a photo', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
            ]),
          ),
          if (done) _thumb(data, size: 44),
        ]),
      ),
    );
  }

  Widget _thumb(String? data, {double size = 60}) {
    if (data == null) {
      return Container(width: size, height: size, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)));
    }
    return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(data, width: size, height: size, fit: BoxFit.cover));
  }

  Widget _reviewRow(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(k, style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textMuted))),
          Expanded(child: Text(v, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        ]),
      );

  Widget _label(String t) => Text(t, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary));

  // ── Status view (pending / verified) ────────────────────────────────────────
  ({Color color, IconData icon, String label, String body}) get _view {
    switch (_status) {
      case 'verified':
        return (color: AppColors.green, icon: Icons.verified_user_rounded, label: 'Verified', body: 'Your identity is verified. You can withdraw funds.');
      case 'pending':
        return (color: AppColors.primary, icon: Icons.hourglass_top_rounded, label: 'Under review', body: 'We\'re reviewing your documents. This usually takes a few minutes to a few hours — we\'ll notify you.');
      default:
        return (color: AppColors.red, icon: Icons.error_outline_rounded, label: 'Rejected', body: 'We couldn\'t verify your identity. Please try again with clearer documents.');
    }
  }

  Widget _statusView() {
    final v = _view;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: v.color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(v.icon, color: v.color, size: 34),
          ),
        ),
        const SizedBox(height: 20),
        Text(v.label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
        const SizedBox(height: 8),
        Text(v.body, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
      ]),
    );
  }
}
