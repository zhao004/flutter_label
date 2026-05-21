/// 应用级配置模型，集中定义默认值和 JSON 边界校验策略。
class AppSettings {
  const AppSettings({required this.spaceCompletesAndSelectsNext});

  const AppSettings.defaults() : spaceCompletesAndSelectsNext = false;

  static const String spaceCompletesAndSelectsNextKey =
      'space_completes_and_selects_next';

  final bool spaceCompletesAndSelectsNext;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawValue = json[spaceCompletesAndSelectsNextKey];
    if (rawValue == null) {
      return const AppSettings.defaults();
    }
    if (rawValue is! bool) {
      throw const FormatException('空格完成并切换配置必须是布尔值');
    }
    return AppSettings(spaceCompletesAndSelectsNext: rawValue);
  }

  Map<String, dynamic> toJson() {
    return {spaceCompletesAndSelectsNextKey: spaceCompletesAndSelectsNext};
  }

  AppSettings copyWith({bool? spaceCompletesAndSelectsNext}) {
    return AppSettings(
      spaceCompletesAndSelectsNext:
          spaceCompletesAndSelectsNext ?? this.spaceCompletesAndSelectsNext,
    );
  }
}
