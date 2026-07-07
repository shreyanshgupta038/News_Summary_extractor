import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shimmer/shimmer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const NewsSummaryApp());
}

class NewsSummaryApp extends StatelessWidget {
  const NewsSummaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'News Summary Extractor',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0E12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF1E1F26),
          background: Color(0xFF0D0E12),
          error: Color(0xFFEF4444),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const DashboardScreen(),
    );
  }
}

class TopicSummary {
  final String name;
  final String summary;

  TopicSummary({required this.name, required this.summary});
}

class ArticleData {
  final String title;
  final String author;
  final String date;
  final String content;
  final String rawSummary;
  final List<TopicSummary> topics;
  final bool isFallback;

  ArticleData({
    required this.title,
    required this.author,
    required this.date,
    required this.content,
    required this.rawSummary,
    required this.topics,
    required this.isFallback,
  });

  factory ArticleData.fromJson(Map<String, dynamic> json) {
    final rawSummary = json['summary'] ?? '';
    final topics = parseSummary(rawSummary);
    return ArticleData(
      title: json['title'] ?? 'Title not found',
      author: json['author'] ?? 'Unknown Author',
      date: json['date'] ?? 'Date not found',
      content: json['content'] ?? '',
      rawSummary: rawSummary,
      topics: topics,
      isFallback: json['fallback'] ?? false,
    );
  }

