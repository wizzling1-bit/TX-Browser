# Tx Browser — Security & Privacy Document

## 1. Security Objectives

Tx Browser should provide a strong baseline of application security without claiming to provide anonymity or complete protection against malicious websites.

Primary objectives:
- Minimize data collection.
- Keep browsing metadata local by default.
- Prevent private sessions from entering persistent browser history.
- Limit the attack surface of WebView and native bridges.
- Protect sensitive settings and authentication operations.
- Keep ads isolated from browser-control logic.

## 2. Privacy Principles

### Local-first
No account or backend is required for normal browsing.

### Data minimization
Only persist the data required to provide requested browser features.

### Explicit state
Privacy-sensitive settings must show their current state clearly.

### No false security claims
A proxy is not a VPN. A private tab does not automatically provide anonymity. A WebView browser is not equivalent to a hardened security browser.

## 3. Data Classification

| Data | Classification | Storage |
|---|---|---|
| Theme preference | Low sensitivity | SQLite/preferences |
| Shortcut URL | Low sensitivity | SQLite |
| Browser history | Sensitive | SQLite |
| Search history | Sensitive | SQLite |
| Download metadata | Sensitive | SQLite |
| App-lock state/config | High sensitivity | Secure storage where required |
| Authentication result | Highly sensitive | Never persist raw biometric data |
| Network credentials/config | High sensitivity | Secure storage when required |

## 4. Threat Model

### Threats in MVP scope
- Malicious webpage scripts.
- Malicious external links/intents.
- Unsafe downloads.
- Local device access to browser metadata.
- Incorrect private-mode persistence.
- Misuse of platform channels.
- WebView navigation to untrusted schemes.
- Accidental exposure through screenshots/recents.
- Ad SDK misuse or accidental browser-UI spoofing.

### Out of scope / not guaranteed
- Nation-state adversaries.
- Full endpoint compromise.
- OS-level malware with unrestricted privileges.
- Perfect anonymity.
- Protection against a compromised Android system.

## 5. WebView Security

### Baseline rules
- Keep WebView debugging disabled in release.
- Avoid allowing arbitrary native JavaScript bridges.
- Expose only narrowly scoped native functionality.
- Validate URL schemes before handing links to external Android intents.
- Prefer HTTPS for app-generated destinations.
- Do not silently downgrade secure navigation.
- Avoid enabling unnecessary file/content access.
- Review WebView settings when changing them.

### JavaScript bridge rule
If JavaScript-to-native communication is needed, expose a minimal command interface. Never expose generic reflection or arbitrary method execution.

## 6. Navigation Policy

Allowed browser destinations include ordinary web URLs such as:
- `https://`
- `http://`

Potentially external schemes such as `mailto:`, `tel:`, `intent:`, custom app schemes, and file-related links must be routed through an allowlist and Android intent policy.

Unknown schemes should not automatically launch external applications.

## 7. Private Browsing

Private mode is an application-level privacy feature.

Required rules:
1. Do not write private visits to history.
2. Do not write private searches to search history.
3. Do not restore private tabs on next launch.
4. Do not display private visits in recently visited UI.
5. Clear/destroy private runtime state when the private tab is closed.
6. Do not mix private tab models with regular tab persistence.

The implementation should have an explicit `isPrivate` flag and enforce this at service/repository boundaries rather than relying only on UI behavior.

## 8. Cookies and Web Storage

Normal mode may use normal Android WebView storage and cookies subject to the selected browser configuration.

Private mode should use the strongest feasible isolation supported by the chosen WebView/plugin architecture. The design must document what is isolated and what is not.

Never promise “zero tracking” solely because private mode is enabled.

## 9. History Security

History records should contain only the fields needed by the product.

Recommended controls:
- Clear individual entry.
- Clear all history.
- Clear search history.
- Clear browsing data action should communicate affected categories.

Do not log full URLs in production diagnostic logs.

## 10. Logging

Never log:
- Full private URLs.
- Authentication secrets.
- Network credentials.
- Tokens.
- User-entered sensitive data.

Debug logs may include safe lifecycle states and feature identifiers. Release builds should disable verbose browser/network logs.

## 11. Secure Storage

Use Android Keystore-backed storage for secrets or cryptographic material.

Do not:
- Hard-code secrets in Dart source.
- Commit production ad/third-party credentials if they are actually secret.
- Store passwords as plain text.
- Store raw biometric data.

Ad unit IDs are identifiers, not secret credentials, but should still be environment/configuration values rather than scattered constants.

## 12. App Lock

App lock should use Android `BiometricPrompt` or an approved platform biometric abstraction.

Flow:

```text
App requires lock
 -> Show Tx Browser lock screen
 -> Request Android biometric authentication
 -> Success -> unlock
 -> Failure/cancel -> remain locked
```

The app must not implement its own biometric algorithm.

Recommended behavior:
- Lock on cold launch when enabled.
- Lock on resume based on a configurable timeout.
- Do not expose browser content behind the lock screen.

## 13. Screenshot/Recents Privacy

Where product requirements justify it, consider Android screenshot/recents protections for locked/private states. Any such behavior must be tested carefully because it changes the user's normal Android experience.

## 14. Downloads

Download URLs and file names must be treated as untrusted input.

Rules:
- Validate destination and filename.
- Prevent path traversal.
- Do not execute downloaded files automatically.
- Use Android file APIs/intents for opening files.
- Show file name, size, status, and source where practical.
- Handle failed or partial downloads safely.

## 15. External Intents

External launch must be explicit and constrained. A web page must not gain unrestricted ability to invoke native actions.

The browser should distinguish:
- Normal web navigation.
- User-initiated external app launch.
- Unsupported/blocked schemes.

## 16. Privacy Network Security

### True VPN
If `VpnService` is used, routing must be explicit and carefully controlled.

Questions that must be resolved during implementation:
- Does the tunnel route all device traffic or only browser traffic?
- Is traffic actually encrypted beyond the local tunnel?
- What remote endpoint is used?
- Are DNS requests routed through the tunnel?
- What happens when the service reconnects or fails?

The app must not market a tunnel as secure merely because a VPN interface exists.

### Proxy
A proxy only handles traffic routed through it. The UI must state its scope clearly.

## 17. AdMob Security and Privacy

- Keep AdMob logic isolated in `AdService`.
- Never place ad widgets over browser controls in a way that can cause accidental clicks.
- Use official test ad units during development.
- Follow Google's current consent/privacy requirements applicable to the distribution region.
- Do not inject ads into webpage content.

## 18. Secure Architecture Rules

1. UI cannot access platform channels directly.
2. UI cannot execute arbitrary Java/Kotlin commands.
3. Repository layer validates privacy mode before storing history/search data.
4. Private mode is enforced by code, not convention.
5. Production logs contain no sensitive URLs/data.
6. Network state is explicit and observable.
7. Any new native permission requires a documented reason.

## 19. Security Review Checklist

Before release:
- [ ] Release WebView debugging disabled.
- [ ] No sensitive debug logs.
- [ ] External schemes reviewed.
- [ ] Private history tests pass.
- [ ] Download path traversal tests pass.
- [ ] Native bridges expose only intended actions.
- [ ] App lock blocks browser content before authentication.
- [ ] Production AdMob IDs/configuration reviewed.
- [ ] Privacy disclosures match actual behavior.
- [ ] VPN/proxy claims match implementation.
- [ ] Android permissions minimized.
- [ ] Release build tested with network unavailable.
