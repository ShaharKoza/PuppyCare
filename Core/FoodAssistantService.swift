import Foundation

// MARK: - Domain types

enum FoodSafetyStatus {
    case safe
    case caution
    case danger
    case unknown

    var label: String {
        switch self {
        case .safe:    return "Safe in moderation"
        case .caution: return "Use with caution"
        case .danger:  return "Dangerous — avoid"
        case .unknown: return "Not sure — ask your vet"
        }
    }

    var icon: String {
        switch self {
        case .safe:    return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .danger:  return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

struct FoodAssistantResult {
    let status: FoodSafetyStatus
    let headline: String
    let explanation: String
    let tips: [String]

    init(status: FoodSafetyStatus, headline: String, explanation: String, tips: [String] = []) {
        self.status = status
        self.headline = headline
        self.explanation = explanation
        self.tips = tips
    }
}

// MARK: - Service protocol
//
// To connect a real AI backend later, create a new type that conforms to this
// protocol (e.g. ClaudeAssistantService) and inject it into FoodAssistantView.
// No UI code needs to change.

protocol FoodAssistantQuerying {
    func query(_ question: String) async -> FoodAssistantResult
}

// MARK: - Local rule-based implementation

final class FoodAssistantService: FoodAssistantQuerying {
    static let shared = FoodAssistantService()
    private init() {}

    func query(_ question: String) async -> FoodAssistantResult {
        try? await Task.sleep(for: .milliseconds(380))
        return FoodKnowledgeBase.lookup(question)
    }
}

// MARK: - Knowledge base (private)

private struct FoodEntry {
    let keywords: [String]
    let result: FoodAssistantResult
}

private enum FoodKnowledgeBase {

    static func lookup(_ input: String) -> FoodAssistantResult {
        let normalized = input.lowercased()
        for entry in entries {
            if entry.keywords.contains(where: { normalized.contains($0) }) {
                return entry.result
            }
        }
        return unknownResult
    }

    // MARK: Unknown / fallback

    static let unknownResult = FoodAssistantResult(
        status: .unknown,
        headline: "Not in our database",
        explanation: "We don't have specific information about this food. When in doubt, it is always safest to check with your vet before giving something new to your dog.",
        tips: [
            "Ask your vet before introducing unfamiliar foods",
            "Introduce any new food gradually in small amounts and watch for reactions"
        ]
    )

    // MARK: Food entries

    static let entries: [FoodEntry] = [

        // ─────────────────────────────────────────────
        // MARK: — Safe —
        // ─────────────────────────────────────────────

        .init(keywords: ["cucumber"], result: .init(
            status: .safe,
            headline: "Cucumber",
            explanation: "Cucumbers are safe for dogs and make a great low-calorie, hydrating snack. Most dogs enjoy their crunchy texture.",
            tips: [
                "Cut into small slices to avoid a choking hazard",
                "Remove the skin if your dog has a sensitive stomach",
                "Avoid pickled cucumbers — the salt and vinegar are not suitable"
            ]
        )),

        .init(keywords: ["carrot"], result: .init(
            status: .safe,
            headline: "Carrots",
            explanation: "Carrots are an excellent snack for dogs. They are low in calories, high in fiber, and support dental health by helping to scrape plaque from teeth.",
            tips: [
                "Raw or cooked — both are fine",
                "Serve frozen to puppies who are teething",
                "Chop into manageable pieces for smaller dogs"
            ]
        )),

        .init(keywords: ["blueberr"], result: .init(
            status: .safe,
            headline: "Blueberries",
            explanation: "Blueberries are safe for dogs and packed with antioxidants, vitamins C and K, and fiber. They make a healthy and tasty treat in small amounts.",
            tips: [
                "Serve fresh or frozen",
                "Limit to a small handful due to natural sugar content",
                "Avoid dried blueberries — much more concentrated in sugar"
            ]
        )),

        .init(keywords: ["watermelon"], result: .init(
            status: .safe,
            headline: "Watermelon",
            explanation: "Watermelon flesh is safe for dogs and a great hydrating treat in warm weather. It is 92% water and provides vitamins A, B6, and C.",
            tips: [
                "Remove all seeds before serving",
                "Remove the green rind — it can cause digestive upset",
                "Cut into small cubes and serve chilled"
            ]
        )),

        .init(keywords: ["banana"], result: .init(
            status: .safe,
            headline: "Banana",
            explanation: "Bananas are safe for dogs in moderation. They are high in potassium and vitamins, but also high in natural sugar, so they should be an occasional treat rather than a daily staple.",
            tips: [
                "A few slices is plenty — not a whole banana at once",
                "Remove the peel — not toxic, but very hard to digest",
                "Too much sugar can affect dental health and weight over time"
            ]
        )),

        .init(keywords: ["egg"], result: .init(
            status: .safe,
            headline: "Eggs",
            explanation: "Cooked eggs are safe and nutritious for dogs. They are a great source of protein, amino acids, and essential fatty acids.",
            tips: [
                "Always serve cooked — raw eggs carry a salmonella risk",
                "Scrambled or boiled without salt or butter is best",
                "One egg a few times a week is a reasonable amount"
            ]
        )),

        .init(keywords: ["chicken"], result: .init(
            status: .safe,
            headline: "Chicken",
            explanation: "Plain cooked chicken is one of the safest and most easily digestible proteins for dogs. It is a common ingredient in commercial dog food for good reason.",
            tips: [
                "Always cook thoroughly — raw chicken carries bacteria",
                "Remove all bones before serving — cooked bones splinter dangerously",
                "No salt, seasoning, garlic, or onion"
            ]
        )),

        .init(keywords: ["rice"], result: .init(
            status: .safe,
            headline: "Rice",
            explanation: "Plain cooked white or brown rice is safe for dogs and very easy on the digestive system. It is often recommended by vets for dogs with an upset stomach.",
            tips: [
                "Serve plain — no butter, salt, or sauces",
                "White rice is easier to digest than brown rice",
                "Commonly paired with plain boiled chicken for sensitive stomachs"
            ]
        )),

        .init(keywords: ["sweet potato", "sweetpotato"], result: .init(
            status: .safe,
            headline: "Sweet Potato",
            explanation: "Cooked sweet potato is safe for dogs and an excellent source of dietary fiber, vitamins A, B6, and C, and minerals. It should always be cooked and served plain.",
            tips: [
                "Cook thoroughly — raw sweet potato is hard to digest",
                "Remove the skin",
                "No butter, salt, or seasoning"
            ]
        )),

        .init(keywords: ["strawberr"], result: .init(
            status: .safe,
            headline: "Strawberries",
            explanation: "Strawberries are safe for dogs in moderation. They contain vitamin C, fiber, and an enzyme that can help whiten teeth. Remove stems before serving.",
            tips: [
                "Remove the stems and leaves",
                "Cut into small pieces for smaller dogs",
                "Limit quantity due to natural sugar content"
            ]
        )),

        .init(keywords: ["pumpkin"], result: .init(
            status: .safe,
            headline: "Pumpkin",
            explanation: "Plain cooked pumpkin is excellent for dogs and one of the best natural remedies for digestive issues. It is high in fiber and can help with both diarrhea and constipation.",
            tips: [
                "Use plain cooked or canned pumpkin — not pumpkin pie filling which contains spices and sugar",
                "A tablespoon or two mixed into food is a good amount",
                "Seeds can be cleaned, roasted without salt, and given as an occasional treat"
            ]
        )),

        .init(keywords: ["green bean", "green beans", "greenbean"], result: .init(
            status: .safe,
            headline: "Green Beans",
            explanation: "Green beans are a great low-calorie snack for dogs and are packed with vitamins and minerals. They are sometimes used as a filler in weight-management diets.",
            tips: [
                "Raw, steamed, or boiled — all are fine",
                "Avoid canned green beans with added salt",
                "Chop into smaller pieces for small breeds"
            ]
        )),

        .init(keywords: ["pea", "peas", "garden pea"], result: .init(
            status: .safe,
            headline: "Peas",
            explanation: "Peas are safe for dogs and provide protein, vitamins, and fiber. They are commonly used in commercial dog food recipes.",
            tips: [
                "Fresh, frozen, or cooked peas are all fine",
                "Avoid canned peas with added salt",
                "Do not give peas to dogs with kidney issues — the purines may aggravate the condition"
            ]
        )),

        .init(keywords: ["celery"], result: .init(
            status: .safe,
            headline: "Celery",
            explanation: "Celery is safe for dogs and a very low-calorie snack. It provides vitamins A, B, and C, and some dogs enjoy the crunch. It can also help freshen breath.",
            tips: [
                "Chop into small pieces to prevent choking",
                "Remove the stringy fibers for smaller dogs",
                "Serve plain without dips or sauces"
            ]
        )),

        .init(keywords: ["zucchini", "courgette"], result: .init(
            status: .safe,
            headline: "Zucchini / Courgette",
            explanation: "Zucchini is safe for dogs and one of the best low-calorie vegetables you can offer. It is high in water content and provides vitamins and minerals with very few calories.",
            tips: [
                "Raw or cooked — both are fine",
                "Slice into manageable pieces",
                "No seasoning, oil, or salt"
            ]
        )),

        .init(keywords: ["turkey"], result: .init(
            status: .safe,
            headline: "Turkey",
            explanation: "Plain cooked turkey is safe for dogs and a lean, digestible source of protein. It is found in many commercial dog food products. Avoid any turkey that has been seasoned or stuffed.",
            tips: [
                "Plain, unseasoned, and fully cooked only",
                "Remove all bones — especially hollow bird bones which splinter easily",
                "Avoid turkey skin — it is very fatty and can trigger pancreatitis",
                "Processed turkey products like deli slices are too high in salt"
            ]
        )),

        .init(keywords: ["beef", "lean beef", "mince", "ground beef"], result: .init(
            status: .safe,
            headline: "Beef",
            explanation: "Plain cooked lean beef is safe for dogs and a rich source of protein, iron, and B vitamins. It is one of the most commonly used proteins in commercial dog food.",
            tips: [
                "Cook thoroughly — plain and unseasoned",
                "Choose lean cuts to avoid excess fat",
                "No onion, garlic, salt, or other seasoning",
                "Drain off any excess fat before serving"
            ]
        )),

        .init(keywords: ["oat", "oatmeal", "porridge"], result: .init(
            status: .safe,
            headline: "Oatmeal / Oats",
            explanation: "Plain cooked oatmeal is safe for dogs and a good source of soluble fiber, which supports digestive health. It is a useful grain alternative for dogs sensitive to wheat.",
            tips: [
                "Serve plain and cooked — not raw",
                "No sugar, salt, flavoring, or milk",
                "Occasional treat rather than a dietary staple",
                "Avoid flavored instant oatmeal packets — they contain sugar and additives"
            ]
        )),

        .init(keywords: ["pasta", "noodle", "spaghetti", "macaroni"], result: .init(
            status: .safe,
            headline: "Pasta",
            explanation: "Plain cooked pasta is safe for dogs in small amounts. It is not particularly nutritious but is not harmful. The risk comes from sauces, seasonings, or added ingredients.",
            tips: [
                "Plain boiled pasta only — no sauce, butter, or salt",
                "Tomato-based sauces often contain onion and garlic — avoid",
                "Small portions only — pasta is calorie-dense and low in nutrients for dogs"
            ]
        )),

        .init(keywords: ["potato", "cooked potato", "boiled potato", "mashed potato"], result: .init(
            status: .safe,
            headline: "Cooked Potato",
            explanation: "Plain cooked potato is safe for dogs in small amounts and provides energy and some vitamins. Raw potatoes contain solanine which is toxic, so they must always be cooked.",
            tips: [
                "Always cook thoroughly — raw potato contains solanine which is toxic",
                "No salt, butter, sour cream, or toppings",
                "Avoid potato skin — it has higher solanine concentration",
                "Do not give to diabetic dogs — potatoes cause blood sugar spikes"
            ]
        )),

        .init(keywords: ["cantaloupe", "melon", "honeydew"], result: .init(
            status: .safe,
            headline: "Cantaloupe / Melon",
            explanation: "Cantaloupe and honeydew melon are safe for dogs and a refreshing, hydrating treat. They are rich in vitamins A and C and high in water content.",
            tips: [
                "Remove the rind and seeds before serving",
                "Cut into small cubes",
                "High in natural sugar — serve in moderation"
            ]
        )),

        .init(keywords: ["lamb"], result: .init(
            status: .safe,
            headline: "Lamb",
            explanation: "Plain cooked lamb is safe for dogs and a good source of protein, iron, and zinc. It is often used in dog food as an alternative protein for dogs with chicken or beef sensitivities.",
            tips: [
                "Cook thoroughly and serve plain",
                "Remove all bones — cooked lamb bones splinter",
                "Trim excess fat before serving to avoid pancreatitis risk",
                "No seasoning, mint sauce, or gravy"
            ]
        )),

        .init(keywords: ["raspberr"], result: .init(
            status: .safe,
            headline: "Raspberries",
            explanation: "Raspberries are safe for dogs in small amounts. They contain antioxidants and fiber. However, raspberries naturally contain very small amounts of xylitol, so portions should be kept small.",
            tips: [
                "Small handful only — no more than a few at a time",
                "The natural xylitol content is very low, but large amounts could be a concern",
                "Fresh only — avoid jam or processed raspberry products"
            ]
        )),

        .init(keywords: ["plain popcorn", "unsalted popcorn", "air popped popcorn", "air-popped"], result: .init(
            status: .safe,
            headline: "Plain Popcorn",
            explanation: "Plain air-popped popcorn is safe for dogs in small amounts and provides trace minerals. The danger comes entirely from toppings — salt, butter, sugar, and caramel are all harmful.",
            tips: [
                "Air-popped only — no butter, salt, sugar, or caramel",
                "Remove any unpopped kernels — choking hazard",
                "Occasional treat only — it is low in nutritional value for dogs"
            ]
        )),

        // ─────────────────────────────────────────────
        // MARK: — Caution —
        // ─────────────────────────────────────────────

        .init(keywords: ["apple"], result: .init(
            status: .caution,
            headline: "Apple",
            explanation: "Apple flesh is safe and healthy for dogs — it provides vitamins A and C and fiber. However, the seeds and core contain amygdalin which releases cyanide and must always be removed.",
            tips: [
                "Remove all seeds and the core before serving",
                "Slice into manageable pieces",
                "The skin is fine in small amounts but can be peeled for sensitive stomachs"
            ]
        )),

        .init(keywords: ["peanut butter", "peanutbutter"], result: .init(
            status: .caution,
            headline: "Peanut Butter",
            explanation: "Plain peanut butter is generally safe for dogs in small amounts. The critical risk is xylitol — an artificial sweetener used in some brands that is highly toxic to dogs.",
            tips: [
                "Always check the label for xylitol — avoid any product that contains it",
                "Choose unsalted and unsweetened varieties",
                "High in fat — serve sparingly to avoid weight gain or pancreatitis"
            ]
        )),

        .init(keywords: ["yogurt", "yoghurt"], result: .init(
            status: .caution,
            headline: "Yogurt",
            explanation: "Plain yogurt can be tolerated by some dogs in small amounts, but many dogs are lactose intolerant. Flavored yogurts often contain added sugar or xylitol — always check the label.",
            tips: [
                "Plain, unsweetened yogurt only",
                "Check ingredients carefully — avoid any product containing xylitol",
                "Watch for signs of lactose intolerance: gas, diarrhea, or vomiting",
                "Greek yogurt is lower in lactose and often better tolerated"
            ]
        )),

        .init(keywords: ["tuna"], result: .init(
            status: .caution,
            headline: "Tuna",
            explanation: "Tuna is not toxic to dogs, but it should only be given occasionally. Tuna contains mercury, and regular consumption can lead to mercury accumulation over time.",
            tips: [
                "Fresh or canned in water is best — not in brine or oil",
                "Occasional treat only — not a regular food",
                "Avoid tuna products with added salt or seasoning",
                "Drain canned tuna thoroughly before serving"
            ]
        )),

        .init(keywords: ["cheese"], result: .init(
            status: .caution,
            headline: "Cheese",
            explanation: "Small amounts of low-fat cheese can be used as a treat or for hiding medication. Cheese is high in fat and lactose, which can cause digestive upset in many dogs.",
            tips: [
                "Low-fat varieties like mozzarella or cottage cheese are better choices",
                "Avoid blue cheese — it contains roquefortine C which is toxic to dogs",
                "Dogs who are lactose intolerant should avoid it entirely",
                "Keep portions very small"
            ]
        )),

        .init(keywords: ["mango"], result: .init(
            status: .caution,
            headline: "Mango",
            explanation: "Mango flesh is safe for dogs in small amounts and provides vitamins A, B6, C, and E. The large pit is a serious choking hazard and contains traces of cyanide compounds.",
            tips: [
                "Always remove the pit — choking hazard and contains cyanide compounds",
                "Peel the skin before serving",
                "High in sugar — serve sparingly",
                "Cut into small pieces"
            ]
        )),

        .init(keywords: ["shrimp", "prawn"], result: .init(
            status: .caution,
            headline: "Shrimp / Prawn",
            explanation: "Plain cooked shrimp is not toxic to dogs and provides protein. It should be fully cooked and served without seasoning, shells, or tails.",
            tips: [
                "Always cook thoroughly",
                "Remove shells and tails — choking hazard",
                "No butter, garlic, salt, or seasoning of any kind",
                "Occasional treat only — high in cholesterol"
            ]
        )),

        .init(keywords: ["broccoli"], result: .init(
            status: .caution,
            headline: "Broccoli",
            explanation: "Broccoli is safe in very small amounts and provides fiber and vitamins. However, the florets contain isothiocyanates which can cause significant gastric irritation in larger quantities.",
            tips: [
                "Treat it as a very occasional snack, not a regular food",
                "Cooked is easier to digest than raw",
                "No seasoning, butter, or sauces",
                "Watch for signs of stomach upset after eating"
            ]
        )),

        .init(keywords: ["pork", "bacon", "ham"], result: .init(
            status: .caution,
            headline: "Pork / Bacon / Ham",
            explanation: "Plain cooked pork is not toxic to dogs, but it is very high in fat which can trigger pancreatitis. Bacon and ham are extremely high in salt and should be avoided entirely.",
            tips: [
                "Avoid processed pork products like bacon and ham entirely",
                "If giving plain pork, cook thoroughly with no seasoning",
                "High fat content is a significant health risk — keep portions very small",
                "Raw pork can carry the trichinella parasite"
            ]
        )),

        .init(keywords: ["salmon", "fish"], result: .init(
            status: .caution,
            headline: "Salmon / Fish",
            explanation: "Cooked salmon and most white fish are safe for dogs and provide omega-3 fatty acids. Raw salmon can carry Neorickettsia helminthoeca, a parasite that causes potentially fatal salmon poisoning disease.",
            tips: [
                "Always cook salmon and fish thoroughly",
                "Remove all bones carefully",
                "No seasoning, butter, or salt",
                "Avoid smoked salmon — extremely high in salt"
            ]
        )),

        .init(keywords: ["honey"], result: .init(
            status: .caution,
            headline: "Honey",
            explanation: "Small amounts of raw honey are not toxic to dogs, but honey is very high in sugar and unsuitable for diabetic or obese dogs. It should be an occasional treat only.",
            tips: [
                "Never give honey to puppies under one year — risk of botulism spores",
                "Avoid in diabetic or overweight dogs",
                "A small lick or teaspoon occasionally is the upper limit"
            ]
        )),

        .init(keywords: ["tomato"], result: .init(
            status: .caution,
            headline: "Tomatoes",
            explanation: "Ripe red tomato flesh is generally safe for dogs in small amounts. However, the green parts — stem, leaves, and unripe tomatoes — contain solanine and tomatine which are toxic to dogs.",
            tips: [
                "Ripe red flesh only — remove all green parts, stems, and leaves",
                "Never give unripe or green tomatoes",
                "Avoid tomato-based sauces — they often contain onion, garlic, and salt",
                "Small amount only — some dogs are sensitive even to ripe tomato"
            ]
        )),

        .init(keywords: ["corn", "sweetcorn", "corn on the cob", "maize"], result: .init(
            status: .caution,
            headline: "Corn",
            explanation: "Corn kernels are safe for dogs in small amounts. However, the corncob is extremely dangerous — it is indigestible and a leading cause of intestinal blockage requiring emergency surgery.",
            tips: [
                "Kernels only — never give the cob under any circumstances",
                "The cob is one of the most common causes of emergency bowel obstruction in dogs",
                "Plain cooked kernels, not from a buttered or salted cob",
                "Small amounts only — corn is high in starch and sugar"
            ]
        )),

        .init(keywords: ["milk", "cow milk", "dairy milk"], result: .init(
            status: .caution,
            headline: "Milk",
            explanation: "Cow's milk is not toxic to dogs, but many dogs are lactose intolerant and cannot properly digest it. Even a small amount can cause stomach upset, gas, and diarrhea in sensitive dogs.",
            tips: [
                "Offer only a small amount first to test tolerance",
                "Watch for signs of lactose intolerance: loose stools, gas, vomiting",
                "Lactose-free alternatives may be better tolerated",
                "Never replace water with milk"
            ]
        )),

        .init(keywords: ["ice cream", "icecream"], result: .init(
            status: .caution,
            headline: "Ice Cream",
            explanation: "Ice cream is not recommended for dogs. It is high in sugar, contains dairy, and some varieties contain xylitol, chocolate, or other toxic ingredients. Plain dog-safe frozen treats are a safer alternative.",
            tips: [
                "Check ingredients carefully — chocolate, raisins, or xylitol make it dangerous",
                "The high sugar and fat content can cause digestive upset",
                "Frozen banana or plain frozen yogurt are safer alternatives",
                "Never give sugar-free ice cream — likely contains xylitol"
            ]
        )),

        .init(keywords: ["spinach"], result: .init(
            status: .caution,
            headline: "Spinach",
            explanation: "Small amounts of spinach are not harmful to dogs, but spinach is high in oxalic acid which can interfere with calcium absorption and stress the kidneys over time. It should be a very occasional addition, not a regular food.",
            tips: [
                "Very small amounts only — not a regular part of the diet",
                "Avoid entirely in dogs with kidney disease or a history of bladder stones",
                "Lightly cooked spinach is easier to digest than raw",
                "Many other greens like green beans or peas are safer choices"
            ]
        )),

        .init(keywords: ["peach"], result: .init(
            status: .caution,
            headline: "Peach",
            explanation: "Ripe peach flesh is safe for dogs in small amounts and provides vitamins A and C. However, the pit contains cyanide compounds and is a serious choking and toxicity hazard.",
            tips: [
                "Always remove the pit completely — it contains cyanide",
                "Peel the skin if possible — easier to digest",
                "No canned peaches — too much sugar and syrup",
                "Small pieces of fresh flesh only"
            ]
        )),

        .init(keywords: ["pineapple"], result: .init(
            status: .caution,
            headline: "Pineapple",
            explanation: "Fresh pineapple flesh is safe for dogs in very small amounts. It is high in natural sugar, acidity, and vitamin C. The tough core and spiky skin should never be given.",
            tips: [
                "Fresh only — not canned pineapple which is soaked in sugary syrup",
                "Remove the skin and tough core entirely",
                "The high acidity can irritate some dogs' stomachs — start with just one small piece",
                "High sugar content means this should be a rare treat"
            ]
        )),

        .init(keywords: ["kiwi", "kiwifruit"], result: .init(
            status: .caution,
            headline: "Kiwi",
            explanation: "Kiwi flesh is not toxic to dogs and contains vitamin C, potassium, and fiber. However, the skin is tough to digest and the small size means the whole fruit could be a choking hazard.",
            tips: [
                "Peel the skin before giving to your dog",
                "Cut into small pieces — never give a whole kiwi",
                "The high fiber content can cause loose stools if given in large amounts",
                "Introduce gradually and in small amounts"
            ]
        )),

        .init(keywords: ["cranberr"], result: .init(
            status: .caution,
            headline: "Cranberries",
            explanation: "Plain cranberries are not toxic to dogs, but they are very tart and many dogs will refuse them. In small amounts they are fine, but large quantities can cause stomach upset. Cranberry juice and dried cranberries often contain added sugar.",
            tips: [
                "Fresh or frozen plain cranberries only — not juice or dried",
                "Small amounts only — they can cause stomach upset in larger quantities",
                "Never give cranberry sauce — it is extremely high in sugar",
                "Cranberry supplements for urinary health should be vet-approved"
            ]
        )),

        .init(keywords: ["almond"], result: .init(
            status: .caution,
            headline: "Almonds",
            explanation: "Almonds are not considered directly toxic to dogs but they are not recommended. Their size and hardness make them a choking hazard, and their high fat content can trigger digestive upset or pancreatitis.",
            tips: [
                "Avoid giving almonds as a habit — the risk outweighs any benefit",
                "Salted or flavored almonds are especially harmful due to salt and additives",
                "Almond flour in baked goods is generally lower risk in small amounts",
                "If your dog eats one or two, monitor for signs of digestive upset"
            ]
        )),

        .init(keywords: ["cashew"], result: .init(
            status: .caution,
            headline: "Cashews",
            explanation: "Cashews are not toxic to dogs but are very high in fat and calories. A few plain cashews are unlikely to cause harm, but regular consumption can lead to weight gain and increase the risk of pancreatitis.",
            tips: [
                "Plain and unsalted only — salted cashews are harmful",
                "A few pieces occasionally is the maximum — not a regular treat",
                "Avoid cashew mixtures containing macadamia nuts — those are toxic",
                "Do not give to overweight dogs or dogs prone to pancreatitis"
            ]
        )),

        .init(keywords: ["coconut", "coconut oil", "coconut milk", "coconut water"], result: .init(
            status: .caution,
            headline: "Coconut",
            explanation: "Coconut flesh and oil are not toxic to dogs, but coconut is very high in saturated fat and can cause digestive upset, especially in larger amounts. Coconut water is high in potassium and should also be limited.",
            tips: [
                "Small amount of fresh coconut flesh is the safest form",
                "Coconut oil can be used in very small amounts — too much causes diarrhea",
                "Coconut milk is very high in fat — avoid giving as a regular food",
                "Coconut water should be given in very small amounts due to high potassium"
            ]
        )),

        .init(keywords: ["liver", "chicken liver", "beef liver"], result: .init(
            status: .caution,
            headline: "Liver",
            explanation: "Liver is nutritious for dogs and a good source of protein, vitamins A and B, and iron. However, too much liver causes vitamin A toxicity, which can be serious. It should be a small, occasional treat.",
            tips: [
                "Cook thoroughly before serving",
                "Small amounts only — 5% or less of the total daily diet",
                "Too much liver causes vitamin A toxicity: bone problems, weight loss, lethargy",
                "Avoid seasoned liver or liver pâté — they contain salt, onion, and garlic"
            ]
        )),

        .init(keywords: ["sardine"], result: .init(
            status: .caution,
            headline: "Sardines",
            explanation: "Sardines are safe for dogs in small amounts and are one of the best sources of omega-3 fatty acids. They must be plain with no added salt, sauce, or seasoning.",
            tips: [
                "Canned in water only — not in oil, brine, or tomato sauce",
                "No added salt",
                "One or two small sardines occasionally is plenty",
                "High in omega-3 which supports skin, coat, and joint health"
            ]
        )),

        .init(keywords: ["crab", "lobster"], result: .init(
            status: .caution,
            headline: "Crab / Lobster",
            explanation: "Plain cooked crab and lobster are not toxic to dogs and provide protein. However, shellfish can cause allergic reactions, and the shells are a serious choking hazard.",
            tips: [
                "Plain and fully cooked only",
                "Remove all shell completely",
                "No butter, garlic, or seasoning",
                "Introduce a small amount first and watch for allergic reactions",
                "Occasional treat only — not a regular food"
            ]
        )),

        .init(keywords: ["bread", "toast", "white bread", "brown bread"], result: .init(
            status: .caution,
            headline: "Bread",
            explanation: "Plain baked bread is not toxic to dogs in small amounts, but it offers little nutritional value and is high in carbohydrates and calories. Bread with raisins, garlic, or onion is dangerous.",
            tips: [
                "Plain bread only — no raisins, garlic, onion, or seeds",
                "Never give raw dough — yeast ferments in the stomach causing dangerous gas expansion and alcohol production",
                "Small piece as an occasional treat only",
                "Avoid bread with artificial sweeteners or xylitol"
            ]
        )),

        .init(keywords: ["sunflower seed", "sunflower"], result: .init(
            status: .caution,
            headline: "Sunflower Seeds",
            explanation: "Plain shelled sunflower seeds are safe for dogs in very small amounts and provide healthy fats and vitamin E. The shells are indigestible and a choking hazard.",
            tips: [
                "Shell them completely before giving — the husks are indigestible",
                "Plain and unsalted only",
                "Very small amounts — they are calorie-dense",
                "Avoid sunflower seeds sold for birds — these may be treated"
            ]
        )),

        // ─────────────────────────────────────────────
        // MARK: — Dangerous —
        // ─────────────────────────────────────────────

        .init(keywords: ["grape", "raisin", "sultana", "currant"], result: .init(
            status: .danger,
            headline: "Grapes / Raisins",
            explanation: "Grapes and raisins are extremely dangerous to dogs. Even a small amount can cause sudden acute kidney failure. The exact toxic compound is unknown, meaning no dose is considered safe.",
            tips: [
                "Never give grapes, raisins, sultanas, or currants to a dog",
                "Contact your vet immediately if your dog has eaten any amount",
                "Symptoms: vomiting, lethargy, loss of appetite, reduced urination, abdominal pain"
            ]
        )),

        .init(keywords: ["chocolate", "cocoa", "cacao"], result: .init(
            status: .danger,
            headline: "Chocolate",
            explanation: "Chocolate is toxic to dogs. It contains theobromine and caffeine which dogs cannot metabolize efficiently. Dark chocolate and baking chocolate are the most dangerous — even small amounts can be fatal.",
            tips: [
                "Never give any form of chocolate to a dog",
                "Dark and baking chocolate are far more dangerous than milk chocolate — but all types are harmful",
                "Contact your vet or emergency line immediately if your dog has eaten chocolate",
                "Symptoms: vomiting, diarrhea, restlessness, tremors, seizures"
            ]
        )),

        .init(keywords: ["onion"], result: .init(
            status: .danger,
            headline: "Onion",
            explanation: "Onions are toxic to dogs in all forms — raw, cooked, powdered, or dehydrated. They damage red blood cells and cause hemolytic anemia. Repeated small exposures are just as dangerous as a single large dose.",
            tips: [
                "Avoid all forms: raw, cooked, powdered, fried, or in sauces and stocks",
                "Onion powder in seasoning blends is particularly dangerous — highly concentrated",
                "Symptoms may be delayed by several days: weakness, pale gums, reduced appetite, fainting"
            ]
        )),

        .init(keywords: ["garlic"], result: .init(
            status: .danger,
            headline: "Garlic",
            explanation: "Garlic is toxic to dogs and approximately five times more potent than onion. It causes red blood cell damage leading to hemolytic anemia. Garlic powder is especially concentrated and dangerous.",
            tips: [
                "Avoid all forms of garlic — raw, cooked, powdered, or in sauces",
                "Never use garlic as a flea or parasite remedy — it is not safe",
                "Symptoms may be delayed: lethargy, weakness, pale gums, rapid breathing, collapse"
            ]
        )),

        .init(keywords: ["leek", "chive", "scallion", "spring onion", "green onion", "shallot"], result: .init(
            status: .danger,
            headline: "Leeks / Chives / Spring Onions",
            explanation: "Leeks, chives, scallions, and shallots all belong to the Allium family along with onions and garlic. They share the same toxic compounds and can cause hemolytic anemia in dogs.",
            tips: [
                "Avoid all Allium family vegetables: leeks, chives, spring onions, shallots",
                "Chive powder or dried chives in seasonings are particularly concentrated",
                "Contact your vet if any amount was consumed",
                "Symptoms: weakness, reduced appetite, pale gums, vomiting"
            ]
        )),

        .init(keywords: ["xylitol", "sugar-free", "sugar free"], result: .init(
            status: .danger,
            headline: "Xylitol",
            explanation: "Xylitol is an artificial sweetener found in many sugar-free products. It causes a rapid and dangerous drop in blood sugar and can lead to liver failure in dogs. Even small amounts can be fatal.",
            tips: [
                "Check ingredient labels on any sugar-free product before giving it to your dog",
                "Found in: sugar-free gum, some peanut butters, certain yogurts, mouthwash, vitamins, and dental products",
                "Contact your vet immediately if you suspect xylitol ingestion"
            ]
        )),

        .init(keywords: ["avocado", "guacamole"], result: .init(
            status: .danger,
            headline: "Avocado",
            explanation: "Avocado contains persin, a fungicidal toxin that is harmless to humans but causes vomiting, diarrhea, and fluid accumulation in the chest and abdomen in dogs. The pit is also a serious choking hazard.",
            tips: [
                "Avoid the flesh, skin, and pit entirely",
                "Guacamole is especially dangerous — it usually contains onion and garlic too",
                "Contact your vet if your dog has eaten any amount"
            ]
        )),

        .init(keywords: ["macadamia"], result: .init(
            status: .danger,
            headline: "Macadamia Nuts",
            explanation: "Macadamia nuts are toxic to dogs. Even a small amount can cause weakness, high temperature, vomiting, tremors, and inability to walk. The exact toxin is not fully understood.",
            tips: [
                "Avoid all macadamia nut products including cookies, trail mix, and nut butter blends",
                "Contact your vet if your dog has eaten any macadamia nuts",
                "Symptoms typically appear within 12 hours of ingestion"
            ]
        )),

        .init(keywords: ["walnut", "black walnut"], result: .init(
            status: .danger,
            headline: "Walnuts",
            explanation: "Walnuts, especially black walnuts, are dangerous to dogs. They can contain a mold called Aspergillus that produces tremorgenic mycotoxins causing seizures and neurological damage. Even fresh walnuts are very high in fat and difficult to digest.",
            tips: [
                "Avoid walnuts entirely — the mold risk makes them unpredictable",
                "Black walnuts from trees are especially dangerous",
                "Contact your vet immediately if tremors or seizures occur after eating any nut",
                "Other safer nuts like cashews or unsalted peanuts carry far less risk"
            ]
        )),

        .init(keywords: ["alcohol", "beer", "wine", "vodka", "rum", "whiskey", "whisky", "spirits", "cider"], result: .init(
            status: .danger,
            headline: "Alcohol",
            explanation: "Alcohol is extremely dangerous to dogs. Even small amounts cause intoxication far more quickly than in humans, leading to dangerous drops in blood sugar, body temperature, blood pressure, and in severe cases, respiratory failure.",
            tips: [
                "Never give alcohol to a dog under any circumstances",
                "Be careful with foods made with alcohol: rum cake, tiramisu, wine-cooked sauces",
                "Contact your vet immediately if accidental ingestion occurs"
            ]
        )),

        .init(keywords: ["coffee", "caffeine", "energy drink", "espresso", "cola", "coke", "pepsi", "redbull", "monster energy"], result: .init(
            status: .danger,
            headline: "Caffeine",
            explanation: "Caffeine is toxic to dogs and found in coffee, tea, energy drinks, some medications, and diet supplements. It causes hyperactivity, elevated heart rate, tremors, and in severe cases, seizures.",
            tips: [
                "Keep coffee grounds, beans, pods, and used capsules well out of reach",
                "Tea bags and loose tea are also a risk",
                "Contact your vet immediately if your dog has consumed caffeine"
            ]
        )),

        .init(keywords: ["tea", "herbal tea", "green tea", "chamomile tea", "peppermint tea"], result: .init(
            status: .danger,
            headline: "Tea",
            explanation: "Regular teas contain caffeine and tannins, both harmful to dogs. Herbal teas should also be avoided — many contain herbs like chamomile, peppermint, or lavender that can cause issues in dogs.",
            tips: [
                "Keep tea bags and loose leaf tea out of reach",
                "Herbal teas are not automatically safe — many herbs are harmful to dogs",
                "Contact your vet if your dog has consumed tea"
            ]
        )),

        .init(keywords: ["mushroom", "fungi", "toadstool"], result: .init(
            status: .danger,
            headline: "Mushrooms",
            explanation: "Many wild mushroom species are extremely toxic to dogs and can cause liver failure, neurological damage, or death. Store-bought plain white mushrooms are generally considered safe, but the risk of misidentification with wild mushrooms makes avoidance the safest approach.",
            tips: [
                "Never allow your dog to eat wild mushrooms — identification is unreliable",
                "Watch carefully in woodland areas or anywhere fungi may be growing",
                "Contact your vet immediately if any wild mushroom was eaten"
            ]
        )),

        .init(keywords: ["cooked bone", "chicken bone", "fish bone", "pork bone", "rib bone", "t-bone", "lamb bone"], result: .init(
            status: .danger,
            headline: "Cooked Bones",
            explanation: "Cooked bones of any kind are dangerous. The cooking process makes bones brittle so they splinter into sharp fragments that can cause internal punctures, choking, and intestinal blockages.",
            tips: [
                "Never give cooked bones — chicken, pork, fish, or beef",
                "Raw meaty bones carry different risks — consult your vet before trying them",
                "If your dog swallows a bone fragment, contact your vet immediately"
            ]
        )),

        .init(keywords: ["nutmeg"], result: .init(
            status: .danger,
            headline: "Nutmeg",
            explanation: "Nutmeg contains myristicin, a compound toxic to dogs. Even moderate amounts can cause disorientation, elevated heart rate, high blood pressure, dry mouth, abdominal pain, and seizures.",
            tips: [
                "Avoid foods seasoned with nutmeg",
                "Many baked goods contain nutmeg — always check before sharing",
                "Keep spice jars stored safely away from dogs"
            ]
        )),

        .init(keywords: ["salt", "salty", "crisp", "chip", "pretzel", "salted popcorn"], result: .init(
            status: .danger,
            headline: "Salty Foods",
            explanation: "Excessive salt intake is harmful to dogs and can cause sodium poisoning. Symptoms include excessive thirst and urination, vomiting, diarrhea, tremors, and in severe cases, seizures.",
            tips: [
                "Avoid salty snacks like crisps, pretzels, and salted popcorn",
                "Never season your dog's food with salt",
                "Always provide fresh water to prevent dehydration"
            ]
        )),

        .init(keywords: ["rhubarb"], result: .init(
            status: .danger,
            headline: "Rhubarb",
            explanation: "Rhubarb is toxic to dogs. The leaves contain extremely high levels of oxalic acid which causes kidney failure. Even the stalks contain enough oxalates to be dangerous.",
            tips: [
                "Avoid rhubarb entirely — both the stalks and especially the leaves",
                "Never leave rhubarb plants accessible in the garden",
                "Contact your vet immediately if any part was consumed",
                "Symptoms: drooling, vomiting, diarrhea, weakness, tremors"
            ]
        )),

        .init(keywords: ["cherry", "cherries"], result: .init(
            status: .danger,
            headline: "Cherries",
            explanation: "Cherry pits, stems, and leaves contain cyanide and are toxic to dogs. While the ripe flesh is technically not toxic, the risk of the dog ingesting the pit makes cherries a food to avoid entirely.",
            tips: [
                "The pit, stem, and leaves all contain cyanide — avoid entirely",
                "If giving a small amount of pitted flesh, monitor carefully",
                "Maraschino cherries are not toxic but are soaked in sugar — not suitable",
                "Contact your vet if your dog has eaten whole cherries with pits"
            ]
        )),

        .init(keywords: ["raw dough", "yeast dough", "bread dough", "pizza dough", "uncooked dough"], result: .init(
            status: .danger,
            headline: "Raw / Yeast Dough",
            explanation: "Raw bread or pizza dough is dangerous for dogs. The yeast continues to rise inside the stomach, causing painful gas expansion and bloating. As the yeast ferments, it also produces alcohol which is absorbed into the bloodstream.",
            tips: [
                "Never give raw or uncooked dough of any kind",
                "Keep dough covered and out of reach while it rises",
                "Baked bread in small amounts is far safer than any raw dough",
                "Contact your vet immediately if dough was consumed"
            ]
        )),

        .init(keywords: ["green tomato", "tomato plant", "tomato leaf", "tomato stem"], result: .init(
            status: .danger,
            headline: "Green Tomatoes / Tomato Plant",
            explanation: "While ripe red tomato flesh is generally safe in small amounts, the green parts of the tomato plant — leaves, stems, and unripe fruit — contain solanine and tomatine, which are toxic to dogs.",
            tips: [
                "Never give unripe green tomatoes",
                "Ensure tomato plants in the garden are fenced off",
                "Leaves and stems are the most toxic parts",
                "Contact your vet if green plant material or unripe tomatoes were consumed"
            ]
        )),

        .init(keywords: ["persimmon"], result: .init(
            status: .danger,
            headline: "Persimmon",
            explanation: "The seeds and pit of persimmons can cause intestinal obstruction and enteritis in dogs. The flesh itself is not considered toxic, but the overall risk means persimmons are best avoided.",
            tips: [
                "Remove seeds and skin completely if giving a small amount of flesh",
                "The pit causes intestinal blockage",
                "Contact your vet if seeds or the pit were swallowed",
                "Symptoms of obstruction: vomiting, loss of appetite, abdominal pain"
            ]
        )),

        .init(keywords: ["ibuprofen", "paracetamol", "acetaminophen", "aspirin", "panadol", "advil", "nurofen", "tylenol", "medication", "medicine", "pill", "tablet"], result: .init(
            status: .danger,
            headline: "Human Medications",
            explanation: "Human pain relievers and medications are extremely dangerous to dogs. Ibuprofen and aspirin cause stomach ulcers and kidney failure. Paracetamol/acetaminophen causes fatal liver damage and red blood cell destruction. Even one tablet can be lethal.",
            tips: [
                "Never give any human medication to a dog without explicit vet instruction",
                "Keep all medications in sealed cabinets out of reach",
                "Contact your vet or animal poison control immediately if any medication was ingested",
                "Always use pet-specific medications prescribed by a veterinarian"
            ]
        )),

        .init(keywords: ["star fruit", "starfruit", "carambola"], result: .init(
            status: .danger,
            headline: "Star Fruit",
            explanation: "Star fruit (carambola) is toxic to dogs. It contains soluble calcium oxalates which can cause acute kidney failure. Even a small amount can be dangerous.",
            tips: [
                "Never give star fruit to a dog",
                "Contact your vet immediately if any was consumed",
                "Symptoms: vomiting, tremors, weakness, and reduced urine output"
            ]
        )),

        .init(keywords: ["hops", "hop pellet"], result: .init(
            status: .danger,
            headline: "Hops",
            explanation: "Hops — used in home beer brewing — are extremely toxic to dogs. They cause malignant hyperthermia, a rapid and dangerous rise in body temperature that can be fatal even with treatment.",
            tips: [
                "Keep all hop products (fresh, dried, or pellets) completely out of reach",
                "Especially relevant to home brewers",
                "Contact your vet immediately — this is a life-threatening emergency",
                "Symptoms: panting, high temperature, seizures, collapse"
            ]
        )),
    ]
}
