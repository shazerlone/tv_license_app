/// Broker partners the platform integrates with for copy trading.
/// Availability is country-gated. Backend can override this list at runtime.
class Broker {
  final String id;
  final String name;
  final String blurb;
  final bool recommended;
  const Broker(this.id, this.name, this.blurb, {this.recommended = false});
}

const Broker _century = Broker('century', 'Century', 'Our recommended partner — fast execution, low spreads', recommended: true);
const Broker _xm = Broker('xm', 'XM', 'Global broker, widely available');
const Broker _exness = Broker('exness', 'Exness', 'Low spreads, instant withdrawals');
const Broker _vantage = Broker('vantage', 'Vantage', 'Trusted multi-asset broker');

const List<Broker> _allBrokers = [_century, _xm, _exness, _vantage];

/// ISO country codes where Century is NOT available.
const Set<String> _centuryBlockedIso = {'IN'};

/// Returns brokers available for a residence country, recommended first.
/// India → Vantage, XM. Everywhere else → Century (recommended), XM, Exness, Vantage.
List<Broker> brokersForCountry(String? iso) {
  if (iso == 'IN') {
    return const [_vantage, _xm];
  }
  final available = _allBrokers.where((b) {
    if (b.id == 'century' && _centuryBlockedIso.contains(iso)) return false;
    return true;
  }).toList();
  available.sort((a, b) => (b.recommended ? 1 : 0).compareTo(a.recommended ? 1 : 0));
  return available;
}

Broker brokerById(String id) => _allBrokers.firstWhere((b) => b.id == id, orElse: () => _xm);
