import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:watch_connectivity/watch_connectivity.dart';
import '../models/match.dart';

class MatchProvider with ChangeNotifier {
  final Box _box;
  final List<Match> _matches = [];
  String? _activeMatchId;
  int? _activeStageIndex;

  final _watchConnectivity = WatchConnectivity();
  WatchConnectivity get watchConnectivity => _watchConnectivity;
  bool _isWatchConnected = false;
  bool get isWatchConnected => _isWatchConnected;
  final _watchResultController = StreamController<WatchResultEvent>.broadcast();
  final _watchLiveUpdateController = StreamController<WatchLiveUpdateEvent>.broadcast();
  final _watchTimerStartedController = StreamController<int?>.broadcast();

  MatchProvider(this._box) {
    _loadMatches();
    _initWatchConnectivity();
  }

  List<Match> get matches => _matches;
  String? get activeMatchId => _activeMatchId;
  int? get activeStageIndex => _activeStageIndex;
  Stream<WatchResultEvent> get watchResultStream => _watchResultController.stream;
  Stream<WatchLiveUpdateEvent> get watchLiveUpdateStream => _watchLiveUpdateController.stream;
  Stream<int?> get watchTimerStartedStream => _watchTimerStartedController.stream;

  Match? get activeMatch {
    if (_activeMatchId == null) return null;
    try {
      return _matches.firstWhere((m) => m.id == _activeMatchId);
    } catch (_) {
      return null;
    }
  }

  Stage? get activeStage {
    final match = activeMatch;
    if (match == null || _activeStageIndex == null) return null;
    if (_activeStageIndex! >= 0 && _activeStageIndex! < match.stages.length) {
      return match.stages[_activeStageIndex!];
    }
    return null;
  }

  void _loadMatches() {
    final List<dynamic>? stored = _box.get('matches_list') as List<dynamic>?;
    if (stored != null) {
      _matches.clear();
      for (var item in stored) {
        if (item is Map) {
          final Map<String, dynamic> casted = Map<String, dynamic>.from(item);
          _matches.add(Match.fromMap(casted));
        } else if (item is String) {
          _matches.add(Match.fromJson(item));
        }
      }
    }
    _activeMatchId = _box.get('active_match_id') as String?;
    _activeStageIndex = _box.get('active_stage_index') as int?;
    notifyListeners();
  }

  void _saveMatches() {
    final List<Map<String, dynamic>> rawList = _matches.map((m) => m.toMap()).toList();
    _box.put('matches_list', rawList);
  }

  void addMatch(Match match) {
    _matches.add(match);
    _saveMatches();
    notifyListeners();
  }

  void deleteMatch(String id) {
    _matches.removeWhere((m) => m.id == id);
    if (_activeMatchId == id) {
      _activeMatchId = null;
      _activeStageIndex = null;
      _box.delete('active_match_id');
      _box.delete('active_stage_index');
    }
    _saveMatches();
    notifyListeners();
  }

  void setActiveStage(String matchId, int stageIndex) {
    _activeMatchId = matchId;
    _activeStageIndex = stageIndex;
    _box.put('active_match_id', matchId);
    _box.put('active_stage_index', stageIndex);
    notifyListeners();

    // Auto-sync active stage to the watch
    syncActiveStageToWatch();
  }

  void updateStage(String matchId, Stage updatedStage) {
    final matchIndex = _matches.indexWhere((m) => m.id == matchId);
    if (matchIndex != -1) {
      final stageIndex = _matches[matchIndex].stages.indexWhere((s) => s.stageNumber == updatedStage.stageNumber);
      if (stageIndex != -1) {
        _matches[matchIndex].stages[stageIndex] = updatedStage;
        _saveMatches();
        notifyListeners();
      }
    }
  }

  void addStage(String matchId) {
    final matchIndex = _matches.indexWhere((m) => m.id == matchId);
    if (matchIndex != -1) {
      final match = _matches[matchIndex];
      final newStageNumber = match.stages.isEmpty ? 1 : match.stages.last.stageNumber + 1;
      match.stages.add(Stage(
        stageNumber: newStageNumber,
        status: 'pending',
        targetArrays: const [],
        windPlan: WindPlan(),
        shotResults: const [],
      ));
      
      // Update match with new stage count
      final updatedMatch = Match(
        id: match.id,
        name: match.name,
        location: match.location,
        date: match.date,
        numStages: match.stages.length,
        shotsPerStage: match.shotsPerStage,
        stages: match.stages,
        winnerHits: match.winnerHits,
        position: match.position,
        matchNotes: match.matchNotes,
        deletedMentalTags: match.deletedMentalTags,
        deletedSkillsTags: match.deletedSkillsTags,
        deletedEnvTags: match.deletedEnvTags,
        customMentalTags: match.customMentalTags,
        customSkillsTags: match.customSkillsTags,
        customEnvTags: match.customEnvTags,
        customTargetTypes: match.customTargetTypes,
        deletedTargetTypes: match.deletedTargetTypes,
      );
      _matches[matchIndex] = updatedMatch;
      _saveMatches();
      notifyListeners();
    }
  }

