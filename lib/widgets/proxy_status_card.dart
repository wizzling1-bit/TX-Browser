import 'package:flutter/material.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';

import '../core/theme/colors.dart';
import '../core/theme/shapes.dart';
import '../core/theme/spacing.dart';
import '../services/proxy_service/proxy_service.dart';
import 'buttons/tx_pressable.dart';

/// Commercial-grade Proxy Status Card with live status indicators.
class ProxyStatusCard extends StatelessWidget {
  const ProxyStatusCard({
    super.key,
    required this.isEnabled,
    required this.host,
    required this.port,
    required this.protocol,
    required this.isTesting,
    this.latencyMs,
    this.lastTestSuccess,
    required this.onTestConnection,
  });

  final bool isEnabled;
  final String host;
  final int port;
  final ProxyProtocol protocol;
  final bool isTesting;
  final int? latencyMs;
  final bool? lastTestSuccess;
  final VoidCallback onTestConnection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;
    final hasHost = host.isNotEmpty && port > 0;

    Color statusColor;
    String statusText;

    if (!isEnabled) {
      statusColor = colors.textTertiary;
      statusText = 'Disconnected';
    } else if (isTesting) {
      statusColor = colors.warning;
      statusText = 'Connecting...';
    } else if (lastTestSuccess == true) {
      statusColor = colors.success;
      statusText = latencyMs != null ? 'Connected (${latencyMs}ms)' : 'Connected';
    } else if (lastTestSuccess == false) {
      statusColor = colors.error;
      statusText = 'Connection Failed';
    } else {
      statusColor = colors.primary;
      statusText = 'Connected';
    }

    return Container(
      padding: const EdgeInsets.all(TxSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TxRadius.borderRadiusMd,
        border: Border.all(
          color: isEnabled ? colors.primary.withValues(alpha: 0.3) : colors.border,
          width: 1,
        ),
        boxShadow: TxElevation.elevation1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isEnabled ? colors.primary : colors.textTertiary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.globe,
                    size: 20,
                    color: isEnabled ? colors.primary : colors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: TxSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasHost
                          ? '${protocol.name.toUpperCase()} • $host:$port'
                          : 'No Proxy Configured',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasHost && isEnabled) ...[
            const SizedBox(height: TxSpacing.md),
            Divider(color: colors.borderSubtle, height: 1),
            const SizedBox(height: TxSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TxPressable(
                onTap: isTesting ? null : onTestConnection,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TxSpacing.sm,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isTesting)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: colors.primary,
                          ),
                        )
                      else
                        Icon(
                          LucideIcons.activity,
                          size: 14,
                          color: colors.primary,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        'Test Latency',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
