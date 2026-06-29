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
  }) : deletedMentalTags = deletedMentalTags ?? [],
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
      stages: List<Stage>.from(map['stages']?.map((x) => Stage.fromMap(x as Map)) ?? const []),
      winnerHits: map['winnerHits']?.toInt(),
      position: map['position']?.toInt(),
      matchNotes: map['matchNotes'],
      deletedMentalTags: List<String>.from(map['deletedMentalTags'] ?? const []),
      deletedSkillsTags: List<String>.from(map['deletedSkillsTags'] ?? const []),
      deletedEnvTags: List<String>.from(map['deletedEnvTags'] ?? const []),
      customMentalTags: List<String>.from(map['customMentalTags'] ?? const []),
      customSkillsTags: List<String>.from(map['customSkillsTags'] ?? const []),
      customEnvTags: List<String>.from(map['customEnvTags'] ?? const []),
      customTargetTypes: List<String>.from(map['customTargetTypes'] ?? const []),
      deletedTargetTypes: List<String>.from(map['deletedTargetTypes'] ?? const []),
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
  });

  List<Target> get targets {
    List<Target> all = [];
    int globalIndex = 1;
    for (var array in targetArrays) {
      for (var t in array.targets) {
        all.add(Target(
          index: globalIndex++,
          size: t.size,
          distance: array.distance,
          degreeOfFire: array.degreeOfFire,
          type: t.type,
          shotsCount: t.shotsCount,
        ));
      }
    }
    return all;
  }

  int get hitCount => shotResults.where((r) => r == 'hit').length;
  int get missCount => shotResults.where((r) => r == 'miss').length;
  int get timeOutMissCount => shotResults.where((r) => r == 'timeOutMiss').length;

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
    };
  }

  factory Stage.fromMap(Map<dynamic, dynamic> map) {
    final targetArraysList = map['targetArrays'] != null
        ? List<TargetArray>.from(map['targetArrays']?.map((x) => TargetArray.fromMap(x as Map)) ?? const [])
        : <TargetArray>[];

    if (targetArraysList.isEmpty && map['targets'] != null) {
      final legacyTargets = List<Target>.from(map['targets']?.map((x) => Target.fromMap(x as Map)) ?? const []);
      if (legacyTargets.isNotEmpty) {
        final Map<String, List<Target>> groups = {};
        for (var t in legacyTargets) {
          final key = '${t.distance}_${t.degreeOfFire}';
          groups.putIfAbsent(key, () => []).add(t);
        }
        for (var group in groups.values) {
          targetArraysList.add(TargetArray(
            distance: group.first.distance,
            degreeOfFire: group.first.degreeOfFire,
            targets: group,
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
    );
  }
}

class Target {
  final int index;
  String size;
  String distance;
  String degreeOfFire;
  String type; // IPSC, Sniper Head, Sniper Shoulders, Circles, Diamonds, Square, Pig, Coyote, Sasquatch, etc.
  int shotsCount; // number of shots for this target

  Target({
    required this.index,
    this.size = '',
    this.distance = '',
    this.degreeOfFire = '',
    this.type = 'IPSC',
    this.shotsCount = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'size': size,
      'distance': distance,
      'degreeOfFire': degreeOfFire,
      'type': type,
      'shotsCount': shotsCount,
    };
  }

  factory Target.fromMap(Map<dynamic, dynamic> map) {
    return Target(
      index: map['index']?.toInt() ?? 0,
      size: map['size'] ?? '',
      distance: map['distance'] ?? '',
      degreeOfFire: map['degreeOfFire'] ?? '',
      type: map['type'] ?? 'IPSC',
      shotsCount: map['shotsCount']?.toInt() ?? 1,
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

  String get prevFormatted => prevDirection == 'None' ? '0.0 MIL' : '${prevValue.toStringAsFixed(1)} MIL $prevDirection';
  String get kestrelFormatted => kestrelDirection == 'None' ? '0.0 MIL' : '${kestrelValue.toStringAsFixed(1)} MIL $kestrelDirection';
  String get actualFormatted => actualDirection == 'None' ? '0.0 MIL' : '${actualValue.toStringAsFixed(1)} MIL $actualDirection';

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
  List<Target> targets;

  TargetArray({
    this.distance = '',
    this.degreeOfFire = '',
    required this.targets,
  });

  Map<String, dynamic> toMap() {
    return {
      'distance': distance,
      'degreeOfFire': degreeOfFire,
      'targets': targets.map((x) => x.toMap()).toList(),
    };
  }

  factory TargetArray.fromMap(Map<dynamic, dynamic> map) {
    return TargetArray(
      distance: map['distance'] ?? '',
      degreeOfFire: map['degreeOfFire'] ?? '',
      targets: List<Target>.from(map['targets']?.map((x) => Target.fromMap(x as Map)) ?? const []),
    );
  }
}
