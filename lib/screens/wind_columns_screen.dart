import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:matchday/models/match.dart';
import 'package:matchday/providers/match_provider.dart';
import 'package:matchday/features/kestrel_ble/providers/kestrel_provider.dart';
import 'package:matchday/features/kestrel_ble/models/kestrel_device.dart';
import 'package:matchday/widgets/wind_clock_picker.dart';

class WindColumnsScreen extends StatefulWidget {
  final String matchId;
  final Stage stage;

  const WindColumnsScreen({
    super.key,
    required this.matchId,
    required this.stage,
  });

  @override
  State<WindColumnsScreen> createState() => _WindColumnsScreenState();
}

class _WindColumnsScreenState extends State<WindColumnsScreen> {
  late String _mode;
  late List<double> _values;
  bool _isBuilding = false;
  double _buildProgress = 0.0;
  String _progressText = '';

  // Controllers for MPH columns editing
  final List<TextEditingController> _mphControllers = [];

  // Clock slots for Angle columns editing (0-23 clock slots)
  final List<int> _angleClockSlots = [];

  @override
  void initState() {
    super.initState();
    _mode = widget.stage.windColumns.mode;
    _values = List.from(widget.stage.windColumns.values);
    _initializeEditors();
  }

  void _initializeEditors() {
    for (var c in _mphControllers) {
      c.dispose();
    }
    _mphControllers.clear();
    _angleClockSlots.clear();

    if (_mode == 'mph') {
      for (var val in _values) {
        _mphControllers.add(TextEditingController(text: val.toStringAsFixed(0)));
      }
    } else {
      for (var val in _values) {
        _angleClockSlots.add(TargetArray.degreesToClockSlot(val));
      }
    }
  }

