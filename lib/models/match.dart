import 'dart:convert';

class Match {
  final String id;
  final String name;
  final String location;
  final DateTime date;
  final int numStages;
  final int shotsPerStage;
  final List<Stage> stages;
  final int? winnerHits;
  final int? position;
  final String? matchNotes;
  final List<String> deletedMentalTags;
  final List<String> deletedSkillsTags;
  final List<String> deletedEnvTags;
  final List<String> customMentalTags;
  final List<String> customSkillsTags;
  final List<String> customEnvTags;
  final List<String> customTargetTypes;
  final List<String> deletedTargetTypes;

  Match({
    required this.id,
    required this.name,
    required this.location,
    required this.date,
    required this.numStages,
    required this.shotsPerStage,
    required this.stages,
    this.winnerHits,
    this.position,
    this.matchNotes,
    List<String>? deletedMentalTags,
    List<String>? deletedSkillsTags,
    List<String>? deletedEnvTags,
    List<String>? customMentalTags,
    List<String>? customSkillsTags,
    List<String>? customEnvTags,
    List<String>? customTargetTypes,
    List<String>? deletedTargetTypes,
  })  : deletedMentalTags = deletedMentalTags ?? [],
        deletedSkillsTags = deletedSkillsTags ?? [],
        deletedEnvTags = deletedEnvTags ?? [],
        customMentalTags = customMentalTags ?? [],
        customSkillsTags = customSkillsTags ?? [],
        customEnvTags = customEnvTags ?? [],
        customTargetTypes = customTargetTypes ?? [],
        deletedTargetTypes = deletedTargetTypes ?? [];

  int get totalHits {
    return stages.fold(0, (sum, stage) => sum + stage.hitCount);
  }

  int get totalShotsTaken {
    return stages.fold(0, (sum, stage) => sum + stage.shotResults.length);
  }

  double get hitRate {
    final shots = totalShotsTaken;
    if (shots == 0) return 0.0;
    return totalHits / shots;
  }

  int get completedStagesCount {
    return stages.where((s) => s.status == 'completed').length;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'date': date.toIso8601String(),
      'numStages': numStages,
      'shotsPerStage': shotsPerStage,
      'stages': stages.map((x) => x.toMap()).toList(),
      'winnerHits': winnerHits,
      'position': position,
      'matchNotes': matchNotes,
      'deletedMentalTags': deletedMentalTags,
      'deletedSkillsTags': deletedSkillsTags,
      'deletedEnvTags': deletedEnvTags,
      'customMentalTags': customMentalTags,
      'customSkillsTags': customSkillsTags,
      'customEnvTags': customEnvTags,
      'customTargetTypes': customTargetTypes,
      'deletedTargetTypes': deletedTargetTypes,
    };
  }

  factory Match.fromMap(Map<dynamic, dynamic> map) {
    return Match(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      date: DateTime.parse(map['date']),
      numStages: map['numStages']?.toInt() ?? 0,
      shotsPerStage: map['shotsPerStage']?.toInt() ?? 10,
      stages: List<Stage>.from(
          map['stages']?.map((x) => Stage.fromMap(x as Map)) ?? const []),
      winnerHits: map['winnerHits']?.toInt(),
      position: map['position']?.toInt(),
      matchNotes: map['matchNotes'],
      deletedMentalTags:
          List<String>.from(map['deletedMentalTags'] ?? const []),
      deletedSkillsTags:
          List<String>.from(map['deletedSkillsTags'] ?? const []),
      deletedEnvTags: List<String>.from(map['deletedEnvTags'] ?? const []),
      customMentalTags: List<String>.from(map['customMentalTags'] ?? const []),
      customSkillsTags: List<String>.from(map['customSkillsTags'] ?? const []),
      customEnvTags: List<String>.from(map['customEnvTags'] ?? const []),
      customTargetTypes:
          List<String>.from(map['customTargetTypes'] ?? const []),
      deletedTargetTypes:
          List<String>.from(map['deletedTargetTypes'] ?? const []),
    );
  }

  String toJson() => json.encode(toMap());

  factory Match.fromJson(String source) => Match.fromMap(json.decode(source));
}

