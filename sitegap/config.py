"""Static configuration: niches, areas (with approx lat/lng), pricing, tuning.

Coordinates are deliberately approximate — they seed a location *bias* circle,
not a hard filter. Google Places is asked to prefer results near the centre.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.environ.get("SITEGAP_DB", os.path.join(BASE_DIR, "leads.db"))
OUTPUT_DIR = os.path.join(BASE_DIR, "outputs")
PITCH_DIR = os.path.join(OUTPUT_DIR, "pitch")
MOCKUP_DIR = os.path.join(OUTPUT_DIR, "mockups")

# --------------------------------------------------------------------------- #
# Google Places API (New) v1
# --------------------------------------------------------------------------- #
PLACES_API_KEY = os.environ.get("GOOGLE_PLACES_API_KEY", "")
PLACES_SEARCH_URL = "https://places.googleapis.com/v1/places:searchText"

# The field mask decides the billing SKU. websiteUri is NOT in the cheapest
# tier — including it moves the request to the "Advanced" text-search SKU.
PLACES_FIELD_MASK = ",".join(
    [
        "nextPageToken",
        "places.id",
        "places.displayName",
        "places.formattedAddress",
        "places.rating",
        "places.userRatingCount",
        "places.websiteUri",
        "places.nationalPhoneNumber",
        "places.internationalPhoneNumber",
        "places.googleMapsUri",
        "places.primaryTypeDisplayName",
        "places.businessStatus",
        "places.location",
    ]
)

# Indicative cost per Text Search (Advanced) request, USD. Verify against live
# pricing before a big fan-out — this is only used to *estimate* run spend.
COST_PER_QUERY_USD = float(os.environ.get("SITEGAP_COST_PER_QUERY", "0.032"))
PAGE_SIZE = 20
MAX_PAGES_PER_QUERY = 3  # Text Search caps at ~60 results (3 x 20)

# --------------------------------------------------------------------------- #
# Qualification thresholds (applied before any audit — audits cost time)
# --------------------------------------------------------------------------- #
MIN_RATING = 4.0
MIN_REVIEWS = 20

# --------------------------------------------------------------------------- #
# Niches — key -> human search phrase fragment
# --------------------------------------------------------------------------- #
NICHES: dict[str, str] = {
    "accounting": "accounting and audit VAT business setup",
    "real_estate": "real estate brokerage",
    "property_mgmt": "property management holiday homes",
    "car_wash": "car wash and detailing",
    "garage": "car garage and tyre shop",
    "laundry_pickup": "laundry pickup and delivery",
    "movers": "movers and packers",
    "courier": "courier and delivery service",
    "dental": "dental clinic",
    "physio": "physiotherapy clinic",
    "derma": "dermatology skin clinic",
    "vet": "veterinary clinic",
    "salon": "beauty salon and spa",
    "barber": "barber shop",
    "gym": "gym and fitness studio",
    "nursery": "nursery and daycare",
    "tuition": "tuition and tutoring centre",
    "driving_school": "driving school",
    "fitout": "fit-out and joinery",
    "ac_maintenance": "AC maintenance and repair",
    "pest_control": "pest control",
    "cleaning": "deep cleaning service",
    "printing": "printing and typing centre",
    "tailoring": "tailoring and alterations",
    "pet_grooming": "pet grooming",
    "catering": "catering service",
}

# High-lifetime-value niches — push toward Premium regardless of review count.
HIGH_LTV_NICHES = {"real_estate", "accounting", "dental", "derma", "physio", "vet"}

# Booking-driven niches — the online booking form is the ROI story, so these
# get bumped to a Growth package minimum.
BOOKING_NICHES = {
    "car_wash",
    "laundry_pickup",
    "salon",
    "barber",
    "dental",
    "physio",
    "derma",
    "vet",
    "driving_school",
    "gym",
}


# --------------------------------------------------------------------------- #
# Areas — approx centre lat/lng and bias radius (metres)
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class Area:
    key: str
    label: str
    region_code: str  # ISO 3166-1 for the Places `regionCode`
    lat: float
    lng: float
    radius_m: int = 5000


AREAS: dict[str, Area] = {
    # --- Dubai, UAE (region AE) ------------------------------------------- #
    "business_bay": Area("business_bay", "Business Bay", "AE", 25.1857, 55.2610),
    "al_quoz": Area("al_quoz", "Al Quoz", "AE", 25.1470, 55.2330, 6000),
    "deira": Area("deira", "Deira", "AE", 25.2710, 55.3120),
    "bur_dubai": Area("bur_dubai", "Bur Dubai", "AE", 25.2530, 55.2960),
    "karama": Area("karama", "Karama", "AE", 25.2440, 55.3040, 4000),
    "jlt": Area("jlt", "JLT", "AE", 25.0693, 55.1440),
    "marina": Area("marina", "Dubai Marina", "AE", 25.0805, 55.1403),
    "jvc": Area("jvc", "JVC", "AE", 25.0590, 55.2090, 6000),
    "al_barsha": Area("al_barsha", "Al Barsha", "AE", 25.1120, 55.2000),
    "dip": Area("dip", "DIP", "AE", 24.9950, 55.1750, 6000),
    "ras_al_khor": Area("ras_al_khor", "Ras Al Khor", "AE", 25.1810, 55.3560, 6000),
    "difc": Area("difc", "DIFC", "AE", 25.2100, 55.2810, 4000),
    "downtown": Area("downtown", "Downtown Dubai", "AE", 25.1972, 55.2744, 4000),
    "silicon_oasis": Area("silicon_oasis", "Silicon Oasis", "AE", 25.1210, 55.3780),
    "mirdif": Area("mirdif", "Mirdif", "AE", 25.2170, 55.4200),
    "al_nahda": Area("al_nahda", "Al Nahda", "AE", 25.2960, 55.3730, 4000),
    "al_qusais": Area("al_qusais", "Al Qusais", "AE", 25.2830, 55.3910),
    "motor_city": Area("motor_city", "Motor City", "AE", 25.0450, 55.2380),
    "arjan": Area("arjan", "Arjan", "AE", 25.0700, 55.2380, 4000),
    "jumeirah": Area("jumeirah", "Jumeirah", "AE", 25.2110, 55.2500),
    "media_city": Area("media_city", "Media City", "AE", 25.0950, 55.1560, 4000),
    "internet_city": Area("internet_city", "Internet City", "AE", 25.0980, 55.1660, 4000),
    "muhaisnah": Area("muhaisnah", "Muhaisnah", "AE", 25.2870, 55.4110),
    # --- United States (region US) ---------------------------------------- #
    "us_austin": Area("us_austin", "Austin, TX", "US", 30.2672, -97.7431, 6000),
    "us_denver": Area("us_denver", "Denver, CO", "US", 39.7392, -104.9903, 6000),
    "us_miami": Area("us_miami", "Miami, FL", "US", 25.7617, -80.1918, 6000),
    # --- United Kingdom (region GB) --------------------------------------- #
    "uk_manchester": Area("uk_manchester", "Manchester", "GB", 53.4808, -2.2426, 6000),
    "uk_birmingham": Area("uk_birmingham", "Birmingham", "GB", 52.4862, -1.8904, 6000),
    "uk_leeds": Area("uk_leeds", "Leeds", "GB", 53.8008, -1.5491, 6000),
    # --- Australia (region AU) -------------------------------------------- #
    "au_sydney": Area("au_sydney", "Sydney", "AU", -33.8688, 151.2093, 6000),
    "au_melbourne": Area("au_melbourne", "Melbourne", "AU", -37.8136, 144.9631, 6000),
    "au_brisbane": Area("au_brisbane", "Brisbane", "AU", -27.4698, 153.0251, 6000),
}

# Grouped for the `--areas` CLI flag.
AREA_GROUPS: dict[str, list[str]] = {
    "dubai": [k for k, a in AREAS.items() if a.region_code == "AE"],
    "uae": [k for k, a in AREAS.items() if a.region_code == "AE"],
    "us": [k for k, a in AREAS.items() if a.region_code == "US"],
    "uk": [k for k, a in AREAS.items() if a.region_code == "GB"],
    "au": [k for k, a in AREAS.items() if a.region_code == "AU"],
    "all": list(AREAS.keys()),
}


# --------------------------------------------------------------------------- #
# Quotation packages — indicative AED
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class Package:
    key: str
    name: str
    price_low: int
    price_high: int
    scope: list[str] = field(default_factory=list)


PACKAGES: dict[str, Package] = {
    "starter": Package(
        "starter",
        "Starter",
        2500,
        4000,
        [
            "5 pages, mobile-first design",
            "WhatsApp + call CTA on every page",
            "Google Business Profile sync",
            "Basic on-page SEO",
        ],
    ),
    "growth": Package(
        "growth",
        "Growth",
        6000,
        9000,
        [
            "10–12 pages incl. dedicated service pages",
            "Online booking / enquiry form",
            "Local SEO + Google Analytics",
            "1 month post-launch support",
        ],
    ),
    "premium": Package(
        "premium",
        "Premium",
        12000,
        20000,
        [
            "Fully custom design",
            "Online booking + payments",
            "Bilingual EN / AR",
            "CRM hookup + 3 months support",
        ],
    ),
    "care": Package(
        "care",
        "Care Plan",
        300,
        800,
        [
            "Managed hosting + SSL",
            "Content updates & backups",
            "Monthly performance report",
        ],
    ),
}

# Care-plan add-on offered alongside build packages (monthly AED).
CARE_ADDON = PACKAGES["care"]

# --------------------------------------------------------------------------- #
# Scoring / tiering
# --------------------------------------------------------------------------- #
TIER_A_MIN = 75  # businesses you'd call today
TIER_B_MIN = 55

# Compliance opt-out line appended to every outreach template (TDRA etc.).
OPT_OUT_LINE = "Reply STOP to opt out. We only reach out once."
