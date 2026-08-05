<?php
/**
 * Central company information.
 * Editing this one file updates the whole website.
 */

$company = [
    'legal_name'   => 'LXEGLOBAL LLC',
    'brand_name'   => 'LXE Global',
    'tagline'      => 'Trading technology & financial consultancy',
    'intro'        => 'We design and build the technology that powers modern trading — analysis platforms, research systems, live market streaming and mobile applications — as a full-fledged financial consultancy.',

    // Registered business address (matches U.S. federal EIN registration)
    'address_line' => '1601-1 N Main St #3159, SMB #83116',
    'address_city' => 'Jacksonville, FL 32206',
    'address_meta' => 'Duval County, Florida, United States',

    // Contact
    'email'        => 'info@lxedxb.com',

    // Phone numbers. Set 'show' => false to hide a line on the site.
    'phones' => [
        [
            'label'   => 'Dubai, UAE',
            'display' => '+971 50 586 0280',
            'tel'     => '+971505860280',
            'show'    => true,
        ],
        [
            'label'   => 'India',
            'display' => '+91 60056 68240',
            'tel'     => '+916005668240',
            'show'    => true,
        ],
        [
            // IMPORTANT: The number you provided (+1 847724552) is only 9 digits
            // and is NOT a valid U.S. number (needs a 3-digit area code + 7 digits = 10).
            // Replace 'display' and 'tel' with the correct number, then set show=true.
            'label'   => 'United States',
            'display' => '+1 (___) ___-____',
            'tel'     => '',
            'show'    => false,
        ],
    ],

    'founded_year' => 2023,
    'copyright'    => 'LXEGLOBAL LLC',
];

/*
 * Optional overrides saved by the installer (data/site-config.json).
 * Lets you update the support email or the U.S. phone number without
 * editing this file. Anything set there wins over the defaults above.
 */
$override_file = __DIR__ . '/../data/site-config.json';
if (is_file($override_file)) {
    $ov = json_decode((string) file_get_contents($override_file), true);
    if (is_array($ov)) {
        if (!empty($ov['email'])) {
            $company['email'] = $ov['email'];
        }
        if (!empty($ov['us_phone_display']) && !empty($ov['us_phone_tel'])) {
            foreach ($company['phones'] as &$ph) {
                if ($ph['label'] === 'United States') {
                    $ph['display'] = $ov['us_phone_display'];
                    $ph['tel']     = $ov['us_phone_tel'];
                    $ph['show']    = true;
                }
            }
            unset($ph);
        }
    }
}

return $company;
