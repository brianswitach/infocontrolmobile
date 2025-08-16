import 'package:hive/hive.dart';

class HiveHelper {
  static const String empresasBoxName = 'empresasBox';
  static const String instalacionesBoxName = 'instalacionesBox';
  static const String empleadosBoxName = 'empleadosBox';
  static const String gruposBoxName = 'gruposBox';
  static const String userDataBoxName = 'userDataBox';
  static const String pendingRequestsBoxName = 'pendingRequestsBox';

  // ────────────────────────────
  //  Inicializar Hive
  // ────────────────────────────
  static Future<void> initHive() async {
    await Hive.openBox(empresasBoxName);
    await Hive.openBox(instalacionesBoxName);
    await Hive.openBox(empleadosBoxName);
    await Hive.openBox(gruposBoxName);
    await Hive.openBox(userDataBoxName);
    await Hive.openBox(pendingRequestsBoxName);
  }

  // ────────────────────────────
  //  EMPRESAS
  // ────────────────────────────
  static Future<void> insertEmpresas(
      List<Map<String, dynamic>> empresas) async {
    final box = Hive.box(empresasBoxName);

    // Cast fuerte: todas las claves → String
    final cleanList =
        empresas.map((e) => Map<String, dynamic>.from(e)).toList();

    await box.put('empresasList', cleanList);
  }

  static List<Map<String, dynamic>> getEmpresas() {
    final box = Hive.box(empresasBoxName);
    final raw = box.get('empresasList', defaultValue: []);

    // Cast seguro elemento-por-elemento
    return (raw as List)
        .map<Map<String, dynamic>>(
          (e) => Map<String, dynamic>.from(
            (e as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  static Future<void> deleteEmpresas() async {
    final box = Hive.box(empresasBoxName);
    await box.delete('empresasList');
  }

  // ────────────────────────────
  //  GRUPOS  (modificado)
  // ────────────────────────────
  static Future<void> insertGrupos(List<Map<String, dynamic>> grupos) async {
    final box = Hive.box(gruposBoxName);

    // Cast fuerte igual que en empresas
    final cleanList = grupos.map((g) => Map<String, dynamic>.from(g)).toList();

    await box.put('gruposList', cleanList);
  }

  static List<Map<String, dynamic>> getGrupos() {
    final box = Hive.box(gruposBoxName);
    final raw = box.get('gruposList', defaultValue: []);

    // Cast seguro elemento-por-elemento
    return (raw as List)
        .map<Map<String, dynamic>>(
          (e) => Map<String, dynamic>.from(
            (e as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  static Future<void> deleteGrupos() async {
    final box = Hive.box(gruposBoxName);
    await box.delete('gruposList');
  }

  // ────────────────────────────
  //  INSTALACIONES
  // ────────────────────────────
  static Future<void> insertInstalaciones(
      String empresaId, List<Map<String, dynamic>> instalaciones) async {
    final box = Hive.box(instalacionesBoxName);
    final cleanList =
        instalaciones.map((e) => Map<String, dynamic>.from(e)).toList();
    await box.put(empresaId, cleanList);
  }

  static List<Map<String, dynamic>> getInstalaciones(String empresaId) {
    final box = Hive.box(instalacionesBoxName);
    final raw = box.get(empresaId, defaultValue: []);
    return (raw as List)
        .map<Map<String, dynamic>>(
          (e) => Map<String, dynamic>.from(
            (e as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  }

  static Future<void> deleteInstalaciones(String empresaId) async {
    final box = Hive.box(instalacionesBoxName);
    await box.delete(empresaId);
  }

  // ────────────────────────────
  //  EMPLEADOS (general)
  // ────────────────────────────
  static Future<void> insertEmpleados(
      String empresaId, List<dynamic> empleados) async {
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

  // ────────────────────────────
  //  EMPLEADOS de un contratista
  // ────────────────────────────
  static Future<void> insertContratistaEmpleados(
      String empresaId, String contractorLower, List<dynamic> empleados) async {
    final box = Hive.box(empleadosBoxName);
    await box.put('${empresaId}_$contractorLower', empleados);
  }

  static List<dynamic> getContratistaEmpleados(
      String empresaId, String contractorLower) {
    final box = Hive.box(empleadosBoxName);
    return List<dynamic>.from(
      box.get('${empresaId}_$contractorLower', defaultValue: []),
    );
  }

  // ────────────────────────────
  //  DATOS DE USUARIO
  // ────────────────────────────
  static Future<void> storeIdUsuarios(String idUsuarios) async {
    final box = Hive.box(userDataBoxName);
    await box.put('id_usuarios', idUsuarios);
  }

  static String getIdUsuarios() {
    final box = Hive.box(userDataBoxName);
    return box.get('id_usuarios', defaultValue: '');
  }

  static Future<void> storeBearerToken(String token) async {
    final box = Hive.box(userDataBoxName);
    await box.put('bearer_token', token);
  }

  static String getBearerToken() {
    final box = Hive.box(userDataBoxName);
    return box.get('bearer_token', defaultValue: '');
  }

  // Puede entrar a LupaEmpresa
  static Future<void> storePuedeEntrarLupa(bool value) async {
    final box = Hive.box(userDataBoxName);
    await box.put('puedeEntrarLupa', value);
  }

  static bool getPuedeEntrarLupa() {
    final box = Hive.box(userDataBoxName);
    return box.get('puedeEntrarLupa', defaultValue: false);
  }

  // ────────────────────────────
  //  CREDENCIALES OFFLINE
  // ────────────────────────────
  static Future<void> storeUsernameOffline(String username) async {
    final box = Hive.box(userDataBoxName);
    await box.put('usernameoffline', username);
  }

  static String getUsernameOffline() {
    final box = Hive.box(userDataBoxName);
    return box.get('usernameoffline', defaultValue: '');
  }

  static Future<void> storePasswordOffline(String password) async {
    final box = Hive.box(userDataBoxName);
    await box.put('passwordoffline', password);
  }

  static String getPasswordOffline() {
    final box = Hive.box(userDataBoxName);
    return box.get('passwordoffline', defaultValue: '');
  }

  // ────────────────────────────
  //  SOLICITUDES OFFLINE
  // ────────────────────────────
  static Future<void> savePendingDNIRequest(
      Map<String, dynamic> pendingData) async {
    final box = Hive.box(pendingRequestsBoxName);
    List<Map<String, dynamic>> pendingList = List<Map<String, dynamic>>.from(
      box.get('pendingDNIList', defaultValue: []),
    );
    pendingList.add(pendingData);
    await box.put('pendingDNIList', pendingList);
  }

  static List<Map<String, dynamic>> getAllPendingDNIRequests() {
    final box = Hive.box(pendingRequestsBoxName);
    return List<Map<String, dynamic>>.from(
      box.get('pendingDNIList', defaultValue: []),
    );
  }

  static Future<void> removePendingDNIRequest(
      Map<String, dynamic> requestData) async {
    final box = Hive.box(pendingRequestsBoxName);
    List<Map<String, dynamic>> pendingList = List<Map<String, dynamic>>.from(
      box.get('pendingDNIList', defaultValue: []),
    );
    pendingList.removeWhere(
      (item) =>
          item['dni'] == requestData['dni'] &&
          item['timestamp'] == requestData['timestamp'],
    );
    await box.put('pendingDNIList', pendingList);
  }
}
