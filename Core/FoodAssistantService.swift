import Foundation

enum FoodSafetyStatus: String, Codable {
    case safe
    case caution
    case danger
    case unknown

    var label: String {
        switch self {
        case .safe:
            return "Safe in moderation"
        case .caution:
            return "Use caution"
        case .danger:
            return "Dangerous — avoid"
        case .unknown:
            return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .safe:
            return "checkmark.circle.fill"
        case .caution:
            return "exclamationmark.triangle.fill"
        case .danger:
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
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

final class FoodAssistantService: FoodAssistantQuerying {
    static let shared = FoodAssistantService()

    private init() {}

    func query(_ text: String) async -> FoodAssistantResult {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized.contains("cucumber") || normalized.contains("מלפפון") {
            return FoodAssistantResult(
                status: .safe,
                headline: "Cucumber",
                explanation: "Cucumbers are generally safe for dogs and can be a low-calorie, hydrating snack when served plain.",
                tips: [
                    "Cut into small slices to reduce choking risk",
                    "Serve plain, without salt or seasoning",
                    "Avoid pickled cucumber"
                ]
            )
        }

        if normalized.contains("banana") || normalized.contains("בננה") {
            return FoodAssistantResult(
                status: .safe,
                headline: "Banana",
                explanation: "Banana is usually safe for dogs in small amounts.",
                tips: [
                    "Serve small pieces only",
                    "Because it contains sugar, keep portions moderate",
                    "Do not give the peel"
                ]
            )
        }

        if normalized.contains("apple") || normalized.contains("תפוח") {
            return FoodAssistantResult(
                status: .safe,
                headline: "Apple",
                explanation: "Apple is generally safe for dogs when prepared properly.",
                tips: [
                    "Remove seeds and core",
                    "Serve in small slices",
                    "Plain apple only"
                ]
            )
        }

        if normalized.contains("egg") || normalized.contains("eggs") || normalized.contains("ביצה") {
            return FoodAssistantResult(
                status: .safe,
                headline: "Eggs",
                explanation: "Cooked eggs are generally safe for dogs.",
                tips: [
                    "Serve cooked, not raw",
                    "Do not add oil, salt, or spices",
                    "Start with a small portion"
                ]
            )
        }

        if normalized.contains("peanut butter") || normalized.contains("חמאת בוטנים") {
            return FoodAssistantResult(
                status: .caution,
                headline: "Peanut Butter",
                explanation: "Peanut butter can be okay in small amounts, but only if it does not contain xylitol.",
                tips: [
                    "Check the ingredient list carefully",
                    "Avoid any product with xylitol",
                    "Use small portions only"
                ]
            )
        }

        if normalized.contains("yogurt") || normalized.contains("יוגורט") {
            return FoodAssistantResult(
                status: .caution,
                headline: "Yogurt",
                explanation: "Plain yogurt may be okay for some dogs, but others are sensitive to dairy.",
                tips: [
                    "Use plain yogurt only",
                    "Avoid sweetened or flavored yogurt",
                    "Stop if your dog shows stomach upset"
                ]
            )
        }

        if normalized.contains("tuna") || normalized.contains("טונה") {
            return FoodAssistantResult(
                status: .caution,
                headline: "Tuna",
                explanation: "Tuna is not usually the best regular food for dogs because of salt and long-term mercury concerns.",
                tips: [
                    "Use plain tuna in water only",
                    "Avoid salty or seasoned versions",
                    "Treat as occasional only"
                ]
            )
        }

        if normalized.contains("grape") || normalized.contains("grapes") || normalized.contains("ענב") {
            return FoodAssistantResult(
                status: .danger,
                headline: "Grapes",
                explanation: "Grapes and raisins are toxic to dogs and can cause serious kidney injury.",
                tips: [
                    "Do not give grapes or raisins at all",
                    "Contact a vet immediately if eaten",
                    "Do not wait for symptoms"
                ]
            )
        }

        if normalized.contains("chocolate") || normalized.contains("שוקולד") {
            return FoodAssistantResult(
                status: .danger,
                headline: "Chocolate",
                explanation: "Chocolate is toxic to dogs. It contains theobromine and caffeine, which can be dangerous even in small amounts.",
                tips: [
                    "Do not give chocolate in any form",
                    "Dark chocolate is especially dangerous",
                    "Contact a vet urgently if your dog ate any"
                ]
            )
        }

        if normalized.contains("onion") || normalized.contains("בצל") {
            return FoodAssistantResult(
                status: .danger,
                headline: "Onion",
                explanation: "Onion is toxic to dogs and can damage red blood cells.",
                tips: [
                    "Avoid raw, cooked, powdered, or seasoned onion",
                    "Seek veterinary advice if eaten",
                    "Watch for weakness or vomiting"
                ]
            )
        }

        if normalized.contains("xylitol") {
            return FoodAssistantResult(
                status: .danger,
                headline: "Xylitol",
                explanation: "Xylitol is highly toxic to dogs and can cause a fast drop in blood sugar and serious complications.",
                tips: [
                    "Treat as an emergency",
                    "Go to a vet immediately",
                    "Check gum, candy, and peanut butter labels"
                ]
            )
        }

        return FoodAssistantResult(
            status: .unknown,
            headline: "Needs a manual check",
            explanation: "I do not have a reliable built-in answer for this food yet.",
            tips: [
                "Check with your veterinarian before feeding it",
                "Avoid guessing with unfamiliar foods",
                "Try asking with the exact food name"
            ]
        )
    }
}
