import 'package:hive/hive.dart';

class HiveHelper {
  static const String empresasBoxName = 'empresasBox';
  static const String instalacionesBoxName = 'instalacionesBox';
  static const String empleadosBoxName = 'empleadosBox';

  // Inicializar Hive y abrir los boxes necesarios
  static Future<void> initHive() async {
    await Hive.openBox(empresasBoxName);
    await Hive.openBox(instalacionesBoxName);
    await Hive.openBox(empleadosBoxName);
  }

  // Métodos para Empresas
  // ---------------------

  // Insertar empresas
  static Future<void> insertEmpresas(
      List<Map<String, dynamic>> empresas) async {
    final box = Hive.box(empresasBoxName);
    await box.put('empresasList', empresas);
  }

  // Obtener empresas
  static List<Map<String, dynamic>> getEmpresas() {
    final box = Hive.box(empresasBoxName);
    return List<Map<String, dynamic>>.from(
      box.get('empresasList', defaultValue: []),
    );
  }

  // Eliminar empresas
  static Future<void> deleteEmpresas() async {
    final box = Hive.box(empresasBoxName);
    await box.delete('empresasList');
  }

  // Métodos para Instalaciones
  // --------------------------

  // Insertar instalaciones para una empresa específica
  static Future<void> insertInstalaciones(String empresaId,
      List<Map<String, dynamic>> instalaciones) async {
    final box = Hive.box(instalacionesBoxName);
    await box.put(empresaId, instalaciones);
  }

  // Obtener instalaciones de una empresa específica
  static List<Map<String, dynamic>> getInstalaciones(String empresaId) {
    final box = Hive.box(instalacionesBoxName);
    return List<Map<String, dynamic>>.from(
      box.get(empresaId, defaultValue: []),
    );
  }

  // Eliminar instalaciones de una empresa específica
  static Future<void> deleteInstalaciones(String empresaId) async {
    final box = Hive.box(instalacionesBoxName);
    await box.delete(empresaId);
  }

  // Métodos para Empleados
  // ----------------------

  // Insertar empleados para una empresa específica
  static Future<void> insertEmpleados(
      String empresaId, List<dynamic> empleados) async {
    final box = Hive.box(empleadosBoxName);
    await box.put(empresaId, empleados);
  }

  // Obtener empleados de una empresa específica
  static List<dynamic> getEmpleados(String empresaId) {
    final box = Hive.box(empleadosBoxName);
    return List<dynamic>.from(
      box.get(empresaId, defaultValue: []),
    );
  }

  // Eliminar empleados de una empresa específica
  static Future<void> deleteEmpleados(String empresaId) async {
    final box = Hive.box(empleadosBoxName);
    await box.delete(empresaId);
  }
}
