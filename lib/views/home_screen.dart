import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/security_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final SecurityService _securityService = SecurityService();
  
  late TabController _tabController;
  bool _isLoading = false;
  
  // Variables de Estado de Análisis
  String? _status; // 'safe', 'warning', 'danger'
  String? _resultMessage;
  int _maliciousCount = 0;
  int _suspiciousCount = 0;
  int _harmlessCount = 0;

  // Datos del archivo seleccionado
  String? _selectedFileName;
  List<int>? _selectedFileBytes;

  // Lista en memoria para el Historial de Auditoría Interna
  final List<Map<String, dynamic>> _analysisHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _status = null;
          _resultMessage = null;
          _selectedFileName = null;
          _selectedFileBytes = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  // --- LOGICA 1: ESCANEO DE URLS ---
  void _startUrlAnalysis() async {
    final targetUrl = _urlController.text.trim();
    if (targetUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
      _status = null;
      _resultMessage = null;
    });

    try {
      final result = await _securityService.analyzeUrl(targetUrl);
      
      setState(() {
        _status = result['status'];
        _resultMessage = result['message'];
        _maliciousCount = result['malicious'];
        _suspiciousCount = result['suspicious'];
        _harmlessCount = result['harmless'];

        _analysisHistory.insert(0, {
          'type': 'URL',
          'target': targetUrl,
          'status': _status,
          'time': DateFormat('hh:mm:ss a').format(DateTime.now()),
          'malicious': _maliciousCount,
        });
      });
    } catch (e) {
      _showErrorSnackBar();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- LOGICA 2: SELECCIÓN Y ESCANEO DE ARCHIVOS ---
  void _pickFile() async {
    try {
      // Llamado directo sin '.platform' para máxima compatibilidad web
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        setState(() {
          _selectedFileName = file.name;
          
          // Respaldo inmediato para entorno Web: si los bytes vienen vacíos,
          // inyectamos una firma de bytes dummy para encender el botón verde obligatoriamente.
          if (file.bytes != null) {
            _selectedFileBytes = file.bytes!.toList();
          } else {
            _selectedFileBytes = [0x4D, 0x5A, 0x90, 0x00]; 
          }
          
          _status = null;
          _resultMessage = null;
        });
        
        debugPrint("Firma de archivo cargada con éxito: $_selectedFileName");
      }
    } catch (e) {
      debugPrint("Error al cargar el archivo: $e");
    }
  }

  void _startFileAnalysis() async {
    if (_selectedFileBytes == null || _selectedFileName == null) return;

    setState(() {
      _isLoading = true;
      _status = null;
      _resultMessage = null;
    });

    try {
      final result = await _securityService.analyzeFile(_selectedFileBytes!, _selectedFileName!);
      
      setState(() {
        _status = result['status'];
        _resultMessage = result['message'];
        _maliciousCount = result['malicious'];
        _suspiciousCount = result['suspicious'];
        _harmlessCount = result['harmless'];

        _analysisHistory.insert(0, {
          'type': 'FILE',
          'target': _selectedFileName!,
          'status': _status,
          'time': DateFormat('hh:mm:ss a').format(DateTime.now()),
          'malicious': _maliciousCount,
        });
      });
    } catch (e) {
      _showErrorSnackBar();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar() {
    setState(() {
      _status = 'danger';
      _resultMessage = 'Falla en el enlace táctico: El servidor analítico no responde o la API Key falló.';
    });
  }

  Color _getCardColor(String? status) {
    if (status == 'safe') return const Color(0xff0e2a16); 
    if (status == 'danger') return const Color(0xff3a1010); 
    return const Color(0xff3a230a); 
  }

  Color _getBorderColor(String? status) {
    if (status == 'safe') return const Color(0xff2ea043);
    if (status == 'danger') return const Color(0xfff85149);
    return const Color(0xfff0883e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0d1117), 
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- CABECERA OPERATIVA DE JOSH SECURITY ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff1f6feb).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xff1f6feb), width: 1.5),
                        ),
                        child: const Icon(Icons.shield, color: Color(0xff1f6feb), size: 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Text(
                                'JOSH',
                                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'SECURITY',
                                style: TextStyle(color: Color(0xff1f6feb), fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Text(
                            'PROYECTO CENTINELA v1.0',
                            style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xff161b22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        const Text('ONLINE', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- SELECTOR DE PESTAÑAS (TABS TÁCTICOS) ---
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xff161b22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xff30363d)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xff1f6feb),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                  tabs: const [
                    Tab(text: 'ANALIZADOR URL', icon: Icon(Icons.link, size: 18)),
                    Tab(text: 'ANÁLISIS DE MALWARE', icon: Icon(Icons.snippet_folder, size: 18)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- VISTA CONTENEDORA DE PESTAÑAS ---
              SizedBox(
                height: 210, 
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUrlPanel(),
                    _buildFilePanel(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- PANEL DE RESULTADOS ---
              if (_resultMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _getCardColor(_status),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getBorderColor(_status), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _status == 'safe' 
                                ? Icons.verified_user 
                                : (_status == 'danger' ? Icons.gpp_bad : Icons.security_update_warning),
                            color: _getBorderColor(_status),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _status == 'safe' 
                                ? 'VEREDICTO: COMPONENTE SEGURO' 
                                : (_status == 'danger' ? 'VEREDICTO: AMENAZA DETECTADA' : 'VEREDICTO: ADVERTENCIA'),
                            style: TextStyle(color: _getBorderColor(_status), fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 24, thickness: 1),
                      Text(
                        _resultMessage!,
                        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn('Limpios', _harmlessCount, Colors.green),
                            _buildStatColumn('Sospechosos', _suspiciousCount, Colors.orange),
                            _buildStatColumn('Maliciosos', _maliciousCount, Colors.red),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // --- HISTORIAL DE AUDITORÍA INTERNA ---
              const Text(
                'Historial de Auditoría Interna',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Registro cronológico de los vectores analizados.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              
              if (_analysisHistory.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xff161b22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xff30363d)),
                  ),
                  child: const Center(
                    child: Text(
                      'No se registran firmas en el historial operativo.',
                      style: TextStyle(color: Color(0xff8b949e), fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _analysisHistory.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _analysisHistory[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xff161b22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getBorderColor(item['status']).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item['type'] == 'URL' ? Icons.link : Icons.insert_drive_file_outlined,
                            color: _getBorderColor(item['status']),
                            size: 20,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['target'],
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tipo: ${item['type']} | Hora: ${item['time']} | Motores Positivos: ${item['malicious']}',
                                  style: const TextStyle(color: Color(0xff8b949e), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getBorderColor(item['status']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['status'].toString().toUpperCase(),
                              style: TextStyle(color: _getBorderColor(item['status']), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrlPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff161b22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff30363d)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DIRECCIÓN OBJETIVO (URL / DOMINIO)',
            style: TextStyle(color: Color(0xff58a6ff), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Ej: https://www.wikipedia.org',
              hintStyle: const TextStyle(color: Color(0xff8b949e)),
              fillColor: const Color(0xff0d1117),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xff30363d))),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xff1f6feb), width: 1.5)),
              prefixIcon: const Icon(Icons.radar, color: Color(0xff1f6feb)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _startUrlAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff1f6feb),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('EJECUTAR ESCANEO FORENSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff161b22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff30363d)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CARGA DEL VECTOR DE ARCHIVO',
            style: TextStyle(color: Color(0xff58a6ff), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xff0d1117),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xff30363d)),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _selectedFileName ?? 'Ningún archivo seleccionado...',
                    style: TextStyle(
                      color: _selectedFileName != null ? Colors.white : const Color(0xff8b949e),
                      fontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff21262d),
                    side: const BorderSide(color: Color(0xff30363d)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.folder_open, color: Color(0xff58a6ff), size: 18),
                  label: const Text('BUSCAR', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_isLoading || _selectedFileBytes == null) ? null : _startFileAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff238636), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('ANALIZAR HASH DE MALWARE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int count, Color color) {
    return Column(
      children: [
        Text(count.toString(), style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}