  void removeStage(String matchId, int stageNumber) {
    final matchIndex = _matches.indexWhere((m) => m.id == matchId);
    if (matchIndex != -1) {
      final match = _matches[matchIndex];
      match.stages.removeWhere((s) => s.stageNumber == stageNumber);
      
      // Re-index remaining stages to ensure continuous numbering
      for (int i = 0; i < match.stages.length; i++) {
        final oldStage = match.stages[i];
        match.stages[i] = Stage(
          stageNumber: i + 1,
          name: oldStage.name,
          status: oldStage.status,
          numTargets: oldStage.numTargets,
          targetArrays: oldStage.targetArrays,
          windPlan: oldStage.windPlan,
          timedOut: oldStage.timedOut,
          timeRemaining: oldStage.timeRemaining,
          avgHeartRate: oldStage.avgHeartRate,
          maxHeartRate: oldStage.maxHeartRate,
          shotResults: oldStage.shotResults,
          mentalErrors: oldStage.mentalErrors,
          skillsErrors: oldStage.skillsErrors,
          environmentalErrors: oldStage.environmentalErrors,
          timeLimit: oldStage.timeLimit,
          numPositions: oldStage.numPositions,
          shotTimes: oldStage.shotTimes,
          plannedRoundCount: oldStage.plannedRoundCount,
          shotTargetsSequence: oldStage.shotTargetsSequence,
          shotRolls: oldStage.shotRolls,
          shotStabilities: oldStage.shotStabilities,
        );
      }

      final updatedMatch = Match(
        id: match.id,
        name: match.name,
        location: match.location,
        date: match.date,
        numStages: match.stages.length,
        shotsPerStage: match.shotsPerStage,
        stages: match.stages,
        winnerHits: match.winnerHits,
        position: match.position,
        matchNotes: match.matchNotes,
        deletedMentalTags: match.deletedMentalTags,
        deletedSkillsTags: match.deletedSkillsTags,
        deletedEnvTags: match.deletedEnvTags,
        customMentalTags: match.customMentalTags,
        customSkillsTags: match.customSkillsTags,
        customEnvTags: match.customEnvTags,
        customTargetTypes: match.customTargetTypes,
        deletedTargetTypes: match.deletedTargetTypes,
      );
      _matches[matchIndex] = updatedMatch;
      
      // Adjust active stage index bounds if it becomes invalid
      if (_activeMatchId == matchId && _activeStageIndex != null) {
        if (_activeStageIndex! >= match.stages.length) {
          _activeStageIndex = match.stages.isEmpty ? null : match.stages.length - 1;
          if (_activeStageIndex == null) {
            _box.delete('active_stage_index');
          } else {
            _box.put('active_stage_index', _activeStageIndex);
          }
        }
      }

      _saveMatches();
      notifyListeners();
    }
  }

  void updateMatchDetails(String matchId, {int? winnerHits, int? position, String? matchNotes}) {
    final matchIndex = _matches.indexWhere((m) => m.id == matchId);
    if (matchIndex != -1) {
      final match = _matches[matchIndex];
      _matches[matchIndex] = Match(
        id: match.id,
        name: match.name,
        location: match.location,
        date: match.date,
        numStages: match.numStages,
        shotsPerStage: match.shotsPerStage,
        stages: match.stages,
        winnerHits: winnerHits,
        position: position,
        matchNotes: matchNotes,
        deletedMentalTags: match.deletedMentalTags,
        deletedSkillsTags: match.deletedSkillsTags,
        deletedEnvTags: match.deletedEnvTags,
        customMentalTags: match.customMentalTags,
        customSkillsTags: match.customSkillsTags,
        customEnvTags: match.customEnvTags,
        customTargetTypes: match.customTargetTypes,
        deletedTargetTypes: match.deletedTargetTypes,
      );
      _saveMatches();
      notifyListeners();
    }
  }

