import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../providers/match_provider.dart';
import 'stage_detail_screen.dart';
import 'match_summary_screen.dart';

class MatchDetailScreen extends StatelessWidget {
  final String matchId;

  const MatchDetailScreen({
    super.key,
    required this.matchId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MatchProvider>(
      builder: (context, provider, child) {
        final match = provider.matches.firstWhere(
          (m) => m.id == matchId,
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
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Match not found.')),
          );
        }

        // Calculate statistics
        final totalHits = match.totalHits;
        final totalShots = match.totalShotsTaken;
        final hitRate = totalShots > 0 ? (totalHits / totalShots * 100) : 0.0;
        final completedStages =
            match.stages.where((s) => s.status == 'completed').toList();
        final completedCount = completedStages.length;

        final double avgHeartRate = completedStages.isNotEmpty
            ? completedStages.fold(
                    0, (sum, stage) => sum + stage.avgHeartRate) /
                completedCount
            : 0.0;

        return Scaffold(
          appBar: AppBar(
            title: Text(match.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.analytics_outlined),
                tooltip: 'Match Summary',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MatchSummaryScreen(matchId: match.id),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {
                  // Optional share function
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sharing coming soon!')),
                  );
                },
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Stats Dashboard
              Container(
                color: const Color(0xFF1E1E24),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.location,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMMM d, yyyy').format(match.date),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Hit Rate: ${hitRate.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDashboardStat(
                          context,
                          'Completed',
                          '$completedCount / ${match.numStages}',
                          Icons.check_circle_outline,
                          Colors.blue,
                        ),
                        _buildDashboardStat(
                          context,
                          'Impacts',
                          '$totalHits / $totalShots',
                          Icons.gps_fixed,
                          Colors.green,
                        ),
                        _buildDashboardStat(
                          context,
                          'Avg Heart Rate',
                          avgHeartRate > 0
                              ? '${avgHeartRate.round()} BPM'
                              : '-- BPM',
                          Icons.favorite_outline,
                          Colors.redAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Stages List Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STAGES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 1.0,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${match.stages.length} Stages',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            provider.addStage(match.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Stage ${match.stages.length + 1} added!'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, size: 16, color: Color(0xFF007AFF)),
                          label: const Text(
                            'Add Stage',
                            style: TextStyle(
                                color: Color(0xFF007AFF),
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stages List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: match.stages.length,
                  itemBuilder: (context, index) {
                    final stage = match.stages[index];
                    return _buildStageTile(
                        context, provider, match, stage, index);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardStat(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildStageTile(BuildContext context, MatchProvider provider,
      Match match, Stage stage, int index) {
    final isCompleted = stage.status == 'completed';
    final targetSummary = stage.targets.isNotEmpty
        ? '${stage.targets[0].distance} • ${stage.targets[0].size} • ${stage.targets[0].type}${stage.targets.length > 1 ? " (+${stage.targets.length - 1})" : ""}'
        : 'No targets defined';

    return Dismissible(
      key: Key('stage_${stage.stageNumber}_${match.stages.length}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Stage'),
            content: Text('Are you sure you want to delete ${stage.name.isNotEmpty ? stage.name : "Stage ${stage.stageNumber}"}? Remaining stages will be renumbered.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        provider.removeStage(match.id, stage.stageNumber);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stage deleted')),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          onTap: () {
            // Set active stage in provider (starts syncing to watch!)
            provider.setActiveStage(match.id, index);

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => StageDetailScreen(
                  matchId: match.id,
                  stageNumber: stage.stageNumber,
                ),
              ),
            );
          },
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.green)
                  : Text(
                      '${stage.stageNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
            ),
          ),
          title: Text(
            stage.name.isNotEmpty ? stage.name : 'Stage ${stage.stageNumber}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              stage.name.isNotEmpty
                  ? 'Stage ${stage.stageNumber} • $targetSummary'
                  : targetSummary,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCompleted) ...[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${stage.hitCount}/${stage.shotResults.length} Hits',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green,
                      ),
                    ),
                    if (stage.avgHeartRate > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite,
                              color: Colors.redAccent, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            '${stage.avgHeartRate} BPM',
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
