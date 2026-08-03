import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../state/session.dart';
import '../services/auth_api.dart';
import '../services/api_client.dart';
import '../services/image_picker_service.dart';
import '../services/app_config.dart';
import '../widgets/avatar.dart';

/// Edit the signed-in user's profile (PATCH /me).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _market = TextEditingController();
  final _platform = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _postal = TextEditingController();
  String? _photoUrl;
  double _leverage = 1;
  bool _saving = false;
  bool _isCreator = false;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final u = SessionScope.of(context).user;
    _name.text = u?.name ?? '';
    _market.text = u?.market ?? '';
    _platform.text = u?.platform ?? '';
    _address.text = u?.addressLine ?? '';
    _city.text = u?.city ?? '';
    _postal.text = u?.postalCode ?? '';
    _photoUrl = u?.photoUrl;
    _leverage = (u?.leverage ?? 1).clamp(1, AppConfig.instance.maxLeverage < 1 ? 1 : AppConfig.instance.maxLeverage);
    _isCreator = u?.isCreator ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _market.dispose();
    _platform.dispose();
    _address.dispose();
    _city.dispose();
    _postal.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final url = await ImagePickerService.pickImageAsDataUrl();
    if (url != null && mounted) setState(() => _photoUrl = url);
  }

  Future<void> _save() async {
    final session = SessionScope.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your name')));
      return;
    }
    setState(() => _saving = true);

    if (kUseBackend) {
      try {
        // Upload a freshly-picked photo (data URL) to get a hosted URL.
        var photo = _photoUrl;
        if (photo != null && photo.startsWith('data:')) {
          final comma = photo.indexOf(',');
          final header = photo.substring(5, comma); // e.g. image/png;base64
          final contentType = header.split(';').first;
          final data = photo.substring(comma + 1);
          photo = await BackendApi.uploadMedia(contentType: contentType, data: data, kind: 'avatar');
        }
        final fields = <String, dynamic>{
          'name': name,
          if (photo != null) 'photoUrl': photo,
          if (_isCreator && _market.text.trim().isNotEmpty) 'market': _market.text.trim(),
          if (_isCreator && _platform.text.trim().isNotEmpty) 'platform': _platform.text.trim(),
          if (_address.text.trim().isNotEmpty) 'addressLine': _address.text.trim(),
          if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
          if (_postal.text.trim().isNotEmpty) 'postalCode': _postal.text.trim(),
          if (AppConfig.instance.maxLeverage > 1) 'leverage': _leverage,
        };
        final updated = await AuthApi.updateMe(fields);
        if (!mounted) return;
        session.applyBackendSession(updated);
        Navigator.pop(context);
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server')));
        return;
      }
    }

    // Demo: update the local session.
    final u = session.user;
    if (u != null) session.applyBackendSession(u.copyWith(name: name, photoUrl: _photoUrl, market: _market.text.trim(), platform: _platform.text.trim()));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Edit profile', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  Avatar(name: _name.text.isEmpty ? '?' : _name.text, photoUrl: _photoUrl, size: 96),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 2)),
                      child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _Label('Full name'),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Your name'),
            onChanged: (_) => setState(() {}),
          ),
          if (_isCreator) ...[
            const SizedBox(height: 20),
            _Label('Market'),
            const SizedBox(height: 8),
            TextField(
              controller: _market,
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'e.g. Forex'),
            ),
            const SizedBox(height: 20),
            _Label('Platform'),
            const SizedBox(height: 8),
            TextField(
              controller: _platform,
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'e.g. MetaTrader 5'),
            ),
          ],
          const SizedBox(height: 24),
          Text('Address', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.2)),
          const SizedBox(height: 4),
          Text('Required for withdrawals & verification.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          _Label('Address line'),
          const SizedBox(height: 8),
          TextField(
            controller: _address,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Street address'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('City'),
                    const SizedBox(height: 8),
                    TextField(controller: _city, style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'City')),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Postal code'),
                    const SizedBox(height: 8),
                    TextField(controller: _postal, style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'ZIP')),
                  ],
                ),
              ),
            ],
          ),
          if (AppConfig.instance.maxLeverage > 1) ...[
            const SizedBox(height: 24),
            Text('Default leverage', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.2)),
            const SizedBox(height: 4),
            Text('Applied to new copies (you can override per trader).', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${_leverage.toStringAsFixed(0)}x', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Expanded(
                  child: Slider(
                    value: _leverage.clamp(1, AppConfig.instance.maxLeverage),
                    min: 1,
                    max: AppConfig.instance.maxLeverage,
                    divisions: (AppConfig.instance.maxLeverage - 1).clamp(1, 500).toInt(),
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.border,
                    onChanged: (v) => setState(() => _leverage = v),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save changes'),
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
  Widget build(BuildContext context) =>
      Text(text, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
}
