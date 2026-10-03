// The score, kept dry: how many you've squished, how many swings missed,
// the biggest swarm you've come back to, the longest you've been gone.
// Persisted in UserDefaults.

import Foundation

final class Stats {
    private(set) var kills = 0, misses = 0, crumbs = 0, peakSwarm = 0
    private(set) var longestAbsence: TimeInterval = 0
    private let d = UserDefaults.standard

    init() {
        kills = d.integer(forKey: "stats.kills"); misses = d.integer(forKey: "stats.misses")
        crumbs = d.integer(forKey: "stats.crumbs"); peakSwarm = d.integer(forKey: "stats.peakSwarm")
        longestAbsence = d.double(forKey: "stats.longestAbsence")
    }
    private func save() {
        d.set(kills, forKey: "stats.kills"); d.set(misses, forKey: "stats.misses")
        d.set(crumbs, forKey: "stats.crumbs"); d.set(peakSwarm, forKey: "stats.peakSwarm")
        d.set(longestAbsence, forKey: "stats.longestAbsence")
    }

    func noteKill() { kills += 1; save() }
    func noteMiss() { misses += 1; save() }
    func noteCrumb() { crumbs += 1; save() }
    func notePopulation(_ n: Int) { if n > peakSwarm { peakSwarm = n; save() } }
    func noteIdle(_ s: TimeInterval) { if s > longestAbsence { longestAbsence = s; save() } }

    var summary: String {
        let abs: String
        if longestAbsence < 60 { abs = "—" }
        else if longestAbsence < 3600 { abs = "\(Int(longestAbsence / 60)) min" }
        else { abs = String(format: "%dh%02dm", Int(longestAbsence / 3600), Int(longestAbsence / 60) % 60) }
        return "\(kills) squished · \(misses) got away · peak swarm \(peakSwarm) · longest absence \(abs)"
    }
}
