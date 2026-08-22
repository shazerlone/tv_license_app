import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';

/// Settings › Security — two-factor authentication (M14).
/// GET /2fa, POST /2fa/setup|enable|disable.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _loading = true;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await BackendApi.twofaStatus();
      if (!mounted) return;
      setState(() {
        _enabled = s['enabled'] == true || s['twofaEnabled'] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Security', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: _loading
          ? const AppLoader()
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(color: (_enabled ? AppColors.green : AppColors.textMuted).withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                        child: Icon(_enabled ? Icons.verified_user_rounded : Icons.lock_outline_rounded, color: _enabled ? AppColors.green : AppColors.textMuted),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Two-factor authentication', style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 3),
                            Text(_enabled ? 'On — your account is protected' : 'Off — add a second layer of security',
                                style: GoogleFonts.inter(fontSize: 13, color: _enabled ? AppColors.green : AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Use an authenticator app (Google Authenticator, Authy, 1Password) to generate a 6-digit code each time you sign in.',
                  style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _enabled
                      ? OutlinedButton(
                          onPressed: _startDisable,
                          style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.red.withOpacity(0.4)), foregroundColor: AppColors.red),
                          child: Text('Turn off 2FA', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.red)),
                        )
                      : ElevatedButton(
                          onPressed: _startSetup,
                          child: Text('Set up 2FA', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                ),
                const SizedBox(height: 28),
                Text('Password', style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _changePassword,
                  icon: Icon(Icons.lock_reset_rounded, size: 19, color: AppColors.primary),
                  label: Text('Change password', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ],
            ),
    );
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Change password', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: current, obscureText: true, style: GoogleFonts.inter(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'Current password')),
            const SizedBox(height: 12),
            TextField(controller: next, obscureText: true, style: GoogleFonts.inter(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: 'New password (min 8)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
        ],
      ),
    );
    if (ok != true) return;
    if (next.text.length < 8) {
      _snack('New password must be at least 8 characters');
      return;
    }
    try {
      await BackendApi.changePassword(current.text, next.text);
      _snack('Password updated');
    } on ApiException catch (e) {
      _snack(e.code == 'invalid_credentials' ? 'Current password is incorrect' : e.message);
    } catch (_) {
      _snack('Could not reach the server');
    }
  }

  Future<void> _startSetup() async {
    Map<String, dynamic> setup;
    try {
      setup = await BackendApi.twofaSetup();
    } on ApiException catch (e) {
      _snack(e.message);
      return;
    } catch (_) {
      _snack('Could not reach the server');
      return;
    }
    if (!mounted) return;
    final secret = setup['secret']?.toString() ?? '';
    final otpauth = setup['otpauthUrl']?.toString() ?? '';
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _EnableScreen(secret: secret, otpauthUrl: otpauth)),
    );
    if (ok == true) _load();
  }

  Future<void> _startDisable() async {
    final code = await _promptCode(title: 'Turn off 2FA', hint: 'Enter a current code to confirm');
    if (code == null || code.isEmpty) return;
    try {
      await BackendApi.twofaDisable(code);
      if (!mounted) return;
      _snack('Two-factor authentication turned off');
      setState(() => _enabled = false);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not reach the server');
    }
  }

  Future<String?> _promptCode({required String title, required String hint}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          style: GoogleFonts.robotoMono(fontSize: 20, letterSpacing: 4, color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted))),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('Confirm')),
        ],
      ),
    );
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}

/// Step 2 of setup: show the secret, take a code, enable, then reveal backup codes.
class _EnableScreen extends StatefulWidget {
  final String secret;
  final String otpauthUrl;
  const _EnableScreen({required this.secret, required this.otpauthUrl});

  @override
  State<_EnableScreen> createState() => _EnableScreenState();
}

class _EnableScreenState extends State<_EnableScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  List<String>? _backupCodes;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _enable() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final codes = await BackendApi.twofaEnable(code);
      if (!mounted) return;
      setState(() {
        _backupCodes = codes;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final codes = _backupCodes;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(codes == null ? 'Set up 2FA' : 'Save your backup codes',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: codes == null ? _setupBody() : _backupBody(codes),
    );
  }

  Widget _setupBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text('1. Add this key to your authenticator app',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text('Open Google Authenticator / Authy, choose “add manually”, and paste this secret.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.45)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _copy(widget.secret, 'Secret copied'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Expanded(child: SelectableText(widget.secret, style: GoogleFonts.robotoMono(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: 1.5))),
                Icon(Icons.copy_rounded, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        if (widget.otpauthUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _copy(widget.otpauthUrl, 'Setup link copied'),
            icon: Icon(Icons.link_rounded, size: 18, color: AppColors.primary),
            label: Text('Copy setup link instead', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
        ],
        const SizedBox(height: 24),
        Text('2. Enter the 6-digit code it shows',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _enable(),
          style: GoogleFonts.robotoMono(fontSize: 22, letterSpacing: 6, color: AppColors.textPrimary),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(hintText: '000000'),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _busy ? null : _enable,
            child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Turn on 2FA', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _backupBody(List<String> codes) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.green),
              const SizedBox(width: 12),
              Expanded(child: Text('2FA is on. Save these backup codes somewhere safe — each works once if you lose your authenticator.',
                  style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textPrimary, height: 1.4))),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Wrap(
            spacing: 18, runSpacing: 12,
            children: codes
                .map((c) => Text(c, style: GoogleFonts.robotoMono(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: 1)))
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => _copy(codes.join('\n'), 'Backup codes copied'),
          icon: Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
          label: Text('Copy all codes', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary)),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  void _copy(String text, String msg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
