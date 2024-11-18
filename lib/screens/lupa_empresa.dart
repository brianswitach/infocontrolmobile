import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LupaEmpresaScreen extends StatefulWidget {
  final Map<String, dynamic> empresa;
  final String bearerToken;
  final String idEmpresaAsociada;

  LupaEmpresaScreen({
    required this.empresa,
    required this.bearerToken,
    required this.idEmpresaAsociada,
  });

  @override
  _LupaEmpresaScreenState createState() => _LupaEmpresaScreenState();
}

class _LupaEmpresaScreenState extends State<LupaEmpresaScreen> {
  String? selectedContractor;
  bool showContractorInfo = false;
  bool showEmployees = false;
  List<dynamic> empleados = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    obtenerEmpleados();
  }

  Future<void> obtenerEmpleados() async {
  try {
    print('Bearer Token: ${widget.bearerToken}');
    print('ID Empresa Asociada: ${widget.idEmpresaAsociada}');

    final response = await http.get(
      Uri.parse('https://www.infocontrol.com.ar/desarrollo_v2/api/mobile/empleados/listar')
          .replace(queryParameters: {
        'id_empresas': widget.idEmpresaAsociada,
      }),
      headers: {
        'Authorization': 'Bearer ${widget.bearerToken}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    print('Response headers: ${response.headers}');
    print('Response body raw: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      print('Response completa: $responseData');
      
      setState(() {
        empleados = responseData['data'] ?? [];
        isLoading = false;
      });

      if (responseData['data'] != null && responseData['data'].isNotEmpty) {
        String nombreRazonSocial = responseData['data'][0]['nombre_razon_social'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se encontró: $nombreRazonSocial'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se encontraron datos de empleados'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      print('Error al obtener empleados: ${response.statusCode}');
      setState(() {
        isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al obtener empleados: ${response.statusCode}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    print('Error en la solicitud: $e');
    setState(() {
      isLoading = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error en la solicitud: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Color(0xFF2a3666)),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.search, color: Color(0xFF2a3666)),
              onPressed: () {},
            ),
            Container(
              height: 24,
              width: 1,
              color: Colors.grey[300],
              margin: EdgeInsets.symmetric(horizontal: 10),
            ),
            CircleAvatar(
              backgroundColor: Color(0xFF232e63),
              radius: 15,
              child: Text(
                widget.empresa['nombre']?[0] ?? 'B',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            SizedBox(width: 5),
            Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF232e63),
            ),
            SizedBox(width: 10),
          ],
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Container(
                color: Color(0xFFe6e6e6),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.empresa['nombre'] ?? 'Nombre no disponible',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 18,
                              color: Color(0xFF7e8e95),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Divider(color: Colors.grey[300], thickness: 1),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFFe0f7fa),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
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
                    SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtros de Búsquedas',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 18,
                              color: Color(0xFF7e8e95),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Divider(color: Colors.grey[300], thickness: 1),
                          SizedBox(height: 20),
                          Text(
                            'Contratista',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            items: [
                              DropdownMenuItem(
                                child: Text("ABC CONSULTING"),
                                value: "ABC CONSULTING",
                              ),
                              DropdownMenuItem(
                                child: Text("XYZ SERVICES"),
                                value: "XYZ SERVICES",
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedContractor = value;
                                showContractorInfo = true;
                              });
                            },
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                              hintText: 'Seleccione Contratista',
                              hintStyle: TextStyle(
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
                          SizedBox(height: 20),
                          Text(
                            'Número de Identificación Personal',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '(Sin puntos ni guiones)',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Número de Identificación Personal',
                                    hintStyle: TextStyle(
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
                              SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFF43b6ed),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.search, color: Colors.white),
                                  onPressed: () {},
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Dominio/Placa/N° de Serie/N° de Chasis',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '(Sin espacios ni guiones)',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'DOMINIO EJ: ABC123',
                                    hintStyle: TextStyle(
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
                              SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFF43b6ed),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.search, color: Colors.white),
                                  onPressed: () {},
                                ),
                              ),
                            ],
                          ),
                          if (showContractorInfo) ...[
                            SizedBox(height: 30),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.empresa['nombre'] ?? 'Empresa',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF232e5f),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.green[300],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'CONTRATISTA HABILITADO',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    'Razón Social: ${widget.empresa['nombre'] ?? 'No disponible'}',
                                    style: TextStyle(
                                      fontFamily: 'Montserrat',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text('CUIT: 30709035262'),
                                  Text('Tipo persona: Persona Jurídica'),
                                  Text('Tipo trabajador: Empleados en Relación de Dependencia'),
                                  Text('Actividades: -'),
                                  SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              showEmployees = !showEmployees;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[200],
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          icon: Icon(Icons.people, color: Colors.black54),
                                          label: Text(
                                            'Empleados',
                                            style: TextStyle(color: Colors.black54),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {},
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[200],
                                            padding: EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          icon: Icon(Icons.directions_car, color: Colors.black54),
                                          label: Text(
                                            'Vehículos',
                                            style: TextStyle(color: Colors.black54),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (showEmployees && empleados.isNotEmpty) ...[
                                    SizedBox(height: 20),
                                    Text(
                                      'Empleados',
                                      style: TextStyle(
                                        fontFamily: 'Montserrat',
                                        fontSize: 18,
                                        color: Color(0xFF7e8e95),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 10),
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
                                          SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () {},
                                            icon: Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                                            label: Text(
                                              'Entrar',
                                              style: TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(0xFF43b6ed),
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size(60, 30),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )).toList(),
                                  ],
                                  SizedBox(height: 20),
                                  Center(
                                    child: ElevatedButton.icon(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[300],
                                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                      icon: Icon(Icons.print, color: Colors.black54),
                                      label: Text(
                                        'Imprimir',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                    SizedBox(height: 30),
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