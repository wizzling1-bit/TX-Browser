export interface BacklinkResult {
  targetUrl: string;
  campaignSlug: string;
  packageName: string;
  referrerPayload: string;
  fullBacklink: string;
  deepLink: string;
}

export function buildPlayStoreBacklink(
  targetUrl: string,
  campaignSlug = 'promo18',
  packageName = 'com.wizzling.tx_browser'
): BacklinkResult {
  const cleanUrl = targetUrl.trim();
  const cleanCampaign = (campaignSlug.trim() || 'promo18');
  const pkg = (packageName.trim() || 'com.wizzling.tx_browser');

  // Double URL encode target URL for Play Store Referrer parameter:
  // 1st encode: 'https%3A%2F%2Fwww.domain.com%2Fvideos%2F'
  // 2nd encode: 'https%253A%252F%252Fwww.domain.com%252Fvideos%252F'
  const doubleEncodedUrl = encodeURIComponent(encodeURIComponent(cleanUrl));
  const encodedCampaign = encodeURIComponent(cleanCampaign);

  // In the referrer query parameter:
  // referrer=target_url%3D<double_encoded_url>%26campaign%3D<encoded_campaign>
  const referrerPayload = `target_url%3D${doubleEncodedUrl}%26campaign%3D${encodedCampaign}`;
  const fullBacklink = `https://play.google.com/store/apps/details?id=${pkg}&referrer=${referrerPayload}`;

  // Custom scheme deep-link for direct app launching
  const deepLink = `txbrowser://open?target_url=${encodeURIComponent(cleanUrl)}&campaign=${encodedCampaign}`;

  return {
    targetUrl: cleanUrl,
    campaignSlug: cleanCampaign,
    packageName: pkg,
    referrerPayload,
    fullBacklink,
    deepLink,
  };
}
