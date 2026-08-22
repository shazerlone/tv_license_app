/// User's chosen indicators + their inputs for the market chart. Overlays (MA,
/// EMA) draw on the price pane; RSI and MACD each get their own sub-pane.
class IndicatorConfig {
  bool maOn;
  int maPeriod;
  bool emaOn;
  int emaPeriod;
  bool rsiOn;
  int rsiPeriod;
  bool macdOn;
  int macdFast;
  int macdSlow;
  int macdSignal;

  IndicatorConfig({
    this.maOn = false,
    this.maPeriod = 20,
    this.emaOn = false,
    this.emaPeriod = 50,
    this.rsiOn = false,
    this.rsiPeriod = 14,
    this.macdOn = false,
    this.macdFast = 12,
    this.macdSlow = 26,
    this.macdSignal = 9,
  });

  /// Number of active sub-panes below the price pane (RSI, MACD).
  int get subPaneCount => (rsiOn ? 1 : 0) + (macdOn ? 1 : 0);

  /// A short summary for the toolbar, e.g. "MA · RSI".
  String get summary {
    final on = <String>[];
    if (maOn) on.add('MA');
    if (emaOn) on.add('EMA');
    if (rsiOn) on.add('RSI');
    if (macdOn) on.add('MACD');
    return on.isEmpty ? 'Indicators' : on.join(' · ');
  }

  int get activeCount => (maOn ? 1 : 0) + (emaOn ? 1 : 0) + (rsiOn ? 1 : 0) + (macdOn ? 1 : 0);

  IndicatorConfig copy() => IndicatorConfig(
        maOn: maOn,
        maPeriod: maPeriod,
        emaOn: emaOn,
        emaPeriod: emaPeriod,
        rsiOn: rsiOn,
        rsiPeriod: rsiPeriod,
        macdOn: macdOn,
        macdFast: macdFast,
        macdSlow: macdSlow,
        macdSignal: macdSignal,
      );
}
