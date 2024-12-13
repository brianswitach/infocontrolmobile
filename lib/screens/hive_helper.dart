import 'package:hive/hive.dart';

class HiveHelper {
  static const String empresasBoxName = 'empresasBox';
  static const String instalacionesBoxName = 'instalacionesBox';
  static const String empleadosBoxName = 'empleadosBox';
  static const String gruposBoxName = 'gruposBox';
  static const String userDataBoxName = 'userDataBox'; // Nuevo box para usuario

  // Inicializar Hive y abrir los boxes necesarios
  static Future<void> initHive() async {
    await Hive.openBox(empresasBoxName);
    await Hive.openBox(instalacionesBoxName);
    await Hive.openBox(empleadosBoxName);
    await Hive.openBox(gruposBoxName);
    await Hive.openBox(userDataBoxName); // Abrimos el box de userData
  }

  // ---------------------
  // Métodos para Empresas
  // ---------------------
  static Future<void> insertEmpresas(List<Map<String, dynamic>> empresas) async {
    final box = Hive.box(empresasBoxName);
    await box.put('empresasList', empresas);
  }

  static List<Map<String, dynamic>> getEmpresas() {
    final box = Hive.box(empresasBoxName);
    return List<Map<String, dynamic>>.from(
      box.get('empresasList', defaultValue: []),
    );
  }

  static Future<void> deleteEmpresas() async {
    final box = Hive.box(empresasBoxName);
    await box.delete('empresasList');
  }

  // ------------------
  // Métodos para Grupos
  // ------------------
  static Future<void> insertGrupos(List<Map<String, dynamic>> grupos) async {
    final box = Hive.box(gruposBoxName);
    await box.put('gruposList', grupos);
  }

  static List<Map<String, dynamic>> getGrupos() {
    final box = Hive.box(gruposBoxName);
    return List<Map<String, dynamic>>.from(
      box.get('gruposList', defaultValue: []),
    );
  }

  static Future<void> deleteGrupos() async {
    final box = Hive.box(gruposBoxName);
    await box.delete('gruposList');
  }

  // --------------------------
  // Métodos para Instalaciones
  // --------------------------
  static Future<void> insertInstalaciones(String empresaId,
      List<Map<String, dynamic>> instalaciones) async {
    final box = Hive.box(instalacionesBoxName);
    await box.put(empresaId, instalaciones);
  }

  static List<Map<String, dynamic>> getInstalaciones(String empresaId) {
    final box = Hive.box(instalacionesBoxName);
    return List<Map<String, dynamic>>.from(
      box.get(empresaId, defaultValue: []),
    );
  }

  static Future<void> deleteInstalaciones(String empresaId) async {
    final box = Hive.box(instalacionesBoxName);
    await box.delete(empresaId);
  }

  // ----------------------
  // Métodos para Empleados
  // ----------------------
  static Future<void> insertEmpleados(String empresaId, List<dynamic> empleados) async {
    final box = Hive.box(empleadosBoxName);
    await box.put(empresaId, empleados);
  }

  static List<dynamic> getEmpleados(String empresaId) {
    final box = Hive.box(empleadosBoxName);
    return List<dynamic>.from(
      box.get(empresaId, defaultValue: []),
    );
  }

  static Future<void> deleteEmpleados(String empresaId) async {
    final box = Hive.box(empleadosBoxName);
    await box.delete(empresaId);
  }

  // ------------------------
  // Métodos para id_usuarios
  // ------------------------
  static Future<void> storeIdUsuarios(String idUsuarios) async {
    final box = Hive.box(userDataBoxName);
    await box.put('id_usuarios', idUsuarios);
  }

  static String getIdUsuarios() {
    final box = Hive.box(userDataBoxName);
    return box.get('id_usuarios', defaultValue: '');
  }
}
