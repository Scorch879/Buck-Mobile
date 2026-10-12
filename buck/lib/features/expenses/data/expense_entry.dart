/// Icon for an expense category name. Matches the Figma
/// "Card / Recent Expenses" icons by keyword; `null` means use the
/// generic receipt icon.
String? expenseCategoryIcon(String categoryName) {
  final name = categoryName.toLowerCase();
  bool has(List<String> words) => words.any(name.contains);

  if (has(['food', 'dining', 'meal', 'grocer', 'restaurant', 'coffee'])) {
    return 'assets/icons/utensils.svg';
  }
  if (has(['shop', 'cloth', 'electronic', 'game', 'gift'])) {
    return 'assets/icons/shopping_bag.svg';
  }
  if (has(['bill', 'utilit', 'electric', 'water', 'telephone', 'internet'])) {
    return 'assets/icons/zap.svg';
  }
  if (has(['transport', 'gas', 'fuel', 'fare', 'commute', 'travel'])) {
    return 'assets/icons/bus.svg';
  }
  return null;
}
