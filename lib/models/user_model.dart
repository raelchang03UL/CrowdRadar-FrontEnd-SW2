class UserModel {
  final int? id;
  final String? nombre;
  final String? apellido;
  final String? email;
  final String? telefono;
  final String? rol;
  final String? distrito;
  final String? status;
  final String? createdAt;
  final String? updatedAt;

  const UserModel({
    this.id,
    this.nombre,
    this.apellido,
    this.email,
    this.telefono,
    this.rol,
    this.distrito,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int?,
        nombre: json['nombre'] as String?,
        apellido: json['apellido'] as String?,
        email: json['email'] as String?,
        telefono: json['telefono'] as String?,
        rol: json['rol'] as String?,
        distrito: json['distrito'] as String?,
        status: json['status'] as String?,
        createdAt: json['createdAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'telefono': telefono,
        'rol': rol,
        'distrito': distrito,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  UserModel copyWith({
    int? id,
    String? nombre,
    String? apellido,
    String? email,
    String? telefono,
    String? rol,
    String? distrito,
    String? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      rol: rol ?? this.rol,
      distrito: distrito ?? this.distrito,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
