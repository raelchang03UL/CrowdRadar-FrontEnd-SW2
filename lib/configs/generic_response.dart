class GenericResponse<T> {
  final bool success;
  final T? data;
  final String message;
  final String? error;

  const GenericResponse({
    required this.success,
    this.data,
    this.message = '',
    this.error,
  });

  bool get hasError => error != null;
  bool get hasData => data != null;

  GenericResponse<T> copyWith({
    bool? success,
    T? data,
    String? message,
    String? error,
  }) {
    return GenericResponse<T>(
      success: success ?? this.success,
      data: data ?? this.data,
      message: message ?? this.message,
      error: error ?? this.error,
    );
  }
}
