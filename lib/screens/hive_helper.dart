import 'package:hive/hive.dart';

class HiveHelper {
  static const String empresasBoxName = 'empresasBox';
  static const String instalacionesBoxName = 'instalacionesBox';
  static const String empleadosBoxName = 'empleadosBox';
  static const String gruposBoxName = 'gruposBox';
  static const String userDataBoxName = 'userDataBox'; 
  static const String pendingRequestsBoxName = 'pendingRequestsBox'; // Nuevo Box para solicitudes offline

  // Inicializar Hive y abrir los boxes necesarios
  static Future<void> initHive() async {
    await Hive.openBox(empresasBoxName);
    await Hive.openBox(instalacionesBoxName);
    await Hive.openBox(empleadosBoxName);
    await Hive.openBox(gruposBoxName);
    await Hive.openBox(userDataBoxName);
    await Hive.openBox(pendingRequestsBoxName); // Abrimos el box de peticiones pendientes
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

  // ---------------------------------
  // Métodos para solicitudes OFFLINE
  // ---------------------------------
  /// Guarda un request pendiente (DNI, id_empresas, etc.) en el box de peticiones pendientes
  static Future<void> savePendingDNIRequest(Map<String, dynamic> pendingData) async {
    final box = Hive.box(pendingRequestsBoxName);
    // Obtenemos la lista de pendientes existente, si no existe creamos una nueva
    List<Map<String, dynamic>> pendingList =
        List<Map<String, dynamic>>.from(box.get('pendingDNIList', defaultValue: []));
    pendingList.add(pendingData);
    await box.put('pendingDNIList', pendingList);
  }

  /// Retorna todas las solicitudes de DNI pendientes
  static List<Map<String, dynamic>> getAllPendingDNIRequests() {
    final box = Hive.box(pendingRequestsBoxName);
    return List<Map<String, dynamic>>.from(
      box.get('pendingDNIList', defaultValue: []),
    );
  }

  /// Elimina una solicitud pendiente concreta del box. 
  /// Recibe el mismo map que se guardó originalmente, lo retira de la lista y sobrescribe.
  static Future<void> removePendingDNIRequest(Map<String, dynamic> requestData) async {
    final box = Hive.box(pendingRequestsBoxName);
    List<Map<String, dynamic>> pendingList =
        List<Map<String, dynamic>>.from(box.get('pendingDNIList', defaultValue: []));
    pendingList.removeWhere((item) {
      // Podemos comparar timestamp + dni para tener unicidad
      return item['dni'] == requestData['dni'] &&
             item['timestamp'] == requestData['timestamp'];
    });
    await box.put('pendingDNIList', pendingList);
  }
}
