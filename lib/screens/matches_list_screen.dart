import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/match.dart';
import '../providers/match_provider.dart';
import 'match_detail_screen.dart';
import '../widgets/global_app_bar.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette for subtype pills — deterministic by name hash
// ─────────────────────────────────────────────────────────────────────────────
final _subtypeColors = [
  const Color(0xFF007AFF), // blue
  const Color(0xFF34C759), // green
  const Color(0xFFFF9500), // orange
  const Color(0xFFAF52DE), // purple
  const Color(0xFFFF2D55), // pink/red
  const Color(0xFF5AC8FA), // light blue
  const Color(0xFFFFCC00), // yellow
  const Color(0xFF00C7BE), // teal
];

Color _subtypeColor(String subtype) {
  if (subtype.isEmpty) return const Color(0xFF007AFF);
  final hash = subtype.codeUnits.fold(0, (p, c) => p + c);
  return _subtypeColors[hash % _subtypeColors.length];
}

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────
class MatchesListScreen extends StatefulWidget {
  const MatchesListScreen({super.key});

  @override
  State<MatchesListScreen> createState() => _MatchesListScreenState();
}

class _MatchesListScreenState extends State<MatchesListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalAppBar(
        title: const Text('My Matches'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Matches'),
            Tab(text: 'Training'),
          ],
          indicatorColor: const Color(0xFF007AFF),
          labelColor: const Color(0xFF007AFF),
          unselectedLabelColor: Colors.white54,
          dividerColor: Colors.transparent,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 26),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showAddMatchWizard(context,
                  initialType: _tabController.index == 0 ? 'match' : 'training');
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MatchTabView(matchType: 'match'),
          _MatchTabView(matchType: 'training'),
        ],
      ),
    );
  }

  void _showAddMatchWizard(BuildContext context, {String initialType = 'match'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MatchSetupWizard(initialType: initialType),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-tab list view with search + collapsible filters
// ─────────────────────────────────────────────────────────────────────────────
class _MatchTabView extends StatefulWidget {
  final String matchType; // 'match' or 'training'
  const _MatchTabView({required this.matchType});

  @override
  State<_MatchTabView> createState() => _MatchTabViewState();
}

class _MatchTabViewState extends State<_MatchTabView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  bool _filtersExpanded = false;
  String _selectedSubtype = 'All';
  bool _showArchived = false;
  // Date filter — null means 'All'
  DateTime? _filterMonth;      // year+month selected (day ignored)
  int? _filterYear;            // year only
  DateTimeRange? _customRange; // custom date range

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesDateFilter(Match m) {
    if (_filterMonth != null) {
      return m.date.year == _filterMonth!.year &&
          m.date.month == _filterMonth!.month;
    }
    if (_filterYear != null) {
      return m.date.year == _filterYear;
    }
    if (_customRange != null) {
      return !m.date.isBefore(_customRange!.start) &&
          !m.date.isAfter(_customRange!.end.add(const Duration(days: 1)));
    }
    return true;
  }

  bool _hasDateFilter() =>
      _filterMonth != null || _filterYear != null || _customRange != null;

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final initial = _filterMonth ?? DateTime(now.year, now.month);
    await showDialog(
      context: context,
      builder: (ctx) => _MonthYearPickerDialog(initial: initial),
    ).then((v) {
      if (v is DateTime) {
        setState(() {
          _filterMonth = v;
          _filterYear = null;
          _customRange = null;
        });
      }
    });
  }

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final initial = _filterYear ?? now.year;
    await showDialog(
      context: context,
      builder: (ctx) => _YearPickerDialog(initial: initial),
    ).then((v) {
      if (v is int) {
        setState(() {
          _filterYear = v;
          _filterMonth = null;
          _customRange = null;
        });
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _customRange,
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _filterMonth = null;
        _filterYear = null;
      });
    }
  }

  List<Match> _applyFilters(List<Match> all, bool archived) {
    final query = _searchController.text.trim().toLowerCase();
    return all.where((m) {
      if (m.matchType != widget.matchType) return false;
      if (m.isArchived != archived) return false;
      if (query.isNotEmpty &&
          !m.name.toLowerCase().contains(query) &&
          !m.location.toLowerCase().contains(query)) { return false; }
      if (_selectedSubtype != 'All' && m.matchSubtype != _selectedSubtype) { return false; }
      if (!_matchesDateFilter(m)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<MatchProvider>(
      builder: (context, provider, _) {
        final subtypes = widget.matchType == 'match'
            ? provider.matchSubtypes
            : provider.trainingSubtypes;
        final allMatches = provider.matches;
        final active = _applyFilters(allMatches, false);
        final archived = _showArchived ? _applyFilters(allMatches, true) : <Match>[];

        if (allMatches.where((m) => m.matchType == widget.matchType).isEmpty) {
          return _buildEmptyState(context);
        }

        return Column(
          children: [
            // ── Search bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by name or location…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.07),
                  isDense: true,
                ),
              ),
            ),

            // ── Filter toggle row ───────────────────────────────────────────
            GestureDetector(
              onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _filtersExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 13,
                        color: _hasActiveFilters()
                            ? const Color(0xFF007AFF)
                            : Colors.white54,
                        fontWeight: _hasActiveFilters()
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (_hasActiveFilters()) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _clearFilters,
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF007AFF),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Collapsible filter panel ────────────────────────────────────
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildFilterPanel(context, subtypes, provider),
              crossFadeState: _filtersExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: active.isEmpty && archived.isEmpty
                  ? Center(
                      child: Text(
                        'No results match your filters.',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: active.length +
                          (archived.isNotEmpty ? archived.length + 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < active.length) {
                          return _buildMatchCard(
                              context, provider, active[index],
                              isArchived: false);
                        }
                        // Section divider
                        if (index == active.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const Expanded(child: Divider()),
                                const SizedBox(width: 8),
                                Text('Archived',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white38)),
                                const SizedBox(width: 8),
                                const Expanded(child: Divider()),
                              ],
                            ),
                          );
                        }
                        final archivedMatch = archived[index - active.length - 1];
                        return _buildMatchCard(
                            context, provider, archivedMatch,
                            isArchived: true);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  bool _hasActiveFilters() =>
      _selectedSubtype != 'All' ||
      _hasDateFilter() ||
      _showArchived;

  void _clearFilters() => setState(() {
        _selectedSubtype = 'All';
        _filterMonth = null;
        _filterYear = null;
        _customRange = null;
        _showArchived = false;
      });

  Widget _buildFilterPanel(
      BuildContext context, List<String> subtypes, MatchProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtype chips
          Text('Subtype',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _filterChip('All', _selectedSubtype == 'All', () {
                setState(() => _selectedSubtype = 'All');
              }),
              ...subtypes.map((s) => _filterChip(
                    s,
                    _selectedSubtype == s,
                    () => setState(() => _selectedSubtype = s),
                  )),
              // ＋ Add subtype
              ActionChip(
                label: const Text('＋ Add'),
                labelStyle:
                    const TextStyle(fontSize: 12, color: Color(0xFF007AFF)),
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: Color(0xFF007AFF)),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                visualDensity: VisualDensity.compact,
                onPressed: () => _showAddSubtypeDialog(context, provider),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Date chips
          Text('Date',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Month chip
              _filterChip(
                _filterMonth != null
                    ? DateFormat('MMM yyyy').format(_filterMonth!)
                    : 'Month',
                _filterMonth != null,
                () async {
                  if (_filterMonth != null) {
                    setState(() => _filterMonth = null);
                  } else {
                    await _pickMonth();
                  }
                },
              ),
              // Year chip
              _filterChip(
                _filterYear != null ? '$_filterYear' : 'Year',
                _filterYear != null,
                () async {
                  if (_filterYear != null) {
                    setState(() => _filterYear = null);
                  } else {
                    await _pickYear();
                  }
                },
              ),
              // Custom range chip
              _filterChip(
                _customRange != null
                    ? '${DateFormat('MM/dd').format(_customRange!.start)}–${DateFormat('MM/dd').format(_customRange!.end)}'
                    : 'Custom…',
                _customRange != null,
                () async {
                  if (_customRange != null) {
                    setState(() => _customRange = null);
                  } else {
                    await _pickCustomRange();
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Show Archived checkbox
          InkWell(
            onTap: () => setState(() => _showArchived = !_showArchived),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _showArchived,
                    onChanged: (v) => setState(() => _showArchived = v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: const Color(0xFF007AFF),
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Show Archived',
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF007AFF).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF007AFF) : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? const Color(0xFF007AFF) : Colors.white60,
          ),
        ),
      ),
    );
  }

  void _showAddSubtypeDialog(BuildContext context, MatchProvider provider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add ${widget.matchType == 'match' ? 'Match' : 'Training'} Subtype'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. IPSC, Sniper Challenge…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                provider.addSubtype(val, widget.matchType);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    MatchProvider provider,
    Match match, {
    required bool isArchived,
  }) {
    final hits = match.totalHits;
    final totalShots = match.totalShotsTaken;
    final percent =
        totalShots > 0 ? (hits / totalShots * 100).toStringAsFixed(1) : '0.0';

    return Opacity(
      opacity: isArchived ? 0.55 : 1.0,
      child: Slidable(
        key: Key('${match.id}_$isArchived'),
        startActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) {
                HapticFeedback.lightImpact();
                _showEditMatchDialog(context, provider, match);
              },
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit',
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            if (!isArchived)
              SlidableAction(
                onPressed: (context) {
                  HapticFeedback.mediumImpact();
                  provider.archiveMatch(match.id);
                },
                backgroundColor: Colors.grey[700]!,
                foregroundColor: Colors.white,
                icon: Icons.archive_outlined,
                label: 'Archive',
              ),
            if (isArchived)
              SlidableAction(
                onPressed: (context) {
                  HapticFeedback.mediumImpact();
                  provider.unarchiveMatch(match.id);
                },
                backgroundColor: const Color(0xFF00C7BE),
                foregroundColor: Colors.white,
                icon: Icons.unarchive_outlined,
                label: 'Restore',
              ),
            SlidableAction(
              onPressed: (context) async {
                HapticFeedback.lightImpact();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Match'),
                    content: Text(
                        'Are you sure you want to delete "${match.name}"? This will delete all stage logs.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context, false);
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context, true);
                        },
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red[400])),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  provider.deleteMatch(match.id);
                }
              },
              backgroundColor: Colors.red[400]!,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
          ],
        ),
        child: Card(
          margin: const EdgeInsets.only(bottom: 10.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isArchived
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            MatchDetailScreen(matchId: match.id),
                      ),
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          match.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontStyle: isArchived
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                        ),
                      ),
                      if (match.matchSubtype.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _SubtypePill(subtype: match.matchSubtype),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$percent%',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          match.location,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.calendar_today,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(match.date),
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Stages: ${match.completedStagesCount} / ${match.numStages}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Impacts: $hits / $totalShots',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.matchType == 'match' ? Icons.stars : Icons.fitness_center,
                size: 50,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.matchType == 'match'
                  ? 'No Matches Logged'
                  : 'No Training Sessions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.matchType == 'match'
                  ? 'Record target data, planned windage, shot impacts, and heart rate metrics directly at the range.'
                  : 'Log your training sessions to track progress over time.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _showAddFromEmpty(context);
              },
              icon: const Icon(Icons.add),
              label: Text(widget.matchType == 'match'
                  ? 'Setup First Match'
                  : 'Log First Training'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFromEmpty(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MatchSetupWizard(initialType: widget.matchType),
    );
  }

  Future<void> _showEditMatchDialog(
      BuildContext context, MatchProvider provider, Match match) async {
    final nameController = TextEditingController(text: match.name);
    final locationController = TextEditingController(text: match.location);
    DateTime selectedDate = match.date;
    String selectedType = match.matchType;
    String selectedSubtype = match.matchSubtype;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final subtypes = selectedType == 'match'
                ? provider.matchSubtypes
                : provider.trainingSubtypes;
            if (selectedSubtype.isNotEmpty &&
                !subtypes.contains(selectedSubtype)) {
              selectedSubtype = '';
            }
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Match',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Type toggle
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'match',
                            label: Text('Match'),
                            icon: Icon(Icons.stars_outlined, size: 16)),
                        ButtonSegment(
                            value: 'training',
                            label: Text('Training'),
                            icon: Icon(Icons.fitness_center, size: 16)),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (s) => setDialogState(() {
                        selectedType = s.first;
                        selectedSubtype = '';
                      }),
                      style: ButtonStyle(
                        textStyle: WidgetStateProperty.all(
                            const TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Subtype dropdown
                    DropdownButtonFormField<String>(
                      initialValue: subtypes.contains(selectedSubtype)
                          ? selectedSubtype
                          : null,
                      hint: const Text('Subtype (optional)'),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: '', child: Text('None')),
                        ...subtypes.map((s) =>
                            DropdownMenuItem(value: s, child: Text(s))),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => selectedSubtype = v ?? ''),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: const Text('Date'),
                      subtitle: Text(
                          DateFormat('MMM d, yyyy').format(selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                IconButton(
                  icon: const Icon(Icons.cancel_outlined,
                      color: Colors.redAccent),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.blueAccent),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (nameController.text.trim().isNotEmpty &&
                        locationController.text.trim().isNotEmpty) {
                      provider.updateMatchBasicInfo(
                        match.id,
                        nameController.text.trim(),
                        locationController.text.trim(),
                        selectedDate,
                        matchType: selectedType,
                        matchSubtype: selectedSubtype,
                      );
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subtype pill badge
// ─────────────────────────────────────────────────────────────────────────────
class _SubtypePill extends StatelessWidget {
  final String subtype;
  const _SubtypePill({required this.subtype});

  @override
  Widget build(BuildContext context) {
    final color = _subtypeColor(subtype);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        subtype,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Match / Training wizard (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────
class _MatchSetupWizard extends StatefulWidget {
  final String initialType;
  const _MatchSetupWizard({this.initialType = 'match'});

  @override
  State<_MatchSetupWizard> createState() => _MatchSetupWizardState();
}

class _MatchSetupWizardState extends State<_MatchSetupWizard> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  int _numStages = 10;
  late String _selectedType;
  String _selectedSubtype = '';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final String matchId = const Uuid().v4();
    final List<Stage> stages = List.generate(
      _numStages,
      (index) => Stage(
        stageNumber: index + 1,
        status: 'pending',
        numTargets: 0,
        targetArrays: const [],
        windPlan: WindPlan(),
        shotResults: const [],
      ),
    );

    final newMatch = Match(
      id: matchId,
      name: _nameController.text.trim(),
      location: _locationController.text.trim(),
      date: _selectedDate,
      numStages: _numStages,
      shotsPerStage: 10,
      stages: stages,
      matchType: _selectedType,
      matchSubtype: _selectedSubtype,
    );

    context.read<MatchProvider>().addMatch(newMatch);
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MatchDetailScreen(matchId: matchId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    final provider = context.watch<MatchProvider>();
    final subtypes = _selectedType == 'match'
        ? provider.matchSubtypes
        : provider.trainingSubtypes;

    return Container(
      padding: EdgeInsets.only(
          top: 24, left: 24, right: 24, bottom: 24 + keyboardSpace),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E24),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Entry',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Type selector
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'match',
                      label: Text('Match'),
                      icon: Icon(Icons.stars_outlined, size: 16)),
                  ButtonSegment(
                      value: 'training',
                      label: Text('Training'),
                      icon: Icon(Icons.fitness_center, size: 16)),
                ],
                selected: {_selectedType},
                onSelectionChanged: (s) => setState(() {
                  _selectedType = s.first;
                  _selectedSubtype = '';
                }),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                onTap: () => HapticFeedback.lightImpact(),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: _selectedType == 'match'
                      ? 'Match Name'
                      : 'Session Name',
                  hintText: _selectedType == 'match'
                      ? 'e.g. Blue Ridge PRS Regional'
                      : 'e.g. Saturday Positional Work',
                  border: const OutlineInputBorder(),
                  fillColor: const Color(0xFF121214),
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _locationController,
                onTap: () => HapticFeedback.lightImpact(),
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Clean Valley Range, VA',
                  border: OutlineInputBorder(),
                  fillColor: Color(0xFF121214),
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Subtype dropdown
              DropdownButtonFormField<String>(
                initialValue: subtypes.contains(_selectedSubtype)
                    ? _selectedSubtype
                    : null,
                hint: const Text('Subtype (optional)'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  fillColor: const Color(0xFF121214),
                  filled: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('None')),
                  ...subtypes.map((s) =>
                      DropdownMenuItem(value: s, child: Text(s))),
                ],
                onChanged: (v) => setState(() => _selectedSubtype = v ?? ''),
              ),
              const SizedBox(height: 12),

              // Date picker
              Card(
                margin: EdgeInsets.zero,
                color: const Color(0xFF121214),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.white10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListTile(
                  title: const Text('Date'),
                  subtitle: Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _selectDate(context);
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Number of stages
              Row(
                children: [
                  const Expanded(
                      child: Text('Number of Stages',
                          style: TextStyle(fontSize: 15))),
                  DropdownButton<int>(
                    value: _numStages,
                    items: List.generate(24, (i) => i + 1)
                        .map((s) => DropdownMenuItem(
                            value: s, child: Text('$s stages')))
                        .toList(),
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      if (val != null) setState(() => _numStages = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _submitForm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Create',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month + Year picker dialog
// ─────────────────────────────────────────────────────────────────────────────
class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime initial;
  const _MonthYearPickerDialog({required this.initial});

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;
  late int _month;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Select Month', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Year row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _year--),
              ),
              Text(
                '$_year',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _year < now.year + 5
                    ? () => setState(() => _year++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Month grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: 12,
            itemBuilder: (context, i) {
              final selected = i + 1 == _month;
              return GestureDetector(
                onTap: () => setState(() => _month = i + 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF007AFF)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF007AFF)
                          : Colors.white12,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _months[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Year-only picker dialog
// ─────────────────────────────────────────────────────────────────────────────
class _YearPickerDialog extends StatefulWidget {
  final int initial;
  const _YearPickerDialog({required this.initial});

  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late int _selected;
  late final ScrollController _scrollController;

  static final int _startYear = 2020;
  static final int _endYear = DateTime.now().year + 3;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    final offset = (_selected - _startYear) * 48.0;
    _scrollController = ScrollController(initialScrollOffset: offset.clamp(0, double.infinity));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(_endYear - _startYear + 1, (i) => _startYear + i);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Select Year', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 180,
        height: 240,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: years.length,
          itemExtent: 48,
          itemBuilder: (context, i) {
            final year = years[i];
            final selected = year == _selected;
            return GestureDetector(
              onTap: () => setState(() => _selected = year),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF007AFF)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$year',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