  @override
  void dispose() {
    for (var c in _mphControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyPresets(String type) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (type == 'angle') {
        _mode = 'angle';
        _values = [300.0, 330.0, 0.0, 30.0, 60.0];
      } else {
        _mode = 'mph';
        _values = [4.0, 8.0, 12.0, 16.0];
      }
      _initializeEditors();
    });
  }

  void _addColumn() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_mode == 'mph') {
        _values.add(10.0);
        _mphControllers.add(TextEditingController(text: '10'));
      } else {
        _values.add(0.0);
        _angleClockSlots.add(0);
      }
    });
  }

  void _removeColumn(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _values.removeAt(index);
      if (_mode == 'mph') {
        _mphControllers[index].dispose();
        _mphControllers.removeAt(index);
      } else {
        _angleClockSlots.removeAt(index);
      }
    });
  }

  Future<void> _buildMatrix() async {
    final kestrelProvider = context.read<KestrelProvider>();
    final matchProvider = context.read<MatchProvider>();
    if (kestrelProvider.connectionState != KestrelConnectionState.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kestrel not connected. Please connect in Settings first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Save edited values first
    if (_mode == 'mph') {
      final newValues = <double>[];
      for (var ctrl in _mphControllers) {
        newValues.add(double.tryParse(ctrl.text) ?? 8.0);
      }
      _values = newValues;
    } else {
      final newValues = <double>[];
      for (var slot in _angleClockSlots) {
        newValues.add(TargetArray.clockSlotToDegrees(slot));
      }
      _values = newValues;
    }

    setState(() {
      _isBuilding = true;
      _buildProgress = 0.0;
      _progressText = 'Starting calculations...';
    });

    // Show custom progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Keep dialog state in sync with parent calculation variables
            Timer.periodic(const Duration(milliseconds: 150), (timer) {
              if (!_isBuilding && Navigator.of(context).canPop()) {
                timer.cancel();
                Navigator.of(context).pop();
              } else {
                setDialogState(() {});
              }
            });
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF007AFF)),
                    const SizedBox(height: 20),
                    Text(
                      _progressText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 6,
                        width: double.infinity,
                        child: LinearProgressIndicator(
                          value: _buildProgress,
                          backgroundColor: Colors.white10,
                          color: const Color(0xFF007AFF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final results = Map<String, String>.from(widget.stage.windColumns.results);
    final totalSteps = _values.length * widget.stage.targetArrays.length;
    int completedSteps = 0;

    try {
      for (int c = 0; c < _values.length; c++) {
        final colValue = _values[c];

        for (int a = 0; a < widget.stage.targetArrays.length; a++) {
          final array = widget.stage.targetArrays[a];
          
          setState(() {
            _progressText = _mode == 'mph'
                ? 'Solving Array ${a + 1} (${array.distance} YD) at ${colValue.toStringAsFixed(0)} mph...'
                : 'Solving Array ${a + 1} (${array.distance} YD) at wind angle ${TargetArray.formatClockSlot(_angleClockSlots[c])}...';
            _buildProgress = completedSteps / totalSteps;
          });

          final rangeYards = double.tryParse(array.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
          final dof = double.tryParse(array.degreeOfFire) ?? 0.0;
          final inc = double.tryParse(array.inclination) ?? 0.0;

          double wind1 = 0.0;
          double wind2 = 0.0;
          double windDirDegrees = 0.0;

          if (_mode == 'mph') {
            wind1 = colValue;
            wind2 = colValue;
            final slot = TargetArray.migrateWindClockSlot(array.windClockDirection);
            windDirDegrees = TargetArray.clockSlotToDegrees(slot);
          } else {
            wind1 = array.minWindSpeed;
            wind2 = array.maxWindSpeed;
            windDirDegrees = colValue;
          }

          final solution = await _sendAndWaitForBalSolution(
            provider: kestrelProvider,
            targetNumber: a,
            send: () => kestrelProvider.sendCmdSetBalFullInputs(
              targetNumber: a,
              targetRangeYards: rangeYards,
              directionOfFire: dof,
              windSpeed1Mph: wind1,
              windSpeed2Mph: wind2,
              windDirection: windDirDegrees,
              inclinationAngle: inc,
              targetSpeedMph: 0.0,
            ),
          );

          final w1 = (solution['windage1'] as num).toDouble();
          final w2 = (solution['windage2'] as num).toDouble();
          final valStr = TargetArray.formatWindagePair(w1, w2);

          results['${a}_$c'] = valStr;
          completedSteps++;
        }
      }

      if (!mounted) return;

      setState(() {
        _buildProgress = 1.0;
        _progressText = 'Done!';
        widget.stage.windColumns.mode = _mode;
        widget.stage.windColumns.values = _values;
        widget.stage.windColumns.results = results;
      });

      matchProvider.updateStage(widget.matchId, widget.stage);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wind Columns built successfully!'),
          backgroundColor: Color(0xFF00E676),
        ),
      );
    } catch (e) {
      debugPrint('[WindColumnsScreen] Build error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error building columns: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() {
        _isBuilding = false;
      });
    }
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

  Widget _buildAngleSelector(int index) {
    final currentSlot = _angleClockSlots[index];
    return InkWell(
      onTap: () async {
        HapticFeedback.lightImpact();
        final picked = await showWindClockPickerDialog(
          context,
          initialSlot: currentSlot,
        );
        if (picked == null || !mounted) return;
        setState(() {
          _angleClockSlots[index] = picked;
          _values[index] = TargetArray.clockSlotToDegrees(picked);
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              TargetArray.formatClockSlot(currentSlot),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = widget.stage.windColumns.results.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Wind Columns Builder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF1E1E24),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Color(0xFF007AFF)),
            onPressed: _isBuilding ? null : _buildMatrix,
            tooltip: 'Build Matrix',
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mode Select
                  Card(
                    color: const Color(0xFF1E1E24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Mode',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
                          ),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Angle', style: TextStyle(fontSize: 11)),
                                selected: _mode == 'angle',
                                onSelected: (_) {
                                  if (_mode == 'angle') return;
                                  _applyPresets('angle');
                                },
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text('MPH', style: TextStyle(fontSize: 11)),
                                selected: _mode == 'mph',
                                onSelected: (_) {
                                  if (_mode == 'mph') return;
                                  _applyPresets('mph');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Config Section
                  Card(
                    color: const Color(0xFF1E1E24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'COLUMNS SETUP',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                              ),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _applyPresets(_mode),
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text('Reset', style: TextStyle(fontSize: 11)),
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  ),
                                  TextButton.icon(
                                    onPressed: _addColumn,
                                    icon: const Icon(Icons.add, size: 14),
                                    label: const Text('Add', style: TextStyle(fontSize: 11)),
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_values.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('No columns configured.', style: TextStyle(color: Colors.white24, fontSize: 12)),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(_values.length, (index) {
                                return Container(
                                  padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4, right: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'C${index + 1}: ',
                                        style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      if (_mode == 'mph')
                                        SizedBox(
                                          width: 48,
                                          height: 24,
                                          child: TextField(
                                            controller: _mphControllers[index],
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            decoration: const InputDecoration(
                                              suffixText: ' mph',
                                              suffixStyle: TextStyle(fontSize: 9, color: Colors.grey),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        )
                                      else
                                        _buildAngleSelector(index),
                                      const SizedBox(width: 2),
                                      IconButton(
                                        onPressed: () => _removeColumn(index),
                                        icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 14),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Calculated Grid Table
                  if (hasResults) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        'GRID SOLUTIONS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Card(
                        color: const Color(0xFF1E1E24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: DataTable(
                          columnSpacing: 20,
                          horizontalMargin: 12,
                          headingRowHeight: 36,
                          dataRowMinHeight: 32,
                          dataRowMaxHeight: 44,
                          columns: [
                            const DataColumn(
                              label: Text('Range', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                            const DataColumn(
                              label: Text('Elevation', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                            ...List.generate(widget.stage.windColumns.values.length, (colIdx) {
                              final colVal = widget.stage.windColumns.values[colIdx];
                              String labelStr;
                              if (widget.stage.windColumns.mode == 'mph') {
                                labelStr = '${colVal.toStringAsFixed(0)} mph';
                              } else {
                                final slot = TargetArray.degreesToClockSlot(colVal);
                                labelStr = TargetArray.formatClockSlot(slot);
                              }
                              return DataColumn(
                                label: Text(labelStr, style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 11)),
                              );
                            }),
                          ],
                          rows: List.generate(widget.stage.targetArrays.length, (arrayIdx) {
                            final array = widget.stage.targetArrays[arrayIdx];
                            
                            // Distance display: clean range e.g. "450 yd"
                            final displayDistance = array.distance;
                            
                            // Elevation display: clean elevation e.g. "2.3 MIL"
                            final displayElevation = array.elevationResult.isNotEmpty
                                ? array.elevationResult.replaceAll(' MIL', '')
                                : '—';

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    displayDistance.isNotEmpty ? displayDistance : '—',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    displayElevation,
                                    style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                                ...List.generate(widget.stage.windColumns.values.length, (colIdx) {
                                  final cellValue = widget.stage.windColumns.results['${arrayIdx}_$colIdx'] ?? '—';
                                  return DataCell(
                                    Text(
                                      cellValue.replaceAll(' MIL', ''), // strip MIL for cleaner grid spacing
                                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                                    ),
                                  );
                                }),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Sticky Bottom build button to make sure it always fits
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              onPressed: _isBuilding ? null : _buildMatrix,
              icon: const Icon(Icons.flash_on, size: 16),
              label: const Text('BUILD MATRIX FROM KESTREL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
