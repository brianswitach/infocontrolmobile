import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

// IMPORTAMOS LA PANTALLA DE LOGIN PARA FORZAR REAUTENTICACIÓN
import 'login_screen.dart';

// **IMPORTAMOS HIVE HELPER** (por si usas otros métodos de helper,
// pero ya no usaremos HiveHelper.getIdUsuarios(),
// sino que leeremos directamente de la box "id_usuarios2")
// ignore: unused_import
import 'hive_helper.dart';

class LupaEmpresaScreen extends StatefulWidget {
  final Map<String, dynamic> empresa;
  final String bearerToken; // token que llega desde HomeScreen
  final String idEmpresaAsociada;
  final String empresaId;
  final String username; // para refrescar token en LupaEmpresa
  final String password; // para refrescar token en LupaEmpresa
  final bool openScannerOnInit;

  const LupaEmpresaScreen({
    Key? key,
    required this.empresa,
    required this.bearerToken,
    required this.idEmpresaAsociada,
    required this.empresaId,
    required this.username,
    required this.password,
    this.openScannerOnInit = false,
  }) : super(key: key);

  @override
  _LupaEmpresaScreenState createState() => _LupaEmpresaScreenState();
}

class _LupaEmpresaScreenState extends State<LupaEmpresaScreen>
    with WidgetsBindingObserver {
  String? selectedContractor;
  String? selectedContractorCuit;
  String? selectedContractorTipo;
  String? selectedContractorMensajeGeneral;
  String? selectedContractorEstado;
  bool showContractorInfo = false;
  bool showEmployees = false;

  // Lista general de empleados (para listartest).
  List<dynamic> allEmpleadosListarTest = [];

  // Lista de proveedores/contratistas que cargamos desde el nuevo endpoint.
  List<dynamic> allProveedoresListarTest = [];

  // ** NUEVA LISTA PARA GUARDAR VEHÍCULOS (para cuando se presione el botón "Vehículos") **
  List<dynamic> allVehiculosListarTest = [];

  // NUEVO: Lista filtrada de vehículos que mostraremos en pantalla
  List<dynamic> filteredVehiculos = [];
  bool showVehicles = false; // para saber si mostrar la lista de vehículos

  // Lista que se mostrará al filtrar por contratista (EMPLEADOS)
  List<dynamic> empleados = [];
  List<dynamic> filteredEmpleados = [];

  bool isLoading = true;

  final MobileScannerController controladorCamara = MobileScannerController();
  final TextEditingController personalIdController = TextEditingController();

  // TextEditingController para el front de "Dominio":
  final TextEditingController dominioController = TextEditingController();

  final TextEditingController searchController = TextEditingController();

  // Controlador para filtrar VEHÍCULOS (igual al de empleados)
  final TextEditingController searchControllerVeh = TextEditingController();

  bool qrScanned = false;
  bool? resultadoHabilitacion;

  late Dio dio;
  late CookieJar cookieJar;
  late Connectivity connectivity;
  late StreamSubscription<ConnectivityResult> connectivitySubscription;

  // id_usuarios que obtenemos del box "id_usuarios2" en Hive
  String hiveIdUsuarios = '';

  // Mapa para almacenar si un empleado está actualmente dentro (true) o fuera (false).
  Map<String, bool> employeeInsideStatus = {};

  // El token actual (viene desde HomeScreen) pero se puede refrescar aquí
  late String bearerToken;

  // Timer para refrescar token en LupaEmpresa
  Timer? _refreshTimerLupa;

  // ------------ BOXES DE HIVE ------------
  Box? employeesBox;
  Box? contractorsBox;
  Box? offlineRequestsBox;
  Box? idUsuariosBox;
  Box? vehiclesBox;

  // NUEVO: Guardamos temporalmente el estado del contratista desde la consulta a vehiculos
  // (para saber si está "Habilitado" o "Inhabilitado")
  String? contractorEstadoFromVehiculos;

  // ==================== CICLO DE VIDA ====================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    bearerToken = widget.bearerToken;

    cookieJar = CookieJar();
    dio = Dio();
    dio.interceptors.add(CookieManager(cookieJar));

    // **AGREGAMOS EL MANEJO AUTOMÁTICO DE COOKIES** (SIN SACAR NADA):
    cookieJar.saveFromResponse(
      Uri.parse("https://www.infocontrol.tech"),
      [
        Cookie(
            'ci_session_infocontrolweb1', 'o564sc60v05mhvvdmpbekllq6chtjloq'),
        Cookie('cookie_sistema', '8433b356c97722102b7f142d8ecf9f8d'),
      ],
    );
    // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

    connectivity = Connectivity();
    connectivitySubscription =
        connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        _processPendingRequests();
      }
    });

    _startTokenRefreshTimerLupa();
    searchController.addListener(_filterEmployees);

    _initHive().then((_) => _openBoxes().then((_) async {
          await _openIdUsuariosBox();
          _readIdUsuariosFromBox();

          var connectivityResult = await connectivity.checkConnectivity();
          if (connectivityResult == ConnectivityResult.none) {
            // SIN CONEXIÓN
            _loadEmployeesFromHive();
            _loadContractorsFromHive();
            _loadVehiclesFromHive();
            setState(() {
              isLoading = false;
            });
          } else {
            // CON CONEXIÓN
            await _fetchAllEmployeesListarTest();
            await _fetchAllProveedoresListar();
            if (widget.openScannerOnInit) {
              _mostrarEscanerQR();
            }
          }
        }));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      connectivity.checkConnectivity().then((connResult) async {
        if (connResult != ConnectivityResult.none) {
          setState(() {
            isLoading = true;
          });
          await _fetchAllEmployeesListarTest();
          setState(() {
            isLoading = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    controladorCamara.dispose();
    personalIdController.dispose();
    dominioController.dispose();
    searchController.dispose();
    searchControllerVeh.dispose();
    connectivitySubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimerLupa?.cancel();
    super.dispose();
  }

  // ==================== HIVE CONFIG ====================
  Future<void> _initHive() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);
  }

  Future<void> _openBoxes() async {
    if (!Hive.isBoxOpen('employees2')) {
      employeesBox = await Hive.openBox('employees2');
    } else {
      employeesBox = Hive.box('employees2');
    }

    if (!Hive.isBoxOpen('contractors2')) {
      contractorsBox = await Hive.openBox('contractors2');
    } else {
      contractorsBox = Hive.box('contractors2');
    }

    if (!Hive.isBoxOpen('offlineRequests2')) {
      offlineRequestsBox = await Hive.openBox('offlineRequests2');
    } else {
      offlineRequestsBox = Hive.box('offlineRequests2');
    }

    if (!Hive.isBoxOpen('vehicles2')) {
      vehiclesBox = await Hive.openBox('vehicles2');
    } else {
      vehiclesBox = Hive.box('vehicles2');
    }
  }

  Future<void> _openIdUsuariosBox() async {
    if (!Hive.isBoxOpen('id_usuarios2')) {
      idUsuariosBox = await Hive.openBox('id_usuarios2');
    } else {
      idUsuariosBox = Hive.box('id_usuarios2');
    }
  }

  void _readIdUsuariosFromBox() {
    if (idUsuariosBox != null) {
      final storedId = idUsuariosBox?.get('id_usuarios_key', defaultValue: '');
      if (storedId is String) {
        hiveIdUsuarios = storedId;
      } else {
        hiveIdUsuarios = '';
      }
    }
  }

  // ==================== TOKEN REFRESH ====================
  void _startTokenRefreshTimerLupa() {
    _refreshTimerLupa?.cancel();
    _refreshTimerLupa = Timer.periodic(
      const Duration(minutes: 4, seconds: 10),
      (_) => _refreshBearerTokenLupa(),
    );
  }

  Future<void> _refreshBearerTokenLupa() async {
    var connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('No hay conexión. No se puede refrescar el token en LupaEmpresa.');
      return;
    }

    try {
      final response = await dio.post(
        "https://www.infocontrol.tech/web/api/mobile/service/login",
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
                'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}',
          },
        ),
        data: jsonEncode({
          'username': widget.username,
          'password': widget.password,
        }),
      );

      if (response.statusCode == 200) {
        final loginData = response.data;
        String newToken = loginData['data']['Bearer'];

        setState(() {
          bearerToken = newToken;
        });

        print('Token refrescado correctamente en LupaEmpresa: $newToken');
      } else {
        throw Exception('Recargando...');
      }
    } catch (e) {
      print('Recargando...');
    }
  }

  // ==================== DESCARGA Y GUARDADO DE EMPLEADOS ====================
  Future<void> _fetchAllEmployeesListarTest() async {
    setState(() {
      isLoading = true;
    });

    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _loadEmployeesFromHive();
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final response = await _makeGetRequest(
        "https://www.infocontrol.tech/web/api/mobile/empleados/listartest",
        queryParameters: {'id_empresas': widget.empresaId},
      );
      final statusCode = response.statusCode ?? 0;

      if (statusCode == 200) {
        final responseData = response.data;
        List<dynamic> employeesData = responseData['data'] ?? [];

        allEmpleadosListarTest = employeesData;
        employeesBox?.put('all_employees', employeesData);

        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      }
    } on DioException catch (e) {
      setState(() {
        isLoading = false;
      });
      if (!mounted) return;

      if (e.response?.statusCode == 401) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    }
  }

  void _loadEmployeesFromHive() {
    List<dynamic> storedEmployees =
        employeesBox?.get('all_employees', defaultValue: []) as List<dynamic>;
    if (storedEmployees.isNotEmpty) {
      allEmpleadosListarTest = storedEmployees;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay datos locales de empleados (listartest).'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== DESCARGA Y GUARDADO DE CONTRATISTAS ====================
  Future<void> _fetchAllProveedoresListar() async {
    setState(() {
      isLoading = true;
    });

    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _loadContractorsFromHive();
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final response = await _makeGetRequest(
        "https://www.infocontrol.tech/web/api/mobile/proveedores/listar",
        queryParameters: {'id_empresas': widget.empresaId},
      );
      final statusCode = response.statusCode ?? 0;

      if (statusCode == 200) {
        final responseData = response.data;
        List<dynamic> proveedoresData = responseData['data'] ?? [];

        allProveedoresListarTest = proveedoresData;
        contractorsBox?.put('all_contractors', proveedoresData);

        setState(() {
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      }
    } on DioException catch (e) {
      setState(() {
        isLoading = false;
      });
      if (!mounted) return;

      if (e.response?.statusCode == 401) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    }
  }

  void _loadContractorsFromHive() {
    List<dynamic> storedContractors = contractorsBox
        ?.get('all_contractors', defaultValue: []) as List<dynamic>;
    if (storedContractors.isNotEmpty) {
      allProveedoresListarTest = storedContractors;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay datos locales de proveedores/contratistas.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadVehiclesFromHive() {
    List<dynamic> storedVehicles =
        vehiclesBox?.get('all_vehicles', defaultValue: []) as List<dynamic>;
    if (storedVehicles.isNotEmpty) {
      allVehiculosListarTest = storedVehicles;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay datos locales de vehículos.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setLastActionVehicle(String idEntidad, String actionText) {
    // Guardamos en vehiclesBox bajo la clave "accion_<idEntidad>" la acción
    vehiclesBox?.put('accion_$idEntidad', actionText);
  }

  String _getLastActionVehicle(String idEntidad) {
    // Leemos de vehiclesBox la última acción conocida, o "" si no existe
    return vehiclesBox?.get('accion_$idEntidad', defaultValue: '') as String;
  }

  // ==================== FILTRO DE EMPLEADOS POR CONTRATISTA ====================
  Future<void> _filtrarEmpleadosDeContratista() async {
    if (selectedContractor == null || selectedContractor!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes elegir un contratista'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final contractorLower = selectedContractor!.trim().toLowerCase();
    List<dynamic> filtrados = allEmpleadosListarTest.where((emp) {
      final nombreRazonSocial =
          emp['nombre_razon_social']?.toString().trim().toLowerCase() ?? '';
      return nombreRazonSocial == contractorLower;
    }).toList();

    setState(() {
      // Para ocultar la lista de vehículos cuando se selecciona Empleados
      showVehicles = false;
      empleados = filtrados;
      filteredEmpleados = filtrados;
      showEmployees = true;
    });
  }

  // ==================== OFFLINE REQUESTS (solo para empleados) ====================
  Future<void> _saveOfflineRequest(String dniIngresado) async {
    List<dynamic> currentRequests =
        offlineRequestsBox?.get('requests', defaultValue: []) as List<dynamic>;

    final Map<String, dynamic> pendingData = {
      "dni": dniIngresado,
      "id_empresas": widget.empresaId,
      "id_usuarios": hiveIdUsuarios,
      "timestamp": DateTime.now().toIso8601String(),
    };

    currentRequests.add(pendingData);
    offlineRequestsBox?.put('requests', currentRequests);
  }

  Future<void> _processPendingRequests() async {
    List<dynamic> pendingRequests =
        offlineRequestsBox?.get('requests', defaultValue: []) as List<dynamic>;
    if (pendingRequests.isEmpty) return;

    List<dynamic> remainingRequests = [];

    for (var requestData in pendingRequests) {
      // CASO EMPLEADO (LOGICA EXISTENTE)
      if (requestData["tipo"] != null && requestData["tipo"] == "empleado") {
        final String dniIngresado = requestData["dni"] ?? '';
        final String idEmpresas = requestData["id_empresas"] ?? '';
        final String idUsuarios = requestData["id_usuarios"] ?? '';

        if (dniIngresado.isEmpty) {
          continue;
        }

        try {
          final response = await _makeGetRequest(
            "https://www.infocontrol.tech/web/api/mobile/empleados/listartest",
            queryParameters: {'id_empresas': idEmpresas},
          );

          final statusCode = response.statusCode ?? 0;
          if (statusCode == 200) {
            final responseData = response.data;
            List<dynamic> employeesData = responseData['data'] ?? [];

            final foundEmployee = employeesData.firstWhere((emp) {
              final val = emp['valor']?.toString().trim() ?? '';
              final cuit = emp['cuit']?.toString().trim() ?? '';
              final cuil = emp['cuil']?.toString().trim() ?? '';
              return (val == dniIngresado ||
                  cuit == dniIngresado ||
                  cuil == dniIngresado);
            }, orElse: () => null);

            if (foundEmployee != null) {
              final String idEntidad =
                  foundEmployee['id_entidad'] ?? 'NO DISPONIBLE';

              final Map<String, dynamic> postData = {
                'id_empresas': idEmpresas,
                'id_usuarios': idUsuarios,
                'id_entidad': idEntidad,
              };

              final postResponse = await _makePostRequest(
                "https://www.infocontrol.tech/web/api/mobile/Ingresos_egresos/register_movement",
                postData,
              );

              print(
                  'Respuesta register_movement empleado: ${postResponse.data}');

              if ((postResponse.statusCode ?? 0) == 200) {
                // Éxito => no se re-agrega
              } else {
                remainingRequests.add(requestData);
              }
            } else {
              remainingRequests.add(requestData);
            }
          } else {
            remainingRequests.add(requestData);
          }
        } catch (_) {
          remainingRequests.add(requestData);
        }
      }

      // CASO VEHÍCULO (LO NUEVO)
      else if (requestData["tipo"] != null &&
          requestData["tipo"] == "vehiculo") {
        final String? idEntidad = requestData["id_entidad"];
        final String idEmpresas = requestData["id_empresas"] ?? '';
        final String idUsuarios = requestData["id_usuarios"] ?? '';

        if (idEntidad == null || idEntidad.isEmpty) {
          remainingRequests.add(requestData);
          continue;
        }

        try {
          final Map<String, dynamic> postDataVeh = {
            'id_empresas': idEmpresas,
            'id_usuarios': idUsuarios,
            'id_entidad': idEntidad,
          };

          final postResponseVeh = await _makePostRequest(
            "https://www.infocontrol.tech/web/api/mobile/Ingresos_egresos/register_movement",
            postDataVeh,
          );

          if ((postResponseVeh.statusCode ?? 0) == 200) {
            print('Movimiento de vehículo registrado con éxito.');
            // Se registró OK => no se re-agrega
          } else {
            // Quedará pendiente
            remainingRequests.add(requestData);
          }
        } catch (_) {
          remainingRequests.add(requestData);
        }
      }

      // SI NO CAE EN EMPLEADO NI VEHÍCULO
      else {
        remainingRequests.add(requestData);
      }
    }

    offlineRequestsBox?.put('requests', remainingRequests);
  }

  // ==================== REGISTRAR MOVIMIENTOS (INGRESO/EGRESO) (Empleados) ====================
  Future<void> _hacerIngresoEgresoEmpleado(dynamic empleado) async {
    final dniVal = (empleado['valor']?.toString().trim() ?? '');
    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      await _saveOfflineRequest(dniVal);
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Modo offline'),
            content: const Text(
                'Se guardó para registrar cuando vuelva la conexión.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    final String idEntidad = empleado['id_entidad'] ?? 'NO DISPONIBLE';
    await _registerMovement(idEntidad);
  }

  Future<void> _saveOfflineVehicleRequest(
      String action, String idEntidad) async {
    // Recuperamos los requests pendientes que ya hubiera
    List<dynamic> currentRequests =
        offlineRequestsBox?.get('requests', defaultValue: []) as List<dynamic>;

    // Creamos el map a guardar
    final Map<String, dynamic> pendingData = {
      'tipo': 'vehiculo', // Para diferenciarlo de empleados
      'action': action, // "Registrar Ingreso" o "Registrar Egreso"
      'id_empresas': widget.empresaId,
      'id_usuarios': hiveIdUsuarios,
      'id_entidad': idEntidad,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Lo guardamos en la box
    currentRequests.add(pendingData);
    offlineRequestsBox?.put('requests', currentRequests);
  }

  // ==================== BÚSQUEDA DE EMPLEADO (DNI/CUIT/CUIL) ====================
  Future<void> _buscarPersonalId() async {
    final texto = personalIdController.text.trim();
    if (texto.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falta informacion en el campo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      await _saveOfflineRequest(texto);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Modo offline'),
            content: const Text(
                'Se guardó para registrar cuando vuelva la conexión.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    // Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text(
                'Cargando...',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: Colors.black,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final response = await _makeGetRequest(
        "https://www.infocontrol.tech/web/api/mobile/empleados/listartest",
        queryParameters: {'id_empresas': widget.empresaId},
      );

      Navigator.pop(context);
      final statusCode = response.statusCode ?? 0;

      if (statusCode == 200) {
        final responseData = response.data;
        List<dynamic> employeesData = responseData['data'] ?? [];

        final String dniIngresado = texto;
        final foundEmployee = employeesData.firstWhere((emp) {
          final val = emp['valor']?.toString().trim() ?? '';
          final cuit = emp['cuit']?.toString().trim() ?? '';
          final cuil = emp['cuil']?.toString().trim() ?? '';
          return (val == dniIngresado ||
              cuit == dniIngresado ||
              cuil == dniIngresado);
        }, orElse: () => null);

        if (foundEmployee != null) {
          _showEmpleadoDetailsModal(foundEmployee);
        } else {
          showDialog(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('No encontrado'),
                content: const Text(
                    'No se encontró el DNI/CUIT/CUIL en la respuesta.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      } else {
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Código de respuesta'),
              content: Text('El código de respuesta es: $statusCode'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } on DioException catch (e) {
      Navigator.pop(context);
      if (e.response?.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Token inválido. Vuelva a HomeScreen para recargar.')),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text(''),
              content: const Text('Recargando...'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (_) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Recargando...'),
            content: const Text(''),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  // ==================== BÚSQUEDA POR DOMINIO/PLACA (con checks) ====================
  Future<void> _buscarDominio() async {
    final textoDominio = dominioController.text.trim();
    if (textoDominio.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falta información en el campo dominio'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Modo offline'),
            content: const Text('No hay conexión para buscar vehículos.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    // Mostramos un loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text(
                'Cargando...',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: Colors.black,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final response = await _makeGetRequest(
        "https://www.infocontrol.tech/web/api/mobile/vehiculos/listartest",
        queryParameters: {'id_empresas': widget.empresaId},
      );

      Navigator.pop(context); // Cerramos el loading

      final statusCode = response.statusCode ?? 0;
      if (statusCode == 200) {
        final responseData = response.data;
        final List<dynamic> vehiculosData = responseData['data'] ?? [];

        allVehiculosListarTest = vehiculosData;
        vehiclesBox?.put('all_vehicles', vehiculosData);

        final foundVehicle = vehiculosData.firstWhere(
          (veh) {
            final dom = veh['valor']?.toString().trim().toLowerCase() ?? '';
            return dom == textoDominio.toLowerCase();
          },
          orElse: () => null,
        );

        if (selectedContractor != null &&
            selectedContractor!.trim().isNotEmpty) {
          final foundContractorFromVehiculos = vehiculosData.firstWhere(
            (veh) {
              final contractorName = (veh['nombre_razon_social'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              return contractorName ==
                  selectedContractor!.toString().trim().toLowerCase();
            },
            orElse: () => null,
          );
          if (foundContractorFromVehiculos != null) {
            contractorEstadoFromVehiculos =
                foundContractorFromVehiculos['estado']?.toString().trim();
          } else {
            contractorEstadoFromVehiculos = 'Inhabilitado';
          }
        } else {
          contractorEstadoFromVehiculos = 'Inhabilitado';
        }

        if (foundVehicle != null) {
          final domainContractor =
              foundVehicle['nombre_razon_social']?.toString().trim() ?? '';
          if (selectedContractor != null &&
              selectedContractor!.trim().isNotEmpty) {
            final selectedContrLower = selectedContractor!.trim().toLowerCase();
            final domainContrLower = domainContractor.toLowerCase();
            if (selectedContrLower != domainContrLower) {
              showDialog(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Error'),
                    content: const Text(
                        'El dominio que ingresó pertenece a otro contratista.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
              return;
            }
          }
          _showVehiculoDetailsModal(foundVehicle);
        } else {
          showDialog(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('No encontrado'),
                content: const Text('El dominio no se encuentra registrado.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      } else {
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Código de respuesta'),
              content: Text('El código de respuesta es: $statusCode'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } on DioException catch (e) {
      Navigator.pop(context);
      if (e.response?.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Token inválido. Vuelva a HomeScreen para recargar.'),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Error'),
              content:
                  const Text('No se pudo procesar la petición de dominio.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Error inesperado'),
            content: Text('Ocurrió un error: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  // ==================== MOSTRAR DETALLES DEL VEHÍCULO ====================
  Future<void> _showVehiculoDetailsModal(dynamic vehiculo) async {
    final estado = (vehiculo['estado']?.toString().trim() ?? '').toLowerCase();
    final bool isVehiculoHabilitado = (estado == 'habilitado');

    // Lógica para saber si hay que mostrar "Registrar Ingreso" o "Registrar Egreso".
    String vehiculoBtnText = '';
    bool showVehiculoActionButton = false;

// Primero chequeamos si hay conexión
    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      // ESTAMOS OFFLINE => cargamos la última acción conocida (si existe)
      final lastAction = _getLastActionVehicle(vehiculo['id_entidad']);
      if (lastAction == 'REGISTRAR INGRESO' ||
          lastAction == 'REGISTRAR EGRESO') {
        // Mostramos el botón con la última acción conocida
        vehiculoBtnText = lastAction;
        showVehiculoActionButton = true;
      } else {
        // Si no había nada guardado, por defecto decimos "Registrar Ingreso"
        vehiculoBtnText = 'Registrar Ingreso';
        showVehiculoActionButton = true;
      }
    } else {
      // HAY CONEXIÓN => pedimos la acción al servidor
      try {
        final Map<String, dynamic> postData = {
          'id_entidad': vehiculo['id_entidad'],
          'id_usuarios': hiveIdUsuarios,
          'tipo_entidad': 'vehiculo',
        };

        final response = await dio.post(
          "https://www.infocontrol.tech/web/api/mobile/ingresos_egresos/action_resource",
          data: jsonEncode(postData),
          options: Options(
            headers: {
              'Authorization': 'Bearer $bearerToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

        final dynamic fullData = response.data;
        final dynamic dataInside = fullData['data'] ?? {};
        final String messageFromResource =
            dataInside['message']?.toString().trim() ?? '';

        if (messageFromResource.toUpperCase() == "REGISTRAR INGRESO") {
          vehiculoBtnText = "Registrar Ingreso"; // Fuerzo mayúscula / minúscula
          showVehiculoActionButton = true;
          _setLastActionVehicle(vehiculo['id_entidad'], "Registrar Ingreso");
        } else if (messageFromResource.toUpperCase() == "REGISTRAR EGRESO") {
          vehiculoBtnText = "Registrar Egreso";
          showVehiculoActionButton = true;
          _setLastActionVehicle(vehiculo['id_entidad'], "Registrar Egreso");
        }
      } catch (e) {
        print("Error al consultar action_resource para vehiculo: $e");
        // Si hay algún error, podrías asignar por defecto "Registrar Ingreso"
        // o no mostrar el botón, depende de tu preferencia
      }
    }

    final dominio = vehiculo['valor']?.toString().trim() ?? '';
    final contratistaSeleccionado = selectedContractor ?? 'No disponible';
    final bool isContractorHabilitadoFromVehiculos =
        (contractorEstadoFromVehiculos?.trim().toLowerCase() == 'habilitado');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              children: [
                Image.asset('assets/generic.jpg', width: 80, height: 80),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isVehiculoHabilitado ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isVehiculoHabilitado ? 'HABILITADO' : 'INHABILITADO',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dominio: $dominio',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contratista: $contratistaSeleccionado',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            // Botón de cerrar el detalle
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cerrar',
                style: TextStyle(fontFamily: 'Montserrat'),
              ),
            ),

            // == AQUÍ SE AGREGA EL BOTÓN EXTRA ==
            // Botón de registrar (Ingreso/Egreso), según corresponda
            if (showVehiculoActionButton && isVehiculoHabilitado)
              TextButton(
                onPressed: () async {
                  final connectivityResult =
                      await connectivity.checkConnectivity();

                  if (connectivityResult == ConnectivityResult.none) {
                    // OFFLINE => GUARDARLO Y MOSTRAR DIALOG
                    await _saveOfflineVehicleRequest(
                        vehiculoBtnText, vehiculo['id_entidad']);

                    // Cerramos el modal actual:
                    Navigator.of(context).pop();

                    // Mostramos alerta de “se guardó…”
                    showDialog(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: const Text('Modo offline'),
                          content: const Text(
                              'Se guardó para registrar cuando vuelva la conexión.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    // ONLINE => HACEMOS EL REQUEST REAL
                    try {
                      final Map<String, dynamic> postDataVeh = {
                        'id_empresas': widget.empresaId,
                        'id_usuarios': hiveIdUsuarios,
                        'id_entidad': vehiculo['id_entidad'],
                      };

                      final postResponseVeh = await dio.post(
                        "https://www.infocontrol.tech/web/api/mobile/Ingresos_egresos/register_movement",
                        data: jsonEncode(postDataVeh),
                        options: Options(
                          headers: {
                            'Authorization': 'Bearer $bearerToken',
                            'Content-Type': 'application/json',
                            'Accept': 'application/json',
                          },
                        ),
                      );

                      if ((postResponseVeh.statusCode ?? 0) == 200) {
                        final responseData = postResponseVeh.data;
                        final data = responseData['data'] ?? {};
                        final String messageToShow =
                            data['message']?.toString() ??
                                'Mensaje no disponible';

                        // Mostramos la respuesta
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          builder: (BuildContext ctx2) {
                            return AlertDialog(
                              title: const Text('Respuesta Vehículo'),
                              content: Text(messageToShow),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(ctx2).pop();
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      }
                    } catch (e) {
                      print("Error al registrar movimiento vehiculo: $e");
                    }
                  }
                },
                child: Text(
                  vehiculoBtnText, // "Registrar Ingreso" o "Registrar Egreso"
                  style: const TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
          ],
        );
      },
    );
  }

  // ==================== REGISTRAR MOVIMIENTO AL SERVIDOR (empleado) ====================
  Future<void> _registerMovement(String idEntidad) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text(
                'Cargando...',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  color: Colors.black,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final Map<String, dynamic> postData = {
        'id_empresas': widget.empresaId,
        'id_usuarios': hiveIdUsuarios,
        'id_entidad': idEntidad,
      };

      print("==> REGISTER_MOVEMENT param: $postData");

      final postResponse = await _makePostRequest(
        "https://www.infocontrol.tech/web/api/mobile/Ingresos_egresos/register_movement",
        postData,
      );

      Navigator.pop(context);

      final int statusCode = postResponse.statusCode ?? 0;
      final dynamic fullResponse = postResponse.data;

      if (statusCode == 200) {
        final dynamic dataObject = fullResponse['data'] ?? {};
        final String messageToShow =
            dataObject['message'] ?? 'Mensaje no disponible';

        bool isInside = employeeInsideStatus[idEntidad] ?? false;
        employeeInsideStatus[idEntidad] = !isInside;

        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Respuesta exitosa'),
              content: Text(messageToShow),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Text('Código de respuesta: $statusCode'),
              content: Text('Respuesta completa:\n${fullResponse.toString()}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } on DioException catch (e) {
      Navigator.pop(context);
      if (e.response?.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Token inválido en POST. Vuelva a HomeScreen para recargar.'),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Error al registrar movimiento'),
              content: const Text('Recargando...'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Error inesperado'),
            content: Text('Ocurrió un error en POST: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  // ==================== ESCANER DENTRO DE ESTA PANTALLA ====================
  void _reIniciarPaginaYEscanear() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LupaEmpresaScreen(
          empresa: widget.empresa,
          bearerToken: bearerToken,
          idEmpresaAsociada: widget.idEmpresaAsociada,
          empresaId: widget.empresaId,
          username: widget.username,
          password: widget.password,
          openScannerOnInit: true,
        ),
      ),
    );
  }

  // ==================== FILTRO DE EMPLEADOS CON TEXTFIELD ====================
  void _filterEmployees() {
    String query = searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        filteredEmpleados = List.from(empleados);
      });
    } else {
      List<dynamic> temp = [];
      for (var emp in empleados) {
        final dniVal = (emp['valor']?.toString().trim() ?? '').toLowerCase();
        final cuitVal = (emp['cuit']?.toString().trim() ?? '').toLowerCase();
        final cuilVal = (emp['cuil']?.toString().trim() ?? '').toLowerCase();

        final datosString = emp['datos']?.toString() ?? '';
        String apellidoVal = '';
        if (datosString.isNotEmpty &&
            datosString.startsWith('[') &&
            datosString.endsWith(']')) {
          try {
            List datosList = jsonDecode(datosString);
            var apellidoMap = datosList.firstWhere(
              (item) => item['id'] == "Apellido:",
              orElse: () => null,
            );
            if (apellidoMap != null && apellidoMap['valor'] is String) {
              apellidoVal =
                  (apellidoMap['valor'] as String).toLowerCase().trim();
            }
          } catch (_) {}
        }

        if (dniVal.contains(query) ||
            apellidoVal.contains(query) ||
            cuitVal.contains(query) ||
            cuilVal.contains(query)) {
          temp.add(emp);
        }
      }
      setState(() {
        filteredEmpleados = temp;
      });
    }
  }

  // ==================== FILTRO DE VEHÍCULOS CON TEXTFIELD ====================
  void _filterVehicles() {
    String queryVeh = searchControllerVeh.text.toLowerCase().trim();
    if (queryVeh.isEmpty) {
      setState(() {
        filteredVehiculos = List.from(allVehiculosListarTest.where((veh) {
          final nombreRazSoc = (veh['nombre_razon_social'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          return nombreRazSoc ==
              (selectedContractor ?? '').trim().toLowerCase();
        }));
      });
    } else {
      List<dynamic> temp = [];
      for (var veh in filteredVehiculos) {
        final dominioVal =
            (veh['valor']?.toString().trim() ?? '').toLowerCase();
        if (dominioVal.contains(queryVeh)) {
          temp.add(veh);
        }
      }
      setState(() {
        filteredVehiculos = temp;
      });
    }
  }

  // ==================== ESCANEAR DNI ====================
  void _mostrarEscanerQR() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              AppBar(
                backgroundColor: const Color(0xFF2a3666),
                title: const Text(
                  'Escanear DNI',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.white,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.flash_on, color: Colors.white),
                    onPressed: () => controladorCamara.toggleTorch(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.flip_camera_android,
                        color: Colors.white),
                    onPressed: () => controladorCamara.switchCamera(),
                  ),
                ],
              ),
              Expanded(
                child: MobileScanner(
                  controller: controladorCamara,
                  onDetect: (captura) {
                    final List<Barcode> codigosBarras = captura.barcodes;
                    if (codigosBarras.isNotEmpty) {
                      final String codigoLeido =
                          codigosBarras.first.rawValue ?? '';
                      Navigator.pop(context);

                      try {
                        bool isJson = false;
                        dynamic decoded;
                        try {
                          decoded = jsonDecode(codigoLeido);
                          isJson = true;
                        } catch (_) {
                          // No es JSON
                        }

                        if (isJson &&
                            decoded != null &&
                            decoded is Map<String, dynamic>) {
                          final entidad = decoded['entidad'];
                          if (entidad == 'empleado') {
                            final dni = decoded['dni'] ?? 'DNI no disponible';
                            personalIdController.text = dni;
                          }
                          setState(() {
                            qrScanned = true;
                          });
                        } else {
                          final partes = codigoLeido.split('@');
                          if (partes.length >= 5) {
                            final dniParseado = partes[4].trim();
                            if (dniParseado.isNotEmpty) {
                              personalIdController.text = dniParseado;
                              setState(() {
                                qrScanned = true;
                              });
                            }
                          }
                        }
                      } catch (_) {}
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== DROPDOWN CONTRATISTAS ====================
  List<String> _getContractorsForDropdown() {
    Set<String> contractors = {};
    for (var prov in allProveedoresListarTest) {
      final nombre = prov['nombre_razon_social']?.toString().trim() ?? '';
      if (nombre.isNotEmpty) {
        contractors.add(nombre);
      }
    }
    List<String> sorted = contractors.toList();
    sorted.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  // ==================== ACTION_RESOURCE (para saber si registrar IN/OUT) (Empleados) ====================
  Future<Map<String, dynamic>> _fetchActionResourceData(
      String idEntidad) async {
    try {
      final postData = {
        "id_entidad": idEntidad,
        "id_usuarios": hiveIdUsuarios,
        "tipo_entidad": "empleado",
      };

      print("==> ACTION_RESOURCE param: $postData");

      final response = await _makePostRequest(
        "https://www.infocontrol.tech/web/api/mobile/ingresos_egresos/action_resource",
        postData,
      );

      if ((response.statusCode ?? 0) == 200) {
        final respData = response.data ?? {};
        final data = respData['data'] ?? {};
        return data;
      } else {
        return {};
      }
    } catch (e) {
      return {};
    }
  }

  // ==================== MOSTRAR DETALLES DEL EMPLEADO ====================
  Future<void> _showEmpleadoDetailsModal(dynamic empleado) async {
    final estado = (empleado['estado']?.toString().trim() ?? '').toLowerCase();
    final bool isHabilitado = estado == 'habilitado';

    final datosString = empleado['datos']?.toString() ?? '';
    String apellidoVal = '';
    String nombreVal = '';
    String dniVal = (empleado['valor']?.toString().trim() ?? '');

    if (datosString.isNotEmpty &&
        datosString.startsWith('[') &&
        datosString.endsWith(']')) {
      try {
        List datosList = jsonDecode(datosString);
        var apellidoMap = datosList.firstWhere(
          (item) => item['id'] == "Apellido:",
          orElse: () => null,
        );
        var nombreMap = datosList.firstWhere(
          (item) => item['id'] == "Nombre:",
          orElse: () => null,
        );

        if (apellidoMap != null && apellidoMap['valor'] is String) {
          apellidoVal = (apellidoMap['valor'] as String).trim();
        }
        if (nombreMap != null && nombreMap['valor'] is String) {
          nombreVal = (nombreMap['valor'] as String).trim();
        }
      } catch (_) {}
    }

    final String displayName = (apellidoVal.isEmpty && nombreVal.isEmpty)
        ? "No disponible"
        : "$apellidoVal $nombreVal";

    final String idEntidad = empleado['id_entidad'] ?? 'NO DISPONIBLE';
    bool isInside = employeeInsideStatus[idEntidad] ?? false;
    String buttonText = isInside ? 'Marcar egreso' : 'Marcar ingreso';

    final dataResource = await _fetchActionResourceData(idEntidad);
    final String actionMessage =
        dataResource['message']?.toString().trim() ?? '';

    if (actionMessage == "REGISTRAR INGRESO") {
      buttonText = "Registrar Ingreso";
    } else if (actionMessage == "REGISTRAR EGRESO") {
      buttonText = "Registrar Egreso";
    }

    // Verificamos si hay docs faltantes
    List<String> missingDocs = [];
    if (!isHabilitado) {
      final motivoConExcepcion = dataResource["motivo_con_excepcion"];
      if (motivoConExcepcion is Map) {
        final docsFaltantes = motivoConExcepcion["docs_faltantes"];
        if (docsFaltantes is List) {
          for (var doc in docsFaltantes) {
            if (doc is Map) {
              final nombreDoc = doc["nombre"]?.toString().trim() ?? "";
              if (nombreDoc.isNotEmpty) {
                missingDocs.add(nombreDoc);
              }
            }
          }
        }
      }
    }
    final missingDocsStr = missingDocs.join(", ");

    final contratistaSeleccionado = selectedContractor ?? 'No disponible';
    bool showActionButton = isHabilitado;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              children: [
                Image.asset('assets/generic.jpg', width: 80, height: 80),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isHabilitado ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isHabilitado ? 'HABILITADO' : 'INHABILITADO',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nombre: $displayName',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dni: $dniVal',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contratista: $contratistaSeleccionado',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    if (!isHabilitado && missingDocsStr.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Documentación faltante: $missingDocsStr',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cerrar',
                style: TextStyle(fontFamily: 'Montserrat'),
              ),
            ),
            if (showActionButton)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _hacerIngresoEgresoEmpleado(empleado);
                },
                child: Text(
                  buttonText,
                  style: const TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
          ],
        );
      },
    );
  }

  // ==================== GET / POST (DIO) ====================
  // Adaptado a FormData (contentType: multipart/form-data)
  Future<Response> _makeGetRequest(String url,
      {Map<String, dynamic>? queryParameters}) async {
    return await dio.get(
      Uri.parse(url).replace(queryParameters: queryParameters).toString(),
      options: Options(
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  Future<Response> _makePostRequest(
      String url, Map<String, dynamic> data) async {
    // Convertimos el map a FormData
    final formData = FormData.fromMap(data);

    return await dio.post(
      url,
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        contentType: 'multipart/form-data', // Importante
      ),
    );
  }

  // ==================== DEMO (PRÓXIMAMENTE) ====================
  void _mostrarProximamente() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Próximamente',
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          content: const Text(
            'Esta funcionalidad estará disponible próximamente.',
            style: TextStyle(fontFamily: 'Montserrat'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'OK',
                style: TextStyle(fontFamily: 'Montserrat'),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    String botonQrText = qrScanned ? "Escanear dni nuevamente" : "Escanear dni";

    List<String> contractorItems = _getContractorsForDropdown();
    bool isContratistaHabilitado = false;
    if (selectedContractorEstado != null) {
      final estado = selectedContractorEstado!.trim().toLowerCase();
      isContratistaHabilitado = estado == 'habilitado';
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2a3666)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF2a3666)),
            onPressed: () {},
          ),
          Container(
            height: 24,
            width: 1,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
          CircleAvatar(
            backgroundColor: const Color(0xFF232e63),
            radius: 15,
            child: Text(
              widget.empresa['nombre']?[0] ?? 'E',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.arrow_drop_down, color: Color(0xFF232e63)),
          const SizedBox(width: 10),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Container(
                color: const Color(0xFFe6e6e6),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // CABECERA
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.empresa['nombre'] ?? 'Nombre no disponible',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 18,
                              color: Color(0xFF7e8e95),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Divider(color: Colors.grey[300], thickness: 1),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFe0f7fa),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "Complete alguno de los filtros para obtener resultados. Puede buscar por contratista, empleado, vehículo o maquinaria",
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // FILTROS
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filtros de Búsquedas',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 18,
                              color: Color(0xFF7e8e95),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Divider(color: Colors.grey[300], thickness: 1),
                          const SizedBox(height: 20),

                          // Dropdown Contratista
                          const Text(
                            'Contratista',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            items: contractorItems
                                .map<DropdownMenuItem<String>>(
                                    (nombreRazonSocial) {
                              return DropdownMenuItem<String>(
                                value: nombreRazonSocial,
                                child: Text(
                                  nombreRazonSocial,
                                  style:
                                      const TextStyle(fontFamily: 'Montserrat'),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            value: selectedContractor,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedContractor = value;
                                  showContractorInfo = false;
                                  showEmployees = false;
                                  showVehicles = false;
                                  selectedContractorEstado = null;
                                  empleados.clear();
                                  filteredEmpleados.clear();
                                  filteredVehiculos.clear();
                                });

                                final contractorLower =
                                    value.trim().toLowerCase();
                                var firstMatch =
                                    allProveedoresListarTest.firstWhere(
                                  (prov) => (prov['nombre_razon_social']
                                          ?.toString()
                                          .trim()
                                          .toLowerCase() ==
                                      contractorLower),
                                  orElse: () => null,
                                );

                                if (firstMatch != null) {
                                  selectedContractorCuit =
                                      firstMatch['cuit'] ?? '';
                                  selectedContractorTipo =
                                      firstMatch['tipo'] ?? '';
                                  selectedContractorMensajeGeneral =
                                      firstMatch['mensaje_general'] ?? '';
                                  selectedContractorEstado =
                                      firstMatch['estado'] ?? '';
                                  showContractorInfo = true;
                                }
                              }
                            },
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 15),
                              hintText: 'Seleccione Contratista',
                              hintStyle: const TextStyle(
                                fontFamily: 'Montserrat',
                                color: Colors.grey,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Nro. Identificación Personal
                          const Text(
                            'Número de Identificación Personal',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '(Sin puntos ni guiones)',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: personalIdController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Número de Identificación Personal',
                                    hintStyle: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      color: Colors.grey,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[200],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF43b6ed),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.search,
                                      color: Colors.white),
                                  onPressed: _buscarPersonalId,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // DOMINIO/Placa
                          const Text(
                            'Dominio/Placa/N° de Serie/N° de Chasis',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '(Sin espacios ni guiones)',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: dominioController,
                                  decoration: InputDecoration(
                                    hintText: 'DOMINIO EJ: ABC123',
                                    hintStyle: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      color: Colors.grey,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[200],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF43b6ed),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.search,
                                      color: Colors.white),
                                  onPressed: _buscarDominio,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (resultadoHabilitacion != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: resultadoHabilitacion!
                                    ? Colors.green[300]
                                    : Colors.red[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  resultadoHabilitacion!
                                      ? 'HABILITADO'
                                      : 'INHABILITADO',
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (resultadoHabilitacion! == false) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _mostrarProximamente,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[300],
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.warning,
                                          color: Colors.black54),
                                      SizedBox(width: 8),
                                      Text(
                                        'Marcar ingreso con excepción',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),

                          // Botón Escanear
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                if (qrScanned) {
                                  _reIniciarPaginaYEscanear();
                                } else {
                                  _mostrarEscanerQR();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BCD4),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.qr_code_scanner,
                                      color: Colors.white, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    botonQrText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // INFO DEL CONTRATISTA
                          if (showContractorInfo) ...[
                            const SizedBox(height: 30),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedContractor ?? 'Empresa',
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF232e5f),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isContratistaHabilitado
                                          ? Colors.green[300]
                                          : Colors.red[300],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        isContratistaHabilitado
                                            ? 'CONTRATISTA HABILITADO'
                                            : 'CONTRATISTA INHABILITADO',
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Razón Social: ${selectedContractor ?? 'No disponible'}',
                                    style: const TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      'CUIT: ${selectedContractorCuit ?? 'No disponible'}'),
                                  const Text('Tipo persona: -'),
                                  Text(
                                      'Tipo trabajador: ${selectedContractorTipo ?? 'No disponible'}'),
                                  const Text('Actividades: -'),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),

                          // BOTONES
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _filtrarEmpleadosDeContratista();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[200],
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.people, color: Colors.black54),
                                      SizedBox(width: 8),
                                      Text(
                                        'Empleados',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    showEmployees = false;
                                    if (selectedContractor == null ||
                                        selectedContractor!.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Debes elegir un contratista'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    // 1) Chequeamos conexión
                                    final connectivityResult =
                                        await connectivity.checkConnectivity();
                                    if (connectivityResult ==
                                        ConnectivityResult.none) {
                                      // MODO OFFLINE -> Cargamos de Hive
                                      _loadVehiclesFromHive();

                                      // Filtramos por el contratista seleccionado
                                      final contractorLower =
                                          selectedContractor!
                                              .trim()
                                              .toLowerCase();
                                      List<dynamic> filtradosVehiculos =
                                          allVehiculosListarTest.where((veh) {
                                        final nombreRazSoc =
                                            (veh['nombre_razon_social'] ?? '')
                                                .toString()
                                                .trim()
                                                .toLowerCase();
                                        return nombreRazSoc == contractorLower;
                                      }).toList();

                                      setState(() {
                                        filteredVehiculos = filtradosVehiculos;
                                        showVehicles = true;
                                      });
                                      return; // Salimos
                                    }

                                    // 2) Si HAY conexión, hacemos la petición
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (ctx) => Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              CircularProgressIndicator(),
                                              SizedBox(width: 16),
                                              Text(
                                                'Cargando...',
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontSize: 16,
                                                  color: Colors.black,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );

                                    try {
                                      final response = await _makeGetRequest(
                                        "https://www.infocontrol.tech/web/api/mobile/vehiculos/listartest",
                                        queryParameters: {
                                          'id_empresas': widget.empresaId
                                        },
                                      );
                                      Navigator.pop(context);

                                      if ((response.statusCode ?? 0) == 200) {
                                        final responseData = response.data;
                                        List<dynamic> vehiculosData =
                                            responseData['data'] ?? [];

                                        // GUARDAMOS EN HIVE:
                                        allVehiculosListarTest = vehiculosData;
                                        vehiclesBox?.put(
                                            'all_vehicles', vehiculosData);

                                        final contractorLower =
                                            selectedContractor!
                                                .trim()
                                                .toLowerCase();
                                        List<dynamic> filtradosVehiculos =
                                            vehiculosData.where((veh) {
                                          final nombreRazSoc =
                                              (veh['nombre_razon_social'] ?? '')
                                                  .toString()
                                                  .trim()
                                                  .toLowerCase();
                                          return nombreRazSoc ==
                                              contractorLower;
                                        }).toList();

                                        setState(() {
                                          filteredVehiculos =
                                              filtradosVehiculos;
                                          showVehicles = true;
                                        });
                                      } else {
                                        print(
                                            "Error al traer vehiculos: codigo ${response.statusCode}");
                                      }
                                    } catch (e) {
                                      Navigator.pop(context);
                                      print("Error: $e");
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[200],
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.directions_car,
                                          color: Colors.black54),
                                      SizedBox(width: 8),
                                      Text(
                                        'Vehículos',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // IMPRIMIR
                          Center(
                            child: ElevatedButton(
                              onPressed: _mostrarProximamente,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.print, color: Colors.black54),
                                  SizedBox(width: 8),
                                  Text(
                                    'Imprimir',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // LISTA DE EMPLEADOS
                          if (showEmployees) ...[
                            const SizedBox(height: 30),
                            TextField(
                              controller: searchController,
                              decoration: InputDecoration(
                                hintText:
                                    'Buscar por Dni, Apellido, Cuit o Cuil',
                                hintStyle: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  color: Colors.grey,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.grey),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.blue),
                                ),
                                prefixIcon: const Icon(Icons.search,
                                    color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (filteredEmpleados.isNotEmpty) ...[
                              for (var empleado in filteredEmpleados)
                                Builder(builder: (context) {
                                  final datosString =
                                      empleado['datos']?.toString() ?? '';
                                  String displayName = 'No disponible';
                                  String apellidoVal = '';
                                  String nombreVal = '';
                                  String dniVal =
                                      (empleado['valor']?.toString().trim() ??
                                          '');

                                  if (datosString.isNotEmpty &&
                                      datosString.startsWith('[') &&
                                      datosString.endsWith(']')) {
                                    try {
                                      List datosList = jsonDecode(datosString);
                                      var apellidoMap = datosList.firstWhere(
                                        (item) => item['id'] == "Apellido:",
                                        orElse: () => null,
                                      );
                                      var nombreMap = datosList.firstWhere(
                                        (item) => item['id'] == "Nombre:",
                                        orElse: () => null,
                                      );

                                      if (apellidoMap != null &&
                                          apellidoMap['valor'] is String) {
                                        apellidoVal =
                                            (apellidoMap['valor'] as String)
                                                .trim();
                                      }
                                      if (nombreMap != null &&
                                          nombreMap['valor'] is String) {
                                        nombreVal =
                                            (nombreMap['valor'] as String)
                                                .trim();
                                      }

                                      if (apellidoVal.isEmpty &&
                                          nombreVal.isEmpty) {
                                        displayName = "No disponible";
                                      } else {
                                        displayName =
                                            "$apellidoVal $nombreVal - $dniVal"
                                                .trim();
                                      }
                                    } catch (_) {
                                      displayName = "No disponible";
                                    }
                                  }

                                  String estado =
                                      (empleado['estado']?.toString().trim() ??
                                              '')
                                          .toLowerCase();
                                  Color textColor = estado == 'habilitado'
                                      ? Colors.green
                                      : Colors.red;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayName,
                                            style: TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontSize: 16,
                                              color: textColor,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              _showEmpleadoDetailsModal(
                                                  empleado),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF43b6ed),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            minimumSize: const Size(60, 30),
                                          ),
                                          child: const Text(
                                            'Consultar',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                            ] else ...[
                              const Text(
                                'No hay empleados.',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 16,
                                  color: Colors.black,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ]
                          ],

                          // LISTA DE VEHICULOS
                          if (showVehicles) ...[
                            const SizedBox(height: 30),
                            TextField(
                              controller: searchControllerVeh,
                              decoration: InputDecoration(
                                hintText: 'Buscar por dominio...',
                                hintStyle: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  color: Colors.grey,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.grey),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.grey),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: Colors.blue),
                                ),
                                prefixIcon: const Icon(Icons.search,
                                    color: Colors.grey),
                              ),
                              onChanged: (value) {
                                _filterVehicles();
                              },
                            ),
                            const SizedBox(height: 20),
                            if (filteredVehiculos.isNotEmpty) ...[
                              for (var veh in filteredVehiculos)
                                Builder(builder: (context) {
                                  final dominioVeh =
                                      (veh['valor']?.toString().trim() ?? '')
                                          .toUpperCase();
                                  final estadoVeh =
                                      (veh['estado']?.toString().trim() ?? '')
                                          .toLowerCase();

                                  final bool isHabilitado =
                                      (estadoVeh == 'habilitado');
                                  final Color textColorVeh =
                                      isHabilitado ? Colors.green : Colors.red;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            dominioVeh,
                                            style: TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontSize: 16,
                                              color: textColorVeh,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              _showVehiculoDetailsModal(veh),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF43b6ed),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            minimumSize: const Size(60, 30),
                                          ),
                                          child: const Text(
                                            'Consultar',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                            ] else ...[
                              const Text(
                                'No hay vehículos.',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 16,
                                  color: Colors.black,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ]
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // LOGO
                    Center(
                      child: Image.asset(
                        'assets/infocontrol_logo.png',
                        width: 150,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