  void updateMatchBasicInfo(String matchId, String name, String location, DateTime date) {
    final matchIndex = _matches.indexWhere((m) => m.id == matchId);
    if (matchIndex != -1) {
      final match = _matches[matchIndex];
      _matches[matchIndex] = Match(
        id: match.id,
        name: name,
        location: location,
        date: date,
        numStages: match.numStages,
        shotsPerStage: match.shotsPerStage,
        stages: match.stages,
        winnerHits: match.winnerHits,
        position: match.position,
        matchNotes: match.matchNotes,
        deletedMentalTags: match.deletedMentalTags,
        deletedSkillsTags: match.deletedSkillsTags,
        deletedEnvTags: match.deletedEnvTags,
        customMentalTags: match.customMentalTags,
        customSkillsTags: match.customSkillsTags,
        customEnvTags: match.customEnvTags,
        customTargetTypes: match.customTargetTypes,
        deletedTargetTypes: match.deletedTargetTypes,
      );
      _saveMatches();
      notifyListeners();
    }
  }

  void addCustomTagToMatch(String matchId, String tag, String errorType) {
    final matchIndex = _matches.indexWhere((m) => m.id == matchId);
    if (matchIndex != -1) {
      final match = _matches[matchIndex];
      final List<String> updatedCustomMental = List.from(match.customMentalTags);
      final List<String> updatedCustomSkills = List.from(match.customSkillsTags);
      final List<String> updatedCustomEnv = List.from(match.customEnvTags);
      final List<String> updatedCustomTargetTypes = List.from(match.customTargetTypes);

      if (errorType == 'mental') {
        if (!updatedCustomMental.contains(tag)) updatedCustomMental.add(tag);
      } else if (errorType == 'skills') {
        if (!updatedCustomSkills.contains(tag)) updatedCustomSkills.add(tag);
      } else if (errorType == 'env') {
        if (!updatedCustomEnv.contains(tag)) updatedCustomEnv.add(tag);
      } else if (errorType == 'targetType') {
        if (!updatedCustomTargetTypes.contains(tag)) updatedCustomTargetTypes.add(tag);
      }

      // Also ensure it is removed from deleted tags list if it was previously deleted
      final List<String> updatedDeletedMental = List.from(match.deletedMentalTags)..remove(tag);
      final List<String> updatedDeletedSkills = List.from(match.deletedSkillsTags)..remove(tag);
      final List<String> updatedDeletedEnv = List.from(match.deletedEnvTags)..remove(tag);
      final List<String> updatedDeletedTargetTypes = List.from(match.deletedTargetTypes)..remove(tag);

      _matches[matchIndex] = Match(
        id: match.id,
        name: match.name,
        location: match.location,
        date: match.date,
        numStages: match.numStages,
        shotsPerStage: match.shotsPerStage,
        stages: match.stages,
        winnerHits: match.winnerHits,
        position: match.position,
        matchNotes: match.matchNotes,
        deletedMentalTags: updatedDeletedMental,
        deletedSkillsTags: updatedDeletedSkills,
        deletedEnvTags: updatedDeletedEnv,
        customMentalTags: updatedCustomMental,
        customSkillsTags: updatedCustomSkills,
        customEnvTags: updatedCustomEnv,
        customTargetTypes: updatedCustomTargetTypes,
        deletedTargetTypes: updatedDeletedTargetTypes,
      );

      _saveMatches();
      notifyListeners();
    }
  }

