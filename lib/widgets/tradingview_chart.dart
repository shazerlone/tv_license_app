import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

/// An embedded TradingView advanced chart for a given TradingView symbol
/// (e.g. "OANDA:XAUUSD"). Real, live market data — the same charts pro
/// platforms show — with no data cost to us.
class TradingViewChart extends StatefulWidget {
  final String tvSymbol;
  final double height;
  /// TradingView interval code: 60 (1H), D (1D), W (1W), etc.
  final String interval;
  const TradingViewChart({super.key, required this.tvSymbol, this.height = 320, this.interval = '60'});

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

class _TradingViewChartState extends State<TradingViewChart> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final theme = AppColors.isDark ? 'dark' : 'light';
    final sym = Uri.encodeComponent(widget.tvSymbol);
    final url =
        'https://s.tradingview.com/widgetembed/?symbol=$sym&interval=${widget.interval}&theme=$theme&style=1&hidesidetoolbar=1&hidetoptoolbar=0&withdateranges=1&saveimage=0&locale=en';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              Container(
                color: AppColors.surface,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)),
              ),
          ],
        ),
      ),
    );
  }
}