class Stage {
  final int stageNumber;
  String name; // Stage name (optional)
  String status; // 'pending', 'completed'
  int numTargets;
  List<TargetArray> targetArrays;
  WindPlan windPlan;
  bool timedOut;
  int timeRemaining; // in seconds
  int avgHeartRate; // in BPM
  List<String> shotResults; // 'hit', 'miss', 'timeOutMiss'
  String mentalErrors;
  String skillsErrors;
  String environmentalErrors;
  int timeLimit; // in seconds
  int numPositions; // number of positions
  List<double> shotTimes; // elapsed time in seconds for each shot
  int plannedRoundCount; // total round count planned for this stage
  List<String> shotTargetsSequence; // sequence of targets in shooting order
  List<double> shotRolls; // roll in degrees for each shot
  List<double> shotStabilities; // stability (MOA) value for each shot

  Stage({
    required this.stageNumber,
    this.name = '',
    this.status = 'pending',
    this.numTargets = 0,
    required this.targetArrays,
    required this.windPlan,
    this.timedOut = false,
    this.timeRemaining = 0,
    this.avgHeartRate = 0,
    required this.shotResults,
    this.mentalErrors = '',
    this.skillsErrors = '',
    this.environmentalErrors = '',
    this.timeLimit = 105,
    this.numPositions = 1,
    this.shotTimes = const [],
    this.plannedRoundCount = 10,
    this.shotTargetsSequence = const [],
    this.shotRolls = const [],
    this.shotStabilities = const [],
  });

  List<Target> get targets {
    List<Target> all = [];
    int globalIndex = 1;
    for (var array in targetArrays) {
      for (var t in array.targets) {
        all.add(Target(
          index: globalIndex++,
          size: t.size,
          type: t.type,
          shotsCount: t.shotsCount,
          isMovingTarget: t.isMovingTarget,
          targetSpeedMph: t.targetSpeedMph,
          targetLeadMil: t.targetLeadMil,
        ));
      }
    }
    return all;
  }

  int get hitCount => shotResults.where((r) => r == 'hit').length;
  int get missCount => shotResults.where((r) => r == 'miss').length;
  int get timeOutMissCount =>
      shotResults.where((r) => r == 'timeOutMiss').length;

  Map<String, dynamic> toMap() {
    return {
      'stageNumber': stageNumber,
      'name': name,
      'status': status,
      'numTargets': numTargets,
      'targetArrays': targetArrays.map((x) => x.toMap()).toList(),
      'windPlan': windPlan.toMap(),
      'timedOut': timedOut,
      'timeRemaining': timeRemaining,
      'avgHeartRate': avgHeartRate,
      'shotResults': shotResults,
      'mentalErrors': mentalErrors,
      'skillsErrors': skillsErrors,
      'environmentalErrors': environmentalErrors,
      'timeLimit': timeLimit,
      'numPositions': numPositions,
      'shotTimes': shotTimes,
      'plannedRoundCount': plannedRoundCount,
      'shotTargetsSequence': shotTargetsSequence,
      'shotRolls': shotRolls,
      'shotStabilities': shotStabilities,
    };
  }

  factory Stage.fromMap(Map<dynamic, dynamic> map) {
    final targetArraysList = map['targetArrays'] != null
        ? List<TargetArray>.from(
            map['targetArrays']?.map((x) => TargetArray.fromMap(x as Map)) ??
                const [])
        : <TargetArray>[];

    if (targetArraysList.isEmpty && map['targets'] != null) {
      final List<dynamic> rawTargets = map['targets'] as List<dynamic>;
      if (rawTargets.isNotEmpty) {
        final Map<String, List<Target>> groups = {};
        final Map<String, String> groupDistance = {};
        final Map<String, String> groupDof = {};

        for (var rawT in rawTargets) {
          if (rawT is Map) {
            final t = Target.fromMap(rawT);
            final d = rawT['distance']?.toString() ?? '';
            final dof = rawT['degreeOfFire']?.toString() ?? '';
            final key = '${d}_$dof';
            groups.putIfAbsent(key, () => []).add(t);
            groupDistance[key] = d;
            groupDof[key] = dof;
          }
        }
        for (var key in groups.keys) {
          targetArraysList.add(TargetArray(
            distance: groupDistance[key] ?? '',
            degreeOfFire: groupDof[key] ?? '',
            targets: groups[key]!,
          ));
        }
      }
    }

    return Stage(
      stageNumber: map['stageNumber']?.toInt() ?? 1,
      name: map['name'] ?? '',
      status: map['status'] ?? 'pending',
      numTargets: map['numTargets']?.toInt() ?? 0,
      targetArrays: targetArraysList,
      windPlan: WindPlan.fromMap(map['windPlan'] as Map? ?? const {}),
      timedOut: map['timedOut'] ?? false,
      timeRemaining: map['timeRemaining']?.toInt() ?? 0,
      avgHeartRate: map['avgHeartRate']?.toInt() ?? 0,
      shotResults: List<String>.from(map['shotResults'] ?? const []),
      mentalErrors: map['mentalErrors'] ?? '',
      skillsErrors: map['skillsErrors'] ?? '',
      environmentalErrors: map['environmentalErrors'] ?? '',
      timeLimit: map['timeLimit']?.toInt() ?? 105,
      numPositions: map['numPositions']?.toInt() ?? 1,
      shotTimes: List<double>.from(map['shotTimes'] ?? const []),
      plannedRoundCount: map['plannedRoundCount']?.toInt() ?? 10,
      shotTargetsSequence: List<String>.from(map['shotTargetsSequence'] ?? const []),
      shotRolls: List<double>.from(map['shotRolls'] ?? const []),
      shotStabilities: List<double>.from(map['shotStabilities'] ?? const []),
    );
  }
}

