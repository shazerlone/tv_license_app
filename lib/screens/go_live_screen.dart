import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';

/// Creator-side "Go Live" setup. The trader streams once (from OBS or the
/// desktop app) to the ingest URL below; the backend simulcasts to the
/// connected destinations and into the Millimore app.
class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  final _titleController = TextEditingController(text: 'Live trading session');

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final live = store.isBroadcasting;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Go Live', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF0B1120), borderRadius: BorderRadius.circular(18)),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(live ? Icons.podcasts_rounded : Icons.videocam_outlined, size: 40, color: live ? AppColors.red : Colors.white24),
                          const SizedBox(height: 10),
                          Text(live ? 'You are live' : 'Preview from OBS / desktop app',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.6))),
                        ],
                      ),
                    ),
                    if (live)
                      Positioned(
                        top: 12, left: 12,
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(6)),
                            child: Text('LIVE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(6)),
                            child: Row(children: [
                              const Icon(Icons.remove_red_eye_rounded, size: 13, color: Colors.white),
                              const SizedBox(width: 4),
                              Text('${store.viewers}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            ]),
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _Label('Stream title'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'What are you trading today?'),
            ),
            const SizedBox(height: 22),

            Text('Stream to', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Go live everywhere at once. Your audience on YouTube & Facebook sees a "Copy on Millimore" call-to-action.',
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
            const SizedBox(height: 14),
            _DestTile(icon: Icons.auto_graph_rounded, name: 'Millimore', sub: 'Always on — your followers watch here', on: true, locked: true, onTap: () {}),
            _DestTile(icon: Icons.smart_display_rounded, name: 'YouTube Live', sub: store.isDestinationOn('youtube') ? 'Connected' : 'Tap to connect', on: store.isDestinationOn('youtube'), onTap: () => store.toggleDestination('youtube')),
            _DestTile(icon: Icons.facebook_rounded, name: 'Facebook Live', sub: store.isDestinationOn('facebook') ? 'Connected' : 'Tap to connect', on: store.isDestinationOn('facebook'), onTap: () => store.toggleDestination('facebook')),
            _DestTile(icon: Icons.camera_alt_rounded, name: 'Instagram', sub: 'Not supported yet', on: false, disabled: true, onTap: () {}),
            const SizedBox(height: 22),

            Text('Connect OBS / desktop app', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('In OBS → Settings → Stream → Custom, paste these. Or use the Millimore desktop app for one-click.',
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
            const SizedBox(height: 14),
            _CopyField(label: 'Ingest URL', value: store.ingestUrl),
            const SizedBox(height: 10),
            _CopyField(label: 'Stream key', value: store.streamKey, secret: true),
            const SizedBox(height: 28),

            if (live)
              OutlinedButton.icon(
                onPressed: () => store.endBroadcast(),
                icon: const Icon(Icons.stop_circle_outlined, size: 19, color: AppColors.red),
                label: Text('End stream', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.red)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), side: BorderSide(color: AppColors.red.withOpacity(0.4))),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  store.startBroadcast();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are now live')));
                },
                icon: const Icon(Icons.podcasts_rounded, size: 19),
                label: const Text('Go Live'),
              ),
            const SizedBox(height: 14),
            Center(child: Text('Streaming uses your connected broker for the live trade overlay.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))),
          ],
        ),
      ),
    );
  }
}

class _DestTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String sub;
  final bool on;
  final bool locked;
  final bool disabled;
  final VoidCallback onTap;
  const _DestTile({required this.icon, required this.name, required this.sub, required this.on, this.locked = false, this.disabled = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? AppColors.primary : AppColors.border, width: on ? 1.5 : 1)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(sub, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (locked)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
            else if (disabled)
              const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 20)
            else
              Switch(value: on, onChanged: (_) => onTap(), activeColor: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;
  final bool secret;
  const _CopyField({required this.label, required this.value, this.secret = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(secret ? '••••••••••••${value.substring(value.length - 4)}' : value,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
            },
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
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
}
