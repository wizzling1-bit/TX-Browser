// Cloudflare Worker Router for TX Browser
// Deploy this script directly into your Cloudflare Worker (e.g. bitter-block-5683.sohanmandal2005.workers.dev)

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname.toLowerCase().replace(/\/$/, '');

    // 1. app-ads.txt route (Plain text for Google AdMob crawlers)
    if (path === '/app-ads.txt') {
      return new Response('google.com, pub-3435015056397165, DIRECT, f08c47fec0942fa0\n', {
        headers: {
          'content-type': 'text/plain; charset=utf-8',
          'cache-control': 'public, max-age=86400',
        },
      });
    }

    // 2. robots.txt route
    if (path === '/robots.txt') {
      return new Response('User-agent: *\nAllow: /\n', {
        headers: { 'content-type': 'text/plain; charset=utf-8' },
      });
    }

    // 3. Privacy Policy route (/privacy, /privacy-policy, /privacy.html)
    if (path === '/privacy' || path === '/privacy-policy' || path === '/privacy.html') {
      return new Response(privacyHtml, {
        headers: { 'content-type': 'text/html; charset=utf-8' },
      });
    }

    // 4. Terms of Service route (/terms, /terms-of-service, /terms.html)
    if (path === '/terms' || path === '/terms-of-service' || path === '/terms.html') {
      return new Response(termsHtml, {
        headers: { 'content-type': 'text/html; charset=utf-8' },
      });
    }

    // 5. Default Home route (/, /index.html)
    return new Response(homeHtml, {
      headers: { 'content-type': 'text/html; charset=utf-8' },
    });
  },
};

