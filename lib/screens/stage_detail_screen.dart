import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../models/match.dart';
import '../providers/match_provider.dart';

class StageDetailScreen extends StatefulWidget {
  final String matchId;
  final int stageNumber;

  const StageDetailScreen({
    super.key,
    required this.matchId,
    required this.stageNumber,
  });

  @override
  State<StageDetailScreen> createState() => _StageDetailScreenState();
}

class _StageDetailScreenState extends State<StageDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<WatchResultEvent>? _watchSubscription;
  StreamSubscription<WatchLiveUpdateEvent>? _liveUpdateSubscription;
  StreamSubscription<void>? _timerStartedSubscription;

  // Controllers for text inputs
  final _stageNameController = TextEditingController();
  final _mentalErrorsController = TextEditingController();
  final _skillsErrorsController = TextEditingController();
  final _envErrorsController = TextEditingController();
  final _timeRemainingController = TextEditingController();
  final _heartRateController = TextEditingController();

  // Local state copy of stage variables
  late Stage _stage;
  bool _initialized = false;

  List<String> _mentalTags = [];
  List<String> _skillsTags = [];
  List<String> _envTags = [];

  final List<String> _presetMentalErrors = [
    'Rushed Shot',
    'Lost Target Track',
    'Timer Panic',
    'Forgot Stage Plan',
    'Wrong Target Index',
    'Dry Fire Mistake',
  ];

  final List<String> _presetSkillsErrors = [
    'Unstable Position',
    'Poor Recoil Control',
    'Trigger Jerk',
    'Slow Bolt Cycle',
    'Bad Bag Placement',
    'Wobble Zone Control',
  ];

  final List<String> _presetEnvErrors = [
    'Misjudged Wind',
    'Incorrect Dial',
    'Mirage Misreading',
    'Kestrel Alignment',
    'Parallax Blur',
  ];

  final List<String> _targetTypes = [
    'IPSC',
    'Sniper Head',
    'Sniper Shoulders',
    'Circles',
    'Diamonds',
    'Square',
    'Pig',
    'Coyote',
    'Sasquatch',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });

    // Listen to watch result stream from MatchProvider
    final matchProvider = context.read<MatchProvider>();
    _watchSubscription = matchProvider.watchResultStream.listen((event) {
      if (!mounted) return;
      // Check if we are currently looking at the active stage
      if (matchProvider.activeMatchId == widget.matchId &&
          matchProvider.activeStage?.stageNumber == widget.stageNumber) {
        // Update local text fields
        setState(() {
          _stage.timeRemaining = event.timeLeft;
          _stage.avgHeartRate = event.avgHeartRate;
          _stage.timedOut = (event.timeLeft == 0);

          _timeRemainingController.text = '${event.timeLeft}';
          _heartRateController.text = '${event.avgHeartRate}';
        });

        // Switch to Review tab automatically
        _tabController.animateTo(2);

        // Notify user via Dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.watch, color: Colors.blue),
                SizedBox(width: 8),
                Text('Telemetry Synced'),
              ],
            ),
            content: Text(
              'Received telemetry from watch:\n'
              '- Time Remaining: ${event.timeLeft} seconds\n'
              '- Average Heart Rate: ${event.avgHeartRate} BPM\n\n'
              'Please complete the stage review.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });

    _liveUpdateSubscription =
        matchProvider.watchLiveUpdateStream.listen((event) {
      if (!mounted) return;
      if (matchProvider.activeMatchId == widget.matchId &&
          matchProvider.activeStage?.stageNumber == widget.stageNumber) {
        setState(() {
          _stage.timeRemaining = event.timeLeft;
          _stage.avgHeartRate = event.heartRate;
          _stage.timedOut = (event.timeLeft == 0);

          _timeRemainingController.text = '${event.timeLeft}';
          _heartRateController.text = '${event.heartRate}';
        });
      }
    });

    _timerStartedSubscription =
        matchProvider.watchTimerStartedStream.listen((_) {
      if (!mounted) return;
      if (matchProvider.activeMatchId == widget.matchId &&
          matchProvider.activeStage?.stageNumber == widget.stageNumber) {
        // Switch to Shoot tab automatically when timer starts on watch
        _tabController.animateTo(1);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final provider = context.watch<MatchProvider>();
      final match = provider.matches.firstWhere((m) => m.id == widget.matchId);
      final currentStage =
          match.stages.firstWhere((s) => s.stageNumber == widget.stageNumber);

      // Deep copy to prevent mutating provider state directly without saving
      _stage = Stage(
        stageNumber: currentStage.stageNumber,
        name: currentStage.name,
        status: currentStage.status,
        numTargets: currentStage.numTargets,
        targets: List<Target>.from(currentStage.targets.map((t) {
          // Normalize size to MIL
          final cleanSize = t.size.replaceAll(RegExp(r'[^0-9.]'), '');
          final normalizedSize = cleanSize.isEmpty ? '' : '$cleanSize MIL';

          // Normalize distance to YD
          final cleanDistance = t.distance.replaceAll(RegExp(r'[^0-9.]'), '');
          final normalizedDistance =
              cleanDistance.isEmpty ? '' : '$cleanDistance YD';

          return Target(
            index: t.index,
            size: normalizedSize,
            distance: normalizedDistance,
            degreeOfFire: t.degreeOfFire,
            type: t.type,
            shotsCount: t.shotsCount,
          );
        })),
        windPlan: WindPlan(
          prevValue: currentStage.windPlan.prevValue,
          prevDirection: currentStage.windPlan.prevDirection,
          kestrelValue: currentStage.windPlan.kestrelValue,
          kestrelDirection: currentStage.windPlan.kestrelDirection,
          actualValue: currentStage.windPlan.actualValue,
          actualDirection: currentStage.windPlan.actualDirection,
        ),
        timedOut: currentStage.timedOut,
        timeRemaining: currentStage.timeRemaining,
        avgHeartRate: currentStage.avgHeartRate,
        shotResults: List<String>.from(currentStage.shotResults),
        mentalErrors: currentStage.mentalErrors,
        skillsErrors: currentStage.skillsErrors,
        environmentalErrors: currentStage.environmentalErrors,
        timeLimit: currentStage.timeLimit,
      );

      // Automatically prefill previous stage's actual windage if this is a fresh stage
      if (_stage.windPlan.prevValue == 0.0 &&
          _stage.windPlan.prevDirection == 'None' &&
          widget.stageNumber > 1) {
        final prevStage = match.stages
            .firstWhere((s) => s.stageNumber == widget.stageNumber - 1);
        _stage.windPlan.prevValue = prevStage.windPlan.actualValue;
        _stage.windPlan.prevDirection = prevStage.windPlan.actualDirection;
      }

      _stageNameController.text = _stage.name;
      _mentalTags = _stage.mentalErrors
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      _skillsTags = _stage.skillsErrors
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      _envTags = _stage.environmentalErrors
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      _timeRemainingController.text =
          _stage.status == 'completed' ? '${_stage.timeRemaining}' : '';
      _heartRateController.text =
          _stage.status == 'completed' && _stage.avgHeartRate > 0
              ? '${_stage.avgHeartRate}'
              : '';

      _adjustShotResultsLength();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _watchSubscription?.cancel();
    _liveUpdateSubscription?.cancel();
    _timerStartedSubscription?.cancel();
    _stageNameController.dispose();
    _mentalErrorsController.dispose();
    _skillsErrorsController.dispose();
    _envErrorsController.dispose();
    _timeRemainingController.dispose();
    _heartRateController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Adjust Flat shot list based on sum of targets shotsCount
  void _adjustShotResultsLength() {
    final int totalShotsNeeded =
        _stage.targets.fold(0, (sum, t) => sum + t.shotsCount);
    if (_stage.shotResults.length < totalShotsNeeded) {
      _stage.shotResults.addAll(List.generate(
        totalShotsNeeded - _stage.shotResults.length,
        (_) => 'miss',
      ));
    } else if (_stage.shotResults.length > totalShotsNeeded) {
      _stage.shotResults = _stage.shotResults.sublist(0, totalShotsNeeded);
    }
    _stage.numTargets = _stage.targets.length;
  }

  void _saveStage({bool exitScreen = true, bool markAsCompleted = false}) {
    _stage.name = _stageNameController.text.trim();
    _stage.mentalErrors = _mentalTags.join(', ');
    _stage.skillsErrors = _skillsTags.join(', ');
    _stage.environmentalErrors = _envTags.join(', ');

    if (markAsCompleted) {
      _stage.status = 'completed';
    }

    _adjustShotResultsLength();

    context.read<MatchProvider>().updateStage(widget.matchId, _stage);

    if (exitScreen) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stage settings saved')),
      );
    }
  }

  void _syncToWatch() {
    _saveStage(exitScreen: false);
    context.read<MatchProvider>().syncActiveStageToWatch();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Syncing Stage ${widget.stageNumber} setup to watch...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<MatchProvider>();
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121214),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF007AFF),
          secondary: Color(0xFF00E676),
          surface: Color(0xFF1E1E24),
          error: Color(0xFFFF5252),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121214),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            _saveStage(exitScreen: false);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_stage.name.isNotEmpty
                ? _stage.name
                : 'Stage ${widget.stageNumber} Setup'),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF007AFF),
              labelColor: const Color(0xFF007AFF),
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.edit_note), text: 'Plan'),
                Tab(icon: Icon(Icons.watch), text: 'Shoot'),
                Tab(icon: Icon(Icons.rate_review), text: 'Review'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPlanTab(),
              _buildShootTab(),
              _buildReviewTab(),
            ],
          ),
        ),
      ),
    );
  }

  // PLAN TAB
  Widget _buildPlanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stage Name Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                controller: _stageNameController,
                decoration: const InputDecoration(
                  labelText: 'Stage Name (Optional)',
                  hintText: 'e.g. Barricade Buster',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Target Config Card
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Text(
                          'TARGETS',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                              color: Color(0xFF007AFF)),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Target'),
                        onPressed: () {
                          setState(() {
                            _stage.targets.add(Target(
                              index: _stage.targets.length + 1,
                              size: '1.5 MIL',
                              distance: '400 YD',
                              degreeOfFire: '0°',
                              type: 'IPSC',
                              shotsCount: 1,
                            ));
                            _adjustShotResultsLength();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_stage.targets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          'No targets defined. Add target positions above.',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ),
                    ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _stage.targets.length,
                    itemBuilder: (context, i) {
                      final target = _stage.targets[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10.0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121214),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFF007AFF)
                                      .withValues(alpha: 0.2),
                                  child: Text('${target.index}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF007AFF),
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: _buildShapeButton(target)),
                                const SizedBox(width: 8),
                                _buildShotsButton(target),
                                const SizedBox(width: 4),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _stage.targets.removeAt(i);
                                      // Reindex
                                      for (int k = 0;
                                          k < _stage.targets.length;
                                          k++) {
                                        _stage.targets[k] = Target(
                                          index: k + 1,
                                          size: _stage.targets[k].size,
                                          distance: _stage.targets[k].distance,
                                          degreeOfFire:
                                              _stage.targets[k].degreeOfFire,
                                          type: _stage.targets[k].type,
                                          shotsCount:
                                              _stage.targets[k].shotsCount,
                                        );
                                      }
                                      _adjustShotResultsLength();
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    key: Key(
                                        'dist_${target.index}_${target.distance}'),
                                    initialValue: target.distance
                                        .replaceAll(RegExp(r'[^0-9.]'), ''),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      labelText: 'Distance',
                                      suffixText: 'YD',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 10),
                                      labelStyle: TextStyle(fontSize: 12),
                                      suffixStyle: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    onChanged: (val) {
                                      target.distance =
                                          val.isEmpty ? '' : '$val YD';
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    key: Key(
                                        'size_${target.index}_${target.size}'),
                                    initialValue: target.size
                                        .replaceAll(RegExp(r'[^0-9.]'), ''),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      labelText: 'Size',
                                      suffixText: 'MIL',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 10),
                                      labelStyle: TextStyle(fontSize: 12),
                                      suffixStyle: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    onChanged: (val) {
                                      target.size =
                                          val.isEmpty ? '' : '$val MIL';
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 4,
                                  child: TextFormField(
                                    key: Key(
                                        'angle_${target.index}_${target.degreeOfFire}'),
                                    initialValue: target.degreeOfFire,
                                    readOnly: true,
                                    onTap: () => _showCompassDialog(target),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      labelText: 'Angle/Dir',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 10),
                                      labelStyle: TextStyle(fontSize: 12),
                                      suffixIcon: Icon(
                                          Icons.compass_calibration,
                                          size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Windage Planning Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WINDAGE FORECAST',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                        color: Color(0xFF007AFF)),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Previous Stage Actual windage',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121214),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Center(
                          child: Text(
                            _getPrevStageWindageString(),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white10),
                  _buildWindagePicker(
                    label: 'Kestrel predicted windage now',
                    value: _stage.windPlan.kestrelValue,
                    direction: _stage.windPlan.kestrelDirection,
                    onChanged: (val, dir) {
                      setState(() {
                        _stage.windPlan.kestrelValue = val;
                        _stage.windPlan.kestrelDirection = dir;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Timer settings Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'STAGE TIME CONFIGURATION',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                        color: Color(0xFF007AFF)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Timer Limit duration',
                          style: TextStyle(fontSize: 15)),
                      DropdownButton<int>(
                        value: _stage.timeLimit,
                        items: [60, 75, 90, 105, 120, 150]
                            .map((limit) => DropdownMenuItem(
                                  value: limit,
                                  child: Text('$limit seconds'),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _stage.timeLimit = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _syncToWatch,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Configuration to Watch'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: const Color(0xFF007AFF),
                      side: const BorderSide(color: Color(0xFF007AFF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Improved custom stepper for MIL windage inputs (scope turret style)
  Widget _buildWindagePicker({
    required String label,
    required double value,
    required String direction,
    required Function(double val, String dir) onChanged,
  }) {
    String displayStr = '';
    if (direction == 'L') {
      displayStr = '${value.toStringAsFixed(1)} L';
    } else if (direction == 'R') {
      displayStr = '${value.toStringAsFixed(1)} R';
    } else {
      displayStr = '0.0';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white70)),
        const SizedBox(height: 10),
        Row(
          children: [
            // Left Adjustment Button
            ElevatedButton(
              onPressed: () {
                if (direction == 'R') {
                  double newVal = value - 0.1;
                  if (newVal < 0.05) {
                    onChanged(0.0, 'None');
                  } else {
                    onChanged(newVal, 'R');
                  }
                } else if (direction == 'L') {
                  onChanged((value + 0.1).clamp(0.0, 5.0), 'L');
                } else {
                  onChanged(0.1, 'L');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF121214),
                foregroundColor: const Color(0xFF007AFF),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('L',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),

            // Value display
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12.0),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF121214),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Center(
                  child: Text(
                    '$displayStr MIL',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
            ),

            // Right Adjustment Button
            ElevatedButton(
              onPressed: () {
                if (direction == 'L') {
                  double newVal = value - 0.1;
                  if (newVal < 0.05) {
                    onChanged(0.0, 'None');
                  } else {
                    onChanged(newVal, 'L');
                  }
                } else if (direction == 'R') {
                  onChanged((value + 0.1).clamp(0.0, 5.0), 'R');
                } else {
                  onChanged(0.1, 'R');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF121214),
                foregroundColor: const Color(0xFF007AFF),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('R',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
      ],
    );
  }

  // SHOOT TAB - CLEAN TELEMETRY
  Widget _buildShootTab() {
    return Container(
      color: const Color(0xFF121214),
      padding: const EdgeInsets.all(24.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulse target decoration
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                  width: 3),
            ),
            child: const Center(
              child: Icon(
                Icons.watch,
                size: 60,
                color: Color(0xFF007AFF),
              ),
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            'ACTIVE RECORDING MODE',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Run the timer on your watch app. Telemetry payload (elapsed time, heart rate) will automatically stream and populate the review section when you stop the watch.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 48),

          // Watch telemetry state card
          if (_stage.timeRemaining > 0 || _stage.avgHeartRate > 0)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.timer,
                            color: Color(0xFF007AFF), size: 24),
                        const SizedBox(height: 6),
                        Text(
                          '${_stage.timeRemaining}s left',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Text('Remaining Time',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    Container(height: 40, width: 1, color: Colors.white10),
                    Column(
                      children: [
                        const Icon(Icons.favorite,
                            color: Colors.redAccent, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          '${_stage.avgHeartRate} BPM',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Text('Avg Heart Rate',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // REVIEW TAB - TARGET SPECIFIC SHOT LOGS
  Widget _buildReviewTab() {
    int flatIndexOffset = 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_stage.targets.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(Icons.gps_off, size: 40, color: Colors.grey[600]),
                    const SizedBox(height: 12),
                    const Text('No Targets Configured',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(
                      'Please define your targets on the Plan page first to construct your shot logs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // Generate a logging card for each target dynamically
          ...List.generate(_stage.targets.length, (targetIdx) {
            final target = _stage.targets[targetIdx];
            final int currentOffset = flatIndexOffset;
            flatIndexOffset += target.shotsCount;

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'TARGET ${target.index}: ${target.type}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF00E676),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Text(
                          '${target.distance} | ${target.size} | ${target.degreeOfFire}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Render shot row for this target
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(target.shotsCount, (shotIdx) {
                        final globalShotIdx = currentOffset + shotIdx;

                        // Safety bounds check
                        if (globalShotIdx >= _stage.shotResults.length) {
                          return const SizedBox();
                        }

                        final result = _stage.shotResults[globalShotIdx];
                        Color bgColor = Colors.grey[850]!;
                        Color textColor = Colors.white70;
                        IconData? icon;

                        if (result == 'hit') {
                          bgColor =
                              const Color(0xFF00E676).withValues(alpha: 0.2);
                          textColor = const Color(0xFF00E676);
                          icon = Icons.gps_fixed;
                        } else if (result == 'miss') {
                          bgColor = Colors.redAccent.withValues(alpha: 0.2);
                          textColor = Colors.redAccent;
                          icon = Icons.close;
                        } else if (result == 'timeOutMiss') {
                          bgColor = Colors.grey.withValues(alpha: 0.2);
                          textColor = Colors.grey;
                          icon = Icons.timer_outlined;
                        }

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (result == 'miss') {
                                _stage.shotResults[globalShotIdx] = 'hit';
                              } else if (result == 'hit') {
                                _stage.shotResults[globalShotIdx] =
                                    'timeOutMiss';
                              } else {
                                _stage.shotResults[globalShotIdx] = 'miss';
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(25),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: bgColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: textColor.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Shot ${shotIdx + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  if (icon != null)
                                    Icon(icon, size: 12, color: textColor),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 12),

          // Telemetry and Windage Review Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TELEMETRY & WINDAGE ACTUALS',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                        color: Color(0xFF007AFF)),
                  ),
                  const SizedBox(height: 16),

                  // Actual Windage Stepper
                  _buildWindagePicker(
                    label: 'Actual windage held (It took to hit)',
                    value: _stage.windPlan.actualValue,
                    direction: _stage.windPlan.actualDirection,
                    onChanged: (val, dir) {
                      setState(() {
                        _stage.windPlan.actualValue = val;
                        _stage.windPlan.actualDirection = dir;
                      });
                    },
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Time Remaining with Steppers
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Color(0xFF007AFF), size: 24),
                            onPressed: () {
                              setState(() {
                                if (_stage.timeRemaining > 0) {
                                  _stage.timeRemaining--;
                                  _timeRemainingController.text =
                                      '${_stage.timeRemaining}';
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer,
                                  color: Color(0xFF007AFF), size: 20),
                              const SizedBox(height: 4),
                              Text(
                                '${_stage.timeRemaining}s left',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const Text('Remaining Time',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.add_circle_outline,
                                color: Color(0xFF007AFF), size: 24),
                            onPressed: () {
                              setState(() {
                                _stage.timeRemaining++;
                                _timeRemainingController.text =
                                    '${_stage.timeRemaining}';
                              });
                            },
                          ),
                        ],
                      ),
                      Container(height: 40, width: 1, color: Colors.white10),
                      // Avg Heart Rate (Read-only)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite,
                              color: Colors.redAccent, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            '${_stage.avgHeartRate} BPM',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const Text('Avg Heart Rate',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Error Cataloging Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STAGE ERROR LOG',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                        color: Color(0xFF007AFF)),
                  ),
                  const SizedBox(height: 16),
                  _buildErrorTagSection(
                    title: 'Mental Errors',
                    selectedTags: _mentalTags,
                    errorType: 'mental',
                  ),
                  _buildErrorTagSection(
                    title: 'Skills Errors',
                    selectedTags: _skillsTags,
                    errorType: 'skills',
                  ),
                  _buildErrorTagSection(
                    title: 'Environmental Errors',
                    selectedTags: _envTags,
                    errorType: 'env',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_stage.status == 'completed') ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _stage.status = 'pending';
                        _stage.timeRemaining = 0;
                        _stage.avgHeartRate = 0;
                        _stage.timedOut = false;
                        _stage.mentalErrors = '';
                        _stage.skillsErrors = '';
                        _stage.environmentalErrors = '';
                        _stage.windPlan.actualValue = 0.0;
                        _stage.windPlan.actualDirection = 'None';

                        // Reset all shot results to 'miss' (preserves configured shot counts)
                        _stage.shotResults =
                            List.filled(_stage.shotResults.length, 'miss');

                        // Clear text controllers and tag lists
                        _mentalErrorsController.clear();
                        _skillsErrorsController.clear();
                        _envErrorsController.clear();
                        _mentalTags = [];
                        _skillsTags = [];
                        _envTags = [];
                        _timeRemainingController.text = '';
                        _heartRateController.text = '';
                      });
                      _saveStage(markAsCompleted: false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Revert',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      _saveStage(markAsCompleted: _stage.status != 'completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _stage.status == 'completed'
                        ? 'Save Changes'
                        : 'Complete & Close Stage',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _getPrevStageWindageString() {
    if (widget.stageNumber > 1) {
      final val = _stage.windPlan.prevValue;
      final dir = _stage.windPlan.prevDirection;
      if (dir == 'None') return '0.0 MIL';
      return '${val.toStringAsFixed(1)} MIL $dir';
    }
    return '---';
  }

  void _showCompassDialog(Target target) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        double currentHeading = 0.0;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return StreamBuilder<CompassEvent>(
              stream: FlutterCompass.events,
              builder: (context, snapshot) {
                double? heading = snapshot.data?.heading;
                if (heading != null) {
                  currentHeading = heading;
                }

                double displayHeading = (currentHeading < 0)
                    ? (360 + currentHeading)
                    : currentHeading;
                String cardinal = _getCardinalDirection(displayHeading);

                return Container(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ALIGN TO TARGET',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.5,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Point your device directly at the target silhouette.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle:
                                -((heading ?? 0.0) * (3.141592653589793 / 180)),
                            child: Container(
                              height: 160,
                              width: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white24, width: 2),
                                color: const Color(0xFF121214),
                              ),
                              child: const Stack(
                                children: [
                                  Positioned(
                                      top: 8,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                          child: Text('N',
                                              style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14)))),
                                  Positioned(
                                      bottom: 8,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                          child: Text('S',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14)))),
                                  Positioned(
                                      left: 8,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                          child: Text('W',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14)))),
                                  Positioned(
                                      right: 8,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                          child: Text('E',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14)))),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            height: 180,
                            width: 180,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.navigation,
                              color: Color(0xFF00E676),
                              size: 24,
                            ),
                          ),
                          Container(
                            width: 90,
                            height: 90,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(
                                  0xFF121214), // Matches dial center background color
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${displayHeading.round()}°',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                cardinal,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            target.degreeOfFire = '${displayHeading.round()}°';
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 48, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Capture Direction',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildShapeButton(Target target) {
    return InkWell(
      onTap: () => _showShapeSelector(target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined,
                size: 14, color: Color(0xFF007AFF)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                target.type,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildShotsButton(Target target) {
    return InkWell(
      onTap: () => _showShotsSelector(target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ads_click, size: 14, color: Color(0xFF007AFF)),
            const SizedBox(width: 4),
            Text(
              '${target.shotsCount} ${target.shotsCount == 1 ? 'Shot' : 'Shots'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showShapeSelector(Target target) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        final originalType = target.type;
        final TextEditingController customController = TextEditingController(
          text: _targetTypes.contains(target.type) ? '' : target.type,
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            final isCustomMode =
                !_targetTypes.contains(target.type) || target.type == 'Other';

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isCustomMode ? 'ENTER CUSTOM SHAPE' : 'SELECT TARGET SHAPE',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                      color: Color(0xFF007AFF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (!isCustomMode) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._targetTypes.where((t) => t != 'Other').map((type) {
                          final isSelected = target.type == type;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                target.type = type;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF007AFF)
                                        .withValues(alpha: 0.2)
                                    : const Color(0xFF121214),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF007AFF)
                                      : Colors.white10,
                                ),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF007AFF)
                                      : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }),
                        InkWell(
                          onTap: () {
                            setModalState(() {
                              target.type = 'Other';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF121214),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white10,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 14, color: Colors.grey),
                                SizedBox(width: 6),
                                Text(
                                  'Custom...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    TextFormField(
                      controller: customController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Shape Name',
                        hintText: 'e.g. Gong, Silhouette, etc.',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                target.type =
                                    _targetTypes.contains(originalType)
                                        ? originalType
                                        : 'IPSC';
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey,
                              side: const BorderSide(color: Colors.white10),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final text = customController.text.trim();
                              if (text.isNotEmpty) {
                                setState(() {
                                  target.type = text;
                                });
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showShotsSelector(Target target) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SELECT NUMBER OF SHOTS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                  color: Color(0xFF007AFF),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: 10,
                itemBuilder: (context, index) {
                  final shots = index + 1;
                  final isSelected = target.shotsCount == shots;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        target.shotsCount = shots;
                        _adjustShotResultsLength();
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF007AFF).withValues(alpha: 0.2)
                            : const Color(0xFF121214),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF007AFF)
                              : Colors.white10,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$shots',
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF007AFF)
                                : Colors.white,
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  String _getCardinalDirection(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading >= 22.5 && heading < 67.5) return 'NE';
    if (heading >= 67.5 && heading < 112.5) return 'E';
    if (heading >= 112.5 && heading < 157.5) return 'SE';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'SW';
    if (heading >= 247.5 && heading < 292.5) return 'W';
    if (heading >= 292.5 && heading < 337.5) return 'NW';
    return '';
  }

  Widget _buildErrorTagSection({
    required String title,
    required List<String> selectedTags,
    required String errorType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  _showErrorTagSelector(title, selectedTags, errorType),
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF007AFF)),
              label: const Text(
                'Manage Tags',
                style: TextStyle(
                    color: Color(0xFF007AFF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: selectedTags.isEmpty
              ? Text(
                  'No $title logged. Tap "Manage Tags" to add.',
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: selectedTags.map((tag) {
                    return InputChip(
                      label: Text(tag,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white)),
                      backgroundColor:
                          const Color(0xFF007AFF).withValues(alpha: 0.15),
                      selectedColor:
                          const Color(0xFF007AFF).withValues(alpha: 0.15),
                      checkmarkColor: const Color(0xFF007AFF),
                      deleteIconColor: Colors.white54,
                      onDeleted: () {
                        setState(() {
                          selectedTags.remove(tag);
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: Color(0xFF007AFF)),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _showErrorTagSelector(
    String title,
    List<String> selectedTags,
    String errorType,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        final TextEditingController customController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setModalState) {
            final match = context.watch<MatchProvider>().matches.firstWhere(
                  (m) => m.id == widget.matchId,
                  orElse: () => Match(
                    id: '',
                    name: 'Not Found',
                    location: '',
                    date: DateTime.now(),
                    numStages: 0,
                    shotsPerStage: 0,
                    stages: [],
                  ),
                );
            final availableTags =
                _getAvailableTagsForCategory(match, errorType);

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LOG $title'.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.2,
                      color: Color(0xFF007AFF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tap presets to toggle. Long-press to delete a tag:',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return InkWell(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              selectedTags.remove(tag);
                            } else {
                              selectedTags.add(tag);
                            }
                          });
                          setState(() {});
                        },
                        onLongPress: () {
                          _confirmDeleteTag(
                              context, tag, errorType, setModalState);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF007AFF).withValues(alpha: 0.2)
                                : const Color(0xFF121214),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF007AFF)
                                  : Colors.white10,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF007AFF)
                                  : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  const Text(
                    'Add custom error tag:',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: customController,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'e.g. forgot wind hold...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final text = customController.text.trim();
                          if (text.isNotEmpty) {
                            // Add custom tag to database immediately
                            context.read<MatchProvider>().addCustomTagToMatch(
                                  widget.matchId,
                                  text,
                                  errorType,
                                );

                            setModalState(() {
                              if (!selectedTags.contains(text)) {
                                selectedTags.add(text);
                              }
                              customController.clear();
                            });
                            setState(() {});
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF121214),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white10),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Done',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<String> _getAvailableTagsForCategory(Match match, String errorType) {
    final List<String> basePresets;
    final List<String> customPresets;
    final List<String> deletedTags;
    final List<String> localSelected;

    if (errorType == 'mental') {
      basePresets = List.from(_presetMentalErrors);
      customPresets = match.customMentalTags;
      deletedTags = match.deletedMentalTags;
      localSelected = _mentalTags;
    } else if (errorType == 'skills') {
      basePresets = List.from(_presetSkillsErrors);
      customPresets = match.customSkillsTags;
      deletedTags = match.deletedSkillsTags;
      localSelected = _skillsTags;
    } else {
      basePresets = List.from(_presetEnvErrors);
      customPresets = match.customEnvTags;
      deletedTags = match.deletedEnvTags;
      localSelected = _envTags;
    }

    final Set<String> allTags = {};

    // Add default presets
    allTags.addAll(basePresets);

    // Add match-level custom presets
    allTags.addAll(customPresets);

    // Add any tags used in any stage of the match
    for (var stage in match.stages) {
      final String rawErrors;
      if (errorType == 'mental') {
        rawErrors = stage.mentalErrors;
      } else if (errorType == 'skills') {
        rawErrors = stage.skillsErrors;
      } else {
        rawErrors = stage.environmentalErrors;
      }
      if (rawErrors.isNotEmpty) {
        final parsed = rawErrors
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty);
        allTags.addAll(parsed);
      }
    }

    // Add local selected tags (so newly added custom tags show up immediately)
    allTags.addAll(localSelected);

    // Subtract deleted tags
    allTags.removeAll(deletedTags);

    return allTags.toList();
  }

  void _confirmDeleteTag(
    BuildContext context,
    String tag,
    String errorType,
    void Function(void Function()) setModalState,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Tag?'),
          content: Text(
            'Are you sure you want to delete the tag "$tag"? This will remove it from all stages in this match.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                // 1. Delete from provider/match (updates db and all stages)
                context.read<MatchProvider>().deleteTagFromMatch(
                      widget.matchId,
                      tag,
                      errorType,
                    );

                // 2. Delete from local screen state lists
                setState(() {
                  if (errorType == 'mental') {
                    _mentalTags.remove(tag);
                  } else if (errorType == 'skills') {
                    _skillsTags.remove(tag);
                  } else if (errorType == 'env') {
                    _envTags.remove(tag);
                  }
                });

                // 3. Rebuild modal
                setModalState(() {});
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
