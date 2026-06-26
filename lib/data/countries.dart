class Country {
  final String name;
  final String dialCode;
  final String flag;
  final String iso;
  const Country(this.name, this.dialCode, this.flag, this.iso);
}

/// A practical list of countries with dial codes and flag emojis.
const List<Country> kCountries = [
  Country('India', '+91', '🇮🇳', 'IN'),
  Country('United States', '+1', '🇺🇸', 'US'),
  Country('United Kingdom', '+44', '🇬🇧', 'GB'),
  Country('United Arab Emirates', '+971', '🇦🇪', 'AE'),
  Country('Australia', '+61', '🇦🇺', 'AU'),
  Country('Canada', '+1', '🇨🇦', 'CA'),
  Country('Singapore', '+65', '🇸🇬', 'SG'),
  Country('Germany', '+49', '🇩🇪', 'DE'),
  Country('France', '+33', '🇫🇷', 'FR'),
  Country('Spain', '+34', '🇪🇸', 'ES'),
  Country('Italy', '+39', '🇮🇹', 'IT'),
  Country('Netherlands', '+31', '🇳🇱', 'NL'),
  Country('Switzerland', '+41', '🇨🇭', 'CH'),
  Country('Sweden', '+46', '🇸🇪', 'SE'),
  Country('Norway', '+47', '🇳🇴', 'NO'),
  Country('Denmark', '+45', '🇩🇰', 'DK'),
  Country('Ireland', '+353', '🇮🇪', 'IE'),
  Country('Portugal', '+351', '🇵🇹', 'PT'),
  Country('Belgium', '+32', '🇧🇪', 'BE'),
  Country('Austria', '+43', '🇦🇹', 'AT'),
  Country('Poland', '+48', '🇵🇱', 'PL'),
  Country('Greece', '+30', '🇬🇷', 'GR'),
  Country('Russia', '+7', '🇷🇺', 'RU'),
  Country('Turkey', '+90', '🇹🇷', 'TR'),
  Country('Saudi Arabia', '+966', '🇸🇦', 'SA'),
  Country('Qatar', '+974', '🇶🇦', 'QA'),
  Country('Kuwait', '+965', '🇰🇼', 'KW'),
  Country('Bahrain', '+973', '🇧🇭', 'BH'),
  Country('Oman', '+968', '🇴🇲', 'OM'),
  Country('Israel', '+972', '🇮🇱', 'IL'),
  Country('South Africa', '+27', '🇿🇦', 'ZA'),
  Country('Nigeria', '+234', '🇳🇬', 'NG'),
  Country('Kenya', '+254', '🇰🇪', 'KE'),
  Country('Egypt', '+20', '🇪🇬', 'EG'),
  Country('Ghana', '+233', '🇬🇭', 'GH'),
  Country('Pakistan', '+92', '🇵🇰', 'PK'),
  Country('Bangladesh', '+880', '🇧🇩', 'BD'),
  Country('Sri Lanka', '+94', '🇱🇰', 'LK'),
  Country('Nepal', '+977', '🇳🇵', 'NP'),
  Country('China', '+86', '🇨🇳', 'CN'),
  Country('Hong Kong', '+852', '🇭🇰', 'HK'),
  Country('Japan', '+81', '🇯🇵', 'JP'),
  Country('South Korea', '+82', '🇰🇷', 'KR'),
  Country('Malaysia', '+60', '🇲🇾', 'MY'),
  Country('Indonesia', '+62', '🇮🇩', 'ID'),
  Country('Thailand', '+66', '🇹🇭', 'TH'),
  Country('Vietnam', '+84', '🇻🇳', 'VN'),
  Country('Philippines', '+63', '🇵🇭', 'PH'),
  Country('New Zealand', '+64', '🇳🇿', 'NZ'),
  Country('Brazil', '+55', '🇧🇷', 'BR'),
  Country('Mexico', '+52', '🇲🇽', 'MX'),
  Country('Argentina', '+54', '🇦🇷', 'AR'),
  Country('Chile', '+56', '🇨🇱', 'CL'),
  Country('Colombia', '+57', '🇨🇴', 'CO'),
  Country('Peru', '+51', '🇵🇪', 'PE'),
  Country('Czech Republic', '+420', '🇨🇿', 'CZ'),
  Country('Hungary', '+36', '🇭🇺', 'HU'),
  Country('Romania', '+40', '🇷🇴', 'RO'),
  Country('Ukraine', '+380', '🇺🇦', 'UA'),
  Country('Finland', '+358', '🇫🇮', 'FI'),
];

Country countryByIso(String iso) =>
    kCountries.firstWhere((c) => c.iso == iso, orElse: () => kCountries.first);
