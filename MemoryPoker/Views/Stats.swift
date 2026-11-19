import Foundation

/// 전적 — UserDefaults에 저장
enum Stats {
    struct Record: Equatable {
        var wins = 0, losses = 0, draws = 0
        var total: Int { wins + losses + draws }
    }

    /// 연습(혼자 하기) 기록: 최고의 조합을 찾은 횟수와 연속 기록
    struct Practice: Equatable {
        var played = 0, perfect = 0, streak = 0, bestStreak = 0
    }

    private static var defaults: UserDefaults { .standard }

    private static func key(_ level: BotLevel, _ kind: String) -> String {
        "stats.bot.\(level.rawValue).\(kind)"
    }

    static func record(for level: BotLevel) -> Record {
        Record(
            wins: defaults.integer(forKey: key(level, "win")),
            losses: defaults.integer(forKey: key(level, "loss")),
            draws: defaults.integer(forKey: key(level, "draw"))
        )
    }

    /// 사람은 항상 first 자리다.
    static func add(_ outcome: Outcome, level: BotLevel) {
        let kind: String
        switch outcome {
        case .firstWins: kind = "win"
        case .secondWins: kind = "loss"
        case .draw: kind = "draw"
        }
        let k = key(level, kind)
        defaults.set(defaults.integer(forKey: k) + 1, forKey: k)
    }

    static var practice: Practice {
        Practice(
            played: defaults.integer(forKey: "stats.practice.played"),
            perfect: defaults.integer(forKey: "stats.practice.perfect"),
            streak: defaults.integer(forKey: "stats.practice.streak"),
            bestStreak: defaults.integer(forKey: "stats.practice.bestStreak")
        )
    }

    static func addPractice(perfect: Bool) {
        var record = practice
        record.played += 1
        if perfect {
            record.perfect += 1
            record.streak += 1
            record.bestStreak = max(record.bestStreak, record.streak)
        } else {
            record.streak = 0
        }
        defaults.set(record.played, forKey: "stats.practice.played")
        defaults.set(record.perfect, forKey: "stats.practice.perfect")
        defaults.set(record.streak, forKey: "stats.practice.streak")
        defaults.set(record.bestStreak, forKey: "stats.practice.bestStreak")
    }
}
