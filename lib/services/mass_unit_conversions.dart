class WeightConverter {
  static const int gramsPerKg = 1000;
  static const double gramsPerLb = 453.59237;

  static int convertToGrams(double weight, String fromUnit) {
    return fromUnit == 'kg'
        ? (weight * gramsPerKg).round()
        : (weight * gramsPerLb).round();
  }

  static double convertFromGrams(int grams, String toUnit) {
    return toUnit == 'kg' ? (grams / gramsPerKg) : (grams / gramsPerLb);
  }

  static double convertWeight(double weight, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return weight;
    int grams = convertToGrams(weight, fromUnit);
    return convertFromGrams(grams, toUnit);
  }
}
