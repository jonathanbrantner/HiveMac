import Foundation

/// Hours a planter takes to grow in each field, from Natro Macro (GPL-3.0). Planters that suit a field
/// (Hydroponic near blue flowers, Heat-Treated near red ones, and so on) grow faster there, so the time
/// depends on both. Natro assumes no field degradation.
public enum PlanterGrowth {
    public static let hours: [String: [String: Double]] = [
        "bamboo": ["blue clay": 5.06, "candy": 4.0, "heat-treated": 12.0, "hydroponic": 8.73, "paper": 1.0, "pesticide": 6.25, "petal": 12.45, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 6.0, "tacky": 8.0, "ticket": 2.0],
        "blue flower": ["blue clay": 5.12, "candy": 4.0, "heat-treated": 12.0, "hydroponic": 8.93, "paper": 1.0, "pesticide": 10.0, "petal": 12.13, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 6.0, "tacky": 5.34, "ticket": 2.0],
        "cactus": ["blue clay": 5.34, "candy": 4.0, "heat-treated": 9.88, "hydroponic": 9.6, "paper": 1.0, "pesticide": 10.0, "petal": 13.53, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 5.42, "tacky": 8.0, "ticket": 2.0],
        "clover": ["blue clay": 5.53, "candy": 4.0, "heat-treated": 10.26, "hydroponic": 10.57, "paper": 1.0, "pesticide": 10.0, "petal": 12.07, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 5.53, "tacky": 5.34, "ticket": 2.0],
        "coconut": ["blue clay": 5.94, "candy": 2.67, "heat-treated": 11.66, "hydroponic": 11.74, "paper": 1.0, "pesticide": 10.0, "petal": 9.68, "planter of plenty": 10.67, "plastic": 2.0, "red clay": 5.92, "tacky": 8.0, "ticket": 2.0],
        "dandelion": ["blue clay": 5.86, "candy": 4.0, "heat-treated": 11.68, "hydroponic": 11.45, "paper": 1.0, "pesticide": 10.0, "petal": 9.84, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 5.92, "tacky": 5.33, "ticket": 2.0],
        "mountain top": ["blue clay": 5.34, "candy": 4.0, "heat-treated": 9.6, "hydroponic": 9.6, "paper": 1.0, "pesticide": 10.0, "petal": 14.0, "planter of plenty": 10.67, "plastic": 2.0, "red clay": 5.34, "tacky": 8.0, "ticket": 2.0],
        "mushroom": ["blue clay": 6.0, "candy": 4.0, "heat-treated": 8.94, "hydroponic": 12.0, "paper": 1.0, "pesticide": 10.0, "petal": 12.1, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 5.12, "tacky": 5.34, "ticket": 2.0],
        "pepper": ["blue clay": 6.0, "candy": 4.0, "heat-treated": 8.22, "hydroponic": 12.0, "paper": 1.0, "pesticide": 10.0, "petal": 13.47, "planter of plenty": 10.67, "plastic": 2.0, "red clay": 4.88, "tacky": 8.0, "ticket": 2.0],
        "pine tree": ["blue clay": 4.96, "candy": 4.0, "heat-treated": 12.0, "hydroponic": 8.46, "paper": 1.0, "pesticide": 10.0, "petal": 12.97, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 6.0, "tacky": 8.0, "ticket": 2.0],
        "pineapple": ["blue clay": 5.93, "candy": 2.67, "heat-treated": 11.66, "hydroponic": 11.71, "paper": 1.0, "pesticide": 10.0, "petal": 9.69, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 5.92, "tacky": 8.0, "ticket": 2.0],
        "pumpkin": ["blue clay": 5.71, "candy": 4.0, "heat-treated": 10.82, "hydroponic": 10.86, "paper": 1.0, "pesticide": 10.0, "petal": 10.9, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 5.69, "tacky": 8.0, "ticket": 2.0],
        "rose": ["blue clay": 6.0, "candy": 4.0, "heat-treated": 8.52, "hydroponic": 12.0, "paper": 1.0, "pesticide": 10.0, "petal": 12.85, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 4.98, "tacky": 8.0, "ticket": 2.0],
        "spider": ["blue clay": 6.0, "candy": 4.0, "heat-treated": 12.0, "hydroponic": 12.0, "paper": 1.0, "pesticide": 6.25, "petal": 9.33, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 6.0, "tacky": 8.0, "ticket": 2.0],
        "strawberry": ["blue clay": 6.0, "candy": 2.67, "heat-treated": 8.93, "hydroponic": 12.0, "paper": 1.0, "pesticide": 6.25, "petal": 12.13, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 5.12, "tacky": 8.0, "ticket": 2.0],
        "stump": ["blue clay": 5.06, "candy": 4.0, "heat-treated": 11.65, "hydroponic": 8.73, "paper": 1.0, "pesticide": 10.0, "petal": 12.79, "planter of plenty": 10.67, "plastic": 2.0, "red clay": 5.92, "tacky": 8.0, "ticket": 2.0],
        "sunflower": ["blue clay": 5.79, "candy": 4.0, "heat-treated": 11.08, "hydroponic": 11.17, "paper": 1.0, "pesticide": 10.0, "petal": 10.44, "planter of plenty": 16.0, "plastic": 2.0, "red clay": 5.76, "tacky": 5.34, "ticket": 2.0],
    ]

    /// Used for a planter Natro has no number for (the Festive planter).
    public static let fallbackHours = 4.0

    public static func hours(planter: String, field: String) -> Double {
        hours[field.lowercased()]?[planter.lowercased()] ?? fallbackHours
    }
}
