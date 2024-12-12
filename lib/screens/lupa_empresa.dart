import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'hive_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class LupaEmpresaScreen extends StatefulWidget {
  final Map<String, dynamic> empresa;
  final String bearerToken;
  final String idEmpresaAsociada;
  final String empresaId;
  final bool openScannerOnInit;

  LupaEmpresaScreen({
    required this.empresa,
    required this.bearerToken,
    required this.idEmpresaAsociada,
    required this.empresaId,
    this.openScannerOnInit = false,
  });

  @override
  _LupaEmpresaScreenState createState() => _LupaEmpresaScreenState();
}

class _LupaEmpresaScreenState extends State<LupaEmpresaScreen> {
  String? selectedContractor;
  String? selectedContractorCuit;
  String? selectedContractorTipo;
  String? selectedContractorMensajeGeneral;
  bool showContractorInfo = false;
  bool showEmployees = false;
  List<dynamic> empleados = [];
  bool isLoading = true;
  bool isLoadingContractors = false;
  final MobileScannerController controladorCamara = MobileScannerController();

  final TextEditingController personalIdController = TextEditingController();
  final TextEditingController dominioController = TextEditingController();

  bool qrScanned = false; 
  bool? resultadoHabilitacion; 

  late Dio dio;
  late CookieJar cookieJar;

  @override
  void initState() {
    super.initState();

    cookieJar = CookieJar();
    dio = Dio();
    dio.interceptors.add(CookieManager(cookieJar));

    obtenerEmpleados().then((_) {
      if (widget.openScannerOnInit) {
        _mostrarEscanerQR();
      }
    });
  }

  @override
  void dispose() {
    controladorCamara.dispose();
    personalIdController.dispose();
    dominioController.dispose();
    super.dispose();
  }