class Target {
  final int index;
  String size;
  String
      type; // IPSC, Sniper Head, Sniper Shoulders, Circles, Diamonds, Square, Pig, Coyote, Sasquatch, etc.
  int shotsCount; // number of shots for this target
  bool isMovingTarget; // whether this target is a moving target
  double targetSpeedMph; // speed in mph to send to Kestrel
  double targetLeadMil; // lead value (MIL) returned from Kestrel

  Target({
    required this.index,
    this.size = '',
    this.type = 'IPSC',
    this.shotsCount = 1,
    this.isMovingTarget = false,
    this.targetSpeedMph = 0.0,
    this.targetLeadMil = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'size': size,
      'type': type,
      'shotsCount': shotsCount,
      'isMovingTarget': isMovingTarget,
      'targetSpeedMph': targetSpeedMph,
      'targetLeadMil': targetLeadMil,
    };
  }

  factory Target.fromMap(Map<dynamic, dynamic> map) {
    return Target(
      index: map['index']?.toInt() ?? 0,
      size: map['size'] ?? '',
      type: map['type'] ?? 'IPSC',
      shotsCount: map['shotsCount']?.toInt() ?? 1,
      isMovingTarget: map['isMovingTarget'] ?? false,
      targetSpeedMph: (map['targetSpeedMph'] as num?)?.toDouble() ?? 0.0,
      targetLeadMil: (map['targetLeadMil'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WindPlan {
  double prevValue; // e.g. 0.5 MIL
  String prevDirection; // 'L' or 'R' or 'None'
  double kestrelValue;
  String kestrelDirection;
  double actualValue;
  String actualDirection;

  WindPlan({
    this.prevValue = 0.0,
    this.prevDirection = 'None',
    this.kestrelValue = 0.0,
    this.kestrelDirection = 'None',
    this.actualValue = 0.0,
    this.actualDirection = 'None',
  });

  String get prevFormatted => prevDirection == 'None'
      ? '0.00 MIL'
      : '${prevValue.toStringAsFixed(2)} MIL $prevDirection';
  String get kestrelFormatted => kestrelDirection == 'None'
      ? '0.00 MIL'
      : '${kestrelValue.toStringAsFixed(2)} MIL $kestrelDirection';
  String get actualFormatted => actualDirection == 'None'
      ? '0.00 MIL'
      : '${actualValue.toStringAsFixed(2)} MIL $actualDirection';

  Map<String, dynamic> toMap() {
    return {
      'prevValue': prevValue,
      'prevDirection': prevDirection,
      'kestrelValue': kestrelValue,
      'kestrelDirection': kestrelDirection,
      'actualValue': actualValue,
      'actualDirection': actualDirection,
    };
  }

  factory WindPlan.fromMap(Map<dynamic, dynamic> map) {
    return WindPlan(
      prevValue: (map['prevValue'] as num?)?.toDouble() ?? 0.0,
      prevDirection: map['prevDirection'] ?? 'None',
      kestrelValue: (map['kestrelValue'] as num?)?.toDouble() ?? 0.0,
      kestrelDirection: map['kestrelDirection'] ?? 'None',
      actualValue: (map['actualValue'] as num?)?.toDouble() ?? 0.0,
      actualDirection: map['actualDirection'] ?? 'None',
    );
  }
}

class TargetArray {
  String distance;
  String degreeOfFire;
  String inclination;
  List<Target> targets;
  double minWindSpeed;
  double maxWindSpeed;
  int windClockDirection;
  double extrapolatedWindSpeed;
  int extrapolatedClockDirection;
  String elevationResult;
  String windageResult;

  /// 0–23 clock slots: 0 = 12:00, 1 = 12:30, 2 = 1:00, … (15° steps).
  static int migrateWindClockSlot(int value) {
    if (value >= 0 && value <= 23) return value;
    if (value == 12) return 0;
    if (value >= 1 && value <= 11) return value * 2;
    return 0;
  }

  static String formatClockSlot(int slot) {
    final normalized = slot % 24;
    final totalMinutes = normalized * 30;
    final hour = (totalMinutes ~/ 60) % 12;
    final minute = totalMinutes % 60;
    final displayHour = hour == 0 ? 12 : hour;
    return minute == 0 ? '$displayHour:00' : '$displayHour:30';
  }

  /// Kestrel Link [F1]: clock position → relative wind degrees (12:00 = 0°).
  static double clockSlotToDegrees(int slot) {
    final normalized = slot % 24;
    final totalMinutes = normalized * 30;
    final hour = (totalMinutes ~/ 60) % 12;
    final minute = totalMinutes % 60;
    final clockHour = hour == 0 ? 0.0 : hour.toDouble();
    var degrees = clockHour * 30.0;
    if (minute == 30) degrees += 15.0;
    return degrees % 360.0;
  }

  static int degreesToClockSlot(double degrees) {
    final normalized = ((degrees % 360) + 360) % 360;
    return ((normalized / 15).round()) % 24;
  }

  static String formatElevationMil(double mil) {
    if (mil.abs() < 0.005) return '0.00 MIL';
    final dir = mil < 0 ? 'U' : 'D';
    return '${mil.abs().toStringAsFixed(2)} $dir MIL';
  }

  static String formatWindageMil(double mil) {
    if (mil.abs() < 0.005) return '0.00 MIL';
    final dir = mil < 0 ? 'R' : 'L';
    return '${mil.abs().toStringAsFixed(2)} $dir MIL';
  }

  static String formatWindagePair(double w1, double w2) {
    final formatted1 = formatWindageMil(w1);
    if ((w1 - w2).abs() < 0.005) return formatted1;
    return 'W1: $formatted1  W2: ${formatWindageMil(w2)}';
  }

  static String formatWindSpeedRange(double minMph, double maxMph) {
    if ((minMph - maxMph).abs() < 0.005) {
      return '${minMph.toStringAsFixed(minMph.truncateToDouble() == minMph ? 0 : 1)} mph';
    }
    return '$minMph - $maxMph mph';
  }

  TargetArray({
    this.distance = '',
    this.degreeOfFire = '',
    this.inclination = '0',
    required this.targets,
    this.minWindSpeed = 0.0,
    this.maxWindSpeed = 0.0,
    this.windClockDirection = 0,
    this.extrapolatedWindSpeed = 0.0,
    this.extrapolatedClockDirection = 0,
    this.elevationResult = '',
    this.windageResult = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'distance': distance,
      'degreeOfFire': degreeOfFire,
      'inclination': inclination,
      'targets': targets.map((x) => x.toMap()).toList(),
      'minWindSpeed': minWindSpeed,
      'maxWindSpeed': maxWindSpeed,
      'windClockDirection': windClockDirection,
      'extrapolatedWindSpeed': extrapolatedWindSpeed,
      'extrapolatedClockDirection': extrapolatedClockDirection,
      'elevationResult': elevationResult,
      'windageResult': windageResult,
    };
  }

  factory TargetArray.fromMap(Map<dynamic, dynamic> map) {
    return TargetArray(
      distance: map['distance'] ?? '',
      degreeOfFire: map['degreeOfFire'] ?? '',
      inclination: map['inclination'] ?? '0',
      targets: List<Target>.from(
          map['targets']?.map((x) => Target.fromMap(x as Map)) ?? const []),
      minWindSpeed: (map['minWindSpeed'] as num?)?.toDouble() ?? 0.0,
      maxWindSpeed: (map['maxWindSpeed'] as num?)?.toDouble() ?? 0.0,
      windClockDirection: TargetArray.migrateWindClockSlot(
        map['windClockDirection']?.toInt() ?? 12,
      ),
      extrapolatedWindSpeed:
          (map['extrapolatedWindSpeed'] as num?)?.toDouble() ?? 0.0,
      extrapolatedClockDirection: TargetArray.migrateWindClockSlot(
        map['extrapolatedClockDirection']?.toInt() ?? 0,
      ),
      elevationResult: map['elevationResult'] ?? '',
      windageResult: map['windageResult'] ?? '',
    );
  }
}
