import 'dart:async'; // <-- IMPORTANTE para Timer y StreamSubscription
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'hive_helper.dart';
// IMPORTAMOS LA PANTALLA DE LOGIN PARA FORZAR REAUTENTICACIÓN
import 'login_screen.dart';

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

class _LupaEmpresaScreenState extends State<LupaEmpresaScreen> with WidgetsBindingObserver {
  String? selectedContractor;
  String? selectedContractorCuit;
  String? selectedContractorTipo;
  String? selectedContractorMensajeGeneral;
  String? selectedContractorEstado;
  bool showContractorInfo = false;
  bool showEmployees = false;

  // Lista general de empleados que obtenemos de "listartest" (UNA SOLA VEZ al abrir la pantalla o al reanudar).
  List<dynamic> allEmpleadosListarTest = [];

  // Lista que se mostrará al filtrar por contratista
  List<dynamic> empleados = [];
  List<dynamic> filteredEmpleados = [];

  bool isLoading = true;

  final MobileScannerController controladorCamara = MobileScannerController();
  final TextEditingController personalIdController = TextEditingController();
  final TextEditingController dominioController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  bool qrScanned = false;
  bool? resultadoHabilitacion;

  late Dio dio;
  late CookieJar cookieJar;
  late Connectivity connectivity;
  late StreamSubscription<ConnectivityResult> connectivitySubscription;

  String hiveIdUsuarios = '';

  // Mapa para almacenar si un empleado está actualmente dentro (true) o fuera (false).
  Map<String, bool> employeeInsideStatus = {};

  // El token actual (viene desde HomeScreen) pero se puede refrescar aquí
  late String bearerToken;

  // Timer para refrescar token en LupaEmpresa
  Timer? _refreshTimerLupa;

