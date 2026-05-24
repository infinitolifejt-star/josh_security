import 'package:flutter/material.dart';

class ModuloEscaneo extends StatelessWidget {
  final String scanType;
  final TextEditingController targetController;
  final bool isLoading;
  final Function(String) onTypeChanged;
  final VoidCallback onExecuteScan;
  final VoidCallback onExportPdf;

  const ModuloEscaneo({
    Key? key,
    required this.scanType,
    required this.targetController,
    required this.isLoading,
    required this.onTypeChanged,
    required this.onExecuteScan,
    required this.onExportPdf,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Módulo Analítico Preventivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildTypeRadio('url', '🌐 Anti-Phishing'),
                  const SizedBox(width: 16),
                  _buildTypeRadio('file', '📁 Anti-Malware'),
                  const SizedBox(width: 16),
                  _buildTypeRadio('phone', '📞 Anti-Fraud'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: targetController,
              decoration: InputDecoration(
                hintText: scanType == 'url' 
                    ? 'Ingresa la URL sospechosa...' 
                    : scanType == 'file' 
                        ? 'Nombre del archivo con extensión...' 
                        : 'Número telefónico (ej: +573...)',
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                prefixIcon: Icon(
                  scanType == 'url' ? Icons.link : scanType == 'file' ? Icons.insert_drive_file : Icons.phone,
                  color: const Color(0xFF818CF8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onExecuteScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Lanzar Escaneo Forense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onExportPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    side: const BorderSide(color: Color(0xFF334155)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 18),
                  label: const Text('Exportar PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeRadio(String value, String label) {
    return InkWell(
      onTap: () => onTypeChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            groupValue: scanType,
            activeColor: const Color(0xFF818CF8),
            onChanged: (String? newValue) {
              if (newValue != null) onTypeChanged(newValue);
            },
          ),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}