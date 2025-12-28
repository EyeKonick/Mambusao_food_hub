// lib/models/filter_state.dart

class FilterState {
  // Category filters (multi-select)
  final List<String> selectedCategories;
  
  // Rating filter (minimum rating)
  final int? minRating;
  
  // Distance filter (in kilometers)
  final double? maxDistance;

  const FilterState({
    this.selectedCategories = const [],
    this.minRating,
    this.maxDistance,
  });

  // Check if any filters are active
  bool get hasActiveFilters =>
      selectedCategories.isNotEmpty ||
      minRating != null ||
      maxDistance != null;

  // Count of active filters
  int get activeFilterCount {
    int count = 0;
    if (selectedCategories.isNotEmpty) count++;
    if (minRating != null) count++;
    if (maxDistance != null) count++;
    return count;
  }

  // Create a copy with modifications
  FilterState copyWith({
    List<String>? selectedCategories,
    int? minRating,
    double? maxDistance,
    bool clearMinRating = false,
    bool clearMaxDistance = false,
  }) {
    return FilterState(
      selectedCategories: selectedCategories ?? this.selectedCategories,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      maxDistance: clearMaxDistance ? null : (maxDistance ?? this.maxDistance),
    );
  }

  // Clear all filters
  FilterState clearFilters() {
    return const FilterState();
  }
}