  @override
  void initState() {
    super.initState();

    // -------- OBSERVADOR DEL CICLO DE VIDA (para detectar cuando se bloquea/desbloquea el dispositivo) --------
    WidgetsBinding.instance.addObserver(this);

    // Asignamos el token que llega como parámetro
    bearerToken = widget.bearerToken;

    cookieJar = CookieJar();
    dio = Dio();
    dio.interceptors.add(CookieManager(cookieJar));

    connectivity = Connectivity();
    connectivitySubscription = connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        _processPendingRequests();
      }
    });

    hiveIdUsuarios = HiveHelper.getIdUsuarios();

    // Iniciamos un timer local para refrescar el token desde LupaEmpresa
    _startTokenRefreshTimerLupa();

    // Escuchamos cambios en el campo de búsqueda (para filtrar empleados)
    searchController.addListener(_filterEmployees);

    // 1) AL ABRIR LA PANTALLA: Traemos TODOS los empleados con 'listartest' (si hay conexión)
    //    y los almacenamos en allEmpleadosListarTest. Si NO hay conexión, se usan los datos locales.
    _fetchAllEmployeesListarTest().then((_) {
      if (widget.openScannerOnInit) {
        _mostrarEscanerQR();
      }
    });
  }

  // -------- DETECTAR CUANDO LA APP SE REANUDA (RESUMED), p.ej. tras desbloquear el dispositivo --------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Cuando el usuario vuelve a la app (ej: desbloquear el dispositivo):
    if (state == AppLifecycleState.resumed) {
      // Mostramos "Cargando..." nuevamente y volvemos a hacer la misma lógica,
      // pero SOLO si hay conexión. Si NO hay conexión, solo usamos datos locales.
      setState(() {
        isLoading = true;
      });
      _fetchAllEmployeesListarTest().then((_) {
        setState(() {
          isLoading = false;
        });
      });
    }
  }

  @override
  void dispose() {
    controladorCamara.dispose();
    personalIdController.dispose();
    dominioController.dispose();
    searchController.dispose();
    connectivitySubscription.cancel();

    // Quitamos el observador del ciclo de vida
    WidgetsBinding.instance.removeObserver(this);

    // Cancelamos también el timer local
    _refreshTimerLupa?.cancel();

    super.dispose();
  }

  // Inicia el Timer local para refrescar el token cada 4min 10s
  void _startTokenRefreshTimerLupa() {
    _refreshTimerLupa?.cancel();
    _refreshTimerLupa = Timer.periodic(
      const Duration(minutes: 4, seconds: 10),
      (_) => _refreshBearerTokenLupa(),
    );
  }

  // Refresca el token usando username y password, en LupaEmpresa
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
            'Authorization': 'Basic ${base64Encode(utf8.encode('${widget.username}:${widget.password}'))}',
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
          bearerToken = newToken; // actualizamos el token local
        });

        // Guardamos también en Hive, si quieres mantener todo sincronizado:
        HiveHelper.storeBearerToken(newToken);

        print('Token refrescado correctamente en LupaEmpresa: $newToken');
      } else {
        throw Exception('Recargando...');
      }
    } catch (e) {
      print('Recargando...');
      // Podrías mostrar un snackbar si prefieres
    }
  }

  // Carga todos los empleados de "listartest" (si hay conexión) y los guarda en allEmpleadosListarTest.
  // Si NO hay conexión, solo usa lo que esté guardado localmente (Hive).
  Future<void> _fetchAllEmployeesListarTest() async {
    setState(() {
      isLoading = true;
    });

    final connectivityResult = await connectivity.checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      // Modo offline:
      List<dynamic> empleadosLocales = HiveHelper.getEmpleados(widget.empresaId);
      if (empleadosLocales.isNotEmpty) {
        allEmpleadosListarTest = empleadosLocales;
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
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Si hay conexión, hacemos la solicitud
    try {
      final response = await _makeGetRequest(
        "https://www.infocontrol.tech/web/api/mobile/empleados/listartest",
        queryParameters: {'id_empresas': widget.empresaId},
      );
      final statusCode = response.statusCode ?? 0;

      if (statusCode == 200) {
        final responseData = response.data;
        List<dynamic> employeesData = responseData['data'] ?? [];

        // Guardamos en "allEmpleadosListarTest"
        allEmpleadosListarTest = employeesData;

        // Guardamos offline en Hive (reutilizamos insertEmpleados)
        HiveHelper.insertEmpleados(widget.empresaId, employeesData);

        setState(() {
          isLoading = false;
        });
      } else {
        // EN LUGAR DE MOSTRAR SNACKBAR, FORZAR REAUTENTICACIÓN
        setState(() {
          isLoading = false;
        });
        if (!mounted) return;
        // Navegamos a LoginScreen
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
        // Token inválido => forzar reautenticación
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      } else {
        // Error distinto => también forzar reautenticación para simplificar
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
      // Error inesperado => forzar reautenticación
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    }
  }

  // Este método se llama al hacer clic en "Empleados" (con un contratista seleccionado).
  // AHORA ya NO hace ninguna solicitud extra, sino que filtra localmente "allEmpleadosListarTest".
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

    // Filtramos localmente
    List<dynamic> filtrados = allEmpleadosListarTest.where((emp) {
      final nombreRazonSocial = emp['nombre_razon_social']?.toString().trim().toLowerCase() ?? '';
      return nombreRazonSocial == contractorLower;
    }).toList();

    // Asignamos a empleados y filteredEmpleados
    setState(() {
      empleados = filtrados;
      filteredEmpleados = filtrados;
      showEmployees = true;
    });
  }

  // LOGICA DE PROCESOS OFFLINE
  Future<void> _saveOfflineRequest(String dniIngresado) async {
    final Map<String, dynamic> pendingData = {
      "dni": dniIngresado,
      "id_empresas": widget.empresaId,
      "id_usuarios": hiveIdUsuarios,
      "timestamp": DateTime.now().toIso8601String(),
    };
    HiveHelper.savePendingDNIRequest(pendingData);
  }

  // Cuando detectamos que hay conexión nuevamente, procesamos los requests pendientes.
  Future<void> _processPendingRequests() async {
    final List<Map<String, dynamic>> pendingRequests = HiveHelper.getAllPendingDNIRequests();
    if (pendingRequests.isEmpty) return;

    for (var requestData in pendingRequests) {
      final String dniIngresado = requestData["dni"] ?? '';
      final String idEmpresas = requestData["id_empresas"] ?? '';
      final String idUsuarios = requestData["id_usuarios"] ?? '';

      if (dniIngresado.isEmpty) continue;

      try {
        // Primero hacemos GET para buscar empleado
        final response = await _makeGetRequest(
          "https://www.infocontrol.tech/web/api/mobile/empleados/listartest",
          queryParameters: {'id_empresas': idEmpresas},
        );

        final statusCode = response.statusCode ?? 0;
        if (statusCode == 200) {
          final responseData = response.data;
          List<dynamic> employeesData = responseData['data'] ?? [];

          // Acá también comparamos con valor / cuit / cuil, por si en offline
          final foundEmployee = employeesData.firstWhere((emp) {
            final val = emp['valor']?.toString().trim() ?? '';
            final cuit = emp['cuit']?.toString().trim() ?? '';
            final cuil = emp['cuil']?.toString().trim() ?? '';
            return (val == dniIngresado || cuit == dniIngresado || cuil == dniIngresado);
          }, orElse: () => null);

          if (foundEmployee != null) {
            final String idEntidad = foundEmployee['id_entidad'] ?? 'NO DISPONIBLE';
            final String estado = foundEmployee['estado']?.toString().trim() ?? '';
            if (estado.toLowerCase() == 'inhabilitado') {
              continue; // No se hace nada
            }

            final Map<String, dynamic> postData = {
              'id_empresas': idEmpresas,
              'id_usuarios': idUsuarios,
              'id_entidad': idEntidad,
            };

            final postResponse = await _makePostRequest(
              "https://www.infocontrol.tech/web/api/mobile/Ingresos_egresos/register_movement",
              postData,
            );

            if ((postResponse.statusCode ?? 0) == 200) {
              HiveHelper.removePendingDNIRequest(requestData);
            }
          }
        }
      } catch (e) {
        // Error procesando pendiente offline, continuamos con la siguiente
      }
    }
  }

  Future<void> _hacerIngresoEgresoEmpleado(dynamic empleado) async {
    final estado = (empleado['estado']?.toString().trim() ?? '').toLowerCase();
    if (estado == 'inhabilitado') {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Empleado Inhabilitado'),
            content: const Text('No se puede hacer el ingreso o egreso para este empleado.'),
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

    // En la API, "valor" es el DNI. Pero también podría ser cuit/cuil. Tomamos "valor" como DNI si existe
    final dniVal = (empleado['valor']?.toString().trim() ?? '');
    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      // Sin conexión, lo guardamos en pendientes
      // (Para offline, guardamos lo que esté en "valor", si fuera cuit/cuil
      //  no lo tendríamos en "valor", así que en offline no se registrarían. 
      //  Se asume "valor" es DNI en la DB. Si quisieras guardarlo igual, 
      //  deberías usar la misma lógica que `_processPendingRequests`.)
      await _saveOfflineRequest(dniVal);
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Modo offline'),
            content: const Text('Se guardó para registrar cuando vuelva la conexión.'),
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

  // AHORA también busca por cuit o cuil, además de valor (dni).
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
      // offline
      await _saveOfflineRequest(texto);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Modo offline'),
            content: const Text('Se guardó para registrar cuando vuelva la conexión.'),
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

    // Mostrar "Cargando..."
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

        // CAMBIO PRINCIPAL: Comparar contra valor (DNI), cuit y cuil
        final foundEmployee = employeesData.firstWhere((emp) {
          final val = emp['valor']?.toString().trim() ?? '';
          final cuit = emp['cuit']?.toString().trim() ?? '';
          final cuil = emp['cuil']?.toString().trim() ?? '';
          return (val == dniIngresado || cuit == dniIngresado || cuil == dniIngresado);
        }, orElse: () => null);

        if (foundEmployee != null) {
          _showEmpleadoDetailsModal(foundEmployee);
        } else {
          showDialog(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('No encontrado'),
                content: const Text('No se encontró el DNI/CUIT/CUIL en la respuesta.'),
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
          const SnackBar(content: Text('Token inválido. Vuelva a HomeScreen para recargar.')),
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
    } catch (e) {
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

  Future<void> _registerMovement(String idEntidad) async {
    // Mostrar "Cargando..."
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

      final postResponse = await _makePostRequest(
        "https://www.infocontrol.tech/web/api/mobile/Ingresos_egresos/register_movement",
        postData,
      );

      Navigator.pop(context);

      final int statusCode = postResponse.statusCode ?? 0;
      final dynamic fullResponse = postResponse.data;

      if (statusCode == 200) {
        final dynamic dataObject = fullResponse['data'] ?? {};
        final String messageToShow = dataObject['message'] ?? 'Mensaje no disponible';

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
        // Token inválido en POST
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token inválido en POST. Vuelva a HomeScreen para recargar.')),
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

  void _reIniciarPaginaYEscanear() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LupaEmpresaScreen(
          empresa: widget.empresa,
          bearerToken: bearerToken, // token actualizado
          idEmpresaAsociada: widget.idEmpresaAsociada,
          empresaId: widget.empresaId,
          username: widget.username,
          password: widget.password,
          openScannerOnInit: true,
        ),
      ),
    );
  }

  Future<void> _buscarDominio() async {
    final texto = dominioController.text.trim();
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

    // Verificamos conexión. Si no hay, NO hacemos la solicitud.
    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Modo offline'),
            content: const Text('No hay conexión para solicitar datos del dominio.'),
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

    // Mostrar "Cargando..."
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
    } on DioException catch (e) {
      Navigator.pop(context);
      if (e.response?.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token inválido en GET. Vuelva a HomeScreen para recargar.')),
        );
      } else {
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
    } catch (e) {
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

  // Filtramos por DNI, Apellido, CUIT o CUIL en la lista "empleados" (la que se obtiene al pulsar "Empleados")
  void _filterEmployees() {
    String query = searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        filteredEmpleados = List.from(empleados);
      });
    } else {
      List<dynamic> temp = [];
      for (var emp in empleados) {
        // Tomamos el dni
        final dniVal = (emp['valor']?.toString().trim() ?? '').toLowerCase();
        // Tomamos cuit y cuil
        final cuitVal = (emp['cuit']?.toString().trim() ?? '').toLowerCase();
        final cuilVal = (emp['cuil']?.toString().trim() ?? '').toLowerCase();

        // Tomamos el apellido (si está en "datos")
        final datosString = emp['datos']?.toString() ?? '';
        String apellidoVal = '';
        if (datosString.isNotEmpty && datosString.startsWith('[') && datosString.endsWith(']')) {
          try {
            List datosList = jsonDecode(datosString);
            var apellidoMap = datosList.firstWhere(
              (item) => item['id'] == "Apellido:",
              orElse: () => null,
            );
            if (apellidoMap != null && apellidoMap['valor'] is String) {
              apellidoVal = (apellidoMap['valor'] as String).toLowerCase().trim();
            }
          } catch (_) {}
        }

        // Si coincide el DNI, el apellido, el CUIT o el CUIL
        if (dniVal.contains(query) || apellidoVal.contains(query) || cuitVal.contains(query) || cuilVal.contains(query)) {
          temp.add(emp);
        }
      }
      setState(() {
        filteredEmpleados = temp;
      });
    }
  }

  // Escanear DNI
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
                    icon: const Icon(Icons.flip_camera_android, color: Colors.white),
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
                      final String codigoLeido = codigosBarras.first.rawValue ?? '';
                      Navigator.pop(context);

                      try {
                        // Intentamos JSON. Si falla, asumimos PDF417/otro.
                        bool isJson = false;
                        dynamic decoded;
                        try {
                          decoded = jsonDecode(codigoLeido);
                          isJson = true;
                        } catch (_) {
                          // No es JSON
                        }

                        if (isJson && decoded != null && decoded is Map<String, dynamic>) {
                          // Lógica anterior de QR JSON
                          final entidad = decoded['entidad'];
                          if (entidad == 'empleado') {
                            final dni = decoded['dni'] ?? 'DNI no disponible';
                            personalIdController.text = dni;
                          } else if (entidad == 'vehiculo') {
                            final dominio = decoded['dominio'] ?? 'Dominio no disponible';
                            dominioController.text = dominio;
                          }
                          setState(() {
                            qrScanned = true;
                          });
                        } else {
                          // Lógica para PDF417 del DNI
                          // Ejemplo: "00123456789@APELLIDO@NOMBRE@F@12345678@A@01/01/2006@31/12/2025"
                          final partes = codigoLeido.split('@');
                          // Se asume que el 5to elemento (índice 4) sería el DNI. 
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
                      } catch (_) {
                        // Error parseando
                      }
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

  List<String> _getContractorsForDropdown() {
    // A partir de la lista general (allEmpleadosListarTest), extraemos
    // todos los "nombre_razon_social" únicos, para el Dropdown
    Set<String> contractors = {};
    for (var emp in allEmpleadosListarTest) {
      final nombre = emp['nombre_razon_social']?.toString().trim() ?? '';
      if (nombre.isNotEmpty) {
        contractors.add(nombre);
      }
    }
    List<String> sorted = contractors.toList();
    sorted.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  // Para action_resource (ingreso/egreso)
  Future<String> _fetchActionResource(String idEntidad) async {
    try {
      final postData = {"id_entidad": idEntidad};
      final response = await _makePostRequest(
        "https://www.infocontrol.tech/web/api/mobile/ingresos_egresos/action_resource",
        postData,
      );

      if ((response.statusCode ?? 0) == 200) {
        final respData = response.data ?? {};
        final data = respData['data'] ?? {};
        final message = data['message'] ?? '';
        return message;
      } else {
        return '';
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _showEmpleadoDetailsModal(dynamic empleado) async {
    final estado = (empleado['estado']?.toString().trim() ?? '').toLowerCase();
    final bool isHabilitado = estado == 'habilitado';
    final bool contractorIsHabilitado = selectedContractorEstado?.trim().toLowerCase() == 'habilitado';

    final datosString = empleado['datos']?.toString() ?? '';
    String apellidoVal = '';
    String nombreVal = '';
    String dniVal = (empleado['valor']?.toString().trim() ?? '');

    if (datosString.isNotEmpty && datosString.startsWith('[') && datosString.endsWith(']')) {
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

        apellidoVal = (apellidoMap != null && apellidoMap['valor'] is String)
            ? (apellidoMap['valor'] as String).trim()
            : '';
        nombreVal = (nombreMap != null && nombreMap['valor'] is String)
            ? (nombreMap['valor'] as String).trim()
            : '';
      } catch (_) {}
    }

    final displayName = (apellidoVal.isEmpty && nombreVal.isEmpty)
        ? "No disponible"
        : "$apellidoVal $nombreVal";

    final contratistaSeleccionado = selectedContractor ?? 'No disponible';
    final String idEntidad = empleado['id_entidad'] ?? 'NO DISPONIBLE';
    bool isInside = employeeInsideStatus[idEntidad] ?? false;

    String buttonText = isInside ? 'Marcar egreso' : 'Marcar ingreso';

    if (isHabilitado && contractorIsHabilitado) {
      final actionMessage = await _fetchActionResource(idEntidad);
      if (actionMessage == "REGISTRAR INGRESO") {
        buttonText = "Registrar Ingreso";
      } else if (actionMessage == "REGISTRAR EGRESO") {
        buttonText = "Registrar Egreso";
      }
    }

    bool showActionButton = false;
    if (isHabilitado && contractorIsHabilitado) {
      showActionButton = true;
    }

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
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar', style: TextStyle(fontFamily: 'Montserrat')),
            ),
            if (showActionButton)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _hacerIngresoEgresoEmpleado(empleado);
                },
                child: Text(buttonText, style: const TextStyle(fontFamily: 'Montserrat')),
              ),
          ],
        );
      },
    );
  }

  // GET/POST con bearerToken actual
  Future<Response> _makeGetRequest(String url, {Map<String, dynamic>? queryParameters}) async {
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

  Future<Response> _makePostRequest(String url, Map<String, dynamic> data) async {
    return await dio.post(
      url,
      data: jsonEncode(data),
      options: Options(
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  void _mostrarProximamente() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Próximamente', style: TextStyle(fontFamily: 'Montserrat')),
          content: const Text('Esta funcionalidad estará disponible próximamente.', style: TextStyle(fontFamily: 'Montserrat')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(fontFamily: 'Montserrat')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cambiamos el texto del botón a "Escanear dni"
    String botonQrText = qrScanned ? "Escanear dni nuevamente" : "Escanear dni";

    // Contratistas para el Dropdown, a partir de la lista general (allEmpleadosListarTest)
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
                            items: contractorItems.map<DropdownMenuItem<String>>((nombreRazonSocial) {
                              return DropdownMenuItem<String>(
                                value: nombreRazonSocial,
                                child: Text(
                                  nombreRazonSocial,
                                  style: const TextStyle(fontFamily: 'Montserrat'),
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
                                  selectedContractorEstado = null;
                                  empleados.clear();
                                  filteredEmpleados.clear();
                                });

                                // Actualizamos info extra (cuit, estado, etc.)
                                final contractorLower = value.trim().toLowerCase();
                                var firstMatch = allEmpleadosListarTest.firstWhere(
                                  (emp) =>
                                      (emp['nombre_razon_social']?.toString().trim().toLowerCase() ==
                                       contractorLower),
                                  orElse: () => null,
                                );

                                if (firstMatch != null) {
                                  selectedContractorCuit = firstMatch['cuit'] ?? '';
                                  selectedContractorTipo = firstMatch['tipo'] ?? '';
                                  selectedContractorMensajeGeneral = firstMatch['mensaje_general'] ?? '';
                                  selectedContractorEstado = firstMatch['estado'] ?? '';
                                  showContractorInfo = true;
                                }
                              }
                            },
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
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

                          // Nro. de Identificación
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
                                    hintText: 'Número de Identificación Personal',
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
                                  icon: const Icon(Icons.search, color: Colors.white),
                                  onPressed: _buscarPersonalId,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Dominio
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
                                  icon: const Icon(Icons.search, color: Colors.white),
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
                                color: resultadoHabilitacion! ? Colors.green[300] : Colors.red[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  resultadoHabilitacion! ? 'HABILITADO' : 'INHABILITADO',
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
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.warning, color: Colors.black54),
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

                          // Botón "Escanear dni"
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
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
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

                          // INFORMACIÓN DEL CONTRATISTA
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
                                      color: isContratistaHabilitado ? Colors.green[300] : Colors.red[300],
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
                                  Text('CUIT: ${selectedContractorCuit ?? 'No disponible'}'),
                                  const Text('Tipo persona: -'),
                                  Text('Tipo trabajador: ${selectedContractorTipo ?? 'No disponible'}'),
                                  const Text('Actividades: -'),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),

                          // BOTONES DE EMPLEADOS Y VEHICULOS
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _filtrarEmpleadosDeContratista,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[200],
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                                  onPressed: _mostrarProximamente,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[200],
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.directions_car, color: Colors.black54),
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

                          // BOTÓN IMPRIMIR
                          Center(
                            child: ElevatedButton(
                              onPressed: _mostrarProximamente,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

                          // LISTA DE EMPLEADOS (cuando showEmployees = true)
                          if (showEmployees) ...[
                            const SizedBox(height: 30),
                            TextField(
                              controller: searchController,
                              decoration: InputDecoration(
                                hintText: 'Buscar por Dni, Apellido, Cuit o Cuil',
                                hintStyle: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  color: Colors.grey,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.blue, width: 1),
                                ),
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (filteredEmpleados.isNotEmpty) ...[
                              for (var empleado in filteredEmpleados)
                                Builder(builder: (context) {
                                  final datosString = empleado['datos']?.toString() ?? '';
                                  String displayName = 'No disponible';
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

                                      if (apellidoVal.isEmpty && nombreVal.isEmpty) {
                                        displayName = "No disponible";
                                      } else {
                                        displayName = "$apellidoVal $nombreVal - $dniVal".trim();
                                      }
                                    } catch (_) {
                                      displayName = "No disponible";
                                    }
                                  }

                                  String estado = (empleado['estado']?.toString().trim() ?? '').toLowerCase();
                                  Color textColor = estado == 'habilitado' ? Colors.green : Colors.red;

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
                                          onPressed: () => _showEmpleadoDetailsModal(empleado),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF43b6ed),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            minimumSize: const Size(60, 30),
                                          ),
                                          child: const Text(
                                            'Consultar',
                                            style: TextStyle(color: Colors.white, fontSize: 12),
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
                          ]
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
