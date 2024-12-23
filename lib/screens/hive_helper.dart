import 'package:hive/hive.dart';

class HiveHelper {
  static const String empresasBoxName = 'empresasBox';
  static const String instalacionesBoxName = 'instalacionesBox';
  static const String empleadosBoxName = 'empleadosBox';
  static const String gruposBoxName = 'gruposBox';
  static const String userDataBoxName = 'userDataBox';
  static const String pendingRequestsBoxName = 'pendingRequestsBox';

  // Inicializar Hive y abrir los boxes necesarios
  static Future<void> initHive() async {
    await Hive.openBox(empresasBoxName);
    await Hive.openBox(instalacionesBoxName);
    await Hive.openBox(empleadosBoxName);
    await Hive.openBox(gruposBoxName);
    await Hive.openBox(userDataBoxName);
    await Hive.openBox(pendingRequestsBoxName);
  }

  // Empresas
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

  // Grupos
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

  // Instalaciones
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

  // Empleados (guarda la lista general para la empresa)
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

  // Empleados de un contratista específico en una empresa
  // Se usa una clave compuesta: "empresaId + '_' + contractorLower"
  static Future<void> insertContratistaEmpleados(
      String empresaId, String contractorLower, List<dynamic> empleados) async {
    final box = Hive.box(empleadosBoxName);
    final key = '${empresaId}_$contractorLower';
    await box.put(key, empleados);
  }

  static List<dynamic> getContratistaEmpleados(String empresaId, String contractorLower) {
    final box = Hive.box(empleadosBoxName);
    final key = '${empresaId}_$contractorLower';
    return List<dynamic>.from(
      box.get(key, defaultValue: []),
    );
  }

  // id_usuarios
  static Future<void> storeIdUsuarios(String idUsuarios) async {
    final box = Hive.box(userDataBoxName);
    await box.put('id_usuarios', idUsuarios);
  }

  static String getIdUsuarios() {
    final box = Hive.box(userDataBoxName);
    return box.get('id_usuarios', defaultValue: '');
  }

  // Bearer Token
  static Future<void> storeBearerToken(String token) async {
    final box = Hive.box(userDataBoxName);
    await box.put('bearer_token', token);
  }

  static String getBearerToken() {
    final box = Hive.box(userDataBoxName);
    return box.get('bearer_token', defaultValue: '');
  }

  // Solicitudes OFFLINE
  static Future<void> savePendingDNIRequest(Map<String, dynamic> pendingData) async {
    final box = Hive.box(pendingRequestsBoxName);
    List<Map<String, dynamic>> pendingList =
        List<Map<String, dynamic>>.from(box.get('pendingDNIList', defaultValue: []));
    pendingList.add(pendingData);
    await box.put('pendingDNIList', pendingList);
  }

  static List<Map<String, dynamic>> getAllPendingDNIRequests() {
    final box = Hive.box(pendingRequestsBoxName);
    return List<Map<String, dynamic>>.from(
      box.get('pendingDNIList', defaultValue: []),
    );
  }

  static Future<void> removePendingDNIRequest(Map<String, dynamic> requestData) async {
    final box = Hive.box(pendingRequestsBoxName);
    List<Map<String, dynamic>> pendingList =
        List<Map<String, dynamic>>.from(box.get('pendingDNIList', defaultValue: []));
    pendingList.removeWhere((item) {
      return item['dni'] == requestData['dni'] &&
             item['timestamp'] == requestData['timestamp'];
    });
    await box.put('pendingDNIList', pendingList);
  }
}
