import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

import 'python_runtime.dart';

class DiagnosisPage extends StatefulWidget {
  final String scanFolderPath;
  final String modelUsed;

  const DiagnosisPage({
    super.key,
    required this.scanFolderPath,
    required this.modelUsed,
  });

  @override
  State<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<DiagnosisPage> {
  static const Color primaryColor = Color(0xFF0D986A);

  final TextEditingController _chatController = TextEditingController();
  final List<_ChatMessage> _messages = [];

  late final File _inputFile;
  late final File _gradCamFile;
  late final File _heatmapFile;
  late final Future<Map<String, dynamic>> _reportFuture;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _inputFile = File(p.join(widget.scanFolderPath, 'input.jpg'));
    _gradCamFile = File(p.join(widget.scanFolderPath, 'grad_cam.png'));
    _heatmapFile = File(p.join(widget.scanFolderPath, 'heatmap.png'));
    _reportFuture = _loadReport();
    _primeWelcomeMessage();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _primeWelcomeMessage() async {
    final data = await _reportFuture;
    if (!mounted) return;

    final diseaseName = data['disease_name'] ?? 'the uploaded sample';
    final recommendation = data['recommendation'] ?? 'Ask about symptoms, evidence, or next steps.';

    setState(() {
      _messages.add(
        _ChatMessage(
          role: ChatRole.assistant,
          text:
              'I studied this scan and saved the MobileNet, VLM, and RAG artifacts. Ask me anything about $diseaseName.\n\nRecommended next step: $recommendation',
        ),
      );
    });
  }

  Future<Map<String, dynamic>> _loadReport() async {
    final file = File(p.join(widget.scanFolderPath, 'report.json'));
    if (!await file.exists()) {
      return {};
    }

    final contents = await file.readAsString();
    final decoded = json.decode(contents);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {};
  }

  Future<void> _sendChatMessage() async {
    final question = _chatController.text.trim();
    if (question.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(role: ChatRole.user, text: question));
      _isSending = true;
      _chatController.clear();
    });

    try {
      String answer;
      if (Platform.isWindows) {
        final result = await PythonRuntime.runScript(
          'chat_cli.py',
          [widget.scanFolderPath, question],
        );

        if (result.exitCode != 0) {
          throw Exception(result.stderr.toString());
        }

        final stdout = result.stdout.toString().trim();
        final payload = jsonDecode(stdout) as Map<String, dynamic>;
        answer = payload['answer']?.toString() ??
            'I could not generate an answer for this question.';
      } else {
        answer =
            'Chat reasoning is currently wired for the desktop Python pipeline. On mobile, review the saved report and analysis cards.';
      }

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(role: ChatRole.assistant, text: answer));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: ChatRole.assistant,
            text: 'I hit a pipeline error while answering: $error',
          ),
        );
      });
    } finally {
      if (!mounted) return;
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          'DIAGNOSIS REPORT',
          style: GoogleFonts.chakraPetch(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reportFuture,
        builder: (context, snapshot) {
          final data = snapshot.data ?? {};
          final String diseaseName = data['disease_name'] ?? 'Analyzing...';
          final double confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
          final Map<String, dynamic> reasoning =
              (data['feature_reasoning'] as Map<String, dynamic>?) ?? {};
          final Map<String, dynamic> vlmFeatures =
              (data['vlm_features'] as Map<String, dynamic>?) ?? {};
          final List<dynamic> evidence =
              (reasoning['supporting_evidence'] as List<dynamic>?) ?? const [];
          final List<dynamic> sources =
              ((data['rag'] as Map<String, dynamic>?)?['sources'] as List<dynamic>?) ??
                  const [];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'EXPLAINABILITY MAPS (GRAD-CAM)',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black54,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                SizedBox(
                  height: 340,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    children: [
                      _buildHeatmapCard(
                        'ORIGINAL',
                        'Raw input photo',
                        displayImage: _inputFile,
                      ),
                      _buildHeatmapCard(
                        'GRAD-CAM OVERLAY',
                        'MobileNet attention',
                        displayImage: _gradCamFile,
                      ),
                      _buildHeatmapCard(
                        'FEATURE INTENSITY',
                        'Raw attribution heatmap',
                        displayImage: _heatmapFile,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DIAGNOSIS',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        diseaseName,
                        style: GoogleFonts.chakraPetch(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(confidence * 100).toStringAsFixed(1)}% Confidence',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 40),
                      _reportRow('Severity:', data['severity'] ?? 'N/A'),
                      _reportRow('Engine:', widget.modelUsed),
                      _reportRow(
                        'Reasoning Mode:',
                        reasoning['reasoning_quality']?.toString() ?? 'VLM + RAG',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'RECOMMENDED ACTION',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.orange[900],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data['recommendation'] ?? 'N/A',
                        style: GoogleFonts.inter(
                          color: Colors.black87,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildFeatureCard(vlmFeatures),
                _buildReasoningCard(reasoning, evidence, sources),
                _buildChatCard(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeatmapCard(
    String title,
    String subtitle, {
    required File displayImage,
  }) {
    final exists = displayImage.existsSync();
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            if (exists)
              Image.file(
                displayImage,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> vlmFeatures) {
    final chips = [
      vlmFeatures['lesion_color'],
      vlmFeatures['lesion_shape'],
      vlmFeatures['distribution'],
      vlmFeatures['texture'],
      vlmFeatures['severity'],
    ].whereType<String>().where((value) => value.isNotEmpty).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VLM FEATURE EXTRACTION',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: primaryColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (chip) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      chip,
                      style: const TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Text(
            vlmFeatures['notes']?.toString() ?? 'No VLM notes saved for this scan.',
            style: GoogleFonts.inter(
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasoningCard(
    Map<String, dynamic> reasoning,
    List<dynamic> evidence,
    List<dynamic> sources,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RAG-GUIDED FEATURE REASONING',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: primaryColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            reasoning['summary']?.toString() ?? 'Reasoning summary is not available.',
            style: GoogleFonts.inter(
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          if (evidence.isNotEmpty) ...[
            const Text(
              'Supporting Evidence',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...evidence.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('* '),
                    Expanded(child: Text(item.toString())),
                  ],
                ),
              ),
            ),
          ],
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'RAG Sources',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              sources.map((item) => item.toString()).join('\n'),
              style: TextStyle(color: Colors.grey[700], height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SCAN CHATBOT',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              color: primaryColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'This assistant answers from the saved MobileNet output, the scan images, extracted VLM features, and the RAG context for this scan.',
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: _messages.isEmpty
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Preparing chat context...'),
                  ))
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(14),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message.role == ChatRole.user;
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 260),
                          decoration: BoxDecoration(
                            color: isUser
                                ? primaryColor
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ask about symptoms, confidence, treatment, or evidence...',
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _isSending ? null : _sendChatMessage,
                style: IconButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

enum ChatRole { user, assistant }

class _ChatMessage {
  final ChatRole role;
  final String text;

  const _ChatMessage({
    required this.role,
    required this.text,
  });
}
