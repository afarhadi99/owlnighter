/// Enums mirroring the TS contracts in @owlnighter/contracts (common.ts).
/// Each carries a [wire] value so JSON (de)serialization stays lossless and
/// matches the backend's string vocabulary exactly.
library;

enum AiProvider {
  gemini('gemini'),
  groq('groq');

  const AiProvider(this.wire);
  final String wire;

  static AiProvider fromWire(String v) => values.firstWhere((e) => e.wire == v);
}

enum PacingMode {
  gentle('gentle'),
  standard('standard'),
  intensive('intensive');

  const PacingMode(this.wire);
  final String wire;

  static PacingMode fromWire(String v) => values.firstWhere((e) => e.wire == v);
}

/// How trustworthy a step's quiz is. Never claim page-level precision the
/// system cannot back with text.
enum QuizMode {
  grounded('grounded'),
  preview('preview'),
  userText('user_text'),
  fallback('fallback');

  const QuizMode(this.wire);
  final String wire;

  static QuizMode fromWire(String v) => values.firstWhere((e) => e.wire == v);
}

enum GroundingStatus {
  pending('pending'),
  grounded('grounded'),
  partial('partial'),
  blocked('blocked');

  const GroundingStatus(this.wire);
  final String wire;

  static GroundingStatus fromWire(String v) =>
      values.firstWhere((e) => e.wire == v);
}

enum UserBookStatus {
  active('active'),
  paused('paused'),
  completed('completed'),
  archived('archived');

  const UserBookStatus(this.wire);
  final String wire;

  static UserBookStatus fromWire(String v) =>
      values.firstWhere((e) => e.wire == v);
}

/// Reader UI state for a step (PlanStepState.status in the contract).
enum StepStatus {
  locked('locked'),
  available('available'),
  completed('completed');

  const StepStatus(this.wire);
  final String wire;

  static StepStatus fromWire(String v) => values.firstWhere((e) => e.wire == v);
}

enum QuizQuestionKind {
  multipleChoice('multiple_choice'),
  trueFalse('true_false'),
  shortAnswer('short_answer');

  const QuizQuestionKind(this.wire);
  final String wire;

  static QuizQuestionKind fromWire(String v) =>
      values.firstWhere((e) => e.wire == v);
}
