import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../models/match.dart';
import '../providers/match_provider.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:flutter/services.dart';
import '../features/kestrel_ble/providers/kestrel_provider.dart';
import '../features/kestrel_ble/models/kestrel_device.dart';
import '../widgets/wind_clock_picker.dart';
import '../features/sg_pulse/providers/sg_pulse_provider.dart';
import '../widgets/global_app_bar.dart';
import '../features/rx5000/providers/rx5000_provider.dart';

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
  late Rx5000Provider _rxProvider;
  bool _isRx5000Active = false;
  StreamSubscription<WatchResultEvent>? _watchSubscription;
  StreamSubscription<WatchLiveUpdateEvent>? _liveUpdateSubscription;
  StreamSubscription<int?>? _timerStartedSubscription;
  Timer? _remainingTimeTimer;
  Timer? _shootTimer;
  int? _currentShootTimeMs;
  bool _isShootTimerRunning = false;
  StreamSubscription<void>? _shotSubscription;
  bool _stoppedByLimit = false;
  final _shootScrollController = ScrollController();
  final _planScrollController = ScrollController();

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

  final Map<int, TextEditingController> _rangeControllers = {};
  final Map<int, TextEditingController> _dofControllers = {};
  final Map<int, TextEditingController> _incControllers = {};
  final Map<int, FocusNode> _rangeFocusNodes = {};
  final Map<int, FocusNode> _incFocusNodes = {};
  StreamSubscription<Map<String, dynamic>>? _rangeSubscription;

  TextEditingController _getRangeController(TargetArray array) {
    final key = array.hashCode;
    if (!_rangeControllers.containsKey(key)) {
      _rangeControllers[key] = TextEditingController(
          text: array.distance.replaceAll(RegExp(r'[^0-9.]'), ''));
    }
    return _rangeControllers[key]!;
  }

  TextEditingController _getDofController(TargetArray array) {
    final key = array.hashCode;
    if (!_dofControllers.containsKey(key)) {
      _dofControllers[key] = TextEditingController(text: array.degreeOfFire);
    }
    return _dofControllers[key]!;
  }

  TextEditingController _getIncController(TargetArray array) {
    final key = array.hashCode;
    if (!_incControllers.containsKey(key)) {
      String initVal = array.inclination;
      final numVal = int.tryParse(initVal);
      if (numVal != null && numVal > 0 && !initVal.startsWith('+')) {
        initVal = '+$numVal';
        array.inclination = initVal;
      }
      _incControllers[key] = TextEditingController(text: initVal);
    }
    return _incControllers[key]!;
  }

  FocusNode _getRangeFocusNode(TargetArray array) {
    final key = array.hashCode;
    if (!_rangeFocusNodes.containsKey(key)) {
      final node = FocusNode();
      node.addListener(() {
        if (mounted) setState(() {});
      });
      _rangeFocusNodes[key] = node;
    }
    return _rangeFocusNodes[key]!;
  }

  FocusNode _getIncFocusNode(TargetArray array) {
    final key = array.hashCode;
    if (!_incFocusNodes.containsKey(key)) {
      final node = FocusNode();
      node.addListener(() {
        if (!node.hasFocus) {
          final ctrl = _incControllers[key];
          if (ctrl != null) {
            final valStr = ctrl.text;
            final numVal = int.tryParse(valStr);
            if (numVal != null && numVal > 0 && !valStr.startsWith('+')) {
              final formatted = '+$numVal';
              ctrl.text = formatted;
              array.inclination = formatted;
              _saveStage(exitScreen: false);
            }
          }
        }
        if (mounted) setState(() {});
      });
      _incFocusNodes[key] = node;
    }
    return _incFocusNodes[key]!;
  }

  @override
  void initState() {
    super.initState();
    _rxProvider = context.read<Rx5000Provider>();
    _rangeSubscription = _rxProvider.onRangeData.listen(_onRangeDataReceived);
    _tabController = TabController(length: 3, vsync: this);
    
    if (_tabController.index == 0) {
      _rxProvider.incrementActivePages();
      _isRx5000Active = true;
    }

    _tabController.addListener(() {
      if (!mounted) return;
      if (_tabController.indexIsChanging) {
        HapticFeedback.lightImpact();
      }
      
      final shouldBeActive = _tabController.index == 0;
      if (shouldBeActive && !_isRx5000Active) {
        _rxProvider.incrementActivePages();
        _isRx5000Active = true;
      } else if (!shouldBeActive && _isRx5000Active) {
        _rxProvider.decrementActivePages();
        _isRx5000Active = false;
      }
      
      setState(() {});
    });

    // Listen to watch result stream from MatchProvider
    final matchProvider = context.read<MatchProvider>();
    _watchSubscription = matchProvider.watchResultStream.listen((event) {
      if (!mounted) return;
      // Check if we are currently looking at the active stage
      if (matchProvider.activeMatchId == widget.matchId &&
          matchProvider.activeStage?.stageNumber == widget.stageNumber) {
        _shootTimer?.cancel();
        _shotSubscription?.cancel();
        _isShootTimerRunning = false;

        // Update local text fields
        setState(() {
          final isStoppedEarly = event.stoppedByPhone || _stoppedByLimit;
          if (isStoppedEarly) {
            // Keep phone's precise remaining time, only update heart rate
            _stage.avgHeartRate = event.avgHeartRate;
            _heartRateController.text = '${event.avgHeartRate}';
          } else {
            _stage.timeRemaining = event.timeLeft;
            _stage.avgHeartRate = event.avgHeartRate;
            _stage.timedOut = (event.timeLeft == 0);

            _timeRemainingController.text = '${event.timeLeft}';
            _heartRateController.text = '${event.avgHeartRate}';
          }
          if (event.timeLeft == 0) {
            _markUntakenShotsAsTimedOut();
          }
          _stoppedByLimit = false; // Reset early stop flag
        });

        // Save stage immediately after telemetry sync!
        _saveStage(exitScreen: false);

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
              '- Time Remaining: ${_stage.timeRemaining} seconds\n'
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
          _stage.avgHeartRate = event.heartRate;
          _heartRateController.text = '${event.heartRate}';
        });
      }
    });

    _timerStartedSubscription =
        matchProvider.watchTimerStartedStream.listen((timeLeft) {
      if (!mounted) return;
      if (matchProvider.activeMatchId == widget.matchId &&
          matchProvider.activeStage?.stageNumber == widget.stageNumber) {
        _shootTimer?.cancel();
        _shotSubscription?.cancel();

        setState(() {
          _stage.shotTimes = [];
          _stage.shotRolls = [];
          _stage.shotStabilities = [];
          _stage.shotResults = List.filled(_stage.shotResults.length, 'miss');
          _stoppedByLimit = false;
        });
        context.read<SgPulseProvider>().clearSession();

        if (timeLeft != null) {
          // Deduct 300ms to compensate for BLE transmission latency
          final durationMs = (timeLeft * 1000) - 300;
          final targetEndTime =
              DateTime.now().add(Duration(milliseconds: durationMs));
          setState(() {
            _currentShootTimeMs = durationMs;
            _isShootTimerRunning = true;
          });

          final sgPulseProvider = context.read<SgPulseProvider>();
          _shotSubscription = sgPulseProvider.shotDetectedStream.listen((_) {
            if (_isShootTimerRunning && _currentShootTimeMs != null) {
              final elapsedSeconds =
                  (durationMs - _currentShootTimeMs!) / 1000.0;
              final currentRoll = sgPulseProvider.latestSnapshot?.roll ?? 0.0;
              final currentStability =
                  sgPulseProvider.latestSnapshot?.stability ?? 0.0;
              setState(() {
                _stage.shotTimes.add(elapsedSeconds);
                _stage.shotRolls.add(currentRoll);
                _stage.shotStabilities.add(currentStability);
              });

              // Auto scroll to bottom
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_shootScrollController.hasClients) {
                  _shootScrollController.animateTo(
                    _shootScrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              final totalShotsNeeded =
                  _stage.targets.fold<int>(0, (sum, t) => sum + t.shotsCount);
              if (_stage.shotTimes.length >= totalShotsNeeded) {
                _stopStageEarly();
              }
            }
          });

          _shootTimer =
              Timer.periodic(const Duration(milliseconds: 10), (timer) {
            final now = DateTime.now();
            final remainingMs = targetEndTime.difference(now).inMilliseconds;
            setState(() {
              if (remainingMs > 0) {
                _currentShootTimeMs = remainingMs;
              } else {
                _currentShootTimeMs = 0;
                _shootTimer?.cancel();
                _shotSubscription?.cancel();
                _isShootTimerRunning = false;
                _markUntakenShotsAsTimedOut();
              }
            });
          });
        }

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
        targetArrays:
            List<TargetArray>.from(currentStage.targetArrays.map((arr) {
          // Normalize targets inside array
          final normalizedTargets = List<Target>.from(arr.targets.map((t) {
            final cleanSize = t.size.replaceAll(RegExp(r'[^0-9.]'), '');
            final normalizedSize = cleanSize.isEmpty ? '' : '$cleanSize MIL';
            return Target(
              index: t.index,
              size: normalizedSize,
              distance: '',
              degreeOfFire: '',
              type: t.type,
              shotsCount: t.shotsCount,
            );
          }));

          final cleanDistance = arr.distance.replaceAll(RegExp(r'[^0-9.]'), '');
          final normalizedDistance =
              cleanDistance.isEmpty ? '' : '$cleanDistance YD';

          return TargetArray(
            distance: normalizedDistance,
            degreeOfFire: arr.degreeOfFire,
            inclination: arr.inclination,
            targets: normalizedTargets,
            minWindSpeed: arr.minWindSpeed,
            maxWindSpeed: arr.maxWindSpeed,
            windClockDirection:
                TargetArray.migrateWindClockSlot(arr.windClockDirection),
            extrapolatedClockDirection: TargetArray.migrateWindClockSlot(
              arr.extrapolatedClockDirection,
            ),
            elevationResult: arr.elevationResult,
            windageResult: arr.windageResult,
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
        numPositions: currentStage.numPositions,
        plannedRoundCount: currentStage.plannedRoundCount,
        shotTargetsSequence:
            List<String>.from(currentStage.shotTargetsSequence),
        shotTimes: List<double>.from(currentStage.shotTimes),
        shotRolls: List<double>.from(currentStage.shotRolls),
        shotStabilities: List<double>.from(currentStage.shotStabilities),
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
      for (int i = 1; i < _stage.targetArrays.length; i++) {
        _extrapolateWindForArray(i);
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _rangeSubscription?.cancel();
    for (final c in _rangeControllers.values) { c.dispose(); }
    for (final c in _dofControllers.values) { c.dispose(); }
    for (final c in _incControllers.values) { c.dispose(); }
    for (final n in _rangeFocusNodes.values) { n.dispose(); }
    for (final n in _incFocusNodes.values) { n.dispose(); }
    
    if (_isRx5000Active) {
      _rxProvider.decrementActivePages();
    }
    _watchSubscription?.cancel();
    _liveUpdateSubscription?.cancel();
    _timerStartedSubscription?.cancel();
    _remainingTimeTimer?.cancel();
    _shootTimer?.cancel();
    _shotSubscription?.cancel();
    _stageNameController.dispose();
    _mentalErrorsController.dispose();
    _skillsErrorsController.dispose();
    _envErrorsController.dispose();
    _timeRemainingController.dispose();
    _heartRateController.dispose();
    _shootScrollController.dispose();
    _planScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onRangeDataReceived(Map<String, dynamic> data) {
    if (!mounted) return;
    
    TargetArray? focusedArray;
    for (final array in _stage.targetArrays) {
      if (_rangeFocusNodes[array.hashCode]?.hasFocus == true) {
        focusedArray = array;
        break;
      }
    }

    if (focusedArray != null) {
      final range = data['range'] as double?;
      final heading = data['heading'] as double?;
      final inclination = data['inclination'] as num?;

      if (range != null) {
        final rangeStr = range.toStringAsFixed(1);
        _getRangeController(focusedArray).text = rangeStr;
        focusedArray.distance = '$rangeStr YD';
      }
      
      if (heading != null) {
        final headingStr = heading.round().toString();
        _getDofController(focusedArray).text = headingStr;
        focusedArray.degreeOfFire = headingStr;
      }

      if (inclination != null) {
        final incVal = inclination.toInt();
        final incStr = incVal > 0 ? '+$incVal' : incVal.toString();
        _getIncController(focusedArray).text = incStr;
        focusedArray.inclination = incStr;
      }

      setState(() {
        _adjustShotResultsLength();
      });
      HapticFeedback.lightImpact();
      _saveStage(exitScreen: false);
    }
  }

  void _stopStageEarly() async {
    if (!_isShootTimerRunning) return;
    final int remainingSeconds = (_currentShootTimeMs! / 1000.0).ceil();
    _stoppedByLimit = true;
    _shootTimer?.cancel();
    _shotSubscription?.cancel();
    setState(() {
      _isShootTimerRunning = false;
      _stage.timeRemaining = remainingSeconds;
      _timeRemainingController.text = '$remainingSeconds';
    });
    await context.read<MatchProvider>().stopWatchTimer();
  }

  void _markUntakenShotsAsTimedOut() {
    final int shotsTaken = _stage.shotTimes.length;
    setState(() {
      for (int i = shotsTaken; i < _stage.shotResults.length; i++) {
        _stage.shotResults[i] = 'timeOutMiss';
      }
    });
  }

  List<int> _getShotIndicesForTarget(int arrayIdx, int targetIdx) {
    final String key = '${arrayIdx}_$targetIdx';
    final List<int> indices = [];
    for (int i = 0; i < _stage.shotTargetsSequence.length; i++) {
      if (_stage.shotTargetsSequence[i] == key) {
        indices.add(i);
      }
    }
    return indices;
  }

  String _getTargetNameForShotIndex(int shotIndex) {
    if (shotIndex >= 0 && shotIndex < _stage.shotTargetsSequence.length) {
      final key = _stage.shotTargetsSequence[shotIndex];
      final parts = key.split('_');
      if (parts.length == 2) {
        final int arrayIdx = int.parse(parts[0]);
        final int targetIdx = int.parse(parts[1]);
        if (arrayIdx < _stage.targetArrays.length) {
          final array = _stage.targetArrays[arrayIdx];
          if (targetIdx < array.targets.length) {
            return 'Array ${arrayIdx + 1} - T${targetIdx + 1} (${array.distance.isEmpty ? "---" : array.distance})';
          }
        }
      }
    }
    return 'Shot ${shotIndex + 1}';
  }

  void _startRemainingTimeAutoIncrement(int delta) {
    _remainingTimeTimer?.cancel();
    _remainingTimeTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        if (delta < 0) {
          if (_stage.timeRemaining > 0) {
            _stage.timeRemaining--;
            _timeRemainingController.text = '${_stage.timeRemaining}';
          }
        } else {
          _stage.timeRemaining++;
          _timeRemainingController.text = '${_stage.timeRemaining}';
        }
      });
    });
  }

  void _stopRemainingTimeAutoIncrement() {
    _remainingTimeTimer?.cancel();
  }

  void _showHeartRateInputDialog() {
    final controller = TextEditingController(
        text: _stage.avgHeartRate > 0 ? '${_stage.avgHeartRate}' : '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Heart Rate'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Heart Rate (BPM)',
            hintText: 'e.g. 110',
            border: OutlineInputBorder(),
          ),
          onTap: () => HapticFeedback.lightImpact(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              final hr = int.tryParse(controller.text.trim()) ?? 0;
              setState(() {
                _stage.avgHeartRate = hr;
              });
              _saveStage(exitScreen: false);
              Navigator.pop(context);
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  double _parseDof(String dofStr) {
    final clean = dofStr.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  double step(double v, int dir) {
    return normalize(v + (0.1 * dir));
  }

  double normalize(double v) {
    return (v * 10).round() / 10.0;
  }

  bool isZero(double v) => v.abs() < 0.00001;

  double _parseRangeYards(String distanceStr) {
    final clean = distanceStr.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 100.0;
  }

  double _absoluteWindBearingForArray(int arrayIdx) {
    return _windDirectionDegreesForArray(arrayIdx);
  }

  double _windDirectionDegreesForArray(int arrayIdx) {
    if (_stage.targetArrays.isEmpty) return 0.0;
    final array0 = _stage.targetArrays[0];
    final slot0 = TargetArray.migrateWindClockSlot(array0.windClockDirection);
    final wd0 = TargetArray.clockSlotToDegrees(slot0);
    if (arrayIdx == 0) return wd0;

    final dof0 = _parseDof(array0.degreeOfFire);
    final array = _stage.targetArrays[arrayIdx];
    final dofN = _parseDof(array.degreeOfFire);
    var relativeWd = (wd0 + dof0 - dofN) % 360.0;
    if (relativeWd < 0) relativeWd += 360.0;
    return relativeWd;
  }

  Future<Map<String, dynamic>> _sendAndWaitForBalSolution({
    required KestrelProvider provider,
    required int targetNumber,
    required Future<void> Function() send,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    late StreamSubscription<Map<String, dynamic>> subscription;
    subscription = provider.onBalFullSolution.listen((data) {
      final slot = (data['targetNumber'] as num?)?.toInt();
      if (slot == targetNumber && !completer.isCompleted) {
        completer.complete(data);
      }
    });
    try {
      await send();
      return await completer.future.timeout(timeout);
    } finally {
      await subscription.cancel();
    }
  }

  void _extrapolateWindForArray(int arrayIdx) {
    if (arrayIdx == 0) return;
    if (_stage.targetArrays.isEmpty) return;

    // final array0 = _stage.targetArrays[0];
    final arrayN = _stage.targetArrays[arrayIdx];
    final relativeWd = _windDirectionDegreesForArray(arrayIdx);

    arrayN.extrapolatedClockDirection =
        TargetArray.degreesToClockSlot(relativeWd);
  }

  void _extrapolateAllDownstreamWind() {
    for (int i = 1; i < _stage.targetArrays.length; i++) {
      _extrapolateWindForArray(i);
    }
  }

  bool _hasBalSolution(Map<String, dynamic> result) {
    return result['elevation'] != null;
  }

  void _applyBalResultToArray(int arrayIdx, Map<String, dynamic> result) {
    final elevation = (result['elevation'] as num).toDouble();
    final w1 = (result['windage1'] as num).toDouble();
    final w2 = (result['windage2'] as num).toDouble();

    final array = _stage.targetArrays[arrayIdx];
    array.elevationResult = TargetArray.formatElevationMil(elevation);
    array.windageResult = TargetArray.formatWindagePair(w1, w2);

    if (arrayIdx == 0) {
      _stage.windPlan.kestrelValue = w1.abs();
      _stage.windPlan.kestrelDirection = w1 < 0 ? 'R' : (w1 > 0 ? 'L' : 'None');
    }
  }

  Widget _buildBalisticsResultsRow(TargetArray array) {
    if (array.elevationResult.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Elevation',
                    style: TextStyle(fontSize: 10, color: Color(0xFF007AFF)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    array.elevationResult,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF00E676).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Windage',
                    style: TextStyle(fontSize: 10, color: Color(0xFF00E676)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    array.windageResult,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildWindClockField(TargetArray array) {
    final slot = TargetArray.migrateWindClockSlot(array.windClockDirection);
    return InkWell(
      onTap: () async {
        HapticFeedback.lightImpact();
        final picked = await showWindClockPickerDialog(
          context,
          initialSlot: slot,
        );
        if (picked == null || !mounted) return;
        setState(() {
          array.windClockDirection = picked;
          _extrapolateAllDownstreamWind();
        });
        _saveStage(exitScreen: false);
      },
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Wind From',
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          labelStyle: TextStyle(fontSize: 10),
          suffixIcon: Icon(Icons.schedule, size: 16),
        ),
        child: Row(
          children: [
            Icon(Icons.navigation, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 6),
            Text(
              TargetArray.formatClockSlot(slot),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetArray0WindConfig(TargetArray array) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WIND',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: array.minWindSpeed == 0
                    ? ''
                    : array.minWindSpeed.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onTap: () => HapticFeedback.lightImpact(),
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Min Speed',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  labelStyle: TextStyle(fontSize: 10),
                ),
                onChanged: (val) {
                  array.minWindSpeed = double.tryParse(val) ?? 0.0;
                  _extrapolateAllDownstreamWind();
                  setState(() {});
                  _saveStage(exitScreen: false);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: array.maxWindSpeed == 0
                    ? ''
                    : array.maxWindSpeed.toString(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onTap: () => HapticFeedback.lightImpact(),
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Max Speed',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  labelStyle: TextStyle(fontSize: 10),
                ),
                onChanged: (val) {
                  array.maxWindSpeed = double.tryParse(val) ?? 0.0;
                  _extrapolateAllDownstreamWind();
                  setState(() {});
                  _saveStage(exitScreen: false);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWindClockField(array),
            ),
          ],
        ),
        _buildBalisticsResultsRow(array),
      ],
    );
  }

  Widget _buildTargetArrayNWindConfig(TargetArray array) {
    final array0 =
        _stage.targetArrays.isNotEmpty ? _stage.targetArrays[0] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EXTRAPOLATED WIND & BALLISTICS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wind Speed',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      array0 != null
                          ? TargetArray.formatWindSpeedRange(
                              array0.minWindSpeed,
                              array0.maxWindSpeed,
                            )
                          : '---',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Direction',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      TargetArray.formatClockSlot(
                        TargetArray.migrateWindClockSlot(
                          array.extrapolatedClockDirection,
                        ),
                      ),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        _buildBalisticsResultsRow(array),
      ],
    );
  }

  // Adjust Flat shot list based on sum of targets shotsCount
  void _adjustShotResultsLength() {
    // 1. Filter out invalid keys from sequence (e.g. if arrays/targets were deleted)
    final List<String> validSequence = [];
    for (var key in _stage.shotTargetsSequence) {
      final parts = key.split('_');
      if (parts.length == 2) {
        final int arrayIdx = int.parse(parts[0]);
        final int targetIdx = int.parse(parts[1]);
        if (arrayIdx >= 0 && arrayIdx < _stage.targetArrays.length) {
          final array = _stage.targetArrays[arrayIdx];
          if (targetIdx >= 0 && targetIdx < array.targets.length) {
            validSequence.add(key);
          }
        }
      }
    }
    _stage.shotTargetsSequence = validSequence;

    // 2. Reset all targets shotsCount to 0
    for (var array in _stage.targetArrays) {
      for (var target in array.targets) {
        target.shotsCount = 0;
      }
    }

    // 3. Count occurrences in sequence and update shotsCount
    for (var key in _stage.shotTargetsSequence) {
      final parts = key.split('_');
      final int arrayIdx = int.parse(parts[0]);
      final int targetIdx = int.parse(parts[1]);
      _stage.targetArrays[arrayIdx].targets[targetIdx].shotsCount++;
    }

    // 4. Adjust flat shot list sizes
    final int totalShotsNeeded = _stage.shotTargetsSequence.length;
    if (_stage.shotResults.length < totalShotsNeeded) {
      _stage.shotResults.addAll(List.generate(
        totalShotsNeeded - _stage.shotResults.length,
        (_) => 'miss',
      ));
    } else if (_stage.shotResults.length > totalShotsNeeded) {
      _stage.shotResults = _stage.shotResults.sublist(0, totalShotsNeeded);
    }
    if (_stage.shotTimes.length > totalShotsNeeded) {
      _stage.shotTimes = _stage.shotTimes.sublist(0, totalShotsNeeded);
    }
    if (_stage.shotRolls.length > totalShotsNeeded) {
      _stage.shotRolls = _stage.shotRolls.sublist(0, totalShotsNeeded);
    }
    if (_stage.shotStabilities.length > totalShotsNeeded) {
      _stage.shotStabilities =
          _stage.shotStabilities.sublist(0, totalShotsNeeded);
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
    }
  }

  Future<void> _syncToWatch() async {
    _saveStage(exitScreen: false);
    context.read<MatchProvider>().syncActiveStageToWatch();

    final kestrelProvider = context.read<KestrelProvider>();
    if (kestrelProvider.connectionState != KestrelConnectionState.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Kestrel not connected. Synced to Watch only.')),
      );
      return;
    }

    if (_stage.targetArrays.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final targetCount = _stage.targetArrays.length.clamp(1, 10);
      final array0 = _stage.targetArrays[0];

      for (int i = 1; i < targetCount; i++) {
        _extrapolateWindForArray(i);
      }

      // Push target inputs then read solution (Link app cmd 137 — one round trip per slot).
      // Reference app polls ~1s; we allow 4s per slot. Phase-2 calc is fallback only.
      for (int i = 0; i < targetCount; i++) {
        if (!mounted) return;

        final array = _stage.targetArrays[i];
        final rangeYards = _parseRangeYards(array.distance);
        final dof = _parseDof(array.degreeOfFire);
        final inc = double.tryParse(array.inclination) ?? 0.0;
        final windDir = _absoluteWindBearingForArray(i);
        final wind1 = array0.minWindSpeed;
        final wind2 = array0.maxWindSpeed;

        debugPrint(
          '[Kestrel Sync] target $i: rng=${rangeYards}yd dof=$dof inc=$inc '
          'wind=$wind1-$wind2 mph wd=${windDir.toStringAsFixed(0)}° '
          '(${TargetArray.formatClockSlot(TargetArray.degreesToClockSlot(windDir))})',
        );

        var result = await _sendAndWaitForBalSolution(
          provider: kestrelProvider,
          targetNumber: i,
          send: () => kestrelProvider.sendCmdSetBalFullInputs(
            targetNumber: i,
            targetRangeYards: rangeYards,
            directionOfFire: dof,
            windSpeed1Mph: wind1,
            windSpeed2Mph: wind2,
            windDirection: windDir,
            inclinationAngle: inc,
          ),
        );

        if (!_hasBalSolution(result)) {
          debugPrint(
              '[Kestrel Sync] target $i: no solution from set inputs, trying calc');
          result = await _sendAndWaitForBalSolution(
            provider: kestrelProvider,
            targetNumber: i,
            timeout: const Duration(seconds: 3),
            send: () => kestrelProvider.sendCalcFullSolution(targetNumber: i),
          );
        }
        setState(() => _applyBalResultToArray(i, result));
      }

      _saveStage(exitScreen: false);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synced to Watch and Kestrel!')),
        );
        if (_planScrollController.hasClients) {
          _planScrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          );
        }
      }
    } catch (e) {
      debugPrint('[StageDetailScreen] _syncToWatch error: $e');
      if (mounted) {
        Navigator.pop(context); // dismiss spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sync error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
          appBar: GlobalAppBar(
            title: Text(_stage.name.isNotEmpty
                ? _stage.name
                : 'Stage ${widget.stageNumber} Setup'),
            bottom: TabBar(
              controller: _tabController,
              onTap: (index) => HapticFeedback.lightImpact(),
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
      ),
    );
  }

  // PLAN TAB
  Widget _buildPlanTab() {
    return SingleChildScrollView(
      controller: _planScrollController,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stage Name Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                controller: _stageNameController,
                onTap: () => HapticFeedback.lightImpact(),
                textCapitalization: TextCapitalization.words,
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

          // Target Config Card (Target Arrays)
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Text(
                          'TARGET ARRAYS',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                              color: Color(0xFF007AFF)),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Array'),
                        onPressed: () {
                          setState(() {
                            _stage.targetArrays.add(TargetArray(
                              distance: '',
                              degreeOfFire: '0°',
                              targets: [
                                Target(
                                  index: 1,
                                  size: '',
                                  distance: '',
                                  degreeOfFire: '',
                                  type: 'IPSC',
                                  shotsCount: 1,
                                ),
                              ],
                            ));
                            _adjustShotResultsLength();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_stage.targetArrays.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          'No target arrays defined. Add one above.',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ),
                    ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _stage.targetArrays.length,
                    itemBuilder: (context, arrayIdx) {
                      final array = _stage.targetArrays[arrayIdx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6.0, vertical: 8.0),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'ARRAY ${arrayIdx + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Color(0xFF007AFF),
                                      ),
                                    ),
                                    if (context.watch<Rx5000Provider>().isConnected && _getRangeFocusNode(array).hasFocus)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 6.0),
                                        child: Icon(Icons.track_changes, color: Colors.redAccent, size: 14),
                                      ),
                                  ],
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.delete_sweep,
                                      color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _stage.targetArrays.removeAt(arrayIdx);
                                      _adjustShotResultsLength();
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: TextFormField(
                                    controller: _getRangeController(array),
                                    focusNode: _getRangeFocusNode(array),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textInputAction: TextInputAction.next,
                                    onTap: () => HapticFeedback.lightImpact(),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      labelText: 'Range',
                                      suffixText: 'YD',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      labelStyle: TextStyle(fontSize: 12),
                                      suffixStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    onChanged: (val) {
                                      array.distance = val.isEmpty ? '0 YD' : '$val YD';
                                    },
                                    onFieldSubmitted: (_) {
                                      _saveStage(exitScreen: false);
                                      _getIncFocusNode(array).requestFocus();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _getDofController(array),
                                    readOnly: true,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      _showCompassDialog(array, arrayIdx);
                                    },
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      labelText: 'DoF',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      labelStyle: TextStyle(fontSize: 12),
                                      suffixIcon: Icon(Icons.compass_calibration, size: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _getIncController(array),
                                    focusNode: _getIncFocusNode(array),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                    textInputAction: arrayIdx < _stage.targetArrays.length - 1
                                        ? TextInputAction.next
                                        : TextInputAction.done,
                                    onTap: () => HapticFeedback.lightImpact(),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      labelText: 'Inc',
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      labelStyle: TextStyle(fontSize: 12),
                                    ),
                                    onChanged: (val) {
                                      array.inclination = val.isEmpty ? '0' : val;
                                    },
                                    onFieldSubmitted: (_) {
                                      _saveStage(exitScreen: false);
                                      if (arrayIdx < _stage.targetArrays.length - 1) {
                                        final nextArray = _stage.targetArrays[arrayIdx + 1];
                                        _getRangeFocusNode(nextArray).requestFocus();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: Colors.white10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TARGETS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Add Target',
                                      style: TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    setState(() {
                                      array.targets.add(Target(
                                        index: array.targets.length + 1,
                                        size: '',
                                        distance: '',
                                        degreeOfFire: '',
                                        type: 'IPSC',
                                        shotsCount: 1,
                                      ));
                                      _adjustShotResultsLength();
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: array.targets.length,
                              itemBuilder: (context, targetIdx) {
                                final target = array.targets[targetIdx];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        'T${targetIdx + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        flex: 11,
                                        child: _buildShapeButton(target),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        flex: 5,
                                        child: TextFormField(
                                          key: Key(
                                              'tgt_size_${arrayIdx}_${targetIdx}_${target.size}'),
                                          initialValue: target.size.replaceAll(
                                              RegExp(r'[^0-9.]'), ''),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          onTap: () =>
                                              HapticFeedback.lightImpact(),
                                          style: const TextStyle(fontSize: 12),
                                          decoration: const InputDecoration(
                                            labelText: 'Size',
                                            suffixText: 'MIL',
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 4, vertical: 6),
                                            labelStyle: TextStyle(fontSize: 10),
                                            suffixStyle: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          onChanged: (val) {
                                            target.size =
                                                val.isEmpty ? '' : '$val MIL';
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        flex: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.white10),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${target.shotsCount} ${target.shotsCount == 1 ? 'Shot' : 'Shots'}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.redAccent, size: 18),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          setState(() {
                                            array.targets.removeAt(targetIdx);
                                            // Reindex targets inside array
                                            for (int k = 0;
                                                k < array.targets.length;
                                                k++) {
                                              array.targets[k] = Target(
                                                index: k + 1,
                                                size: array.targets[k].size,
                                                distance: '',
                                                degreeOfFire: '',
                                                type: array.targets[k].type,
                                                shotsCount:
                                                    array.targets[k].shotsCount,
                                              );
                                            }
                                            _adjustShotResultsLength();
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Colors.white10),
                            const SizedBox(height: 12),
                            if (arrayIdx == 0)
                              _buildTargetArray0WindConfig(array)
                            else
                              _buildTargetArrayNWindConfig(array),
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

          // Timer Settings & Positions Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'STAGE CONFIGURATION',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                        color: Color(0xFF007AFF)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Timer Limit',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70),
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showTimePickerDialog();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121214),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined,
                                  size: 16, color: Color(0xFF007AFF)),
                              const SizedBox(width: 6),
                              Text(
                                '${_stage.timeLimit} seconds',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down,
                                  size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Number of Positions',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70),
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showPositionsSelector();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121214),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 16, color: Color(0xFF00E676)),
                              const SizedBox(width: 6),
                              Text(
                                '${_stage.numPositions} ${_stage.numPositions == 1 ? 'Position' : 'Positions'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down,
                                  size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Stage Round Count',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70),
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showRoundsPickerDialog();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121214),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.ads_click,
                                  size: 16, color: Color(0xFFFF9500)),
                              const SizedBox(width: 6),
                              Text(
                                '${_stage.plannedRoundCount} Rounds',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down,
                                  size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showCofSetupDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF007AFF).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFF007AFF),
                      side:
                          const BorderSide(color: Color(0xFF007AFF), width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.route_outlined),
                    label: Text(
                      _stage.shotTargetsSequence.isEmpty
                          ? 'Configure Course of Fire (COF)'
                          : 'Configure Course of Fire (COF) (${_stage.shotTargetsSequence.length} / ${_stage.plannedRoundCount} mapped)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121214),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Time Per Position',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        Text(
                          '${(_stage.timeLimit / _stage.numPositions).toStringAsFixed(1)}s',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E676),
                          ),
                        ),
                      ],
                    ),
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
                    'BALLISTICS',
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
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _syncToWatch();
            },
            icon: const Icon(Icons.sync),
            label: const Text('Sync Configuration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: const Color(0xFF007AFF),
              side: const BorderSide(color: Color(0xFF007AFF)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
    String displayStr;

    if (value.abs() < 0.00001) {
      displayStr = '0.00';
    } else {
      final dir = value < 0 ? 'L' : 'R';
      displayStr = '${value.abs().toStringAsFixed(2)} $dir';
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
                HapticFeedback.lightImpact();

                double next = step(value, -1);
                next = normalize(next);

                final dir = isZero(next) ? 'None' : (next < 0 ? 'L' : 'R');

                onChanged(next, dir);
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
              child: const Text(
                'L',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
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
                HapticFeedback.lightImpact();

                double next = step(value, 1);
                next = normalize(next);

                final dir = isZero(next) ? 'None' : (next < 0 ? 'L' : 'R');

                onChanged(next, dir);
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
              child: const Text(
                'R',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTimeMs(int ms) {
    final displayMs = ms > 0 ? ms + 999 : 0;
    final seconds = displayMs ~/ 1000;
    final milliseconds = (displayMs % 1000) ~/ 10;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${milliseconds.toString().padLeft(2, '0')}';
  }

  Widget _buildShootTab() {
    final showShotList = _stage.shotTimes.isNotEmpty;

    return Container(
      color: const Color(0xFF121214),
      padding: const EdgeInsets.all(24.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment:
            showShotList ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          if (!showShotList) ...[
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
          ],

          // Watch telemetry state card
          if (_stage.timeRemaining > 0 ||
              _stage.avgHeartRate > 0 ||
              _isShootTimerRunning)
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
                          _isShootTimerRunning && _currentShootTimeMs != null
                              ? _formatTimeMs(_currentShootTimeMs!)
                              : '${_stage.timeRemaining}s left',
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
                        const Text('Live Heart Rate',
                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          if (showShotList) ...[
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SHOT DETECTIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF007AFF),
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: _shootScrollController,
                itemCount: _stage.shotTimes.length,
                itemBuilder: (context, index) {
                  final shotTime = _stage.shotTimes[index];
                  final split = index == 0
                      ? shotTime
                      : shotTime - _stage.shotTimes[index - 1];
                  final targetName = _getTargetNameForShotIndex(index);
                  final sgPulseProvider = context.read<SgPulseProvider>();
                  final rollThreshold = sgPulseProvider.rollThreshold;

                  final roll = index < _stage.shotRolls.length
                      ? _stage.shotRolls[index]
                      : 0.0;
                  final sign = roll < 0 ? -1.0 : 1.0;
                  final truncatedRoll =
                      sign * ((roll.abs() * 10).floor() / 10.0);
                  final isWithinThreshold =
                      truncatedRoll.abs() <= rollThreshold;
                  final rollColor = roll == 0.0
                      ? Colors.grey
                      : (isWithinThreshold
                          ? const Color(0xFF30D158)
                          : (truncatedRoll < 0
                              ? const Color(0xFFFF453A)
                              : const Color(0xFF0A84FF)));

                  final hasRoll = index < _stage.shotRolls.length;
                  final hasStability = index < _stage.shotStabilities.length;
                  final rollVal = hasRoll ? _stage.shotRolls[index] : 0.0;
                  final stability =
                      hasStability ? _stage.shotStabilities[index] : 0.0;

                  Color stabilityColor = Colors.grey;
                  if (hasStability) {
                    if (stability <= sgPulseProvider.stabilityGreenZone) {
                      stabilityColor = const Color(0xFF30D158); // green
                    } else if (stability <=
                        sgPulseProvider.stabilityYellowZone) {
                      stabilityColor = const Color(0xFFFFD60A); // yellow
                    } else {
                      stabilityColor = const Color(0xFFFF453A); // red
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    color: Colors.white.withValues(alpha: 0.02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side: const BorderSide(color: Colors.white10, width: 1.0),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            const Color(0xFF007AFF).withValues(alpha: 0.1),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ),
                      title: Text(
                        targetName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: (!hasRoll && !hasStability)
                          ? null
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasRoll && rollVal != 0.0)
                                  Text(
                                    'Roll: ${truncatedRoll.toStringAsFixed(1)}° ${truncatedRoll < 0 ? "Left" : "Right"}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: rollColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (hasStability)
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                            text: 'Stability: ',
                                            style:
                                                TextStyle(color: Colors.grey)),
                                        TextSpan(
                                          text: stability.toStringAsFixed(1),
                                          style: TextStyle(
                                              color: stabilityColor,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${shotTime.toStringAsFixed(2)}s',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '+${split.toStringAsFixed(2)}s',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // REVIEW TAB - TARGET SPECIFIC SHOT LOGS
  Widget _buildReviewTab() {
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

          // Group targets inside array boxes
          ..._stage.targetArrays.asMap().entries.map((arrayEntry) {
            final arrayIdx = arrayEntry.key;
            final array = arrayEntry.value;

            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Array Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ARRAY ${arrayIdx + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF007AFF),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${array.distance.isEmpty ? "---" : array.distance} | ${array.degreeOfFire}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: Colors.white10),

                    if (array.targets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No targets in this array',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Targets list inside array
                    ...List.generate(array.targets.length, (targetIdxInside) {
                      final target = array.targets[targetIdxInside];
                      final List<int> shotIndices =
                          _getShotIndicesForTarget(arrayIdx, targetIdxInside);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'T${targetIdxInside + 1}: ${target.type}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF00E676),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      (target.size.isEmpty ||
                                              target.size
                                                  .replaceAll(
                                                      RegExp(r'[^0-9.]'), '')
                                                  .trim()
                                                  .isEmpty)
                                          ? '---'
                                          : target.size,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${target.shotsCount} ${target.shotsCount == 1 ? 'Shot' : 'Shots'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Render shot row for this target
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children:
                                  List.generate(shotIndices.length, (shotIdx) {
                                final globalShotIdx = shotIndices[shotIdx];

                                // Safety bounds check
                                if (globalShotIdx >=
                                    _stage.shotResults.length) {
                                  return const SizedBox();
                                }

                                final result =
                                    _stage.shotResults[globalShotIdx];
                                Color bgColor = Colors.grey[850]!;
                                Color borderColor =
                                    Colors.white70.withValues(alpha: 0.3);
                                Color embossedColor =
                                    Colors.white70.withValues(alpha: 0.15);
                                Color shotTimeColor = Colors.white;

                                if (result == 'hit') {
                                  bgColor = const Color(0xFF00E676)
                                      .withValues(alpha: 0.2);
                                  borderColor = const Color(0xFF00E676)
                                      .withValues(alpha: 0.3);
                                  embossedColor = const Color(0xFF00E676)
                                      .withValues(alpha: 0.60);
                                } else if (result == 'miss') {
                                  bgColor =
                                      Colors.redAccent.withValues(alpha: 0.2);
                                  borderColor =
                                      Colors.redAccent.withValues(alpha: 0.3);
                                  embossedColor =
                                      Colors.redAccent.withValues(alpha: 0.60);
                                } else if (result == 'timeOutMiss') {
                                  bgColor = Colors.grey.withValues(alpha: 0.2);
                                  borderColor =
                                      Colors.grey.withValues(alpha: 0.3);
                                  embossedColor =
                                      Colors.grey.withValues(alpha: 0.60);
                                }

                                final roll =
                                    globalShotIdx < _stage.shotRolls.length
                                        ? _stage.shotRolls[globalShotIdx]
                                        : 0.0;
                                final sign = roll < 0 ? -1.0 : 1.0;
                                final truncatedRoll =
                                    sign * ((roll.abs() * 10).floor() / 10.0);
                                final rollText = roll == 0.0
                                    ? '---'
                                    : '${truncatedRoll.toStringAsFixed(1)}°${truncatedRoll < 0 ? "L" : "R"}';
                                final sgPulseProvider =
                                    context.read<SgPulseProvider>();
                                final rollThreshold =
                                    sgPulseProvider.rollThreshold;
                                final isWithinThreshold =
                                    truncatedRoll.abs() <= rollThreshold;
                                final rollColor = roll == 0.0
                                    ? Colors.grey
                                    : (isWithinThreshold
                                        ? const Color(0xFF30D158)
                                        : (truncatedRoll < 0
                                            ? const Color(0xFFFF453A)
                                            : const Color(0xFF0A84FF)));

                                final hasStability = globalShotIdx <
                                    _stage.shotStabilities.length;
                                final stability = hasStability
                                    ? _stage.shotStabilities[globalShotIdx]
                                    : 0.0;
                                final stabilityText = hasStability
                                    ? 'S: ${stability.toStringAsFixed(1)}'
                                    : '---';
                                Color stabilityColor = Colors.grey;
                                if (hasStability) {
                                  if (stability <=
                                      sgPulseProvider.stabilityGreenZone) {
                                    stabilityColor =
                                        const Color(0xFF30D158); // green
                                  } else if (stability <=
                                      sgPulseProvider.stabilityYellowZone) {
                                    stabilityColor =
                                        const Color(0xFFFFD60A); // yellow
                                  } else {
                                    stabilityColor =
                                        const Color(0xFFFF453A); // red
                                  }
                                }

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          if (result == 'miss') {
                                            _stage.shotResults[globalShotIdx] =
                                                'hit';
                                          } else if (result == 'hit') {
                                            _stage.shotResults[globalShotIdx] =
                                                'timeOutMiss';
                                          } else {
                                            _stage.shotResults[globalShotIdx] =
                                                'miss';
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
                                            color: borderColor,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Embossed background number
                                            Text(
                                              '${globalShotIdx + 1}',
                                              style: TextStyle(
                                                fontSize: 36,
                                                fontWeight: FontWeight.w900,
                                                color: embossedColor,
                                                height: 1.0,
                                              ),
                                            ),
                                            // Foreground time
                                            if (_stage.shotTimes.length >
                                                globalShotIdx)
                                              Text(
                                                '${_stage.shotTimes[globalShotIdx].toStringAsFixed(1)}s',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: shotTimeColor,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      rollText,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: rollColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      stabilityText,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: stabilityColor,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                            if (targetIdxInside < array.targets.length - 1)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child:
                                    Divider(height: 1, color: Colors.white10),
                              ),
                          ],
                        ),
                      );
                    }),
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
                          GestureDetector(
                            onTapDown: (_) {
                              SystemSound.play(SystemSoundType.click);
                              HapticFeedback.lightImpact();
                            },
                            onTap: () {
                              setState(() {
                                if (_stage.timeRemaining > 0) {
                                  _stage.timeRemaining--;
                                  _timeRemainingController.text =
                                      '${_stage.timeRemaining}';
                                }
                              });
                            },
                            onLongPressStart: (_) {
                              _startRemainingTimeAutoIncrement(-1);
                            },
                            onLongPressEnd: (_) {
                              _stopRemainingTimeAutoIncrement();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4.0),
                              child: Icon(Icons.remove_circle_outline,
                                  color: Color(0xFF007AFF), size: 24),
                            ),
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
                          GestureDetector(
                            onTapDown: (_) {
                              SystemSound.play(SystemSoundType.click);
                              HapticFeedback.lightImpact();
                            },
                            onTap: () {
                              setState(() {
                                _stage.timeRemaining++;
                                _timeRemainingController.text =
                                    '${_stage.timeRemaining}';
                              });
                            },
                            onLongPressStart: (_) {
                              _startRemainingTimeAutoIncrement(1);
                            },
                            onLongPressEnd: (_) {
                              _stopRemainingTimeAutoIncrement();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4.0),
                              child: Icon(Icons.add_circle_outline,
                                  color: Color(0xFF007AFF), size: 24),
                            ),
                          ),
                        ],
                      ),
                      Container(height: 40, width: 1, color: Colors.white10),
                      // Avg Heart Rate (Long press to manually edit)
                      GestureDetector(
                        onLongPress: () {
                          HapticFeedback.lightImpact();
                          _showHeartRateInputDialog();
                        },
                        child: Column(
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
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 10)),
                          ],
                        ),
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
                      HapticFeedback.lightImpact();
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
                        // Reset COF sequence, shot times, rolls, stabilities, and restore default target shot counts
                        _stage.shotTargetsSequence = [];
                        _stage.shotTimes = [];
                        _stage.shotRolls = [];
                        _stage.shotStabilities = [];
                        for (var array in _stage.targetArrays) {
                          for (var target in array.targets) {
                            target.shotsCount = 1;
                          }
                        }
                        _adjustShotResultsLength();

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
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _saveStage(markAsCompleted: _stage.status != 'completed');
                  },
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
      if (dir == 'None') return '0.00 MIL';
      return '${val.toStringAsFixed(2)} MIL $dir';
    }
    return '---';
  }

  void _showCompassDialog(dynamic targetOrArray, [int? arrayIdx]) {
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
                            if (targetOrArray is Target) {
                              targetOrArray.degreeOfFire =
                                  '${displayHeading.round()}°';
                            } else if (targetOrArray is TargetArray) {
                              targetOrArray.degreeOfFire =
                                  '${displayHeading.round()}°';
                              _getDofController(targetOrArray).text = targetOrArray.degreeOfFire;
                              final idx = arrayIdx ??
                                  _stage.targetArrays.indexOf(targetOrArray);
                              if (idx > 0) {
                                _extrapolateWindForArray(idx);
                              }
                            }
                          });
                          _saveStage(exitScreen: false);
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
      onTap: () {
        HapticFeedback.lightImpact();
        _showShapeSelector(target);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Shape',
          labelStyle: TextStyle(fontSize: 10),
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                target.type,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showRoundsPickerDialog() {
    int tempRounds = _stage.plannedRoundCount;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('STAGE ROUND COUNT'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the total number of rounds planned for this stage.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: '$tempRounds',
                keyboardType: TextInputType.number,
                autofocus: true,
                onChanged: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null && parsed > 0) {
                    tempRounds = parsed;
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Round Count',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _stage.plannedRoundCount = tempRounds;
                  // Adjust sequence if it exceeds the new planned round count
                  if (_stage.shotTargetsSequence.length >
                      _stage.plannedRoundCount) {
                    _stage.shotTargetsSequence = _stage.shotTargetsSequence
                        .sublist(0, _stage.plannedRoundCount);
                    _adjustShotResultsLength();
                  }
                });
                _saveStage(exitScreen: false);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  List<String> _buildTargetTypeOptions(Match match) {
    final Set<String> allTypes = {};
    allTypes.addAll(_targetTypes.where((t) => t != 'Other'));
    allTypes.addAll(match.customTargetTypes);
    for (var stage in match.stages) {
      for (var t in stage.targets) {
        if (t.type.isNotEmpty && t.type != 'Other') {
          allTypes.add(t.type);
        }
      }
    }
    allTypes.removeAll(match.deletedTargetTypes);
    return allTypes.toList();
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
        final match = context.read<MatchProvider>().matches.firstWhere(
              (m) => m.id == widget.matchId,
            );
        var availableTypes = _buildTargetTypeOptions(match);
        final prefillText =
            (availableTypes.contains(target.type) || target.type == 'Other')
                ? ''
                : target.type;
        final TextEditingController customController = TextEditingController(
          text: prefillText,
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentMatch =
                context.read<MatchProvider>().matches.firstWhere(
                      (m) => m.id == widget.matchId,
                    );
            availableTypes = _buildTargetTypeOptions(currentMatch);
            final isCustomMode =
                !availableTypes.contains(target.type) || target.type == 'Other';

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
                        ...availableTypes.map((type) {
                          final isSelected = target.type == type;
                          return InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                target.type = type;
                              });
                              Navigator.pop(context);
                            },
                            onLongPress: () {
                              HapticFeedback.lightImpact();
                              _confirmDeleteTag(
                                  context, type, 'targetType', setModalState);
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
                            HapticFeedback.lightImpact();
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
                      onTap: () => HapticFeedback.lightImpact(),
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
                                    availableTypes.contains(originalType)
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
                                context
                                    .read<MatchProvider>()
                                    .addCustomTagToMatch(
                                        widget.matchId, text, 'targetType');
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

  void _showCofSetupDialog() {
    List<String> tempSequence = List.from(_stage.shotTargetsSequence);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isFull = tempSequence.length >= _stage.plannedRoundCount;

            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('COF TARGET SELECTOR'),
                  const SizedBox(height: 4),
                  Text(
                    'Tap targets in shooting order. Total limit: ${_stage.plannedRoundCount} rounds.',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status & Progress Bar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121214),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Course of Fire Sequence',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                '${tempSequence.length} / ${_stage.plannedRoundCount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isFull
                                      ? const Color(0xFF00E676)
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (tempSequence.isEmpty)
                            const Text(
                              'No targets tapped yet.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 11),
                            )
                          else
                            SizedBox(
                              height: 32,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: tempSequence.length,
                                itemBuilder: (context, index) {
                                  final key = tempSequence[index];
                                  final parts = key.split('_');
                                  String label = '?';
                                  if (parts.length == 2) {
                                    final int aIdx = int.parse(parts[0]);
                                    final int tIdx = int.parse(parts[1]);
                                    if (aIdx < _stage.targetArrays.length &&
                                        tIdx <
                                            _stage.targetArrays[aIdx].targets
                                                .length) {
                                      label = 'A${aIdx + 1}-T${tIdx + 1}';
                                    }
                                  }
                                  return Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF007AFF)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: const Color(0xFF007AFF)
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${index + 1}. ',
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          label,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Target arrays selection
                    if (_stage.targetArrays.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          'Please define target arrays first on the Plan page.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _stage.targetArrays.length,
                          itemBuilder: (context, arrayIdx) {
                            final array = _stage.targetArrays[arrayIdx];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: Colors.white.withValues(alpha: 0.01),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ARRAY ${arrayIdx + 1} (${array.distance.isEmpty ? "---" : array.distance})',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF007AFF)),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: List.generate(
                                          array.targets.length, (targetIdx) {
                                        final target = array.targets[targetIdx];
                                        final key = '${arrayIdx}_$targetIdx';

                                        // Count occurrences in current temp sequence
                                        final count = tempSequence
                                            .where((k) => k == key)
                                            .length;

                                        return ElevatedButton(
                                          onPressed: isFull
                                              ? null
                                              : () {
                                                  HapticFeedback.lightImpact();
                                                  setDialogState(() {
                                                    tempSequence.add(key);
                                                  });
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: count > 0
                                                ? const Color(0xFF00E676)
                                                    .withValues(alpha: 0.15)
                                                : Colors.white
                                                    .withValues(alpha: 0.05),
                                            side: BorderSide(
                                              color: count > 0
                                                  ? const Color(0xFF00E676)
                                                      .withValues(alpha: 0.4)
                                                  : Colors.white10,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'A${arrayIdx + 1}-T${targetIdx + 1} (${target.type})',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              if (count > 0)
                                                Text(
                                                  '$count ${count == 1 ? "shot" : "shots"}',
                                                  style: const TextStyle(
                                                      color: Color(0xFF00E676),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setDialogState(() {
                      tempSequence.clear();
                    });
                  },
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: const Text('Reset'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _stage.shotTargetsSequence = tempSequence;
                      _adjustShotResultsLength();
                    });
                    _saveStage(exitScreen: false);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
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
              onPressed: () {
                HapticFeedback.lightImpact();
                _showErrorTagSelector(title, selectedTags, errorType);
              },
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
                        HapticFeedback.lightImpact();
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
                          HapticFeedback.lightImpact();
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
                          HapticFeedback.lightImpact();
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
                          onTap: () => HapticFeedback.lightImpact(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'e.g. forgot wind hold...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
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
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
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
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
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

  void _showTimePickerDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) =>
          MobileTimePickerDialog(initialTime: _stage.timeLimit),
    );
    if (result != null) {
      setState(() {
        _stage.timeLimit = result;
      });
      _syncToWatch();
    }
  }

  void _showPositionsSelector() {
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
                'SELECT NUMBER OF POSITIONS',
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
                  crossAxisCount: 6,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final positions = index + 1;
                  final isSelected = _stage.numPositions == positions;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _stage.numPositions = positions;
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
                          '$positions',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class MobileTimePickerDialog extends StatefulWidget {
  final int initialTime;

  const MobileTimePickerDialog({super.key, required this.initialTime});

  @override
  State<MobileTimePickerDialog> createState() => _MobileTimePickerDialogState();
}

class _MobileTimePickerDialogState extends State<MobileTimePickerDialog> {
  late int _selectedTime;
  late int _presetA;
  late int _presetB;
  Timer? _autoIncrementTimer;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime.clamp(5, 600);
    final box = Hive.box('matchesBox');
    _presetA = box.get("PRESET_CUSTOM_A") ?? 105;
    _presetB = box.get("PRESET_CUSTOM_B") ?? 120;
  }

  @override
  void dispose() {
    _autoIncrementTimer?.cancel();
    super.dispose();
  }

  void _startAutoIncrement(int val) {
    _autoIncrementTimer?.cancel();
    _autoIncrementTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _selectedTime = (_selectedTime + val).clamp(5, 600);
      });
    });
  }

  void _stopAutoIncrement() {
    _autoIncrementTimer?.cancel();
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString()}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _savePresetA() {
    final box = Hive.box('matchesBox');
    setState(() {
      _presetA = _selectedTime;
    });
    box.put("PRESET_CUSTOM_A", _presetA);
  }

  void _savePresetB() {
    final box = Hive.box('matchesBox');
    setState(() {
      _presetB = _selectedTime;
    });
    box.put("PRESET_CUSTOM_B", _presetB);
  }

  Widget _buildPresetButton(String label, int value) {
    return ElevatedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedTime = value;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white10,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildCustomPresetButton({
    required String label,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.lightImpact();
        onLongPress();
      },
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF).withValues(alpha: 0.2),
          foregroundColor: const Color(0xFF007AFF),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF007AFF)),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildAdjustButton({
    required IconData icon,
    required int delta,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPressStart: (_) => _startAutoIncrement(delta),
      onLongPressEnd: (_) => _stopAutoIncrement(),
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SET TIMER DURATION',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF007AFF),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPresetButton("30s", 30),
                const SizedBox(width: 8),
                _buildPresetButton("60s", 60),
                const SizedBox(width: 8),
                _buildPresetButton("90s", 90),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAdjustButton(
                  icon: Icons.remove,
                  delta: -1,
                  onTap: () {
                    setState(() {
                      _selectedTime = (_selectedTime - 1).clamp(5, 600);
                    });
                  },
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_selectedTime}s',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _formatTime(_selectedTime),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                _buildAdjustButton(
                  icon: Icons.add,
                  delta: 1,
                  onTap: () {
                    setState(() {
                      _selectedTime = (_selectedTime + 1).clamp(5, 600);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'HOLD TO SAVE NEW PRESET',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCustomPresetButton(
                  label: '${_presetA}s',
                  onTap: () {
                    setState(() {
                      _selectedTime = _presetA;
                    });
                  },
                  onLongPress: _savePresetA,
                ),
                const SizedBox(width: 12),
                _buildCustomPresetButton(
                  label: '${_presetB}s',
                  onTap: () {
                    setState(() {
                      _selectedTime = _presetB;
                    });
                  },
                  onLongPress: _savePresetB,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selectedTime),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}




