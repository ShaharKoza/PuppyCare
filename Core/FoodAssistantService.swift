import Foundation

enum FoodSafetyStatus: String, Codable {
    case safe
    case caution
    case danger
    case unknown

    var label: String {
        switch self {
        case .safe:    return "Safe in moderation"
        case .caution: return "Use caution"
        case .danger:  return "Dangerous — avoid"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .safe:    return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .danger:  return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

struct FoodAssistantResult: Codable {
    let status: FoodSafetyStatus
    let headline: String
    let explanation: String
    let tips: [String]
}

protocol FoodAssistantQuerying {
    func query(_ text: String) async -> FoodAssistantResult
}

// MARK: - Service

final class FoodAssistantService: FoodAssistantQuerying {
    static let shared = FoodAssistantService()

    /// One entry per food. Keywords are matched against the user's input;
    /// the first entry whose keyword matches exactly OR fuzzily wins.
    private struct FoodEntry {
        let keywords: [String]
        let result: FoodAssistantResult
    }

    private let entries: [FoodEntry]

    private init() {
        self.entries = Self.buildDatabase()
    }

    // ── Public query API ────────────────────────────────────────────────

    func query(_ text: String) async -> FoodAssistantResult {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else { return Self.unknownResult }

        // Fast path: exact substring on any keyword.
        for entry in entries {
            for kw in entry.keywords where normalized.contains(kw) {
                return entry.result
            }
        }

        // Fuzzy path: tokenise the query, compute Levenshtein distance
        // against every keyword, accept best match if distance ≤ threshold.
        // Threshold scales with word length — short words ("egg", "ביצה")
        // tolerate at most 1 edit; longer words tolerate 2.
        let tokens = normalized
            .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "אבגדהוזחטיכךלמםנןסעפףצץקרשת")).inverted)
            .filter { !$0.isEmpty }

        var bestEntry: FoodEntry?
        var bestDistance = Int.max

        for entry in entries {
            for kw in entry.keywords {
                let kwTokens = kw.split(separator: " ")
                for kwToken in kwTokens {
                    let kwStr = String(kwToken)
                    let allowed = kwStr.count >= 6 ? 2 : 1
                    for token in tokens {
                        // Skip tokens that are too different in length to plausibly match.
                        guard abs(token.count - kwStr.count) <= allowed else { continue }
                        let d = Self.levenshtein(token, kwStr)
                        if d <= allowed && d < bestDistance {
                            bestDistance = d
                            bestEntry = entry
                        }
                    }
                }
            }
        }

        if let bestEntry, bestDistance < Int.max {
            return bestEntry.result
        }
        return Self.unknownResult
    }

    // ── Database ────────────────────────────────────────────────────────

