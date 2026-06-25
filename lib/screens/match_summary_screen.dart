import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/match.dart';
import '../providers/match_provider.dart';

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
  }

  @override
  void dispose() {
    _winnerHitsController.dispose();
    _positionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveDetails() {
    final winnerHitsVal = int.tryParse(_winnerHitsController.text.trim());
    final positionVal = int.tryParse(_positionController.text.trim());
    final notesVal = _notesController.text.trim();

    context.read<MatchProvider>().updateMatchDetails(
          widget.matchId,
          winnerHits: winnerHitsVal,
          position: positionVal,
          matchNotes: notesVal,
        );
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
          appBar: AppBar(
            title: const Text('Match Summary'),
            actions: [
              TextButton(
                onPressed: () {
                  _saveDetails();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Match summary details saved')),
                  );
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
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(match.location,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Standings Entry Card
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
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMetricItem(
                                  'Score / Impact %',
                                  '${ourPercent.toStringAsFixed(1)}%',
                                  '$totalHits / $totalShots Impacts',
                                  const Color(0xFF00E676),
                                ),
                                _buildMetricItem(
                                  '% to Winner',
                                  winnerPercent != null
                                      ? '${winnerPercent.toStringAsFixed(1)}%'
                                      : 'N/A',
                                  winnerHits != null
                                      ? 'Winner: $winnerHits'
                                      : 'Winner hits empty',
                                  const Color(0xFF00E676),
                                ),
                                _buildMetricItem(
                                  'Final Position',
                                  positionText,
                                  '',
                                  Colors.blueAccent,
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
                              children: [
                                _buildMissDetailBox(
                                  'Total Misses',
                                  '$totalMisses',
                                  Colors.redAccent,
                                ),
                                const SizedBox(width: 12),
                                _buildMissDetailBox(
                                  'Missed for Timeout',
                                  '$timeoutMisses',
                                  Colors.orangeAccent,
                                ),
                                const SizedBox(width: 12),
                                _buildMissDetailBox(
                                  'Normal Misses',
                                  '$normalMisses',
                                  Colors.grey,
                                ),
                              ],
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
                            TextFormField(
                              controller: _notesController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText:
                                    'Add overall match execution notes, highlights, gear issues, or training takeaways...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
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
      String label, String value, String subtext, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: valueColor),
        ),
        if (subtext.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  Widget _buildMissDetailBox(String label, String count, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Column(
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
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121214),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          '${entry.value} ${entry.value == 1 ? 'time' : 'times'}',
                          style: TextStyle(
                              fontSize: 11,
                              color: categoryColor,
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
}
