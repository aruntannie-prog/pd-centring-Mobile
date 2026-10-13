/// Settings for reading name and address from uploaded documents.
abstract final class DocumentAi {
  /// Set to false to switch the feature off completely.
  static const enabled = true;

  /// Gemini model used through Firebase AI Logic. A "flash" model is fast
  /// and costs a fraction of a paisa per document.
  static const model = 'gemini-3.5-flash';

  /// true: the paid Gemini API (Firebase "Agent Platform", needs the Blaze
  /// plan). Google does not use the documents to improve its models, which
  /// matters for Aadhaar and other ID cards.
  ///
  /// false: the free Gemini Developer API. Free-tier requests may be used by
  /// Google to improve its products, so it is not recommended for ID cards.
  static const useAgentPlatform = true;
}
