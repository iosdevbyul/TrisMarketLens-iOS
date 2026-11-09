import Foundation

/// Ensures the read-only baseline response is structurally safe to display.
/// This does not prove model performance or independently authenticated evidence.
enum BaselinePayloadValidation {
    static func validate(_ snapshot: BaselineBacktestSnapshot) -> Bool {
        guard nonblank(snapshot.id), nonblank(snapshot.title),
              snapshot.readiness.count <= 100,
              snapshot.timeline.count <= 100,
              snapshot.policyGroups.count <= 100,
              snapshot.fingerprints.count <= 100 else { return false }

        var readiness = Set<String>()
        for step in snapshot.readiness {
            guard nonblank(step.label), readiness.insert(step.label).inserted else { return false }
        }

        var timeline = Set<String>()
        for item in snapshot.timeline {
            guard nonblank(item.label), timeline.insert(item.label).inserted else { return false }
        }

        var groups = Set<String>()
        for group in snapshot.policyGroups {
            guard nonblank(group.title), group.rules.count <= 100,
                  groups.insert(group.title).inserted else { return false }
            var rules = Set<String>()
            for rule in group.rules {
                guard nonblank(rule.label), rules.insert(rule.label).inserted else { return false }
            }
        }

        var fingerprints = Set<String>()
        for fingerprint in snapshot.fingerprints {
            guard nonblank(fingerprint.label),
                  fingerprints.insert(fingerprint.label).inserted else { return false }
        }
        return true
    }

    private static func nonblank(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