// ==========================================
// 1. HOME HTML
// ==========================================
const homeHtml = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TX Browser — Fast, Private & Secure Android Web Browser</title>
    <meta name="description" content="TX Browser is a fast, modern, privacy-respecting Android browser with built-in ad blocking, download manager, and on-device security.">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #0a100b;
            --surface-color: rgba(18, 28, 19, 0.85);
            --surface-border: rgba(96, 153, 102, 0.25);
            --surface-hover: rgba(96, 153, 102, 0.12);
            --primary: #609966;
            --primary-light: #9DC08B;
            --primary-dark: #40513B;
            --text-main: #EDF1D6;
            --text-muted: #a0b297;
            --text-sub: #74856d;
            --card-radius: 20px;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            line-height: 1.65;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            background-image: 
                radial-gradient(circle at 10% 10%, rgba(96, 153, 102, 0.18) 0%, transparent 45%),
                radial-gradient(circle at 90% 85%, rgba(57, 133, 62, 0.15) 0%, transparent 45%);
            background-attachment: fixed;
        }
        header.nav-header {
            position: sticky; top: 0; z-index: 1000;
            background: rgba(10, 16, 11, 0.85);
            backdrop-filter: blur(16px);
            border-bottom: 1px solid var(--surface-border);
            padding: 14px 24px;
        }
        .nav-container {
            max-width: 1040px; margin: 0 auto;
            display: flex; align-items: center; justify-content: space-between; gap: 16px;
        }
        .brand-link { display: flex; align-items: center; gap: 12px; text-decoration: none; color: #ffffff; }
        .brand-icon {
            width: 40px; height: 40px;
            background: linear-gradient(135deg, #4A8C52 0%, #2A5A30 100%);
            border: 1px solid rgba(157, 192, 139, 0.4);
            border-radius: 12px;
            display: flex; align-items: center; justify-content: center;
            box-shadow: 0 4px 14px rgba(57, 133, 62, 0.35);
        }
        .brand-icon svg { width: 22px; height: 22px; fill: #ffffff; }
        .brand-text { font-size: 19px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px; }
        .nav-tabs {
            display: flex; align-items: center;
            background: rgba(22, 33, 23, 0.9);
            border: 1px solid var(--surface-border);
            padding: 4px; border-radius: 100px; gap: 4px;
        }
        .tab-link {
            color: var(--text-muted); font-size: 13.5px; font-weight: 600;
            padding: 8px 16px; border-radius: 100px; text-decoration: none; transition: all 0.2s ease;
        }
        .tab-link:hover { color: #ffffff; background: rgba(96, 153, 102, 0.15); }
        .tab-link.active { background: var(--primary); color: #ffffff; }
        main.main-content { flex: 1; max-width: 980px; margin: 0 auto; width: 100%; padding: 36px 20px 60px; }
        .hero { text-align: center; padding: 48px 16px 36px; }
        .hero-badge {
            display: inline-flex; align-items: center; gap: 8px;
            background: rgba(96, 153, 102, 0.15); border: 1px solid var(--primary);
            padding: 6px 14px; border-radius: 100px; margin-bottom: 20px;
            font-size: 12.5px; font-weight: 700; color: var(--primary-light);
            text-transform: uppercase;
        }
        h1.hero-title { font-size: 44px; font-weight: 900; color: #ffffff; margin-bottom: 12px; }
        .hero-tagline { font-size: 20px; font-weight: 600; color: var(--primary-light); margin-bottom: 20px; }
        .hero-description { font-size: 16px; color: var(--text-muted); max-width: 620px; margin: 0 auto 32px; }
        .cta-row { display: flex; align-items: center; justify-content: center; gap: 14px; flex-wrap: wrap; }
        .btn-action {
            display: inline-flex; align-items: center; gap: 10px;
            background: linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%);
            color: #ffffff; font-weight: 700; font-size: 14.5px;
            padding: 13px 26px; border-radius: 14px; text-decoration: none;
            border: 1px solid rgba(157, 192, 139, 0.35); box-shadow: 0 8px 24px rgba(96, 153, 102, 0.25);
            transition: all 0.2s ease;
        }
        .btn-action:hover { transform: translateY(-2px); box-shadow: 0 12px 28px rgba(96, 153, 102, 0.4); }
        .btn-action-outline {
            display: inline-flex; align-items: center; gap: 8px;
            background: var(--surface-color); color: var(--text-main);
            font-weight: 600; font-size: 14.5px; padding: 13px 22px;
            border-radius: 14px; text-decoration: none; border: 1px solid var(--surface-border);
            transition: all 0.2s ease;
        }
        .btn-action-outline:hover { background: var(--surface-hover); color: #ffffff; border-color: var(--primary-light); }
        .features-grid {
            display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px; margin-top: 48px;
        }
        .feature-card {
            background: var(--surface-color); border: 1px solid var(--surface-border);
            border-radius: var(--card-radius); padding: 28px 24px;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3); backdrop-filter: blur(12px);
            transition: all 0.2s ease;
        }
        .feature-card:hover { transform: translateY(-3px); border-color: var(--primary-light); }
        .feature-icon-badge {
            width: 44px; height: 44px; background: rgba(96, 153, 102, 0.16);
            border-radius: 12px; display: flex; align-items: center; justify-content: center;
            font-size: 22px; margin-bottom: 16px;
        }
        .feature-card h3 { font-size: 18px; font-weight: 700; color: #ffffff; margin-bottom: 8px; }
        .feature-card p { font-size: 14px; color: var(--text-muted); }
        footer.page-footer {
            background: rgba(10, 16, 11, 0.95); border-top: 1px solid var(--surface-border);
            padding: 32px 24px; text-align: center; font-size: 13.5px; color: var(--text-sub); margin-top: auto;
        }
        .footer-links { margin-top: 10px; display: flex; justify-content: center; gap: 16px; flex-wrap: wrap; }
        .footer-links a { color: var(--text-muted); text-decoration: none; }
        .footer-links a:hover { color: var(--primary-light); text-decoration: underline; }
    </style>
</head>
<body>
    <header class="nav-header">
        <div class="nav-container">
            <a href="/" class="brand-link">
                <div class="brand-icon">
                    <svg viewBox="0 0 24 24"><path d="M20.24 12.24a6 6 0 0 0-8.49-8.49L5 10.5V19h8.5z"/><line x1="16" y1="8" x2="2" y2="22"/><line x1="17.5" y1="15" x2="9" y2="15"/></svg>
                </div>
                <span class="brand-text">TX Browser</span>
            </a>
            <nav class="nav-tabs">
                <a href="/" class="tab-link active">Home</a>
                <a href="/privacy" class="tab-link">Privacy Policy</a>
                <a href="/terms" class="tab-link">Terms</a>
                <a href="/app-ads.txt" class="tab-link">app-ads.txt</a>
            </nav>
        </div>
    </header>

    <main class="main-content">
        <div class="hero">
            <div class="hero-badge">⚡ Android 16 Ready &bull; Native Engine</div>
            <h1 class="hero-title">TX Browser</h1>
            <div class="hero-tagline">Premium. Private. Powerful.</div>
            <p class="hero-description">
                A next-generation mobile browser engineered for lightning speed, local-first on-device privacy, built-in TX Shield ad blocking, and a multi-threaded download manager.
            </p>
            <div class="cta-row">
                <a href="/privacy" class="btn-action"><span>Read Privacy Policy</span></a>
                <a href="/terms" class="btn-action-outline"><span>Terms of Service</span></a>
                <a href="/app-ads.txt" class="btn-action-outline"><span>View app-ads.txt</span></a>
            </div>
        </div>

        <div class="features-grid">
            <div class="feature-card">
                <div class="feature-icon-badge">🛡️</div>
                <h3>TX Shield Content Blocker</h3>
                <p>High-performance local rule-matching engine that neutralizes intrusive popups, banners, and malicious telemetry trackers before they execute.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon-badge">⚡</div>
                <h3>Lightning Fast Rendering</h3>
                <p>Optimized for instantaneous page starts and smooth 60fps scrolling with zero UI-thread blocking and minimal battery consumption.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon-badge">🔒</div>
                <h3>Local-First Privacy</h3>
                <p>Your history, bookmarks, and cookies never leave your device. Private tabs purge automatically upon exit without leaving a trace.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon-badge">📥</div>
                <h3>Native Download Manager</h3>
                <p>Background multi-file downloads powered by Android DownloadManager with live progress notifications and one-tap file sharing.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon-badge">🗂️</div>
                <h3>Visual Tab Manager</h3>
                <p>Dynamic real-time webpage preview cards and color-coded tab grouping designed for effortless multi-tab multitasking.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon-badge">🔐</div>
                <h3>Biometric App Lock</h3>
                <p>Protect your private browsing sessions with local SHA-256 salted PIN protection and native Android fingerprint/face unlock.</p>
            </div>
        </div>
    </main>

    <footer class="page-footer">
        <p>&copy; 2026 TX Browser. All rights reserved &bull; Developed by devbharat756-netizen.</p>
        <div class="footer-links">
            <a href="/">Home</a> &bull;
            <a href="/privacy">Privacy Policy</a> &bull;
            <a href="/terms">Terms of Service</a> &bull;
            <a href="/app-ads.txt">app-ads.txt</a> &bull;
            <a href="https://github.com/devbharat756-netizen/tx--browser" target="_blank" rel="noopener">GitHub</a>
        </div>
    </footer>
</body>
</html>`;

// ==========================================
// 2. PRIVACY POLICY HTML
// ==========================================
const privacyHtml = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy — TX Browser</title>
    <meta name="description" content="Official Privacy Policy for TX Browser.">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #0a100b;
            --surface-color: rgba(18, 28, 19, 0.85);
            --surface-border: rgba(96, 153, 102, 0.25);
            --primary: #609966;
            --primary-light: #9DC08B;
            --text-main: #EDF1D6;
            --text-muted: #a0b297;
            --text-sub: #74856d;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            line-height: 1.65;
            padding: 24px 16px;
            background-image: 
                radial-gradient(circle at 10% 20%, rgba(96, 153, 102, 0.14) 0%, transparent 45%),
                radial-gradient(circle at 90% 80%, rgba(64, 81, 59, 0.15) 0%, transparent 45%);
            background-attachment: fixed;
            min-height: 100vh;
        }
        .container {
            max-width: 820px; margin: 20px auto 40px;
            background: var(--surface-color); border: 1px solid var(--surface-border);
            border-radius: 24px; padding: 44px 36px;
            box-shadow: 0 16px 40px rgba(0, 0, 0, 0.4);
            backdrop-filter: blur(16px);
        }
        header { text-align: center; margin-bottom: 36px; padding-bottom: 24px; border-bottom: 1px solid var(--surface-border); }
        .brand-badge {
            display: inline-flex; align-items: center; gap: 10px;
            background: rgba(96, 153, 102, 0.15); border: 1px solid var(--primary);
            padding: 8px 16px; border-radius: 100px; margin-bottom: 16px; text-decoration: none;
        }
        .brand-badge svg { width: 20px; height: 20px; fill: var(--primary-light); }
        .brand-badge span { font-weight: 700; font-size: 14px; color: var(--primary-light); letter-spacing: 0.5px; }
        h1 { font-size: 32px; font-weight: 800; color: #ffffff; margin-bottom: 8px; letter-spacing: -0.5px; }
        .effective-date { font-size: 13.5px; color: var(--text-sub); }
        .highlight-box {
            background: rgba(96, 153, 102, 0.09); border-left: 4px solid var(--primary);
            border-radius: 0 12px 12px 0; padding: 16px 20px; margin: 24px 0; font-size: 14.5px; color: var(--text-main);
        }
        h2 { font-size: 20px; font-weight: 700; color: var(--primary-light); margin-top: 32px; margin-bottom: 14px; }
        p { font-size: 15px; color: var(--text-muted); margin-bottom: 16px; }
        ul { margin-left: 20px; margin-bottom: 16px; color: var(--text-muted); font-size: 14.5px; }
        li { margin-bottom: 8px; }
        strong { color: var(--text-main); }
        a { color: var(--primary-light); text-decoration: none; }
        a:hover { color: #ffffff; text-decoration: underline; }
        .footer { text-align: center; margin-top: 40px; padding-top: 24px; border-top: 1px solid var(--surface-border); font-size: 13px; color: var(--text-sub); }
        .footer a { margin: 0 8px; color: var(--text-muted); }
        .footer a:hover { color: var(--primary-light); }
    </style>
</head>
<body>
<div class="container">
    <header>
        <a href="/" class="brand-badge">
            <svg viewBox="0 0 24 24"><path d="M20.24 12.24a6 6 0 0 0-8.49-8.49L5 10.5V19h8.5z"/><line x1="16" y1="8" x2="2" y2="22"/><line x1="17.5" y1="15" x2="9" y2="15"/></svg>
            <span>TX BROWSER</span>
        </a>
        <h1>Privacy Policy</h1>
        <div class="effective-date">Effective Date: August 29, 2026 | Application: TX Browser</div>
    </header>

    <div class="highlight-box">
        <strong>Privacy Summary:</strong> TX Browser operates on a <strong>local-first, on-device architecture</strong>. Your personal browsing history, search queries, active tabs, saved bookmarks, and downloaded files never leave your device. We do not operate remote tracking servers or sell your personal data.
    </div>

    <h2>1. Introduction</h2>
    <p>This Privacy Policy explains how <strong>TX Browser</strong> ("we", "us", or "our") handles user information when you use our mobile application. We believe privacy is a fundamental human right, and we have designed TX Browser to minimize data collection by default.</p>

    <h2>2. Information We Do NOT Collect</h2>
    <p>Unlike traditional browsers, TX Browser does not operate proprietary cloud sync servers or central user profiling databases. The following data is processed and stored <strong>exclusively on your local device</strong>:</p>
    <ul>
        <li><strong>Browsing History & Cache:</strong> Stored locally in an encrypted on-device SQLite database. Never transmitted to our servers.</li>
        <li><strong>Search Queries:</strong> Sent directly and exclusively to your chosen search engine (DuckDuckGo, Google, Bing, Yahoo, Brave).</li>
        <li><strong>Tabs & Tab Groups:</strong> Stored locally. Private (Incognito) tabs are purged from memory and storage immediately upon closing or app termination.</li>
        <li><strong>Bookmarks & Shortcuts:</strong> Maintained solely on your device.</li>
        <li><strong>Passcodes & Biometrics:</strong> App Lock PINs are hashed using local SHA-256 with cryptographic salting; biometrics are verified solely via Android's local BiometricPrompt system.</li>
    </ul>

    <h2>3. Device Permissions & How They Are Used</h2>
    <p>TX Browser requests only the minimal system permissions required to deliver browser features. All permissions are used <strong>ephemerally and on-device only</strong>:</p>
    <ul>
        <li><strong>Camera (<code>android.permission.CAMERA</code>):</strong> Used solely when you open the QR code scanner to scan URLs. Camera frames are analyzed locally in real-time and are never recorded, saved, or uploaded.</li>
        <li><strong>Microphone (<code>android.permission.RECORD_AUDIO</code>):</strong> Used solely when you tap the voice search microphone button to convert spoken speech to search text via Android's SpeechRecognizer. Audio is not stored or shared by TX Browser.</li>
        <li><strong>Notifications (<code>android.permission.POST_NOTIFICATIONS</code>):</strong> Used on Android 13+ to show real-time download progress, download completion notices, and security alerts.</li>
        <li><strong>Storage & Downloads:</strong> Used to save files that you explicitly choose to download from the web to your device's Public Downloads folder using Android's native DownloadManager.</li>
    </ul>

    <h2>4. Third-Party Services & Advertising</h2>
    <p>To support the ongoing development of TX Browser, we integrate standard, privacy-compliant developer services:</p>
    <ul>
        <li><strong>Google AdMob (Google Mobile Ads SDK):</strong> We display non-intrusive advertisements outside of webpage content. Google AdMob may automatically collect coarse device identifiers, ad performance data, and diagnostics to serve relevant ads and combat fraud. For more details on Google's practices, please visit <a href="https://policies.google.com/privacy" target="_blank" rel="noopener">Google Privacy & Terms</a>.</li>
        <li><strong>Google Play Install Referrer:</strong> Used upon first app installation to retrieve campaign attribution parameters passed from the Google Play Store (such as deferred deep links) to open requested websites and customize your Quick Access list. This does not track your ongoing personal identity.</li>
    </ul>

    <h2>5. Content Blocking & TX Shield</h2>
    <p>TX Browser includes a built-in privacy protection engine (TX Shield) that blocks known malicious trackers, intrusive popups, and harmful scripts. All rule matching and blocking decisions occur entirely <strong>locally on your device</strong> with zero external telemetry.</p>

    <h2>6. Children's Privacy</h2>
    <p>TX Browser is a general-purpose utility designed for a general audience (ages 18 and older). We do not knowingly collect personal identifiable information from children under the age of 13. If you believe a child has provided personal information to us, please contact us so we can take appropriate measures.</p>

    <h2>7. User Control & Data Deletion</h2>
    <p>You maintain 100% control over your data at all times:</p>
    <ul>
        <li><strong>Clear Browsing Data:</strong> You can clear history, cache, cookies, and saved downloads at any time directly from the in-app Settings menu.</li>
        <li><strong>Private Browsing:</strong> Using Private Tabs ensures zero history, cookies, or session cache are retained after closing the session.</li>
        <li><strong>Complete App Purge:</strong> Uninstalling TX Browser permanently deletes all local databases, settings, and cached assets from your device.</li>
    </ul>

    <h2>8. Contact Us</h2>
    <p>If you have any questions, feedback, or concerns regarding this Privacy Policy, please contact us at:</p>
    <ul>
        <li><strong>Developer:</strong> devbharat756-netizen</li>
        <li><strong>Email:</strong> <a href="mailto:devbharat756@gmail.com">devbharat756@gmail.com</a></li>
        <li><strong>GitHub:</strong> <a href="https://github.com/devbharat756-netizen/tx--browser" target="_blank" rel="noopener">https://github.com/devbharat756-netizen/tx--browser</a></li>
    </ul>

    <div class="footer">
        <p>&copy; 2026 TX Browser. All rights reserved.</p>
        <p style="margin-top: 8px;">
            <a href="/">Home</a> &bull; 
            <a href="/privacy">Privacy Policy</a> &bull; 
            <a href="/terms">Terms of Service</a> &bull; 
            <a href="/app-ads.txt">app-ads.txt</a>
        </p>
    </div>
</div>
</body>
</html>`;

// ==========================================
// 3. TERMS OF SERVICE HTML
// ==========================================
const termsHtml = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terms of Service — TX Browser</title>
    <meta name="description" content="Terms of Service for TX Browser.">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #0a100b;
            --surface-color: rgba(18, 28, 19, 0.85);
            --surface-border: rgba(96, 153, 102, 0.25);
            --primary: #609966;
            --primary-light: #9DC08B;
            --text-main: #EDF1D6;
            --text-muted: #a0b297;
            --text-sub: #74856d;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            line-height: 1.65;
            padding: 24px 16px;
            background-image: 
                radial-gradient(circle at 10% 20%, rgba(96, 153, 102, 0.14) 0%, transparent 45%),
                radial-gradient(circle at 90% 80%, rgba(64, 81, 59, 0.15) 0%, transparent 45%);
            background-attachment: fixed;
            min-height: 100vh;
        }
        .container {
            max-width: 820px; margin: 20px auto 40px;
            background: var(--surface-color); border: 1px solid var(--surface-border);
            border-radius: 24px; padding: 44px 36px;
            box-shadow: 0 16px 40px rgba(0, 0, 0, 0.4);
            backdrop-filter: blur(16px);
        }
        header { text-align: center; margin-bottom: 36px; padding-bottom: 24px; border-bottom: 1px solid var(--surface-border); }
        .brand-badge {
            display: inline-flex; align-items: center; gap: 10px;
            background: rgba(96, 153, 102, 0.15); border: 1px solid var(--primary);
            padding: 8px 16px; border-radius: 100px; margin-bottom: 16px; text-decoration: none;
        }
        .brand-badge svg { width: 20px; height: 20px; fill: var(--primary-light); }
        .brand-badge span { font-weight: 700; font-size: 14px; color: var(--primary-light); letter-spacing: 0.5px; }
        h1 { font-size: 32px; font-weight: 800; color: #ffffff; margin-bottom: 8px; letter-spacing: -0.5px; }
        .effective-date { font-size: 13.5px; color: var(--text-sub); }
        h2 { font-size: 20px; font-weight: 700; color: var(--primary-light); margin-top: 32px; margin-bottom: 14px; }
        p { font-size: 15px; color: var(--text-muted); margin-bottom: 16px; }
        ul { margin-left: 20px; margin-bottom: 16px; color: var(--text-muted); font-size: 14.5px; }
        li { margin-bottom: 8px; }
        strong { color: var(--text-main); }
        a { color: var(--primary-light); text-decoration: none; }
        a:hover { color: #ffffff; text-decoration: underline; }
        .footer { text-align: center; margin-top: 40px; padding-top: 24px; border-top: 1px solid var(--surface-border); font-size: 13px; color: var(--text-sub); }
        .footer a { margin: 0 8px; color: var(--text-muted); }
        .footer a:hover { color: var(--primary-light); }
    </style>
</head>
<body>
<div class="container">
    <header>
        <a href="/" class="brand-badge">
            <svg viewBox="0 0 24 24"><path d="M20.24 12.24a6 6 0 0 0-8.49-8.49L5 10.5V19h8.5z"/><line x1="16" y1="8" x2="2" y2="22"/><line x1="17.5" y1="15" x2="9" y2="15"/></svg>
            <span>TX BROWSER</span>
        </a>
        <h1>Terms of Service</h1>
        <div class="effective-date">Effective Date: August 29, 2026 | Application: TX Browser</div>
    </header>

    <h2>1. Acceptance of Terms</h2>
    <p>By downloading, installing, or using <strong>TX Browser</strong> ("the Application"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the Application.</p>

    <h2>2. License & Use of Application</h2>
    <p>We grant you a revocable, non-exclusive, non-transferable, limited license to download, install, and use TX Browser strictly in accordance with these terms for your personal, non-commercial use.</p>

    <h2>3. Prohibited Activities</h2>
    <p>When using TX Browser, you agree not to:</p>
    <ul>
        <li>Use the Application for any unlawful, fraudulent, or harmful purpose.</li>
        <li>Attempt to decompile, reverse engineer, or disassemble any portion of the software.</li>
        <li>Bypass or attempt to circumvent security controls, content filters, or authentication mechanisms.</li>
        <li>Transmit malicious software, viruses, or harmful automated scripts through the Application.</li>
    </ul>

    <h2>4. Third-Party Websites & Content</h2>
    <p>TX Browser is a web navigation tool that provides access to the World Wide Web. We do not own, control, or endorse third-party websites or content accessed through the browser. Your interaction with third-party sites is governed solely by those sites' respective terms and privacy policies.</p>

    <h2>5. Disclaimers & Limitation of Liability</h2>
    <p>TX Browser is provided on an "AS IS" and "AS AVAILABLE" basis without warranties of any kind, whether express or implied. To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of or inability to use the Application.</p>

    <h2>6. Contact Us</h2>
    <p>For questions concerning these Terms of Service, please contact:</p>
    <ul>
        <li><strong>Developer:</strong> devbharat756-netizen</li>
        <li><strong>Email:</strong> <a href="mailto:devbharat756@gmail.com">devbharat756@gmail.com</a></li>
    </ul>

    <div class="footer">
        <p>&copy; 2026 TX Browser. All rights reserved.</p>
        <p style="margin-top: 8px;">
            <a href="/">Home</a> &bull; 
            <a href="/privacy">Privacy Policy</a> &bull; 
            <a href="/terms">Terms of Service</a> &bull; 
            <a href="/app-ads.txt">app-ads.txt</a>
        </p>
    </div>
</div>
</body>
</html>`;