    private static func buildDatabase() -> [FoodEntry] {
        return [
            FoodEntry(
                keywords: ["cucumber", "מלפפון"],
                result: FoodAssistantResult(
                    status: .safe, headline: "Cucumber",
                    explanation: "Cucumbers are generally safe for dogs and can be a low-calorie, hydrating snack when served plain.",
                    tips: [
                        "Cut into small slices to reduce choking risk",
                        "Serve plain, without salt or seasoning",
                        "Avoid pickled cucumber"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["banana", "בננה"],
                result: FoodAssistantResult(
                    status: .safe, headline: "Banana",
                    explanation: "Banana is usually safe for dogs in small amounts.",
                    tips: [
                        "Serve small pieces only",
                        "Because it contains sugar, keep portions moderate",
                        "Do not give the peel"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["apple", "תפוח"],
                result: FoodAssistantResult(
                    status: .safe, headline: "Apple",
                    explanation: "Apple is generally safe for dogs when prepared properly.",
                    tips: [
                        "Remove seeds and core",
                        "Serve in small slices",
                        "Plain apple only"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["egg", "eggs", "ביצה", "ביצים"],
                result: FoodAssistantResult(
                    status: .safe, headline: "Eggs",
                    explanation: "Cooked eggs are generally safe for dogs.",
                    tips: [
                        "Serve cooked, not raw",
                        "Do not add oil, salt, or spices",
                        "Start with a small portion"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["carrot", "carrots", "גזר"],
                result: FoodAssistantResult(
                    status: .safe, headline: "Carrot",
                    explanation: "Carrots are safe and a good low-calorie snack — many dogs enjoy them raw.",
                    tips: [
                        "Cut into bite-sized pieces",
                        "Raw or cooked is fine",
                        "Avoid seasoned carrots"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["chicken", "עוף"],
                result: FoodAssistantResult(
                    status: .safe, headline: "Chicken",
                    explanation: "Plain cooked chicken is a common, safe protein source for most dogs.",
                    tips: [
                        "Serve unseasoned and fully cooked",
                        "Remove bones — cooked bones can splinter",
                        "Watch for allergies"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["peanut butter", "חמאת בוטנים"],
                result: FoodAssistantResult(
                    status: .caution, headline: "Peanut Butter",
                    explanation: "Peanut butter can be okay in small amounts, but only if it does not contain xylitol.",
                    tips: [
                        "Check the ingredient list carefully",
                        "Avoid any product with xylitol",
                        "Use small portions only"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["yogurt", "yoghurt", "יוגורט"],
                result: FoodAssistantResult(
                    status: .caution, headline: "Yogurt",
                    explanation: "Plain yogurt may be okay for some dogs, but others are sensitive to dairy.",
                    tips: [
                        "Use plain yogurt only",
                        "Avoid sweetened or flavored yogurt",
                        "Stop if your dog shows stomach upset"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["tuna", "טונה"],
                result: FoodAssistantResult(
                    status: .caution, headline: "Tuna",
                    explanation: "Tuna is not usually the best regular food for dogs because of salt and long-term mercury concerns.",
                    tips: [
                        "Use plain tuna in water only",
                        "Avoid salty or seasoned versions",
                        "Treat as occasional only"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["cheese", "גבינה"],
                result: FoodAssistantResult(
                    status: .caution, headline: "Cheese",
                    explanation: "Many dogs tolerate small amounts of cheese, but it's high in fat and some dogs are lactose intolerant.",
                    tips: [
                        "Tiny portions only",
                        "Skip if your dog is overweight",
                        "Avoid blue cheese — it can be toxic"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["grape", "grapes", "raisin", "raisins", "ענב", "ענבים", "צימוק", "צימוקים"],
                result: FoodAssistantResult(
                    status: .danger, headline: "Grapes",
                    explanation: "Grapes and raisins are toxic to dogs and can cause serious kidney injury.",
                    tips: [
                        "Do not give grapes or raisins at all",
                        "Contact a vet immediately if eaten",
                        "Do not wait for symptoms"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["chocolate", "שוקולד"],
                result: FoodAssistantResult(
                    status: .danger, headline: "Chocolate",
                    explanation: "Chocolate is toxic to dogs. It contains theobromine and caffeine, which can be dangerous even in small amounts.",
                    tips: [
                        "Do not give chocolate in any form",
                        "Dark chocolate is especially dangerous",
                        "Contact a vet urgently if your dog ate any"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["onion", "onions", "בצל"],
                result: FoodAssistantResult(
                    status: .danger, headline: "Onion",
                    explanation: "Onion is toxic to dogs and can damage red blood cells.",
                    tips: [
                        "Avoid raw, cooked, powdered, or seasoned onion",
                        "Seek veterinary advice if eaten",
                        "Watch for weakness or vomiting"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["garlic", "שום"],
                result: FoodAssistantResult(
                    status: .danger, headline: "Garlic",
                    explanation: "Garlic is in the same family as onion and is similarly toxic — even small amounts can damage red blood cells.",
                    tips: [
                        "Avoid raw, cooked, and powdered garlic",
                        "Read labels carefully — many human foods contain it",
                        "Seek veterinary advice if eaten in any amount"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["xylitol", "קסיליטול"],
                result: FoodAssistantResult(
                    status: .danger, headline: "Xylitol",
                    explanation: "Xylitol is highly toxic to dogs and can cause a fast drop in blood sugar and serious complications.",
                    tips: [
                        "Treat as an emergency",
                        "Go to a vet immediately",
                        "Check gum, candy, and peanut butter labels"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["avocado", "אבוקדו"],
                result: FoodAssistantResult(
                    status: .danger, headline: "Avocado",
                    explanation: "Avocado contains persin, which is toxic to dogs in larger amounts. The pit also poses a choking and obstruction risk.",
                    tips: [
                        "Avoid avocado, including guacamole and dips",
                        "Never let your dog access the pit",
                        "Contact a vet if eaten in quantity"
                    ]
                )
            ),
            FoodEntry(
                keywords: ["macadamia", "מקדמיה"],
                result: FoodAssistantResult(
                    status: .danger, headline: "Macadamia Nuts",
                    explanation: "Macadamia nuts are toxic to dogs and can cause weakness, vomiting, tremors, and hyperthermia.",
                    tips: [
                        "Do not give macadamia nuts",
                        "Watch food labels and cookies for them",
                        "Seek veterinary help if eaten"
                    ]
                )
            ),
        ]
    }

    private static let unknownResult = FoodAssistantResult(
        status: .unknown,
        headline: "Needs a manual check",
        explanation: "I do not have a reliable built-in answer for this food yet.",
        tips: [
            "Check with your veterinarian before feeding it",
            "Avoid guessing with unfamiliar foods",
            "Try asking with the exact food name"
        ]
    )

    // MARK: - Levenshtein
    //
    // Classic dynamic-programming edit distance. Used for fuzzy matching so
    // a typo like "Bananaa" or "yougurt" still finds the right entry. The
    // implementation works the same for Hebrew because Swift Strings index
    // by Character (extended grapheme clusters), not bytes.
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let n = aChars.count
        let m = bChars.count
        if n == 0 { return m }
        if m == 0 { return n }

        var prev = Array(0...m)
        var curr = [Int](repeating: 0, count: m + 1)

        for i in 1...n {
            curr[0] = i
            for j in 1...m {
                let cost = aChars[i-1] == bChars[j-1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,        // deletion
                    curr[j-1] + 1,      // insertion
                    prev[j-1] + cost    // substitution
                )
            }
            swap(&prev, &curr)
        }
        return prev[m]
    }
}
