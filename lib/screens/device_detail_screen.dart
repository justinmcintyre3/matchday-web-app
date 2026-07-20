import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/match_provider.dart';
import '../widgets/global_app_bar.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceName;
  final String deviceType;

  const DeviceDetailScreen({
    super.key,
    required this.deviceName,
    required this.deviceType,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  bool? _isReachable;
  bool? _isPaired;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (mounted) setState(() => _loading = true);
    try {
      final wc = context.read<MatchProvider>().watchConnectivity;
      final reachable = await wc.isReachable;
      // isPaired is supported on iOS (WatchKit); on Android it may throw.
      bool? paired;
      try {
        paired = await wc.isPaired;
      } catch (_) {
        paired = null;
      }
      if (mounted) {
        setState(() {
          _isReachable = reachable;
          _isPaired = paired;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(
        title: Text(widget.deviceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh status',
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadStatus();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        children: [
          // -- Device header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.watch_rounded,
                    color: Color(0xFF007AFF),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.deviceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.deviceType,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // -- STATUS section header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'STATUS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 1.2,
              ),
            ),
          ),

          // -- Status card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF007AFF),
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      _InfoRow(
                        label: 'Connection',
                        value: _isReachable == true
                            ? 'Reachable'
                            : 'Not Reachable',
                        valueColor: _isReachable == true
                            ? const Color(0xFF00E676)
                            : Colors.white38,
                        dot: _isReachable == true
                            ? const Color(0xFF00E676)
                            : Colors.grey,
                        showDivider: _isPaired != null,
                        tooltipMessage: 'On Android, this shows whether the watch is connected via Bluetooth/Wear OS. On iOS, it checks if the watch app is currently active in the foreground.',
                      ),
                      if (_isPaired != null)
                        _InfoRow(
                          label: 'Paired',
                          value: _isPaired! ? 'Yes' : 'No',
                          valueColor: _isPaired!
                              ? Colors.white70
                              : Colors.white38,
                          showDivider: false,
                          tooltipMessage: 'Shows whether the watch is paired with your phone in Bluetooth/Wear OS settings.',
                        ),
                    ],
                  ),
          ),

          const SizedBox(height: 20),

          if (widget.deviceName == 'Matchday Watch') ...[
            // -- SETTINGS section header
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'SETTINGS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            
            // -- Settings card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Consumer<MatchProvider>(
                builder: (context, provider, child) {
                  return Column(
                    children: [
                      _SettingSwitchRow(
                        label: 'Auto Dope',
                        value: provider.watchAutoDope,
                        onChanged: (value) => provider.updateWatchSetting('autoDope', value),
                      ),
                      _SettingSwitchRow(
                        label: 'Read Aloud',
                        value: provider.watchReadAloud,
                        onChanged: (value) => provider.updateWatchSetting('readAloud', value),
                      ),
                      _SettingCycleRow(
                        label: 'Beep Pitch',
                        value: provider.watchBeepPitch,
                        onTap: () {
                          final current = provider.watchBeepPitch;
                          String next = 'Med';
                          if (current == 'Med') {
                            next = 'High';
                          } else if (current == 'High') {
                            next = 'Low';
                          } else if (current == 'Low') {
                            next = 'Med';
                          }
                          provider.updateWatchSetting('beepPitch', next);
                        },
                      ),
                      _SettingSwitchRow(
                        label: '50% Beep',
                        value: provider.watchFiftyCentBeep,
                        onChanged: (value) => provider.updateWatchSetting('fiftyCentBeep', value),
                      ),
                      _SettingSwitchRow(
                        label: '40sec Beep',
                        value: provider.watchFortySecondsRemaining,
                        onChanged: (value) => provider.updateWatchSetting('fortySecondsRemaining', value),
                      ),
                      _SettingSwitchRow(
                        label: '30sec Beep',
                        value: provider.watchThirtySecondsRemaining,
                        onChanged: (value) => provider.updateWatchSetting('thirtySecondsRemaining', value),
                      ),
                      _SettingSwitchRow(
                        label: '20sec Beep',
                        value: provider.watchTwentySecondsRemaining,
                        onChanged: (value) => provider.updateWatchSetting('twentySecondsRemaining', value),
                      ),
                      _SettingSwitchRow(
                        label: '10sec Beep',
                        value: provider.watchTenSecondsRemaining,
                        onChanged: (value) => provider.updateWatchSetting('tenSecondsRemaining', value),
                      ),
                      _SettingSwitchRow(
                        label: 'Final 4 Beep',
                        value: provider.watchFinalFourCountdown,
                        onChanged: (value) => provider.updateWatchSetting('finalFourCountdown', value),
                      ),
                      _SettingSwitchRow(
                        label: 'Final Beep',
                        value: provider.watchFinalEndingBeep,
                        onChanged: (value) => provider.updateWatchSetting('finalEndingBeep', value),
                        showDivider: false,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // -- Troubleshooting Guidelines Expandable Card
          const _TroubleshootingCard(),
        ],
      ),
    );
  }
}

// -- Expandable Troubleshooting Card
class _TroubleshootingCard extends StatefulWidget {
  const _TroubleshootingCard();

  @override
  State<_TroubleshootingCard> createState() => _TroubleshootingCardState();
}

class _TroubleshootingCardState extends State<_TroubleshootingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _expanded = !_expanded;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TROUBLESHOOTING GUIDE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBulletPoint(
                    '1. Ensure the Matchday companion app is installed on your Wear OS watch.',
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint(
                    '2. Make sure Bluetooth is enabled on both your phone and watch.',
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint(
                    '3. Verify the watch is paired using the companion Wear OS / Google Pixel Watch app.',
                  ),

                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF007AFF),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// -- Reusable status row widget
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Color? dot;
  final bool showDivider;
  final String? tooltipMessage;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.dot,
    required this.showDivider,
    this.tooltipMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  if (tooltipMessage != null) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: tooltipMessage!,
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: const Duration(seconds: 15),
                      preferBelow: false,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E24),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                      child: const Icon(
                        Icons.info_outline,
                        size: 15,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dot != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    value,
                    style: TextStyle(color: valueColor, fontSize: 15),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            color: Colors.white.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

class _SettingSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const _SettingSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              Switch(
                value: value,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  onChanged(val);
                },
                activeThumbColor: const Color(0xFF00E676),
                activeTrackColor: const Color(0xFF00E676).withValues(alpha: 0.2),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            color: Colors.white.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

class _SettingCycleRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingCycleRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF007AFF),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          indent: 16,
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ],
    );
  }
}
