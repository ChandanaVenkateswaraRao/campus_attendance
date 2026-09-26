import 'dart:math';

class FaceMatcher {
  // Calculates Euclidean distance between two vectors
  static double euclideanDistance(List<double> v1, List<double> v2) {
    if (v1.length != v2.length) {
      throw ArgumentError('Vectors must be of the same length');
    }

    double sum = 0.0;
    for (int i = 0; i < v1.length; i++) {
      sum += pow(v1[i] - v2[i], 2);
    }
    return sqrt(sum);
  }

  // Calculates Cosine Similarity between two vectors
  static double cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length) {
      throw ArgumentError('Vectors must be of the same length');
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      normA += pow(v1[i], 2);
      normB += pow(v2[i], 2);
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}
