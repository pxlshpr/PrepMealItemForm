import SwiftUI
import PrepDataTypes
import PrepCoreDataStack
import PrepMocks
import PrepViews

public enum MealItemFormRoute {
    case mealItemForm
    case food
    case meal
    case quantity
}

public class MealItemViewModel: ObservableObject {
    
    let date: Date
    
    @Published var path: [MealItemFormRoute]

    @Published var food: Food?
    @Published var dayMeals: [DayMeal]
    
    @Published var unit: FoodQuantity.Unit = .serving

    @Published var internalAmountDouble: Double? = 1
    @Published var internalAmountString: String = "1"

    @Published var dayMeal: DayMeal

    @Published var day: Day? = nil

    @Published var mealFoodItem: MealFoodItem
    
    @Published var isAnimatingAmountChange = false

    let existingMealFoodItem: MealFoodItem?
    let initialDayMeal: DayMeal?

    public init(
        existingMealFoodItem: MealFoodItem?,
        date: Date,
        day: Day? = nil,
        dayMeal: DayMeal? = nil,
        food: Food? = nil,
        amount: FoodValue? = nil,
        dayMeals: [DayMeal] = [], //TODO: Do we need to pass this in if we have day?
        initialPath: [MealItemFormRoute] = []
    ) {
        self.path = initialPath
        self.date = date
        self.day = day
        self.food = food
        self.dayMeals = dayMeals
        
        self.dayMeal = dayMeal ?? DayMeal(name: "New Meal", time: Date().timeIntervalSince1970)
        self.initialDayMeal = dayMeal
        
        //TODO: Handle this in a better way
        /// [ ] Try making `mealFoodItem` nil and set it as that if we don't get a food here
        /// [ ] Try and get this fed in with an existing `FoodItem`, from which we create this when editing!
        self.mealFoodItem = MealFoodItem(
            food: food ?? FoodMock.peanutButter,
            amount: .init(0, .g),
            isSoftDeleted: false
        )

        self.existingMealFoodItem = existingMealFoodItem

        if let amount, let food,
           let unit = FoodQuantity.Unit(foodValue: amount, in: food)
        {
            self.amount = amount.value
            self.unit = unit
        } else {
            setDefaultUnit()
        }
        setFoodItem()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didPickDayMeal),
            name: .didPickDayMeal,
            object: nil
        )
    }
    
    @objc func didPickDayMeal(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let dayMeal = userInfo[Notification.Keys.dayMeal] as? DayMeal
        else { return }
        
        self.dayMeal = dayMeal
    }

    func setFood(_ food: Food) {
        self.food = food
        setDefaultUnit()
        setFoodItem()
    }
    
    func setDefaultUnit() {
        guard let food else { return }
        let amountQuantity = DataManager.shared.lastUsedQuantity(for: food) ?? food.defaultQuantity
        guard let amountQuantity else { return }
        
        self.amount = amountQuantity.value
        self.unit = amountQuantity.unit
    }
    
    var amountIsValid: Bool {
        guard let amount else { return false }
        return amount > 0
    }
    
    var isDirty: Bool {        
        guard let existing = existingMealFoodItem else {
            return amountIsValid
        }
        
        return existing.food.id != food?.id
        || (existing.amount != amountValue && amountIsValid)
        || initialDayMeal?.id != dayMeal.id
    }

    var amount: Double? {
        get {
            return internalAmountDouble
        }
        set {
            internalAmountDouble = newValue
            internalAmountString = newValue?.cleanAmount ?? ""
            setFoodItem()
        }
    }
    
    func setFoodItem() {
        guard let food else { return }
        self.mealFoodItem = MealFoodItem(
            id: existingMealFoodItem?.id ?? UUID(),
            food: food,
            amount: amountValue,
            markedAsEatenAt: existingMealFoodItem?.markedAsEatenAt ?? nil,
            sortPosition: existingMealFoodItem?.sortPosition ?? 1,
            isSoftDeleted: existingMealFoodItem?.isSoftDeleted ?? false
        )
    }
    
    var amountString: String {
        get { internalAmountString }
        set {
            guard !newValue.isEmpty else {
                internalAmountDouble = nil
                internalAmountString = newValue
                setFoodItem()
                return
            }
            guard let double = Double(newValue) else {
                return
            }
            self.internalAmountDouble = double
            self.internalAmountString = newValue
            setFoodItem()
        }
    }
    
    var timelineItems: [TimelineItem] {
        dayMeals.map { TimelineItem(dayMeal: $0) }
    }
    
    var amountTitle: String? {
        guard let internalAmountDouble else {
            return nil
        }
        return "\(internalAmountDouble.cleanAmount) \(unit.shortDescription)"
    }
    
    var amountDetail: String? {
        //TODO: Get the primary equivalent value here
        ""
    }
    
    var isEditing: Bool {
        existingMealFoodItem != nil
    }
    
    var navigationTitle: String {
        guard !isEditing else {
            return "Edit Entry"
        }
        let prefix = dayMeal.time < Date().timeIntervalSince1970 ? "Log" : "Prep"
        return "\(prefix) Food"
    }
    
    var saveButtonTitle: String {
        isEditing ? "Save" : "Add"
    }
    
    func stepAmount(by step: Int) {
        programmaticallyChangeAmount(to: (amount ?? 0) + Double(step))
    }
    
    func programmaticallyChangeAmount(to newAmount: Double) {
        isAnimatingAmountChange = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.amount = newAmount
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isAnimatingAmountChange = false
            }
        }
    }
    
    func amountCanBeStepped(by step: Int) -> Bool {
        let amount = self.internalAmountDouble ?? 0
        return amount + Double(step) > 0
    }
    
    var unitDescription: String {
        unit.shortDescription
    }
    
    var shouldShowServingInUnitPicker: Bool {
        guard let food else { return false }
        return food.info.serving != nil
    }
    
    var foodSizes: [FormSize] {
        food?.formSizes ?? []
    }
    
    var servingDescription: String? {
        food?.servingDescription(using: DataManager.shared.userVolumeUnits)
    }
    
    func didPickUnit(_ formUnit: FormUnit) {
        guard
            let food,
            let unit = FoodQuantity.Unit(
                formUnit: formUnit,
                food: food,
                userVolumeUnits: DataManager.shared.userVolumeUnits
            )
        else { return }
        
        self.unit = unit
        setFoodItem()
    }
    
    func didPickQuantity(_ quantity: FoodQuantity) {
//        programmaticallyChangeAmount(to: quantity.value)
        self.amount = quantity.value
        self.unit = quantity.unit
        setFoodItem()
    }
    var amountHeaderString: String {
        unit.unitType.description
    }
    
    var shouldShowWeightUnits: Bool {
        food?.canBeMeasuredInWeight ?? false
    }
    
    var shouldShowVolumeUnits: Bool {
        food?.canBeMeasuredInVolume ?? false
    }
    
    var amountValue: FoodValue {
        FoodValue(
            value: amount ?? 0,
            foodQuantityUnit: unit,
            userUnits: DataManager.shared.user?.units ?? .standard
        )
    }
    
