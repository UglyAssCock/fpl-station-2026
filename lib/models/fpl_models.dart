class FplUserSession {
  final int entryId;
  final String firstName;
  final String lastName;
  final String email;
  final String cookieHeader;

  FplUserSession({
    required this.entryId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.cookieHeader,
  });

  String get fullName => '$firstName $lastName'.trim();
}

class TeamClub {
  final int id;
  final int code;
  final String name;
  final String shortName;
  final int strength;
  final int strengthAttackHome;
  final int strengthDefenseHome;

  TeamClub({
    required this.id,
    required this.code,
    required this.name,
    required this.shortName,
    required this.strength,
    required this.strengthAttackHome,
    required this.strengthDefenseHome,
  });

  factory TeamClub.fromJson(Map<String, dynamic> json) {
    return TeamClub(
      id: json['id'] ?? 0,
      code: json['code'] ?? 0,
      name: json['name'] ?? '',
      shortName: json['short_name'] ?? '',
      strength: json['strength'] ?? 3,
      strengthAttackHome: json['strength_attack_home'] ?? 1000,
      strengthDefenseHome: json['strength_defence_home'] ?? 1000,
    );
  }
}

class Player {
  final int id;
  final int code;
  final String firstName;
  final String secondName;
  final String webName;
  final int teamId;
  final int elementType; // 1=GKP, 2=DEF, 3=MID, 4=FWD
  final int nowCost; // tenths of million, e.g. 112 = £11.2m
  final int totalPoints;
  final int eventPoints;
  final double form;
  final double selectedByPercent;
  final String status; // a=available, d=doubtful, i=injured, s=suspended, u=unavailable
  final String news;
  final int? chanceOfPlayingNextRound;
  final int goalsScored;
  final int assists;
  final int cleanSheets;
  final int minutes;
  final int bonus;
  final int transfersInEvent;

  Player({
    required this.id,
    required this.code,
    required this.firstName,
    required this.secondName,
    required this.webName,
    required this.teamId,
    required this.elementType,
    required this.nowCost,
    required this.totalPoints,
    required this.eventPoints,
    required this.form,
    required this.selectedByPercent,
    required this.status,
    required this.news,
    required this.chanceOfPlayingNextRound,
    required this.goalsScored,
    required this.assists,
    required this.cleanSheets,
    required this.minutes,
    required this.bonus,
    required this.transfersInEvent,
  });

  double get price => nowCost / 10.0;
  String get priceString => '£${price.toStringAsFixed(1)}m';

  String get positionShort {
    switch (elementType) {
      case 1:
        return 'GKP';
      case 2:
        return 'DEF';
      case 3:
        return 'MID';
      case 4:
        return 'FWD';
      default:
        return 'PLY';
    }
  }

  String get positionFull {
    switch (elementType) {
      case 1:
        return 'GOALKEEPER';
      case 2:
        return 'DEFENDER';
      case 3:
        return 'MIDFIELDER';
      case 4:
        return 'FORWARD';
      default:
        return 'PLAYER';
    }
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] ?? 0,
      code: json['code'] ?? 0,
      firstName: json['first_name'] ?? '',
      secondName: json['second_name'] ?? '',
      webName: json['web_name'] ?? '',
      teamId: json['team'] ?? 0,
      elementType: json['element_type'] ?? 3,
      nowCost: json['now_cost'] ?? 50,
      totalPoints: json['total_points'] ?? 0,
      eventPoints: json['event_points'] ?? 0,
      form: double.tryParse((json['form'] ?? '0').toString()) ?? 0.0,
      selectedByPercent:
          double.tryParse((json['selected_by_percent'] ?? '0').toString()) ??
              0.0,
      status: json['status'] ?? 'a',
      news: json['news'] ?? '',
      chanceOfPlayingNextRound: json['chance_of_playing_next_round'],
      goalsScored: json['goals_scored'] ?? 0,
      assists: json['assists'] ?? 0,
      cleanSheets: json['clean_sheets'] ?? 0,
      minutes: json['minutes'] ?? 0,
      bonus: json['bonus'] ?? 0,
      transfersInEvent: json['transfers_in_event'] ?? 0,
    );
  }
}

class GameweekEvent {
  final int id;
  final String name;
  final String deadlineTime;
  final int averageEntryScore;
  final int highestScore;
  final bool isCurrent;
  final bool isNext;
  final bool finished;
  final int? mostSelected;
  final int? mostTransferredIn;
  final int? mostCaptained;
  final int transfersMade;
  final int chipPlaysCount;

