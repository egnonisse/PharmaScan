enum AppInitStatus { initial, loading, ready, error }

class AppInitState {
  const AppInitState({
    required this.status,
    required this.errorMessage,
    this.hasPhone = false,
  });

  final AppInitStatus status;
  final String? errorMessage;

  /// true si le compte a un numéro lié (sinon → écran de connexion).
  final bool hasPhone;

  const AppInitState.initial()
      : status = AppInitStatus.initial,
        errorMessage = null,
        hasPhone = false;

  AppInitState copyWith({
    AppInitStatus? status,
    String? errorMessage,
    bool? hasPhone,
  }) {
    return AppInitState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      hasPhone: hasPhone ?? this.hasPhone,
    );
  }
}