  static List<TopicSummary> parseSummary(String raw) {
    List<TopicSummary> topics = [];
    List<String> lines = raw.split('\n');
    String currentName = '';
    String currentSummary = '';

    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('TOPIC_1_NAME:') ||
          line.startsWith('TOPIC_2_NAME:') ||
          line.startsWith('TOPIC_3_NAME:')) {
        if (currentName.isNotEmpty &&
            currentName.toUpperCase() != 'NONE' &&
            currentSummary.isNotEmpty &&
            currentSummary.toUpperCase() != 'NONE') {
          topics.add(TopicSummary(name: currentName, summary: currentSummary));
        }
        currentName = line.substring(line.indexOf(':') + 1).trim();
        currentSummary = '';
      } else if (line.startsWith('TOPIC_1_SUMMARY:') ||
          line.startsWith('TOPIC_2_SUMMARY:') ||
          line.startsWith('TOPIC_3_SUMMARY:')) {
        currentSummary = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.isNotEmpty) {
        if (currentSummary.isNotEmpty) {
          currentSummary += '\n$line';
        } else {
          currentSummary = line;
        }
      }
    }
    
    if (currentName.isNotEmpty &&
        currentName.toUpperCase() != 'NONE' &&
        currentSummary.isNotEmpty &&
        currentSummary.toUpperCase() != 'NONE') {
      topics.add(TopicSummary(name: currentName, summary: currentSummary));
    }

    if (topics.isEmpty) {
      topics.add(TopicSummary(
        name: 'Summary Overview',
        summary: raw.replaceAll(RegExp(r'TOPIC_\d_(NAME|SUMMARY):'), '').trim(),
      ));
    }

    return topics;
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _serverController = TextEditingController(text: 'http://localhost:8000');
  
  bool _isLoading = false;
  bool _isCheckingServer = false;
  bool _isServerOnline = false;
  bool _isLlmLoaded = false;
  String _llmPath = '';
  
  ArticleData? _articleData;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkServerStatus();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _serverController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkServerStatus() async {
    setState(() {
      _isCheckingServer = true;
      _errorMessage = null;
    });

    final serverUrl = _serverController.text.trim();
    try {
      final infoResponse = await http.get(
        Uri.parse('$serverUrl/info'),
      ).timeout(const Duration(seconds: 5));

      if (infoResponse.statusCode == 200) {
        final data = jsonDecode(infoResponse.body);
        setState(() {
          _isServerOnline = true;
          _isLlmLoaded = data['loaded'] ?? false;
          _llmPath = data['model_path'] ?? '';
          _isCheckingServer = false;
        });
      } else {
        // Fallback to checking root health endpoint
        final healthResponse = await http.get(
          Uri.parse('$serverUrl/'),
        ).timeout(const Duration(seconds: 5));
        
        setState(() {
          _isServerOnline = healthResponse.statusCode == 200;
          _isLlmLoaded = false;
          _isCheckingServer = false;
        });
      }
    } catch (e) {
      setState(() {
        _isServerOnline = false;
        _isLlmLoaded = false;
        _isCheckingServer = false;
      });
    }
  }

  Future<void> _processUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a news article URL')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _articleData = null;
    });

    final serverUrl = _serverController.text.trim();
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/summarize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(minutes: 3)); // Model inference can take time on CPU

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _articleData = ArticleData.fromJson(decoded);
          _isLoading = false;
        });
      } else {
        final err = jsonDecode(response.body);
        setState(() {
          _errorMessage = err['detail'] ?? 'Failed to analyze article.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection Error: Could not connect to the backend server. Make sure the server is running at $serverUrl.\n\nDetail: $e';
        _isLoading = false;
      });
    }
  }

  void _shareSummary() {
    if (_articleData == null) return;
    
    final buffer = StringBuffer();
    buffer.writeln('📰 *${_articleData!.title}*');
    buffer.writeln('By: ${_articleData!.author} | ${_articleData!.date}');
    buffer.writeln('\n--- AI Summary ---');
    for (var topic in _articleData!.topics) {
      buffer.writeln('\n📌 *Topic: ${topic.name}*');
      buffer.writeln(topic.summary);
    }
    
    Share.share(buffer.toString(), subject: 'News Summary: ${_articleData!.title}');
  }

  Future<void> _exportPdf() async {
    if (_articleData == null) return;

    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                cross: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('NEWS SUMMARY EXTRACTOR', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, letterSpacing: 1.5)),
                  pw.SizedBox(height: 4),
                  pw.Text(_articleData!.title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.SizedBox(height: 6),
                  pw.Text('Author: ${_articleData!.author}  |  Date: ${_articleData!.date}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  pw.SizedBox(height: 12),
                ]
              )
            ),
            pw.SizedBox(height: 10),
            pw.Text('AI IDENTIFIED TOPICS & SUMMARIES', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
            pw.SizedBox(height: 8),
            ..._articleData!.topics.map((topic) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5)
                ),
                child: pw.Column(
                  cross: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(topic.name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.SizedBox(height: 6),
                    pw.Text(topic.summary, style: const pw.TextStyle(fontSize: 10, height: 1.4)),
                  ]
                )
              );
            }).toList(),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Text('Generated offline using Gemma LLM & News Summary Extractor.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))
          ];
        },
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final sanitizedTitle = _articleData!.title.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
      final path = '${dir.path}/summary_$sanitizedTitle.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      final params = SaveFileDialogParams(sourceFilePath: file.path);
      final finalPath = await FlutterFileDialog.saveFile(params: params);
      
      if (finalPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF saved successfully! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1F26),
        title: const Text('Backend API Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter local or hosted backend URL:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _serverController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g., http://localhost:8000',
                prefixIcon: Icon(Icons.dns, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _checkServerStatus();
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.newspaper, color: Color(0xFF6366F1)),
            const SizedBox(width: 8),
            const Text('News Summarizer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: const Color(0xFF14151B),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkServerStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionStatusBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildUrlInputField(),
                  const SizedBox(height: 20),
                  if (_isLoading) _buildShimmerLoading(),
                  if (_errorMessage != null) _buildErrorCard(),
                  if (_articleData != null) _buildResultSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusBar() {
    Color barColor = Colors.grey[800]!;
    Widget statusWidget = const SizedBox.shrink();

    if (_isCheckingServer) {
      barColor = Colors.orange[800]!;
      statusWidget = const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 8),
          Text('Connecting to API...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      );
    } else if (_isServerOnline) {
      if (_isLlmLoaded) {
        barColor = Colors.green[800]!;
        statusWidget = const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text('API Connected • Gemma LLM Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        );
      } else {
        barColor = Colors.blue[800]!;
        statusWidget = const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text('API Connected • Fallback Mode Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        );
      }
    } else {
      barColor = Colors.red[900]!;
      statusWidget = const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text('API Offline • Tap Settings to Configure', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: barColor,
      child: statusWidget,
    );
  }

  Widget _buildUrlInputField() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1E1F26),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Analyze News Article',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Paste a URL from Firstpost, Times of India, or other supported sources to extract and summarize content.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'Enter news article URL...',
                prefixIcon: const Icon(Icons.link, color: Color(0xFF6366F1)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste, size: 18),
                  onPressed: () async {
                    ClipboardData? data = await Clipboard.getData('text/plain');
                    if (data != null && data.text != null) {
                      _urlController.text = data.text!;
                    }
                  },
                ),
                filled: true,
                fillColor: const Color(0xFF14151B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              onPressed: _isLoading ? null : _processUrl,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 18),
                  SizedBox(width: 8),
                  Text('Extract & Summarize', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.error.withOpacity(0.5)),
      ),
      color: Theme.of(context).colorScheme.error.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                const Text('Analysis Failed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'An error occurred.',
              style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFFFDA4AF)),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _processUrl,
              icon: const Icon(Icons.replay, size: 16),
              label: const Text('Try Again', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1F26),
      highlightColor: const Color(0xFF2E2F38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(3, (index) => Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    final article = _articleData!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Meta Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1E1F26),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (article.isFallback)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[900]!.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue[400]!, width: 0.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info, size: 12, color: Colors.blue),
                        SizedBox(width: 4),
                        Text('Fallback extractive summarizer was used', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                Text(
                  article.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              article.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              article.date,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6366F1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _shareSummary,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share Summary', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('Export PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Tabs
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF14151B),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF6366F1),
            ),
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'AI Summary Details'),
              Tab(text: 'Scraped Article'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tab Content
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 400, // Fixed height scroll view for tab elements
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSummaryTab(),
              _buildArticleTextTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTab() {
    final topics = _articleData!.topics;
    
    return ListView.builder(
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final t = topics[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: const Color(0xFF1E1F26),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'TOPIC ${index + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA78BFA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  t.summary,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildArticleTextTab() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF1E1F26),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            _articleData!.content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }
}
