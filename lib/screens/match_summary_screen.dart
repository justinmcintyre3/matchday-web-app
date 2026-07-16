import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../providers/match_provider.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/performance_charts.dart';
import '../features/sg_pulse/providers/sg_pulse_provider.dart';

class MatchSummaryScreen extends StatefulWidget {
  final String matchId;

  const MatchSummaryScreen({
    super.key,
    required this.matchId,
  });

  @override
  State<MatchSummaryScreen> createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<MatchSummaryScreen> {
  late TextEditingController _winnerHitsController;
  late TextEditingController _positionController;
  late TextEditingController _notesController;
  late List<TextEditingController> _stageTimeControllers;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<MatchProvider>();
    final match = provider.matches.firstWhere((m) => m.id == widget.matchId);
    _winnerHitsController =
        TextEditingController(text: match.winnerHits?.toString() ?? '');
    _positionController =
        TextEditingController(text: match.position?.toString() ?? '');
    _notesController = TextEditingController(text: match.matchNotes ?? '');

    _stageTimeControllers = match.stages.map((stage) {
      final timeTaken = stage.timeLimit - stage.timeRemaining;
      return TextEditingController(text: '$timeTaken');
    }).toList();

    final hasData = match.winnerHits != null ||
        match.position != null ||
        (match.matchNotes != null && match.matchNotes!.isNotEmpty);
    _isEditing = !hasData;
  }