  void deleteTagFromMatch(String matchId, String tag, String errorType) {
    final matchIndex = _matches.indexWhere((m) => m.id == matchId);
    if (matchIndex != -1) {
      final match = _matches[matchIndex];
      final List<String> updatedDeletedMental = List.from(match.deletedMentalTags);
      final List<String> updatedDeletedSkills = List.from(match.deletedSkillsTags);
      final List<String> updatedDeletedEnv = List.from(match.deletedEnvTags);
      final List<String> updatedDeletedTargetTypes = List.from(match.deletedTargetTypes);

      final List<String> updatedCustomMental = List.from(match.customMentalTags);
      final List<String> updatedCustomSkills = List.from(match.customSkillsTags);
      final List<String> updatedCustomEnv = List.from(match.customEnvTags);
      final List<String> updatedCustomTargetTypes = List.from(match.customTargetTypes);

      if (errorType == 'mental') {
        if (!updatedDeletedMental.contains(tag)) updatedDeletedMental.add(tag);
        updatedCustomMental.remove(tag);
      } else if (errorType == 'skills') {
        if (!updatedDeletedSkills.contains(tag)) updatedDeletedSkills.add(tag);
        updatedCustomSkills.remove(tag);
      } else if (errorType == 'env') {
        if (!updatedDeletedEnv.contains(tag)) updatedDeletedEnv.add(tag);
        updatedCustomEnv.remove(tag);
      } else if (errorType == 'targetType') {
        if (!updatedDeletedTargetTypes.contains(tag)) updatedDeletedTargetTypes.add(tag);
        updatedCustomTargetTypes.remove(tag);
      }

      // Also remove it from all stages in this match
      for (var stage in match.stages) {
        if (errorType == 'mental') {
          final tags = stage.mentalErrors
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty && t != tag)
              .toList();
          stage.mentalErrors = tags.join(', ');
        } else if (errorType == 'skills') {
          final tags = stage.skillsErrors
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty && t != tag)
              .toList();
          stage.skillsErrors = tags.join(', ');
        } else if (errorType == 'env') {
          final tags = stage.environmentalErrors
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty && t != tag)
              .toList();
          stage.environmentalErrors = tags.join(', ');
        }
      }

      _matches[matchIndex] = Match(
        id: match.id,
        name: match.name,
        location: match.location,
        date: match.date,
        numStages: match.numStages,
        shotsPerStage: match.shotsPerStage,
        stages: match.stages,
        winnerHits: match.winnerHits,
        position: match.position,
        matchNotes: match.matchNotes,
        deletedMentalTags: updatedDeletedMental,
        deletedSkillsTags: updatedDeletedSkills,
        deletedEnvTags: updatedDeletedEnv,
        customMentalTags: updatedCustomMental,
        customSkillsTags: updatedCustomSkills,
        customEnvTags: updatedCustomEnv,
        customTargetTypes: updatedCustomTargetTypes,
        deletedTargetTypes: updatedDeletedTargetTypes,
      );

      _saveMatches();
      notifyListeners();
    }
  }

  Future<void> syncActiveStageToWatch() async {
    final stage = activeStage;
    if (stage == null) return;

    try {
      final isSupported = await _watchConnectivity.isSupported;
      if (!isSupported) return;

      await _watchConnectivity.sendMessage({
        'type': 'sync_stage',
        'stageNumber': stage.stageNumber,
        'timeLimit': stage.timeLimit,
      });
      debugPrint('Synced active stage ${stage.stageNumber} to watch');

      // If this stage has target arrays, sync the DOPE immediately!
      final hasDope = stage.targetArrays.isNotEmpty;

      if (hasDope) {
        final dopeTargets = <Map<String, String>>[];
        for (int i = 0; i < stage.targetArrays.length; i++) {
          final array = stage.targetArrays[i];
          String holdoverVal = '';
          if (i >= 1 &&
              stage.targetArrays[0].elevationValue != null &&
              array.elevationValue != null) {
            final v1 = double.parse(stage.targetArrays[0].elevationValue!.toStringAsFixed(2));
            final v2 = double.parse(array.elevationValue!.toStringAsFixed(2));
            final diff = v2 - v1;
            final dir = diff < 0 ? 'U' : 'D';
            holdoverVal = '${diff.abs().toStringAsFixed(2)} $dir';
          }

          // Check for moving targets and their lead
          String leadVal = '';
          Target? movingTarget;
          for (final t in array.targets) {
            if (t.isMovingTarget) {
              movingTarget = t;
              break;
            }
          }
          if (movingTarget != null && movingTarget.targetLeadMil != 0.0) {
            double parsedWidth = 0.0;
            final cleanStr = movingTarget.size.replaceAll(RegExp(r'[^0-9.]'), '');
            if (cleanStr.isNotEmpty) {
              parsedWidth = double.tryParse(cleanStr) ?? 0.0;
            }
            double finalLead = movingTarget.targetLeadMil;
            if (movingTarget.selectedLeadType == 'leadingEdge') {
              finalLead = movingTarget.targetLeadMil - (parsedWidth / 2);
            } else if (movingTarget.selectedLeadType == 'trailingEdge') {
              finalLead = movingTarget.targetLeadMil + (parsedWidth / 2);
            }
            leadVal = '${finalLead.toStringAsFixed(2)} MIL';
          }

          // Check target safety status (isSafe) and center hold text for watch display
          bool isSafe = false;
          String centerHoldText = '';
          if (array.windage1Value != null &&
              array.windage2Value != null &&
              array.targets.isNotEmpty) {
            final w1 = array.windage1Value!;
            final w2 = array.windage2Value!;
            final spread = (w2 - w1).abs();
            final hold = (w1 + w2) / 2;
            final cleanStr = array.targets[0].size.replaceAll(RegExp(r'[^0-9.]'), '');
            final targetWidth = double.tryParse(cleanStr) ?? 0.0;
            if (targetWidth > 0.0) {
              isSafe = spread <= targetWidth;
              if (hold.abs() < 0.005) {
                centerHoldText = '0.00';
              } else {
                final dir = hold < 0 ? 'R' : 'L';
                centerHoldText = '${hold.abs().toStringAsFixed(2)} $dir';
              }
            }
          }

          dopeTargets.add({
            'distance': array.distance,
            'elevation': array.elevationResult,
            'windage': array.windageResult,
            'holdover': holdoverVal,
            'lead': leadVal,
            'isSafe': isSafe ? 'true' : 'false',
            'centerHoldText': centerHoldText,
          });
        }
        await syncDopeToWatch(dopeTargets);
      }
    } catch (e) {
      debugPrint('Error syncing stage to watch: $e');
    }
  }

  Future<void> syncOnlyDopeToWatch() async {
    final stage = activeStage;
    if (stage == null) return;

    final hasDope = stage.targetArrays.isNotEmpty;

    if (hasDope) {
      final dopeTargets = <Map<String, String>>[];
      for (int i = 0; i < stage.targetArrays.length; i++) {
        final array = stage.targetArrays[i];
        String holdoverVal = '';
        if (i >= 1 &&
            stage.targetArrays[0].elevationValue != null &&
            array.elevationValue != null) {
          final v1 = double.parse(stage.targetArrays[0].elevationValue!.toStringAsFixed(2));
          final v2 = double.parse(array.elevationValue!.toStringAsFixed(2));
          final diff = v2 - v1;
          final dir = diff < 0 ? 'U' : 'D';
          holdoverVal = '${diff.abs().toStringAsFixed(2)} $dir';
        }

        // Check for moving targets and their lead
        String leadVal = '';
        Target? movingTarget;
        for (final t in array.targets) {
          if (t.isMovingTarget) {
            movingTarget = t;
            break;
          }
        }
        if (movingTarget != null && movingTarget.targetLeadMil != 0.0) {
          double parsedWidth = 0.0;
          final cleanStr = movingTarget.size.replaceAll(RegExp(r'[^0-9.]'), '');
          if (cleanStr.isNotEmpty) {
            parsedWidth = double.tryParse(cleanStr) ?? 0.0;
          }
          double finalLead = movingTarget.targetLeadMil;
          if (movingTarget.selectedLeadType == 'leadingEdge') {
            finalLead = movingTarget.targetLeadMil - (parsedWidth / 2);
          } else if (movingTarget.selectedLeadType == 'trailingEdge') {
            finalLead = movingTarget.targetLeadMil + (parsedWidth / 2);
          }
          leadVal = '${finalLead.toStringAsFixed(2)} MIL';
        }

          // Check target safety status (isSafe) and center hold text for watch display
          bool isSafe = false;
          String centerHoldText = '';
          if (array.windage1Value != null &&
              array.windage2Value != null &&
              array.targets.isNotEmpty) {
            final w1 = array.windage1Value!;
            final w2 = array.windage2Value!;
            final spread = (w2 - w1).abs();
            final hold = (w1 + w2) / 2;
            final cleanStr = array.targets[0].size.replaceAll(RegExp(r'[^0-9.]'), '');
            final targetWidth = double.tryParse(cleanStr) ?? 0.0;
            if (targetWidth > 0.0) {
              isSafe = spread <= targetWidth;
              if (hold.abs() < 0.005) {
                centerHoldText = '0.00';
              } else {
                final dir = hold < 0 ? 'R' : 'L';
                centerHoldText = '${hold.abs().toStringAsFixed(2)} $dir';
              }
            }
          }

          dopeTargets.add({
            'distance': array.distance,
            'elevation': array.elevationResult,
            'windage': array.windageResult,
            'holdover': holdoverVal,
            'lead': leadVal,
            'isSafe': isSafe ? 'true' : 'false',
            'centerHoldText': centerHoldText,
          });
        }
      await syncDopeToWatch(dopeTargets);
    }
  }

  Future<void> syncDopeToWatch(List<Map<String, String>> targets) async {
    final stage = activeStage;
    if (stage == null) return;

    try {
      final isSupported = await _watchConnectivity.isSupported;
      if (!isSupported) return;

      await _watchConnectivity.sendMessage({
        'type': 'sync_dope',
        'stageNumber': stage.stageNumber,
        'targets': targets,
      });
      debugPrint('Synced DOPE to watch for stage ${stage.stageNumber}: $targets');
    } catch (e) {
      debugPrint('Error syncing DOPE to watch: $e');
    }
  }

  Future<void> stopWatchTimer() async {
    try {
      final isSupported = await _watchConnectivity.isSupported;
      if (!isSupported) return;

      await _watchConnectivity.sendMessage({
        'type': 'stop_timer',
      });
      debugPrint('Sent stop_timer command to watch');
    } catch (e) {
      debugPrint('Error sending stop_timer to watch: $e');
    }
  }

  void _initWatchConnectivity() {
    void handleIncoming(Map<String, dynamic> message) {
      debugPrint('Incoming watch message: $message');
      if (message['type'] == 'stage_result') {
        final timeLeft = message['timeLeft'] as int?;
        final avgHeartRate = message['avgHeartRate'] as int?;
        final maxHeartRate = message['maxHeartRate'] as int? ?? 0;
        final lastSetTime = message['lastSetTime'] as int?;
        final stoppedByPhone = message['stoppedByPhone'] as bool? ?? false;

        if (timeLeft != null && avgHeartRate != null) {
          final event = WatchResultEvent(
            timeLeft: timeLeft,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            lastSetTime: lastSetTime ?? 105,
            stoppedByPhone: stoppedByPhone,
          );
          _handleWatchResult(event);
        }
      } else if (message['type'] == 'live_update') {
        final timeLeft = message['timeLeft'] as int?;
        final heartRate = message['heartRate'] as int?;
        if (timeLeft != null && heartRate != null) {
          final stage = activeStage;
          if (stage != null) {
            stage.timeRemaining = timeLeft;
            stage.avgHeartRate = heartRate;
            if (heartRate > stage.maxHeartRate) {
              stage.maxHeartRate = heartRate;
            }
            notifyListeners();
          }
          _watchLiveUpdateController.add(WatchLiveUpdateEvent(
            timeLeft: timeLeft,
            heartRate: heartRate,
          ));
        }
      } else if (message['type'] == 'timer_started') {
        final timeLeft = message['timeLeft'] as int?;
        _watchTimerStartedController.add(timeLeft);
      }
    }

    _watchConnectivity.messageStream.listen((message) {
      handleIncoming(Map<String, dynamic>.from(message));
    });
    
    _watchConnectivity.contextStream.listen((contextMap) {
      handleIncoming(Map<String, dynamic>.from(contextMap));
    });

    Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final isSupported = await _watchConnectivity.isSupported;
        if (isSupported) {
          final isReachable = await _watchConnectivity.isReachable;
          final isPaired = await _watchConnectivity.isPaired;
          final connected = isReachable && isPaired;
          if (connected != _isWatchConnected) {
            _isWatchConnected = connected;
            notifyListeners();
          }
        }
      } catch (_) {}
    });
  }

  void _handleWatchResult(WatchResultEvent event) {
    final match = activeMatch;
    final stage = activeStage;
    if (match != null && stage != null) {
      stage.timeRemaining = event.timeLeft;
      stage.avgHeartRate = event.avgHeartRate;
      stage.maxHeartRate = event.maxHeartRate;
      stage.timedOut = (event.timeLeft == 0);
      
      updateStage(match.id, stage);

      // Trigger UI callback stream so detail screen can prompt user
      _watchResultController.add(event);
    }
  }

  @override
  void dispose() {
    _watchResultController.close();
    _watchLiveUpdateController.close();
    _watchTimerStartedController.close();
    super.dispose();
  }
}

class WatchResultEvent {
  final int timeLeft;
  final int avgHeartRate;
  final int maxHeartRate;
  final int lastSetTime;
  final bool stoppedByPhone;

  WatchResultEvent({
    required this.timeLeft,
    required this.avgHeartRate,
    required this.maxHeartRate,
    required this.lastSetTime,
    this.stoppedByPhone = false,
  });
}

class WatchLiveUpdateEvent {
  final int timeLeft;
  final int heartRate;

  WatchLiveUpdateEvent({
    required this.timeLeft,
    required this.heartRate,
  });
}