//    var foodItemBinding: Binding<MealFoodItem> {
//        Binding<MealFoodItem>(
//            get: {
//                print("Getting MealFoodItem")
//                return MealFoodItem(
//                    food: self.food,
//                    amount: self.amountValue
//                )
//            },
//            set: { _ in }
//        )
//    }
//
//    var dayMeal: DayMeal? {
//        guard let meal else { return nil }
//        return DayMeal(from: meal)
//    }
}

extension FoodValue {
    init(
        value: Double,
        foodQuantityUnit unit: FoodQuantity.Unit,
        userUnits: UserUnits
    ) {
        
        let volumeExplicitUnit: VolumeExplicitUnit?
        if let volumeUnit = unit.formUnit.volumeUnit {
            volumeExplicitUnit = userUnits.volume.volumeExplicitUnit(for: volumeUnit)
        } else {
            volumeExplicitUnit = nil
        }

        let sizeUnitVolumePrefixExplicitUnit: VolumeExplicitUnit?
        if let volumeUnit = unit.formUnit.sizeUnitVolumePrefixUnit {
            sizeUnitVolumePrefixExplicitUnit = userUnits.volume.volumeExplicitUnit(for: volumeUnit)
        } else {
            sizeUnitVolumePrefixExplicitUnit = nil
        }

        self.init(
            value: value,
            unitType: unit.unitType,
            weightUnit: unit.formUnit.weightUnit,
            volumeExplicitUnit: volumeExplicitUnit,
            sizeUnitId: unit.formUnit.size?.id,
            sizeUnitVolumePrefixExplicitUnit: sizeUnitVolumePrefixExplicitUnit
        )
    }
}

extension MealItemViewModel {
    var equivalentQuantities: [FoodQuantity] {
        guard let currentQuantity else { return [] }
        let quantities = currentQuantity.equivalentQuantities(using: DataManager.shared.userVolumeUnits)
        return quantities
    }
    
    var currentQuantity: FoodQuantity? {
        guard
            let food,
            let internalAmountDouble
        else { return nil }
        
        return FoodQuantity(
            value: internalAmountDouble,
            unit: unit,
            food: food
        )
    }    
}

extension MealItemViewModel: NutritionSummaryProvider {
    public var energyAmount: Double {
        mealFoodItem.scaledValue(for: .energy)
    }
    
    public var carbAmount: Double {
        mealFoodItem.scaledValue(for: .carb)
    }
    
    public var fatAmount: Double {
        mealFoodItem.scaledValue(for: .fat)
    }
    
    public var proteinAmount: Double {
        mealFoodItem.scaledValue(for: .protein)
    }
}
