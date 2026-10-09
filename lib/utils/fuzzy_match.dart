/// Fuzzy match: checks if all characters in the query appear in order
/// within the target string, case-insensitive. Falls back to substring
/// match first for more intuitive short-query results.
bool fuzzyMatch(String target, String query) {
  if (query.isEmpty) return true;
  final lowerTarget = target.toLowerCase();
  final lowerQuery = query.toLowerCase();

  // First try substring match (more intuitive for short queries)
  if (lowerTarget.contains(lowerQuery)) return true;

  // Then try subsequence match (fuzzy)
  int targetIdx = 0;
  int queryIdx = 0;
  while (targetIdx < lowerTarget.length && queryIdx < lowerQuery.length) {
    if (lowerTarget[targetIdx] == lowerQuery[queryIdx]) {
      queryIdx++;
    }
    targetIdx++;
  }
  return queryIdx == lowerQuery.length;
}