  GameweekEvent({
    required this.id,
    required this.name,
    required this.deadlineTime,
    required this.averageEntryScore,
    required this.highestScore,
    required this.isCurrent,
    required this.isNext,
    required this.finished,
    this.mostSelected,
    this.mostTransferredIn,
    this.mostCaptained,
    required this.transfersMade,
    required this.chipPlaysCount,
  });

  factory GameweekEvent.fromJson(Map<String, dynamic> json) {
    int chipsTotal = 0;
    if (json['chip_plays'] is List) {
      for (final c in json['chip_plays']) {
        chipsTotal += (c['num_played'] as int? ?? 0);
      }
    }
    return GameweekEvent(
      id: json['id'] ?? 1,
      name: json['name'] ?? 'Gameweek',
      deadlineTime: json['deadline_time'] ?? '',
      averageEntryScore: json['average_entry_score'] ?? 0,
      highestScore: json['highest_score'] ?? 0,
      isCurrent: json['is_current'] ?? false,
      isNext: json['is_next'] ?? false,
      finished: json['finished'] ?? false,
      mostSelected: json['most_selected'],
      mostTransferredIn: json['most_transferred_in'],
      mostCaptained: json['most_captained'],
      transfersMade: json['transfers_made'] ?? 0,
      chipPlaysCount: chipsTotal,
    );
  }
}

class FixtureItem {
  final int id;
  final int? event;
  final String? kickoffTime;
  final int teamH;
  final int teamA;
  final int? teamHScore;
  final int? teamAScore;
  final int teamHDifficulty;
  final int teamADifficulty;
  final bool started;
  final bool finished;
  final int minutes;

  FixtureItem({
    required this.id,
    required this.event,
    required this.kickoffTime,
    required this.teamH,
    required this.teamA,
    required this.teamHScore,
    required this.teamAScore,
    required this.teamHDifficulty,
    required this.teamADifficulty,
    required this.started,
    required this.finished,
    required this.minutes,
  });

  factory FixtureItem.fromJson(Map<String, dynamic> json) {
    return FixtureItem(
      id: json['id'] ?? 0,
      event: json['event'],
      kickoffTime: json['kickoff_time'],
      teamH: json['team_h'] ?? 0,
      teamA: json['team_a'] ?? 0,
      teamHScore: json['team_h_score'],
      teamAScore: json['team_a_score'],
      teamHDifficulty: json['team_h_difficulty'] ?? 3,
      teamADifficulty: json['team_a_difficulty'] ?? 3,
      started: json['started'] ?? false,
      finished: json['finished'] ?? false,
      minutes: json['minutes'] ?? 0,
    );
  }
}

class SquadPick {
  int element;
  int position; // 1..11 starting, 12..15 bench
  int multiplier;
  bool isCaptain;
  bool isViceCaptain;
  int sellingPrice;

  SquadPick({
    required this.element,
    required this.position,
    required this.multiplier,
    required this.isCaptain,
    required this.isViceCaptain,
    this.sellingPrice = 0,
  });

  factory SquadPick.fromJson(Map<String, dynamic> json) {
    return SquadPick(
      element: json['element'] ?? 0,
      position: json['position'] ?? 1,
      multiplier: json['multiplier'] ?? 1,
      isCaptain: json['is_captain'] ?? false,
      isViceCaptain: json['is_vice_captain'] ?? false,
      sellingPrice: json['selling_price'] ?? 0,
    );
  }
}

class LeagueItem {
  final int id;
  final String name;
  final int? entryRank;
  final int? entryLastRank;

  LeagueItem({
    required this.id,
    required this.name,
    this.entryRank,
    this.entryLastRank,
  });

  factory LeagueItem.fromJson(Map<String, dynamic> json) {
    return LeagueItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Classic League',
      entryRank: json['entry_rank'],
      entryLastRank: json['entry_last_rank'],
    );
  }
}

class LeagueStandingRow {
  final int id;
  final int entry;
  final String playerName;
  final String entryName;
  final int rank;
  final int lastRank;
  final int eventTotal;
  final int total;

  LeagueStandingRow({
    required this.id,
    required this.entry,
    required this.playerName,
    required this.entryName,
    required this.rank,
    required this.lastRank,
    required this.eventTotal,
    required this.total,
  });

  factory LeagueStandingRow.fromJson(Map<String, dynamic> json) {
    return LeagueStandingRow(
      id: json['id'] ?? 0,
      entry: json['entry'] ?? 0,
      playerName: json['player_name'] ?? 'Manager',
      entryName: json['entry_name'] ?? 'Team',
      rank: json['rank'] ?? 0,
      lastRank: json['last_rank'] ?? 0,
      eventTotal: json['event_total'] ?? 0,
      total: json['total'] ?? 0,
    );
  }
}