  void _mostrarEscanerQR() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              AppBar(
                backgroundColor: const Color(0xFF2a3666),
                title: const Text(
                  'Escanear QR',
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
                      final String codigo = codigosBarras.first.rawValue ?? '';
                      Navigator.pop(context);

                      try {
                        final qrData = jsonDecode(codigo);
                        final entidad = qrData['entidad'];

                        if (entidad == 'empleado') {
                          final dni = qrData['dni'] ?? 'DNI no disponible';
                          personalIdController.text = dni;
                        } else if (entidad == 'vehiculo') {
                          final dominio = qrData['dominio'] ?? 'Dominio no disponible';
                          dominioController.text = dominio;
                        }
                        setState(() {
                          qrScanned = true;
                        });
                      } catch (e) {
                        // no hacer nada si falla el parseo
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

  Future<void> obtenerEmpleados() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      List<dynamic>? empleadosLocales = HiveHelper.getEmpleados(widget.empresaId);
      if (empleadosLocales != null && empleadosLocales.isNotEmpty) {
        setState(() {
          empleados = empleadosLocales;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay datos locales disponibles para empleados.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      try {
        final url = Uri.parse(
          'https://www.infocontrol.tech/web/api/mobile/proveedores/listar',
        ).replace(queryParameters: {
          'id_empresas': widget.idEmpresaAsociada,
        });

        final response = await dio.get(
          url.toString(),
          options: Options(
            headers: {
              'Authorization': 'Bearer ${widget.bearerToken}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

        if (response.statusCode == 200) {
          final responseData = response.data;
          setState(() {
            empleados = responseData['data'] ?? [];
            isLoading = false;
          });
          await HiveHelper.insertEmpleados(widget.empresaId, empleados);
        } else {
          setState(() {
            isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al obtener empleados: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } on DioException catch (e) {
        setState(() {
          isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en la solicitud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en la solicitud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void updateSelectedContractor(String nombreRazonSocial) {
    var empleadoSeleccionado = empleados.firstWhere(
      (empleado) => empleado['nombre_razon_social'] == nombreRazonSocial,
      orElse: () => null,
    );

    if (!mounted) return;
    setState(() {
      selectedContractor = nombreRazonSocial;
      selectedContractorCuit = empleadoSeleccionado != null ? empleadoSeleccionado['cuit'] : '';
      selectedContractorTipo = empleadoSeleccionado != null ? empleadoSeleccionado['tipo'] : '';
      selectedContractorMensajeGeneral = empleadoSeleccionado != null ? empleadoSeleccionado['mensaje_general'] : '';
      showContractorInfo = true;
    });
  }

  void _reIniciarPaginaYEscanear() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LupaEmpresaScreen(
          empresa: widget.empresa,
          bearerToken: widget.bearerToken,
          idEmpresaAsociada: widget.idEmpresaAsociada,
          empresaId: widget.empresaId,
          openScannerOnInit: true,
        ),
      ),
    );
  }

  void _buscarPersonalId() {
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

    if (!mounted) return;
    setState(() {
      resultadoHabilitacion = Random().nextBool();
    });
  }

  void _buscarDominio() {
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

    if (!mounted) return;
    setState(() {
      resultadoHabilitacion = Random().nextBool();
    });
  }

  void _mostrarProximamente() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Próximamente', style: TextStyle(fontFamily: 'Montserrat')),
          content: const Text('Esta funcionalidad estará disponible próximamente.', style: TextStyle(fontFamily: 'Montserrat')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); 
              },
              child: const Text('OK', style: TextStyle(fontFamily: 'Montserrat')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchEmpleadosAPI() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Sin conexión'),
              content: Text('No hay conexión a internet para solicitar datos.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }

      final url = Uri.parse("https://www.infocontrol.tech/web/api/mobile/empleados/listartest")
          .replace(queryParameters: {
        'id_empresas': widget.empresaId,
      });

      final response = await dio.get(
        url.toString(),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${widget.bearerToken}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final statusCode = response.statusCode;

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Código de respuesta'),
            content: Text('El código de respuesta es: $statusCode'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } on DioException catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Error de solicitud: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Error inesperado'),
            content: Text('Ocurrió un error: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String botonQrText = qrScanned ? "Ingresar con otro QR" : "Ingreso con QR";

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
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
            const Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF232e63),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Container(
                color: const Color(0xFFe6e6e6),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
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
                          const Text(
                            'Contratista',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          isLoadingContractors
                              ? const Center(child: CircularProgressIndicator())
                              : DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  items: empleados
                                      .map((e) => e['nombre_razon_social']?.toString() ?? '')
                                      .toSet()
                                      .map<DropdownMenuItem<String>>((nombreRazonSocial) {
                                    return DropdownMenuItem<String>(
                                      value: nombreRazonSocial,
                                      child: Text(
                                        nombreRazonSocial,
                                        style: const TextStyle(
                                          fontFamily: 'Montserrat',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    );
                                  }).toList(),
                                  value: selectedContractor,
                                  onChanged: (value) {
                                    if (value != null) {
                                      updateSelectedContractor(value);
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
                          const Text(
                            'Número de Identificación Personal',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize:16,
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
                          const Text(
                            'Dominio/Placa/N° de Serie/N° de Chasis',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize:16,
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
                                  onPressed: () {
                                    _mostrarProximamente();
                                  },
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
                                  const Icon(
                                    Icons.qr_code_scanner,
                                    color: Colors.white,
                                    size: 24,
                                  ),
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
                                      color: selectedContractorMensajeGeneral?.toLowerCase().contains('inhabilitado') == true
                                          ? Colors.red[300]
                                          : Colors.green[300],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        selectedContractorMensajeGeneral?.toLowerCase().contains('inhabilitado') == true
                                            ? 'CONTRATISTA INHABILITADO'
                                            : 'CONTRATISTA HABILITADO',
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
                                  if (showEmployees && empleados.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    const Text(
                                      'Empleados',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 18,
                                        color: Color(0xFF7e8e95),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ...empleados.map((empleado) => Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${empleado['documento']} - ${empleado['apellido_nombre']}',
                                                  style: TextStyle(
                                                    color: empleado['habilitado'] == true ? Colors.green : Colors.red[800],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () {
                                                  _mostrarProximamente();
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF43b6ed),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  minimumSize: const Size(60, 30),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: const [
                                                    Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Entrar',
                                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )).toList(),
                                  ],
                                  const SizedBox(height: 20),
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _mostrarProximamente();
                                      },
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
                                ],
                              ),
                            ),
                          ],
                          // Los 3 botones siempre al final (después de todo)
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    await _fetchEmpleadosAPI();
                                  },
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
                                  onPressed: () {
                                    _mostrarProximamente();
                                  },
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
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                _mostrarProximamente();
                              },
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
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
