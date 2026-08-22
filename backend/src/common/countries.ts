/**
 * Minimal ISO-3166 alpha-2 → display-name lookup so the User entity can expose
 * both `residenceIso` and `residenceCountry` (contract §3 User) from a single
 * stored ISO code. Extend as onboarding country coverage grows.
 */
const COUNTRY_NAMES: Record<string, string> = {
  IN: 'India',
  AE: 'United Arab Emirates',
  US: 'United States',
  GB: 'United Kingdom',
  SG: 'Singapore',
  SA: 'Saudi Arabia',
  PK: 'Pakistan',
  BD: 'Bangladesh',
  NG: 'Nigeria',
  ZA: 'South Africa',
  AU: 'Australia',
  CA: 'Canada',
  DE: 'Germany',
  FR: 'France',
  ES: 'Spain',
  IT: 'Italy',
  MY: 'Malaysia',
  ID: 'Indonesia',
  PH: 'Philippines',
  EG: 'Egypt',
  KE: 'Kenya',
};

export function countryNameFromIso(iso?: string | null): string | null {
  if (!iso) return null;
  return COUNTRY_NAMES[iso.toUpperCase()] ?? iso.toUpperCase();
}
