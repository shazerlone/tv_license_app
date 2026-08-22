import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../state/session.dart';
import '../services/auth_api.dart';
import '../services/api_client.dart';
import 'email_verify_screen.dart';
import '../services/backend_api.dart';
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
  final _email = TextEditingController();
  String? _photoUrl;
  double _leverage = 1;
  bool _saving = false;
  bool _isCreator = false;
  bool _init = false;
  bool _emailNotif = true;
  String? _origEmail;
  bool _emailVerified = false;

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
    _email.text = u?.email ?? '';
    _origEmail = u?.email;
    _emailNotif = u?.emailNotifications ?? true;
    _emailVerified = u?.emailVerified ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _market.dispose();
    _platform.dispose();
    _address.dispose();
    _city.dispose();
    _postal.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Save the email if it changed, (re)send the code, then open the verify
  /// screen. Refreshes the verified state on return.
  Future<void> _verifyEmail() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email first')));
      return;
    }
    final session = SessionScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String? devCode;
    try {
      if (email != (_origEmail ?? '')) {
        final updated = await AuthApi.updateMe({'email': email, 'emailNotifications': _emailNotif});
        session.applyBackendSession(updated);
        _origEmail = email;
      }
      devCode = await AuthApi.sendEmailCode();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.code == 'email_taken' ? 'That email is already in use.' : e.message)));
      return;
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not reach the server')));
      return;
    }
    if (!mounted) return;
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EmailVerifyScreen(email: email, devCode: devCode)));
    if (ok == true && mounted) setState(() => _emailVerified = true);
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
          if (_email.text.trim() != (_origEmail ?? '')) 'email': _email.text.trim(),
          'emailNotifications': _emailNotif,
        };
        final updated = await AuthApi.updateMe(fields);
        if (!mounted) return;
        session.applyBackendSession(updated);
        Navigator.pop(context);
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          e.code == 'email_taken' ? 'That email is already in use.' : e.message,
        )));
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
          const SizedBox(height: 20),
          Row(children: [
            _Label('Email'),
            const SizedBox(width: 8),
            if (_email.text.trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: (_emailVerified ? AppColors.green : AppColors.slate).withOpacity(0.14), borderRadius: BorderRadius.circular(5)),
                child: Text(_emailVerified ? 'Verified' : 'Unverified',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: _emailVerified ? AppColors.green : AppColors.slate)),
              ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'you@email.com'),
            onChanged: (_) => setState(() {}),
          ),
          if (_email.text.trim().isNotEmpty && !_emailVerified) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _verifyEmail,
                icon: Icon(Icons.mark_email_read_outlined, size: 17, color: AppColors.primary),
                label: Text('Verify email', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ),
          ],
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _emailNotif,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _emailNotif = v),
            title: Text('Email notifications', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            subtitle: Text('Deposits, copies, and important account updates.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
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
