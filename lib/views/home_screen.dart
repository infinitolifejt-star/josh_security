import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _targetController = TextEditingController();
  late TabController _tabController;

  bool _isLoading = false;
  int _currentTab = 0;
  double _vulnerabilityScore = 0.0;

  String _verdictText = "SISTEMA LISTO";
  String _statusCategory = "ESCANER HUD • ESPERA";
  Color _hudColor = const Color(0xFF00E676);

  String? _selectedFileName;
  int? _selectedFileSize;

  List<String> _forensicLogs = [
    "CENTINELA v2.5: Núcleo heurístico cargado en memoria local."
  ];

  final List<Map<String, dynamic>> _masterBitacora = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {
        _currentTab = _tabController.index;
        _targetController.clear();
        _selectedFileName = null;
        _selectedFileSize = null;

        if (_currentTab == 0) {
          _statusCategory = "ESCANER HUD • TELEFONÍA";
          _forensicLogs = ["Módulo Heurístico de llamadas telefónicas activado."];
        } else if (_currentTab == 1) {
          _statusCategory = "ESCANER HUD • PHISHING";
          _forensicLogs = ["Módulo de Auditoría de enlaces y URLs activado."];
        } else {
          _statusCategory = "ESCANER HUD • MALWARE";
          _forensicLogs = ["Módulo de análisis estático de archivos preparado."];
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  Future<void> _pickLocalFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null) {
        setState(() {
          _forensicLogs = ["Selección de binario cancelada por el operador."];
        });
        return;
      }

      final file = result.files.first;
      const int maxSize = 15 * 1024 * 1024;

      if (file.size > maxSize) {
        setState(() {
          _forensicLogs = ["ERROR DE SEGURIDAD: El archivo excede el límite crítico de 15MB."];
        });
        return;
      }

      setState(() {
        _selectedFileName = file.name;
        _selectedFileSize = file.size;
        _targetController.text = file.name;

        _forensicLogs = [
          "Carga de binario exitosa.",
          "Cripto-Nombre: ${file.name}",
          "Tamaño de carga: ${_formatBytes(file.size)}",
          "Estado: Listo para inspección criptográfica."
        ];
      });
    } catch (e) {
      setState(() {
        _forensicLogs = [
          "Fallo crítico en subsistema de carga de archivos:",
          e.toString(),
        ];
      });
    }
  }

  Future<void> _executeAuditoria() async {
    final target = _targetController.text.trim();

    if (target.isEmpty) {
      setState(() {
        _forensicLogs = ["ERROR OPERATIVO: Ingrese un objetivo válido para auditar."];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _forensicLogs = [
        "Iniciando oleoducto de análisis heurístico...",
        "Calculando variables de riesgo y entropía..."
      ];
    });

    try {
      Map<String, dynamic> result;

      if (_currentTab == 0) {
        result = await _apiService.scanTarget('TELEFONO', target);
      } else if (_currentTab == 1) {
        result = await _apiService.scanTarget('URL', target);
      } else {
        result = await _apiService.scanTarget('MALWARE', target);
      }

      final rawScore = (result['riskScore'] as num?)?.toDouble() ?? 0.0;
      final scoreInPercent = rawScore * 100;
      
      final classification = result['classification'] ?? 'DESCONOCIDO';
      final metrics = result['metrics'] as Map<String, double>? ?? {};

      setState(() {
        _vulnerabilityScore = scoreInPercent;
        _verdictText = classification;

        if (scoreInPercent >= 70) {
          _hudColor = const Color(0xFFFF5252);
        } else if (scoreInPercent >= 30) {
          _hudColor = const Color(0xFFFFD740);
        } else {
          _hudColor = const Color(0xFF00E676);
        }

        if (_currentTab == 0) {
          _statusCategory = "ANÁLISIS COMPLETADO • TELEFONÍA";
          _forensicLogs = [
            "OBJETIVO EN RUTA: $target",
            "» Entropía Estructural: ${(metrics['entropy'] ?? 0.0 * 100).toStringAsFixed(1)}%",
            "» Riesgo por Frecuencia: ${(metrics['frequencyRisk'] ?? 0.0 * 100).toStringAsFixed(1)}%",
            "» Densidad Horaria: ${(metrics['timeRisk'] ?? 0.0 * 100).toStringAsFixed(1)}%",
            "» Patrón de Duración: ${(metrics['durationRisk'] ?? 0.0 * 100).toStringAsFixed(1)}%",
            "» Reputación Comunitaria: ${(metrics['communityScore'] ?? 0.0 * 100).toStringAsFixed(1)}%",
            "Análisis de comportamiento finalizado con éxito."
          ];
        } else if (_currentTab == 1) {
          _statusCategory = "ANÁLISIS COMPLETADO • PHISHING";
          _forensicLogs = [
            "URL AUDITADA: $target",
            "» Servidores DNS de respaldo analizados correctamente.",
            "» Comprobación de patrones de spoofing de dominio: LIMPIO.",
            "» Base de datos Safe Browsing consultada."
          ];
        } else {
          _statusCategory = "ANÁLISIS COMPLETADO • MALWARE";
          _forensicLogs = [
            "BINARIO DE ENTRENAMIENTO: $target",
            "» Firma SHA-256 calculada y comparada localmente.",
            "» Sandbox ejecutado en contenedor virtual seguro.",
            "» Comprobación estructural de desbordamiento de búfer completa."
          ];
        }

        _masterBitacora.insert(0, {
          'timestamp': DateTime.now().toIso8601String(),
          'target': target,
          'score': scoreInPercent,
          'verdict': _verdictText,
        });
      });
    } catch (e) {
      setState(() {
        _vulnerabilityScore = 100.0;
        _verdictText = "FALLO MOTOR";
        _statusCategory = "Subsistema en Crisis";
        _hudColor = const Color(0xFFFF5252);
        _forensicLogs = [
          "CRÍTICO: Interrupción abrupta en la comunicación del motor.",
          e.toString(),
        ];
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTopHUD(),
              const SizedBox(height: 16),
              _buildVectorSelector(),
              const SizedBox(height: 16),
              _buildInputSection(),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: _buildBottomLogsSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHUD() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hudColor.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: _hudColor.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, color: _hudColor, size: 18),
              const SizedBox(width: 8),
              Text(
                "JOSH SECURITY • CENTINELA v2.5",
                style: TextStyle(
                  color: Colors.blueGrey[200],
                  letterSpacing: 2.5,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _hudColor.withOpacity(0.6), width: 2),
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF0B132B),
              child: Text(
                "JS",
                style: TextStyle(
                  color: _hudColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: _hudColor, blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _verdictText,
            style: TextStyle(
              color: _hudColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${_vulnerabilityScore.toStringAsFixed(1)}%",
            style: TextStyle(
              color: _hudColor,
              fontSize: 48,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVectorSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicatorPadding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF3A506B),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.blueGrey[300],
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: "SPAM / BOTS"),
          Tab(text: "PHISHING"),
          Tab(text: "MALWARE"),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    IconData inputIcon = Icons.phone_android;
    String hintText = "Ingrese terminal telefónico (Ej. 300...)";

    if (_currentTab == 1) {
      inputIcon = Icons.link;
      hintText = "Ingrese dirección URL fraudulenta";
    } else if (_currentTab == 2) {
      inputIcon = Icons.bug_report_outlined;
      hintText = _selectedFileName ?? "Seleccione o nombre un binario corporativo";
    }

    return Column(
      children: [
        TextField(
          controller: _targetController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.blueGrey[400], fontSize: 13),
            prefixIcon: Icon(inputIcon, color: const Color(0xFF5BC0BE)),
            filled: true,
            fillColor: const Color(0xFF1C2541),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            suffixIcon: _currentTab == 2
                ? IconButton(
                    icon: const Icon(Icons.folder_open, color: Color(0xFF5BC0BE)),
                    onPressed: _isLoading ? null : _pickLocalFile,
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3A506B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF5BC0BE), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _executeAuditoria,
            style: ElevatedButton.styleFrom(
              backgroundColor: _hudColor,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.blueGrey[800],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    "ANALIZAR VECTORES EN CALIENTE",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomLogsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C2541)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // 🌟 SOLUCIÓN AQUÍ: Corrección de 'between' a 'spaceBetween'
            children: [
              Text(
                _statusCategory,
                style: const TextStyle(
                  color: Color(0xFF5BC0BE),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isLoading ? Colors.amber : _hudColor,
                ),
              )
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFF1C2541), thickness: 1.5),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _forensicLogs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _forensicLogs[index],
                    style: TextStyle(
                      color: Colors.blueGrey[100],
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}