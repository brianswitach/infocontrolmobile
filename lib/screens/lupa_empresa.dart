import 'package:flutter/material.dart';

class LupaEmpresaScreen extends StatelessWidget {
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
              Navigator.pop(context); // Vuelve a la pantalla anterior
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
                'B', // Logo temporal
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
      body: SingleChildScrollView(
        child: Container(
          color: Color(0xFFe6e6e6),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Recuadro principal
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
                      'Bancor S.A.',
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
              // Recuadro de filtros de búsqueda
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
                    SizedBox(height: 8),
                    // Botón Generar QR
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF24bcd4),
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(Icons.qr_code, color: Colors.white),
                        label: Text(
                          'Generar QR',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
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
                        DropdownMenuItem(child: Text("1"), value: "1"),
                        DropdownMenuItem(child: Text("2"), value: "2"),
                        DropdownMenuItem(child: Text("3"), value: "3"),
                        DropdownMenuItem(child: Text("4"), value: "4"),
                      ],
                      onChanged: (value) {},
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15), // Margen izquierdo de 15 px
                        hintText: 'Seleccione Contratista',
                        hintStyle: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200], // Fondo gris claro
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
                              fillColor: Colors.grey[200], // Fondo gris claro
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
                            color: Color(0xFF43b6ed), // Fondo del botón de la lupa
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.search, color: Colors.white), // Icono blanco
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Dominio',
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
                              fillColor: Colors.grey[200], // Fondo gris claro
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
                            color: Color(0xFF43b6ed), // Fondo del botón de la lupa
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.search, color: Colors.white), // Icono blanco
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),
              // Logo de InfoControl al final
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
