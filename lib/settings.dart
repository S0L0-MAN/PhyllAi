import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'model_provider.dart';
import 'scan_storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _disableVlmRag = false;
  String? _ollamaSelectedModel;
  bool _ollamaChecked = false;
  bool _ollamaReachable = false;
  List<String> _ollamaInstalledModels = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final disable = prefs.getBool('disable_vlm_rag') ?? false;
    final selectedOllamaModel = prefs.getString('ollama_model');
    if (!mounted) return;
    setState(() {
      _disableVlmRag = disable;
      _ollamaSelectedModel = selectedOllamaModel;
      _loaded = true;
    });

    // Only check Ollama on Windows.
    if (Platform.isWindows) {
      await _refreshOllamaStatus();
    } else {
      if (!mounted) return;
      setState(() {
        _ollamaChecked = true;
        _ollamaReachable = false;
        _ollamaInstalledModels = const [];
      });
    }
  }

  Future<void> _setDisableVlmRag(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disable_vlm_rag', value);
    if (!mounted) return;
    setState(() => _disableVlmRag = value);
  }

  Future<void> _setOllamaModel(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove('ollama_model');
    } else {
      await prefs.setString('ollama_model', value);
    }
    if (!mounted) return;
    setState(() => _ollamaSelectedModel = value);
  }

  Future<void> _refreshOllamaStatus() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final request =
          await client.getUrl(Uri.parse('http://127.0.0.1:11434/api/tags'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final models = (decoded['models'] as List<dynamic>? ?? const [])
          .map((e) => (e as Map<String, dynamic>)['name']?.toString())
          .whereType<String>()
          .toList()
        ..sort();

      if (!mounted) return;
      setState(() {
        _ollamaChecked = true;
        _ollamaReachable = true;
        _ollamaInstalledModels = models;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ollamaChecked = true;
        _ollamaReachable = false;
        _ollamaInstalledModels = const [];
      });
    }
  }

  Widget _buildOllamaSection() {
    const String defaultModel = 'qwen2.5vl:3b';
    final selected = (_ollamaSelectedModel != null && _ollamaSelectedModel!.isNotEmpty)
        ? _ollamaSelectedModel!
        : defaultModel;

    final hasSelectedInstalled = _ollamaInstalledModels.contains(selected);

    if (!Platform.isWindows) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("OLLAMA (WINDOWS ONLY)"),
          _buildSettingsCard([
            _buildSettingTile(
              icon: Icons.smart_toy_outlined,
              color: Colors.blueGrey,
              title: "Ollama Status",
              subtitle: "Not available on this platform build.",
            ),
          ]),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("OLLAMA STATUS"),
        _buildSettingsCard([
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_ollamaReachable ? Colors.green : Colors.red).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _ollamaReachable ? Icons.check_circle_outline : Icons.error_outline,
                color: _ollamaReachable ? Colors.green : Colors.red,
                size: 22,
              ),
            ),
            title: const Text(
              "Ollama Server",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              !_ollamaChecked
                  ? "Checking http://127.0.0.1:11434 ..."
                  : _ollamaReachable
                      ? "Running (http://127.0.0.1:11434)"
                      : "Not running. Install/start Ollama to enable VLM/RAG.",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: IconButton(
              tooltip: "Refresh",
              onPressed: _refreshOllamaStatus,
              icon: const Icon(Icons.refresh),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.model_training_outlined, color: Colors.indigo, size: 22),
            ),
            title: const Text(
              "VLM Model",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              _ollamaReachable
                  ? "Select which Ollama model PhyllAI will use."
                  : "Set preferred model now; install it after Ollama is running.",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: DropdownButtonFormField<String>(
              initialValue: selected,
              items: (<String>{
                defaultModel,
                'moondream:latest',
                ..._ollamaInstalledModels,
              }.toList()
                    ..sort())
                  .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                  .toList(),
              onChanged: _loaded ? (value) => _setOllamaModel(value) : null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          if (!_ollamaReachable) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Text(
                "Install Ollama:\n"
                "  winget install Ollama.Ollama\n\n"
                "Then pull the model:\n"
                "  ollama pull $selected",
                style: TextStyle(color: Colors.grey[700], fontSize: 12, height: 1.4),
              ),
            ),
          ] else if (!hasSelectedInstalled) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Text(
                "Selected model not installed.\nRun:\n  ollama pull $selected",
                style: TextStyle(color: Colors.grey[700], fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0D986A);
    final modelProvider = Provider.of<ModelProvider>(context);
    final String activeModelName = p.basename(modelProvider.selectedModel)
        .replaceAll('.onnx', '')
        .toUpperCase();

    return FutureBuilder<String>(
      future: getScansRootPath(),
      builder: (context, snapshot) {
        final scansPath = snapshot.data ?? "Loading workspace...";

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            title: Text(
              "SETTINGS",
              style: GoogleFonts.chakraPetch(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
            backgroundColor: primaryColor,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: ListView(
            children: [
              _buildHeroHeader(primaryColor),
              
              _buildSectionHeader("SYSTEM INFORMATION"),
              _buildSettingsCard([
                _buildSettingTile(
                  icon: Icons.info_outline,
                  color: Colors.blue,
                  title: "App Version",
                  subtitle: "v1.1.0-pipeline",
                ),
                _buildSettingTile(
                  icon: Icons.update_rounded,
                  color: Colors.orange,
                  title: "Build Fingerprint",
                  subtitle: "2026.04.12.multistage_vlm_rag",
                ),
              ]),

              _buildSectionHeader("AI ENGINE & ARCHITECTURE"),
              _buildSettingsCard([
                _buildSettingTile(
                  icon: Icons.memory_rounded,
                  color: Colors.deepPurple,
                  title: "Active Logic",
                  subtitle: activeModelName,
                ),
                _buildSettingTile(
                  icon: Icons.rocket_launch_outlined,
                  color: Colors.redAccent,
                  title: "Acceleration",
                  subtitle: Platform.isWindows ? "MobileNet + Python VLM/RAG" : "CPU-Native",
                ),
              ]),

              _buildSectionHeader("PIPELINE OPTIONS"),
              _buildSettingsCard([
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  secondary: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_off_outlined, color: Colors.orange, size: 22),
                  ),
                  title: const Text(
                    "Disable VLM/RAG (Windows)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    Platform.isWindows
                        ? "Skips Ollama + retrieval steps to prevent long hangs. Keeps MobileNet + Grad-CAM."
                        : "This option affects the Windows Python pipeline only.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  value: _disableVlmRag,
                  onChanged: (Platform.isWindows && _loaded)
                      ? (value) => _setDisableVlmRag(value)
                      : null,
                ),
              ]),

              _buildOllamaSection(),

              _buildSectionHeader("STORAGE & DATA"),
              _buildSettingsCard([
                _buildSettingTile(
                  icon: Icons.folder_open_rounded,
                  color: Colors.teal,
                  title: "Local Workspace",
                  subtitle: scansPath,
                ),
              ]),

              _buildSectionHeader("DEVELOPER & CREDITS"),
              _buildSettingsCard([
                _buildSettingTile(
                  icon: Icons.code_rounded,
                  color: Colors.black87,
                  title: "Engine Developer",
                  subtitle: "PhyllAI Core Team",
                ),
                _buildSettingTile(
                  icon: Icons.article_outlined,
                  color: Colors.blueGrey,
                  title: "Licenses",
                  subtitle: "MIT & Open Source Attribution",
                ),
              ]),
              
              const SizedBox(height: 30),
              Center(
                child: Text(
                  "PHYLL AI IS AN OPEN RESEARCH PROJECT",
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black26,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 45,
            backgroundColor: Colors.white24,
            child: Icon(Icons.eco_rounded, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            "Phyll AI Enterprise",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Agricultural Intelligence for Everyone",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 25, 25, 10),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.black38,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black12),
      onTap: () {},
    );
  }
}