  @override
  void dispose() {
    _winnerHitsController.dispose();
    _positionController.dispose();
    _notesController.dispose();
    for (var controller in _stageTimeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saveDetails() {
    final provider = context.read<MatchProvider>();
    final match = provider.matches.firstWhere((m) => m.id == widget.matchId);

    // Save stage times back to the stage objects in the match
    for (int i = 0; i < match.stages.length; i++) {
      if (i < _stageTimeControllers.length) {
        final stage = match.stages[i];
        final newTimeTaken = int.tryParse(_stageTimeControllers[i].text.trim()) ??
            (stage.timeLimit - stage.timeRemaining);
        stage.timeRemaining =
            (stage.timeLimit - newTimeTaken).clamp(0, stage.timeLimit);
      }
    }

    final winnerHitsVal = int.tryParse(_winnerHitsController.text.trim());
    final positionVal = int.tryParse(_positionController.text.trim());
    final notesVal = _notesController.text.trim();

    provider.updateMatchDetails(
      widget.matchId,
      winnerHits: winnerHitsVal,
      position: positionVal,
      matchNotes: notesVal,
    );

    setState(() {
      _isEditing = false;
    });
  }

  String _getOrdinal(int number) {
    if (number <= 0) return 'N/A';
    final remainder10 = number % 10;
    final remainder100 = number % 100;
    if (remainder10 == 1 && remainder100 != 11) {
      return '${number}st';
    } else if (remainder10 == 2 && remainder100 != 12) {
      return '${number}nd';
    } else if (remainder10 == 3 && remainder100 != 13) {
      return '${number}rd';
    } else {
      return '${number}th';
    }
  }

  Map<String, int> _getErrorFrequency(List<Stage> stages, String category) {
    final Map<String, int> counts = {};
    for (var stage in stages) {
      String rawErrors = '';
      if (category == 'mental') {
        rawErrors = stage.mentalErrors;
      } else if (category == 'skills') {
        rawErrors = stage.skillsErrors;
      } else if (category == 'env') {
        rawErrors = stage.environmentalErrors;
      }

      if (rawErrors.isEmpty) continue;
      final tags =
          rawErrors.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty);
      for (var tag in tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    // Sort map by value descending
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries);
  }

  @override
  Widget build(BuildContext context) {
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
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
            _saveDetails();
          }
        },
        child: Scaffold(
          appBar: GlobalAppBar(
            title: const Text('Match Summary'),
            actions: [
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _saveDetails();
                  FocusScope.of(context).unfocus();
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          body: Consumer<MatchProvider>(
            builder: (context, provider, child) {
              final match = provider.matches.firstWhere(
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

              if (match.id.isEmpty) {
                return const Center(child: Text('Match not found.'));
              }

              final totalHits = match.totalHits;
              final totalShots = match.totalShotsTaken;
              final ourPercent =
                  totalShots > 0 ? (totalHits / totalShots * 100) : 0.0;

              final winnerHits = match.winnerHits;
              final winnerPercent = (winnerHits != null && winnerHits > 0)
                  ? (totalHits / winnerHits * 100)
                  : null;

              final position = match.position;
              final positionText =
                  position != null ? _getOrdinal(position) : 'N/A';

              // Calculate misses details
              int normalMisses = 0;
              int timeoutMisses = 0;
              for (var stage in match.stages) {
                normalMisses +=
                    stage.shotResults.where((r) => r == 'miss').length;
                timeoutMisses +=
                    stage.shotResults.where((r) => r == 'timeOutMiss').length;
              }
              final totalMisses = normalMisses + timeoutMisses;

              // Get error frequencies
              final completedStages =
                  match.stages.where((s) => s.status == 'completed').toList();
              final mentalFreq = _getErrorFrequency(completedStages, 'mental');
              final skillsFreq = _getErrorFrequency(completedStages, 'skills');
              final envFreq = _getErrorFrequency(completedStages, 'env');

              final heartRateStages =
                  completedStages.where((s) => s.avgHeartRate > 0).toList();
              final double avgHeartRate = heartRateStages.isNotEmpty
                  ? heartRateStages.fold(
                          0.0, (sum, stage) => sum + stage.avgHeartRate) /
                      heartRateStages.length
                  : 0.0;

              final maxHeartRateStages =
                  completedStages.where((s) => s.maxHeartRate > 0).toList();
              final int maxHeartRate = maxHeartRateStages.isNotEmpty
                  ? maxHeartRateStages.map((s) => s.maxHeartRate).reduce((a, b) => a > b ? a : b)
                  : 0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Match Header Info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(match.location,
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined,
                                        size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('MMM d, yyyy').format(match.date),
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Standings Entry Card
                    if (_isEditing) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MATCH STANDINGS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF007AFF),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Winner\'s Impacts',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white70)),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _winnerHitsController,
                                          keyboardType: TextInputType.number,
                                          onTap: () => HapticFeedback.lightImpact(),
                                          decoration: const InputDecoration(
                                            hintText: 'e.g. 78',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Our Standing',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white70)),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _positionController,
                                          keyboardType: TextInputType.number,
                                          onTap: () => HapticFeedback.lightImpact(),
                                          decoration: const InputDecoration(
                                            hintText: 'e.g. 12',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                        ),
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
                    ],

                    // Key Performance Indicators Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PERFORMANCE STATISTICS',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF00E676),
                                  letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                  child: _buildMetricItem(
                                    'Score / Impact %',
                                    '${ourPercent.toStringAsFixed(1)}%',
                                    '$totalHits / $totalShots Impacts',
                                    const Color(0xFF00E676),
                                  ),
                                ),
                                Expanded(
                                  child: _buildMetricItem(
                                    '% to Winner',
                                    winnerPercent != null
                                        ? '${winnerPercent.toStringAsFixed(1)}%'
                                        : 'N/A',
                                    winnerHits != null
                                        ? 'Winner: $winnerHits'
                                        : 'Winner hits empty',
                                    const Color(0xFF00E676),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                  child: _buildMetricItem(
                                    'Final Position',
                                    positionText,
                                    '',
                                    Colors.blueAccent,
                                  ),
                                ),
                                Expanded(
                                  child: _buildMetricItem(
                                    'Heart Rate',
                                    avgHeartRate > 0
                                        ? Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '${avgHeartRate.round()} BPM',
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.redAccent),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.favorite,
                                                  size: 16,
                                                  color: Colors.redAccent),
                                            ],
                                          )
                                        : const Text(
                                            '--',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.redAccent),
                                          ),
                                    maxHeartRate > 0
                                        ? Text.rich(
                                            TextSpan(
                                              text: 'Max: ',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600]),
                                              children: [
                                                TextSpan(
                                                  text: '$maxHeartRate BPM',
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.redAccent),
                                                ),
                                              ],
                                            ),
                                          )
                                        : '',
                                    Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32, color: Colors.white10),
                            const Text(
                              'TARGET MISS BREAKDOWN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildMissDetailBox(
                                  'Normal Misses',
                                  '$normalMisses',
                                  Colors.redAccent,
                                  flex: 7,
                                  verticalPadding: 10,
                                  minHeight: 68,
                                ),
                                const SizedBox(width: 12),
                                _buildMissDetailBox(
                                  'Total Misses',
                                  '$totalMisses',
                                  Colors.orangeAccent,
                                  flex: 8,
                                  verticalPadding: 26,
                                  minHeight: 100,
                                ),
                                const SizedBox(width: 12),
                                _buildMissDetailBox(
                                  'Missed for Timeout',
                                  '$timeoutMisses',
                                  Colors.grey,
                                  flex: 7,
                                  verticalPadding: 10,
                                  minHeight: 68,
                                ),
                              ],
                            ),
                            const Divider(height: 32, color: Colors.white10),
                            _buildOverallPerformanceChartsSection(match),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stage Performance Breakdown Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'STAGE PERFORMANCE BREAKDOWN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF007AFF),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: match.stages.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 24, color: Colors.white10),
                              itemBuilder: (context, index) {
                                final stage = match.stages[index];
                                final stageHits = stage.hitCount;
                                final stageShots = stage.shotResults.length;
                                final stageImpactPct = stageShots > 0
                                    ? (stageHits / stageShots * 100)
                                    : 0.0;
                                final stageTimeouts = stage.shotResults.where((r) => r == 'timeOutMiss').length;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stage.name.isNotEmpty
                                          ? 'Stage ${stage.stageNumber}: ${stage.name}'
                                          : 'Stage ${stage.stageNumber}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              const Text(
                                                'Time',
                                                style: TextStyle(fontSize: 10, color: Colors.grey),
                                              ),
                                              const SizedBox(height: 4),
                                              _isEditing
                                                  ? SizedBox(
                                                      width: 60,
                                                      height: 32,
                                                      child: TextFormField(
                                                        controller: _stageTimeControllers[index],
                                                        keyboardType: TextInputType.number,
                                                        onTap: () => HapticFeedback.lightImpact(),
                                                        textAlign: TextAlign.center,
                                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                                        decoration: const InputDecoration(
                                                          contentPadding: EdgeInsets.zero,
                                                          border: OutlineInputBorder(),
                                                        ),
                                                      ),
                                                    )
                                                  : Text(
                                                      '${stage.timeLimit - stage.timeRemaining}s',
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white70),
                                                    ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildStageMetric(
                                            'HR',
                                            stage.avgHeartRate > 0
                                                ? '${stage.avgHeartRate}/${stage.maxHeartRate} BPM'
                                                : '--',
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildStageMetric(
                                            'Score',
                                            '${stage.hitCount}/${stage.shotResults.length}',
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildStageMetric(
                                            'Impact %',
                                            '${stageImpactPct.toStringAsFixed(1)}%',
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildStageMetric(
                                            'Timeouts',
                                            '$stageTimeouts',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Errors Catalog Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ERROR FREQUENCY CATALOG',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFFFF5252),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildErrorFrequencySection(
                                'Mental Errors', mentalFreq, Colors.blueAccent),
                            const SizedBox(height: 16),
                            _buildErrorFrequencySection('Skills Errors',
                                skillsFreq, Colors.amberAccent),
                            const SizedBox(height: 16),
                            _buildErrorFrequencySection('Environmental Errors',
                                envFreq, Colors.tealAccent),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Overall Match Notes Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'OVERALL MATCH NOTES',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _isEditing
                                ? TextFormField(
                                    controller: _notesController,
                                    maxLines: 4,
                                    onTap: () => HapticFeedback.lightImpact(),
                                    textCapitalization: TextCapitalization.sentences,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Add overall match execution notes, highlights, gear issues, or training takeaways...',
                                      border: OutlineInputBorder(),
                                    ),
                                  )
                                : Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF121214),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Text(
                                      _notesController.text.trim().isNotEmpty
                                          ? _notesController.text.trim()
                                          : 'No overall match notes recorded.',
                                      style: TextStyle(
                                        color: _notesController.text.trim().isNotEmpty
                                            ? Colors.white70
                                            : Colors.grey[600],
                                        fontSize: 14,
                                        fontStyle: _notesController.text.trim().isNotEmpty
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    if (_isEditing)
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _saveDetails();
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save Summary'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _isEditing = true;
                          });
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Summary'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(
      String label, dynamic value, dynamic subtext, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        const SizedBox(height: 6),
        value is Widget
            ? value
            : Text(
                value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: valueColor),
              ),
        if (subtext != null && subtext != '') ...[
          const SizedBox(height: 4),
          subtext is Widget
              ? subtext
              : Text(
                  subtext.toString(),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
        ],
      ],
    );
  }

  Widget _buildMissDetailBox(
      String label, String count, Color textColor,
      {int flex = 1, double verticalPadding = 10, double? minHeight}) {
    return Expanded(
      flex: flex,
      child: Container(
        constraints: minHeight != null ? BoxConstraints(minHeight: minHeight) : null,
        padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              count,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorFrequencySection(
      String title, Map<String, int> frequencies, Color categoryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 14,
              color: categoryColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (frequencies.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 4),
            child: Text(
              'No $title recorded for this match.',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Column(
              children: frequencies.entries.map((entry) {
                final count = entry.value;
                final isHeavy = count >= 7;
                final isMedium = count >= 3 && count < 7;

                Color textColor = Colors.white;
                FontWeight fontWeight = FontWeight.normal;
                Widget? warningIcon;
                Color chipBgColor = const Color(0xFF121214);
                Border chipBorder = Border.all(color: Colors.white10);
                Color chipTextColor = categoryColor;

                if (isHeavy) {
                  textColor = const Color(0xFFFF5252);
                  fontWeight = FontWeight.bold;
                  warningIcon = const Padding(
                    padding: EdgeInsets.only(right: 6.0),
                    child: Icon(Icons.warning_amber_rounded,
                        size: 14, color: Color(0xFFFF5252)),
                  );
                  chipBgColor = const Color(0xFFFF5252).withValues(alpha: 0.15);
                  chipBorder = Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.3));
                  chipTextColor = const Color(0xFFFF5252);
                } else if (isMedium) {
                  textColor = Colors.deepOrangeAccent;
                  fontWeight = FontWeight.bold;
                  chipBgColor = Colors.deepOrangeAccent.withValues(alpha: 0.1);
                  chipBorder = Border.all(color: Colors.deepOrangeAccent.withValues(alpha: 0.2));
                  chipTextColor = Colors.deepOrangeAccent;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (warningIcon != null) warningIcon,
                            Expanded(
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: textColor,
                                    fontWeight: fontWeight),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: chipBgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: chipBorder,
                        ),
                        child: Text(
                          '${entry.value} ${entry.value == 1 ? 'time' : 'times'}',
                          style: TextStyle(
                              fontSize: 11,
                              color: chipTextColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildOverallPerformanceChartsSection(Match match) {
    int rollGreen = 0;
    int rollRed = 0;
    int rollBlue = 0;

    int stabilityGreen = 0;
    int stabilityYellow = 0;
    int stabilityRed = 0;

    final sgPulseProvider = context.read<SgPulseProvider>();
    final rollThreshold = sgPulseProvider.rollThreshold;

    for (final stage in match.stages) {
      for (final roll in stage.shotRolls) {
        if (roll == 0.0) continue;
        final sign = roll < 0 ? -1.0 : 1.0;
        final truncatedRoll = sign * ((roll.abs() * 10).floor() / 10.0);
        final isWithinThreshold = truncatedRoll.abs() <= rollThreshold;
        if (isWithinThreshold) {
          rollGreen++;
        } else if (truncatedRoll < 0) {
          rollRed++;
        } else {
          rollBlue++;
        }
      }

      for (final stability in stage.shotStabilities) {
        if (stability == 0.0) continue;
        if (stability <= sgPulseProvider.stabilityGreenZone) {
          stabilityGreen++;
        } else if (stability <= sgPulseProvider.stabilityYellowZone) {
          stabilityYellow++;
        } else {
          stabilityRed++;
        }
      }
    }

    final totalRolls = rollGreen + rollRed + rollBlue;
    final totalStabilities = stabilityGreen + stabilityYellow + stabilityRed;

    if (totalRolls == 0 && totalStabilities == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OVERALL SHOT QUALITY METRICS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        if (totalRolls > 0) ...[
          const Text(
            'Overall Firearm Roll Consistency',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          MatchdayDonutChart(
            size: 80,
            centerLabel: '$totalRolls',
            centerSubLabel: 'SHOTS',
            segments: [
              ChartSegment(value: rollGreen.toDouble(), color: const Color(0xFF30D158), label: 'Centered (Green)'),
              ChartSegment(value: rollRed.toDouble(), color: const Color(0xFFFF453A), label: 'Roll Left (Red)'),
              ChartSegment(value: rollBlue.toDouble(), color: const Color(0xFF0A84FF), label: 'Roll Right (Blue)'),
            ],
          ),
        ],
        if (totalRolls > 0 && totalStabilities > 0) const SizedBox(height: 16),
        if (totalStabilities > 0) ...[
          const Text(
            'Overall Firearm Stability Zones',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          MatchdayDonutChart(
            size: 80,
            centerLabel: '$totalStabilities',
            centerSubLabel: 'SHOTS',
            segments: [
              ChartSegment(value: stabilityGreen.toDouble(), color: const Color(0xFF30D158), label: 'Excellent (Green)'),
              ChartSegment(value: stabilityYellow.toDouble(), color: const Color(0xFFFFD60A), label: 'Acceptable (Yellow)'),
              ChartSegment(value: stabilityRed.toDouble(), color: const Color(0xFFFF453A), label: 'Poor (Red)'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStageMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
      ],
    );
  }
}
