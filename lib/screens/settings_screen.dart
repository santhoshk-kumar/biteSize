import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/dietary_preferences.dart';
import '../models/health_log.dart';
import '../models/llm_config.dart';
import '../models/nutrition.dart';
import '../services/date_utils.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import '../widgets/bitesize_logo.dart';
import '../widgets/user_profile_sheet.dart';
import 'achievements_screen.dart';

/// Settings screen for LLM providers, secure BYOK keys, daily targets, and data.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late LlmProviderType _provider;
  late final TextEditingController _geminiModelCtrl;
  late final TextEditingController _groqModelCtrl;
  late final TextEditingController _openAiUrlCtrl;
  late final TextEditingController _openAiModelCtrl;
  late final TextEditingController _ollamaUrlCtrl;
  late final TextEditingController _ollamaModelCtrl;
  late final TextEditingController _apiKeyCtrl;

  late final TextEditingController _calGoalCtrl;
  late final TextEditingController _proteinGoalCtrl;
  late final TextEditingController _carbsGoalCtrl;
  late final TextEditingController _fatGoalCtrl;
  late final TextEditingController _fiberGoalCtrl;
  late final TextEditingController _weightGoalCtrl;
  late final TextEditingController _dietaryNotesCtrl;

  bool _obscureKey = true;
  bool _testingConnection = false;
  bool _fetchingGeminiModels = false;
  bool _fetchingGroqModels = false;
  bool _fetchingOllamaModels = false;
  String? _connectionStatus;
  bool _connectionSuccess = false;
  List<String> _geminiModels = const [];
  List<String> _groqModels = const [];
  List<String> _ollamaModels = const [];

  bool _showGeminiModels = false;
  bool _showGroqModels = false;
  bool _showOllamaModels = false;

  bool _llmEngineExpanded = false;
  bool _profileExpanded = false;
  bool _targetsExpanded = false;
  bool _calorieBankingExpanded = false;
  bool _dietaryExpanded = false;
  bool _notificationsExpanded = false;
  bool _appearanceExpanded = false;
  bool _dashboardCustomizationExpanded = false;
  bool _dataManagementExpanded = false;

  @override
  void initState() {
    super.initState();
    final llm = widget.appState.llmSettings;
    final goals = widget.appState.goals;
    final useKg = widget.appState.prefs.useKg;

    _provider = llm.provider;
    _geminiModelCtrl = TextEditingController(text: llm.geminiModel);
    _groqModelCtrl = TextEditingController(text: llm.groqModel);
    _openAiUrlCtrl = TextEditingController(text: llm.openAiBaseUrl);
    _openAiModelCtrl = TextEditingController(text: llm.openAiModel);
    _ollamaUrlCtrl = TextEditingController(text: llm.ollamaBaseUrl);
    _ollamaModelCtrl = TextEditingController(text: llm.ollamaModel);
    _apiKeyCtrl = TextEditingController();

    _calGoalCtrl = TextEditingController(text: goals.calorieTarget.toString());
    _proteinGoalCtrl =
        TextEditingController(text: goals.proteinTargetG.toString());
    _carbsGoalCtrl = TextEditingController(text: goals.carbsTargetG.toString());
    _fatGoalCtrl = TextEditingController(text: goals.fatTargetG.toString());
    _fiberGoalCtrl = TextEditingController(text: goals.fiberTargetG.toString());
    final displayWeight = useKg
        ? goals.targetWeightKg
        : ZenDateUtils.kgToLb(goals.targetWeightKg);
    _weightGoalCtrl = TextEditingController(
      text: displayWeight.toStringAsFixed(1),
    );
    _dietaryNotesCtrl = TextEditingController(
      text: widget.appState.dietary.customNote,
    );

    _loadKeyForProvider(_provider);
  }

  @override
  void dispose() {
    _geminiModelCtrl.dispose();
    _groqModelCtrl.dispose();
    _openAiUrlCtrl.dispose();
    _openAiModelCtrl.dispose();
    _ollamaUrlCtrl.dispose();
    _ollamaModelCtrl.dispose();
    _apiKeyCtrl.dispose();
    _calGoalCtrl.dispose();
    _proteinGoalCtrl.dispose();
    _carbsGoalCtrl.dispose();
    _fatGoalCtrl.dispose();
    _fiberGoalCtrl.dispose();
    _weightGoalCtrl.dispose();
    _dietaryNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadKeyForProvider(LlmProviderType provider) async {
    final key = await widget.appState.readApiKey(provider) ?? '';
    if (!mounted) return;
    setState(() {
      _apiKeyCtrl.text = key;
      _connectionStatus = null;
    });
  }

  LlmSettings _draftLlmSettings() {
    return LlmSettings(
      provider: _provider,
      geminiModel: _geminiModelCtrl.text.trim().isEmpty
          ? LlmSettings.defaultGeminiModel
          : _geminiModelCtrl.text.trim(),
      groqModel: _groqModelCtrl.text.trim().isEmpty
          ? LlmSettings.defaultGroqModel
          : _groqModelCtrl.text.trim(),
      groqBaseUrl: LlmSettings.defaultGroqBaseUrl,
      openAiBaseUrl: _openAiUrlCtrl.text.trim().isEmpty
          ? LlmSettings.defaultOpenAiBaseUrl
          : _openAiUrlCtrl.text.trim(),
      openAiModel: _openAiModelCtrl.text.trim().isEmpty
          ? LlmSettings.defaultOpenAiModel
          : _openAiModelCtrl.text.trim(),
      ollamaBaseUrl: _ollamaUrlCtrl.text.trim().isEmpty
          ? LlmSettings.defaultOllamaBaseUrl
          : _ollamaUrlCtrl.text.trim(),
      ollamaModel: _ollamaModelCtrl.text.trim().isEmpty
          ? LlmSettings.defaultOllamaModel
          : _ollamaModelCtrl.text.trim(),
    );
  }

  Future<void> _saveLlmConfig({bool showToast = true}) async {
    final next = _draftLlmSettings();
    await widget.appState.updateLlmSettings(next);
    await widget.appState.saveApiKey(_provider, _apiKeyCtrl.text);
    if (!mounted) return;
    if (showToast) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${next.provider.displayName} (${next.activeModel}) securely on device',
          ),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    await _saveLlmConfig(showToast: false);
    if (!mounted) return;
    setState(() {
      _testingConnection = true;
      _connectionStatus = null;
    });
    try {
      final msg = await widget.appState.testLlmConnection();
      if (!mounted) return;
      setState(() {
        _testingConnection = false;
        _connectionSuccess = true;
        _connectionStatus = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testingConnection = false;
        _connectionSuccess = false;
        _connectionStatus = e.toString();
      });
    }
  }

  Future<void> _fetchGeminiModels() async {
    await _saveLlmConfig(showToast: false);
    if (!mounted) return;
    setState(() {
      _fetchingGeminiModels = true;
      _connectionStatus = null;
    });
    try {
      final models = await widget.appState.fetchGeminiModels();
      if (!mounted) return;
      setState(() {
        _fetchingGeminiModels = false;
        _geminiModels = models;
        _showGeminiModels = true;
        if (models.isNotEmpty && !models.contains(_geminiModelCtrl.text.trim())) {
          final flash = models.firstWhere(
            (m) => m.contains('flash'),
            orElse: () => models.first,
          );
          _geminiModelCtrl.text = flash;
        }
        _connectionSuccess = true;
        _connectionStatus = models.isEmpty
            ? 'Connected, but no models found.'
            : 'Found ${models.length} authorized Gemini model(s) for your key.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchingGeminiModels = false;
        _connectionSuccess = false;
        _connectionStatus = e.toString();
      });
    }
  }

  Future<void> _fetchGroqModels() async {
    await _saveLlmConfig(showToast: false);
    if (!mounted) return;
    setState(() {
      _fetchingGroqModels = true;
      _connectionStatus = null;
    });
    try {
      final models = await widget.appState.fetchGroqModels();
      if (!mounted) return;
      setState(() {
        _fetchingGroqModels = false;
        _groqModels = models;
        _showGroqModels = true;
        _connectionSuccess = true;
        _connectionStatus = models.isEmpty
            ? 'Connected to Groq.'
            : 'Found ${models.length} Groq model(s).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchingGroqModels = false;
        _connectionSuccess = false;
        _connectionStatus = e.toString();
      });
    }
  }

  Future<void> _fetchOllamaModels() async {
    await _saveLlmConfig(showToast: false);
    if (!mounted) return;
    setState(() {
      _fetchingOllamaModels = true;
      _connectionStatus = null;
    });
    try {
      final models = await widget.appState.fetchOllamaModels();
      if (!mounted) return;
      setState(() {
        _fetchingOllamaModels = false;
        _ollamaModels = models;
        _showOllamaModels = true;
        if (models.isNotEmpty && !models.contains(_ollamaModelCtrl.text.trim())) {
          _ollamaModelCtrl.text = models.first;
        }
        _connectionSuccess = true;
        _connectionStatus = models.isEmpty
            ? 'Connected, but no models found in Ollama.'
            : 'Found ${models.length} installed Ollama model(s).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchingOllamaModels = false;
        _connectionSuccess = false;
        _connectionStatus = e.toString();
      });
    }
  }

  Future<void> _saveGoals() async {
    final useKg = widget.appState.prefs.useKg;
    final enteredWeight = parseNonNegativeDouble(
      _weightGoalCtrl.text,
      fallback: 68.0,
    );
    final weightKg = useKg ? enteredWeight : ZenDateUtils.lbToKg(enteredWeight);

    final next = DailyGoals(
      calorieTarget:
          parseNonNegativeDouble(_calGoalCtrl.text, fallback: 2000).round().clamp(800, 7000),
      proteinTargetG:
          parseNonNegativeDouble(_proteinGoalCtrl.text, fallback: 130).round().clamp(20, 450),
      carbsTargetG:
          parseNonNegativeDouble(_carbsGoalCtrl.text, fallback: 220).round().clamp(20, 800),
      fatTargetG:
          parseNonNegativeDouble(_fatGoalCtrl.text, fallback: 67).round().clamp(15, 300),
      fiberTargetG:
          parseNonNegativeDouble(_fiberGoalCtrl.text, fallback: 28).round().clamp(10, 100),
      waterTargetMl: widget.appState.goals.waterTargetMl,
      targetWeightKg: weightKg.clamp(30.0, 250.0),
    );
    await widget.appState.updateGoals(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Daily nutrition targets updated')),
    );
  }

  void _autoBalanceMacros() {
    final kcal =
        parseNonNegativeDouble(_calGoalCtrl.text, fallback: 2000).round();
    final balanced = DailyGoals.balancedForCalories(kcal);
    setState(() {
      _proteinGoalCtrl.text = balanced.proteinTargetG.toString();
      _carbsGoalCtrl.text = balanced.carbsTargetG.toString();
      _fatGoalCtrl.text = balanced.fatTargetG.toString();
      _fiberGoalCtrl.text = balanced.fiberTargetG.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;
    final prefs = widget.appState.prefs;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: zen.surfaceSubtle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: zen.borderSoft, width: 1),
          ),
          child: Row(
            children: [
              const BiteSizeLogo(size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Bite',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: zen.inkPrimary,
                                  letterSpacing: -0.4,
                                ),
                          ),
                          TextSpan(
                            text: 'Size',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: zen.sage,
                                  letterSpacing: -0.4,
                                ),
                          ),
                          TextSpan(
                            text: '  ULTRA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: zen.carbs,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Evidence-Based Metabolic & Nutrition Intelligence',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: zen.inkMuted,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bring your own LLM key — stored encrypted on your device.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: zen.inkMuted),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _llmEngineExpanded = !_llmEngineExpanded),
                  child: Row(
                    children: [
                      Icon(Icons.psychology_outlined, color: zen.sage, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LLM Calorie Engine',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              '${_provider.displayName} · ${_draftLlmSettings().activeModel}',
                              style: TextStyle(fontSize: 11, color: zen.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _llmEngineExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: zen.inkMuted,
                      ),
                    ],
                  ),
                ),
                if (_llmEngineExpanded) ...[
                  const SizedBox(height: 14),
                  // Logo-based provider selector
                  Row(
                    children: LlmProviderType.values.map((p) {
                      final isSelected = _provider == p;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              ZenHaptics.selection();
                              setState(() => _provider = p);
                              _loadKeyForProvider(p);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _getProviderAccentColor(p).withValues(alpha: 0.12)
                                    : zen.surfaceSubtle,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? _getProviderAccentColor(p)
                                      : zen.borderSoft,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: _getProviderAccentColor(p).withValues(alpha: 0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildProviderLogoBadge(p, isSelected),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? _getProviderAccentColor(p)
                                          : Colors.transparent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Selected Provider Header Banner (displays name and description on click)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: zen.surfaceSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _getProviderAccentColor(_provider).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildProviderLogoBadge(_provider, true, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _provider.displayName,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getProviderAccentColor(_provider).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _getProviderTag(_provider),
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: _getProviderAccentColor(_provider),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _provider.subtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: zen.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                if (_provider == LlmProviderType.gemini) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _geminiModelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Gemini Model ID',
                            hintText: 'gemini-2.0-flash-lite',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _fetchingGeminiModels ? null : _fetchGeminiModels,
                        icon: _fetchingGeminiModels
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded, size: 16),
                        label: const Text('Detect'),
                      ),
                    ],
                  ),
                  _buildModelChipsSection(
                    context: context,
                    title: 'Gemini Models',
                    models: _geminiModels,
                    currentModel: _geminiModelCtrl.text.trim(),
                    isExpanded: _showGeminiModels,
                    onToggleExpanded: () => setState(() => _showGeminiModels = !_showGeminiModels),
                    onSelectModel: (m) => setState(() => _geminiModelCtrl.text = m),
                  ),
                  const SizedBox(height: 12),
                  _buildApiKeyField(
                    label: 'Gemini API Key',
                    hint: 'AIza...',
                  ),
                ] else if (_provider == LlmProviderType.groq) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _groqModelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Groq Model ID',
                            hintText: 'llama-3.3-70b-versatile',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _fetchingGroqModels ? null : _fetchGroqModels,
                        icon: _fetchingGroqModels
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded, size: 16),
                        label: const Text('Detect'),
                      ),
                    ],
                  ),
                  _buildModelChipsSection(
                    context: context,
                    title: 'Groq Models',
                    models: _groqModels,
                    currentModel: _groqModelCtrl.text.trim(),
                    isExpanded: _showGroqModels,
                    onToggleExpanded: () => setState(() => _showGroqModels = !_showGroqModels),
                    onSelectModel: (m) => setState(() => _groqModelCtrl.text = m),
                  ),
                  const SizedBox(height: 12),
                  _buildApiKeyField(
                    label: 'Groq API Key',
                    hint: 'gsk_...',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Get your free key from console.groq.com. Groq runs on specialized LPU hardware delivering sub-second meal estimation (~500 tokens/sec).',
                    style: TextStyle(fontSize: 11, color: zen.inkMuted),
                  ),
                ] else if (_provider == LlmProviderType.openAiCompatible) ...[
                  TextField(
                    controller: _openAiUrlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://api.openai.com/v1',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
                      (
                        'OpenRouter',
                        'https://openrouter.ai/api/v1',
                        'google/gemini-2.5-flash',
                      ),
                      (
                        'Groq',
                        'https://api.groq.com/openai/v1',
                        'meta-llama/llama-4-scout-17b-16e-instruct',
                      ),
                    ].map((preset) {
                      return ActionChip(
                        label: Text(preset.$1),
                        onPressed: () => setState(() {
                          _openAiUrlCtrl.text = preset.$2;
                          _openAiModelCtrl.text = preset.$3;
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _openAiModelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Model ID',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildApiKeyField(
                    label: 'API Key',
                    hint: 'sk-...',
                  ),
                ] else ...[
                  TextField(
                    controller: _ollamaUrlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Ollama Server URL',
                      hintText: 'http://10.0.2.2:11434',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tip: Use http://10.0.2.2:11434 on Android Emulator, or http://<PC-LAN-IP>:11434 on a physical device.',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: zen.inkMuted),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ollamaModelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ollama Model',
                            hintText: 'llama3.2-vision',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed:
                            _fetchingOllamaModels ? null : _fetchOllamaModels,
                        icon: _fetchingOllamaModels
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Fetch'),
                      ),
                    ],
                  ),
                  _buildModelChipsSection(
                    context: context,
                    title: 'Ollama Models',
                    models: _ollamaModels,
                    currentModel: _ollamaModelCtrl.text.trim(),
                    isExpanded: _showOllamaModels,
                    onToggleExpanded: () => setState(() => _showOllamaModels = !_showOllamaModels),
                    onSelectModel: (m) => setState(() => _ollamaModelCtrl.text = m),
                  ),
                  const SizedBox(height: 12),
                  _buildApiKeyField(
                    label: 'Bearer Token (optional proxy auth)',
                    hint: 'Leave blank for local Ollama',
                  ),
                ],
                if (_connectionStatus != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_connectionSuccess ? zen.sage : zen.gentleClay)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _connectionStatus!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _connectionSuccess
                                ? zen.sage
                                : zen.gentleClay,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testingConnection ? null : _testConnection,
                        icon: _testingConnection
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.bolt_rounded, size: 18),
                        label: const Text('Test'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _saveLlmConfig,
                        icon: const Icon(Icons.lock_outline_rounded, size: 18),
                        label: const Text('Save Provider'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _profileExpanded = !_profileExpanded),
                  child: Row(
                    children: [
                      Icon(Icons.person_pin_rounded, color: zen.sage, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personal Profile',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (!_profileExpanded && widget.appState.profile.isConfigured)
                              Text(
                                '${widget.appState.profile.sexLabel} · ${widget.appState.profile.age}y · ${widget.appState.profile.weightKg.toStringAsFixed(1)}kg',
                                style: TextStyle(fontSize: 11, color: zen.inkMuted),
                              ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => showUserProfileSheet(context, appState: widget.appState),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: Text(widget.appState.profile.isConfigured ? 'Edit' : 'Configure'),
                      ),
                      Icon(
                        _profileExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: zen.inkMuted,
                      ),
                    ],
                  ),
                ),
                if (_profileExpanded) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Your biological sex, age, height, and weight are saved here and automatically populate all fitness calculators.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: zen.inkMuted),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: zen.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: zen.borderSoft),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildProfileStat('Sex', widget.appState.profile.sexLabel, zen),
                        _buildProfileStat('Age', '${widget.appState.profile.age}y', zen),
                        _buildProfileStat('Height', '${widget.appState.profile.heightCm.toStringAsFixed(0)}cm', zen),
                        _buildProfileStat('Weight', '${widget.appState.profile.weightKg.toStringAsFixed(1)}kg', zen),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _targetsExpanded = !_targetsExpanded),
                  child: Row(
                    children: [
                      Icon(Icons.track_changes_rounded, color: zen.sage, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Targets',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              '${_calGoalCtrl.text} kcal · ${_proteinGoalCtrl.text}g P · ${_carbsGoalCtrl.text}g C · ${_fatGoalCtrl.text}g F',
                              style: TextStyle(fontSize: 11, color: zen.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      if (_targetsExpanded)
                        TextButton(
                          onPressed: _autoBalanceMacros,
                          child: const Text('Auto-balance'),
                        ),
                      Icon(
                        _targetsExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: zen.inkMuted,
                      ),
                    ],
                  ),
                ),
                if (_targetsExpanded) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _calGoalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Daily Calorie Target (kcal)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _proteinGoalCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Protein (g)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _carbsGoalCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Carbs (g)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _fatGoalCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Fat (g)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fiberGoalCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Fiber (g)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _weightGoalCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                'Goal Weight (${prefs.useKg ? 'kg' : 'lb'})',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saveGoals,
                      child: const Text('Update Daily Targets'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildCalorieBankingCard(context),
        const SizedBox(height: 14),
        _buildDietaryPreferencesCard(context),
        const SizedBox(height: 14),
        _buildNotificationsCard(context),
        const SizedBox(height: 14),
        _buildAchievementsCard(context),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _appearanceExpanded = !_appearanceExpanded),
                  child: Row(
                    children: [
                      Icon(Icons.palette_outlined, color: zen.sage, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appearance & Units',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              '${prefs.themeMode.name.toUpperCase()} · ${prefs.useKg ? 'Kilograms (kg)' : 'Pounds (lb)'}',
                              style: TextStyle(fontSize: 11, color: zen.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _appearanceExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: zen.inkMuted,
                      ),
                    ],
                  ),
                ),
                if (_appearanceExpanded) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Obsidian'),
                      ),
                    ],
                    selected: {prefs.themeMode},
                    onSelectionChanged: (sel) => appStateUpdatePrefs(
                      prefs.copyWith(themeMode: sel.first),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use kilograms (kg)'),
                    subtitle: Text(prefs.useKg ? 'Kilograms' : 'Pounds (lb)'),
                    value: prefs.useKg,
                    onChanged: (val) async {
                      final current = parseNonNegativeDouble(
                        _weightGoalCtrl.text,
                        fallback: 68.0,
                      );
                      final converted = val
                          ? ZenDateUtils.lbToKg(current)
                          : ZenDateUtils.kgToLb(current);
                      _weightGoalCtrl.text = converted.toStringAsFixed(1);
                      await appStateUpdatePrefs(prefs.copyWith(useKg: val));
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildDashboardCustomizationCard(context),
        const SizedBox(height: 14),
        _buildDataManagementCard(context),
      ],
    );
  }

  Future<void> appStateUpdatePrefs(UserPreferences next) =>
      widget.appState.updateUserPreferences(next);

  Widget _buildDashboardCustomizationCard(BuildContext context) {
    final zen = context.zen;
    final prefs = widget.appState.prefs;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _dashboardCustomizationExpanded = !_dashboardCustomizationExpanded),
              child: Row(
                children: [
                  Icon(Icons.dashboard_customize_outlined, size: 20, color: zen.sage),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard Layout & Widgets',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          'Customize which cards and modules appear on Today',
                          style: TextStyle(fontSize: 11, color: zen.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _dashboardCustomizationExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: zen.inkMuted,
                  ),
                ],
              ),
            ),
            if (_dashboardCustomizationExpanded) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Macro Progress Card'),
                subtitle: const Text('Carbs, Protein & Fat daily progress bars'),
                value: prefs.showMacroCard,
                onChanged: (val) => appStateUpdatePrefs(prefs.copyWith(showMacroCard: val)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hydration Tracking Card'),
                subtitle: const Text('Compact 1-tap water intake bar with customizable target'),
                value: prefs.showHydrationCard,
                onChanged: (val) => appStateUpdatePrefs(prefs.copyWith(showHydrationCard: val)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Quick Bites 1-Tap Bar'),
                subtitle: const Text('Horizontal shortcut row for frequent snacks & coffee'),
                value: prefs.showQuickBites,
                onChanged: (val) => appStateUpdatePrefs(prefs.copyWith(showQuickBites: val)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Today's Plates Filmstrip"),
                subtitle: const Text('Visual photo thumbnails gallery of logged meals'),
                value: prefs.showTodaysPlates,
                onChanged: (val) => appStateUpdatePrefs(prefs.copyWith(showTodaysPlates: val)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStat(String label, String value, ZenColors zen) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: zen.inkMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: zen.sage,
          ),
        ),
      ],
    );
  }

  Widget _buildModelChipsSection({
    required BuildContext context,
    required String title,
    required List<String> models,
    required String currentModel,
    required bool isExpanded,
    required VoidCallback onToggleExpanded,
    required ValueChanged<String> onSelectModel,
  }) {
    final zen = context.zen;
    final isCustomList = models.isNotEmpty;
    final displayModels = isCustomList
        ? models
        : (title.contains('Gemini')
            ? const [
                'gemini-2.0-flash-lite',
                'gemini-2.0-flash',
                'gemini-1.5-flash',
                'gemini-2.5-flash',
              ]
            : title.contains('Groq')
                ? const [
                    'llama-3.3-70b-versatile',
                    'llama-3.1-8b-instant',
                    'llama-3.2-11b-vision-preview',
                    'mixtral-8x7b-32768',
                  ]
                : const ['llama3.2-vision', 'qwen2.5vl:7b', 'gemma3:4b']);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_outlined, size: 14, color: zen.sage),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$title (${displayModels.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: zen.inkPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                ),
                onPressed: onToggleExpanded,
                icon: Icon(
                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 16,
                  color: zen.sage,
                ),
                label: Text(
                  isExpanded ? 'Collapse' : 'Show',
                  style: TextStyle(fontSize: 11, color: zen.sage, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Close / Hide models',
                color: zen.inkMuted,
                onPressed: onToggleExpanded,
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: displayModels.map((m) {
                    final selected = m == currentModel;
                    return ActionChip(
                      label: Text(
                        m,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected ? zen.sage : zen.inkPrimary,
                        ),
                      ),
                      backgroundColor: selected ? zen.sageSoft : null,
                      side: BorderSide(
                        color: selected ? zen.sage.withValues(alpha: 0.45) : zen.borderSoft,
                      ),
                      onPressed: () {
                        ZenHaptics.selection();
                        onSelectModel(m);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getProviderAccentColor(LlmProviderType type) {
    switch (type) {
      case LlmProviderType.gemini:
        return const Color(0xFF4285F4); // Google Blue
      case LlmProviderType.groq:
        return const Color(0xFFFF5722); // Groq Orange
      case LlmProviderType.openAiCompatible:
        return const Color(0xFF10A37F); // OpenAI Emerald
      case LlmProviderType.ollama:
        return const Color(0xFF94A3B8); // Ollama Slate
    }
  }

  String _getProviderTag(LlmProviderType type) {
    switch (type) {
      case LlmProviderType.gemini:
        return 'RECOMMENDED';
      case LlmProviderType.groq:
        return 'ULTRA-FAST ⚡';
      case LlmProviderType.openAiCompatible:
        return 'COMPATIBLE';
      case LlmProviderType.ollama:
        return 'LOCAL & PRIVATE';
    }
  }

  Widget _buildProviderLogoBadge(LlmProviderType type, bool isSelected, {double size = 32}) {
    final color = _getProviderAccentColor(type);
    switch (type) {
      case LlmProviderType.gemini:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF4285F4), Color(0xFF9B72CF), Color(0xFF2DD4BF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: size * 0.58,
          ),
        );
      case LlmProviderType.groq:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7A45), Color(0xFFF05238)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.bolt_rounded,
            color: Colors.white,
            size: size * 0.65,
          ),
        );
      case LlmProviderType.openAiCompatible:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10A37F),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.hub_rounded,
            color: Colors.white,
            size: size * 0.58,
          ),
        );
      case LlmProviderType.ollama:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF334155), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.terminal_rounded,
            color: Colors.white,
            size: size * 0.58,
          ),
        );
    }
  }

  Widget _buildApiKeyField({required String label, required String hint}) {
    return TextField(
      controller: _apiKeyCtrl,
      obscureText: _obscureKey,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
            if (_apiKeyCtrl.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded),
                tooltip: 'Clear key',
                onPressed: () => setState(() => _apiKeyCtrl.clear()),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all logs?'),
        content: const Text(
          'This removes all meal logs and weight history. Your API keys and targets stay intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.appState.clearAllData();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All meal logs and weight history cleared')),
      );
    }
  }

  Widget _buildDietaryPreferencesCard(BuildContext context) {
    final zen = context.zen;
    final dietary = widget.appState.dietary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _dietaryExpanded = !_dietaryExpanded),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: zen.sageSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('🥗', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dietary Preferences & Allergies',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          '${dietary.dietType.label} · ${dietary.allergies.isEmpty ? 'No allergens' : dietary.allergies.join(", ")}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: zen.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _dietaryExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: zen.inkMuted,
                  ),
                ],
              ),
            ),
            if (_dietaryExpanded) ...[
              const SizedBox(height: 14),
              Text(
                'Diet Type:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: zen.inkPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: DietType.values.map((type) {
                  final selected = type == dietary.dietType;
                  return ChoiceChip(
                    label: Text(type.label),
                    selected: selected,
                    onSelected: (val) {
                      if (val) {
                        widget.appState.updateDietaryPreferences(
                          dietary.copyWith(dietType: type),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text(
                'Allergies & Food Avoidances:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: zen.inkPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Gluten-Free',
                  'Dairy-Free',
                  'Nut-Free',
                  'Peanut-Free',
                  'Soy-Free',
                  'Egg-Free',
                  'Low-Oil',
                  'No Beef',
                  'No Pork',
                  'Jain Friendly',
                ].map((allergy) {
                  final selected = dietary.allergies.contains(allergy);
                  return FilterChip(
                    label: Text(allergy),
                    selected: selected,
                    onSelected: (val) {
                      final current = List<String>.from(dietary.allergies);
                      if (val) {
                        current.add(allergy);
                      } else {
                        current.remove(allergy);
                      }
                      widget.appState.updateDietaryPreferences(
                        dietary.copyWith(allergies: current),
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _dietaryNotesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Special Dietary Notes or Instructions',
                  hintText:
                      'e.g. Prefer homemade Tamil Nadu style, less coconut, high satiety',
                ),
                onChanged: (text) {
                  widget.appState.updateDietaryPreferences(
                    dietary.copyWith(customNote: text),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsCard(BuildContext context) {
    final zen = context.zen;
    final notifs = widget.appState.notifications;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _notificationsExpanded = !_notificationsExpanded),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: zen.sageSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.notifications_active_outlined,
                        color: zen.sage, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reminders & Push Alerts',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          notifs.enabled ? 'Enabled · Meal, fasting & water timers' : 'Disabled',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: zen.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _notificationsExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: zen.inkMuted,
                  ),
                ],
              ),
            ),
            if (_notificationsExpanded) ...[
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Enable Reminders & Alerts',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Master control for all BiteSize notifications'),
                value: notifs.enabled,
                onChanged: (val) async {
                  if (val) {
                    await widget.appState.notificationService.requestPermissions();
                  }
                  await widget.appState.updateNotificationSettings(
                    notifs.copyWith(enabled: val),
                  );
                },
              ),
            if (notifs.enabled) ...[
              const Divider(height: 24),
              Text(
                'Meal Logging Timers',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: zen.sage,
                    ),
              ),
              const SizedBox(height: 8),
              _buildReminderTile(
                context,
                title: 'Breakfast Reminder',
                enabled: notifs.breakfastReminder,
                hour: notifs.breakfastHour,
                minute: notifs.breakfastMinute,
                onToggle: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(breakfastReminder: val),
                ),
                onTimeChanged: (h, m) =>
                    widget.appState.updateNotificationSettings(
                  notifs.copyWith(breakfastHour: h, breakfastMinute: m),
                ),
              ),
              _buildReminderTile(
                context,
                title: 'Lunch Reminder',
                enabled: notifs.lunchReminder,
                hour: notifs.lunchHour,
                minute: notifs.lunchMinute,
                onToggle: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(lunchReminder: val),
                ),
                onTimeChanged: (h, m) =>
                    widget.appState.updateNotificationSettings(
                  notifs.copyWith(lunchHour: h, lunchMinute: m),
                ),
              ),
              _buildReminderTile(
                context,
                title: 'Dinner Reminder',
                enabled: notifs.dinnerReminder,
                hour: notifs.dinnerHour,
                minute: notifs.dinnerMinute,
                onToggle: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(dinnerReminder: val),
                ),
                onTimeChanged: (h, m) =>
                    widget.appState.updateNotificationSettings(
                  notifs.copyWith(dinnerHour: h, dinnerMinute: m),
                ),
              ),
              const Divider(height: 24),
              Text(
                'Intermittent Fasting Alerts',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: zen.carbs,
                    ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Live Status Bar Fasting Tracker'),
                subtitle: const Text(
                  'Glanceable ongoing status bar timer showing elapsed hours and metabolic stage',
                ),
                value: notifs.fastingOngoingNotification,
                onChanged: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(fastingOngoingNotification: val),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Metabolic Stage Transitions'),
                subtitle: const Text(
                  'Alerts when entering Glycogen Depletion, Ketosis & Autophagy',
                ),
                value: notifs.fastingStageTransitionAlert,
                onChanged: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(fastingStageTransitionAlert: val),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fasting Goal Reached'),
                subtitle: const Text(
                  'Alerts when your selected fasting window is complete',
                ),
                value: notifs.fastingTargetReachedAlert,
                onChanged: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(fastingTargetReachedAlert: val),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Eating Window Closing'),
                subtitle: const Text(
                  'Reminds you 30 minutes before your eating window closes',
                ),
                value: notifs.fastingWindowClosingAlert,
                onChanged: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(fastingWindowClosingAlert: val),
                ),
              ),
              const Divider(height: 24),
              Text(
                'Hydration Reminders',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: zen.protein,
                    ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Interval Water Reminder'),
                subtitle: Text(
                  'Nudges you every ${notifs.hydrationIntervalHours} hour${notifs.hydrationIntervalHours > 1 ? 's' : ''} during the day',
                ),
                value: notifs.hydrationReminder,
                onChanged: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(hydrationReminder: val),
                ),
              ),
              if (notifs.hydrationReminder) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Row(
                    children: [
                      const Text('Interval: ', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      ...[1, 2, 3].map((hours) {
                        final sel = notifs.hydrationIntervalHours == hours;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('${hours}h'),
                            selected: sel,
                            visualDensity: VisualDensity.compact,
                            onSelected: (val) {
                              if (val) {
                                widget.appState.updateNotificationSettings(
                                  notifs.copyWith(hydrationIntervalHours: hours),
                                );
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
              const Divider(height: 24),
              Text(
                'Calorie & Habit Alerts',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: zen.carbs,
                    ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Under-Fueling Warning'),
                subtitle: const Text(
                  'Alerts at 6:00 PM if logged calories are below 55% of your target',
                ),
                value: notifs.underCalorieAlert,
                onChanged: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(underCalorieAlert: val),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Over-Calorie Warning'),
                subtitle: const Text(
                  'Alerts immediately when you exceed your daily calorie budget',
                ),
                value: notifs.overCalorieAlert,
                onChanged: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(overCalorieAlert: val),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Weekend Banking Bonus Alert'),
                subtitle: const Text(
                  'Notifies Saturday morning of your unlocked calorie bonus',
                ),
                value: notifs.weekendBankingAlert,
                onChanged: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(weekendBankingAlert: val),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Evening Daily Debrief'),
                subtitle: const Text(
                  'Nudges you at 8:30 PM to review daily macros and nutrition score',
                ),
                value: notifs.eveningDebriefReminder,
                onChanged: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(eveningDebriefReminder: val),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Streak Protector'),
                subtitle: const Text(
                  'Nudges you at 9:30 PM if no meals have been logged today',
                ),
                value: notifs.streakProtection,
                onChanged: (val) => widget.appState.updateNotificationSettings(
                  notifs.copyWith(streakProtection: val),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Test Live In-App Alerts:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: zen.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final granted = await widget.appState.notificationService.requestPermissions();
                      await widget.appState.notificationService.showImmediateNotification(
                        id: 999,
                        title: 'BiteSize Notification Test 🔔',
                        body: 'Mobile push notifications are working on your device!',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              granted
                                  ? 'Test push notification sent to status bar!'
                                  : 'Notification sent. Note: Notification permissions may need to be enabled in Android Settings.',
                            ),
                            backgroundColor: zen.sage,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.notifications_active_rounded, size: 14),
                    label: const Text('Test Mobile Push Notification'),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: zen.carbs.withValues(alpha: 0.18),
                      foregroundColor: zen.carbs,
                    ),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await widget.appState.notificationService.requestPermissions();
                      await widget.appState.notificationService.showTestFastingNotification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Persistent Fasting Notification posted! Pull down status bar to view.',
                            ),
                            backgroundColor: zen.sage,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.timer_rounded, size: 14),
                    label: const Text('Test Persistent Fasting Notification'),
                  ),
                  if (!widget.appState.fasting.isActive)
                    TextButton.icon(
                      onPressed: () async {
                        await widget.appState.notificationService.cancelOngoingFastingNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cleared test persistent notification.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.clear_rounded, size: 14),
                      label: const Text('Dismiss Fasting Notification'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.appState.triggerNotification(
                        const CalorieAlert(
                          title: 'Metabolic Shift: Ketosis Reached!',
                          message:
                              '12 hours elapsed. Liver glycogen is depleted; fat oxidation and ketone production have surged.',
                          isOver: false,
                          severity: 'info',
                        ),
                      );
                    },
                    icon: const Icon(Icons.hub_outlined, size: 14),
                    label: const Text('Fasting Alert'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.appState.triggerNotification(
                        const CalorieAlert(
                          title: 'Hydration Check',
                          message:
                              'Time for a glass of water (250ml) to keep hydration and metabolism optimal.',
                          isOver: false,
                          severity: 'info',
                        ),
                      );
                    },
                    icon: const Icon(Icons.water_drop_outlined, size: 14),
                    label: const Text('Hydration Alert'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.appState.triggerNotification(
                        const CalorieAlert(
                          title: 'Calorie Budget Exceeded',
                          message:
                              'You are 140 kcal over your target. No worries! Adjust dinner portions to balance your weekly average.',
                          isOver: true,
                          severity: 'warning',
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_fire_department_rounded, size: 14),
                    label: const Text('Calorie Alert'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.appState.triggerNotification(
                        const CalorieAlert(
                          title: 'Protect Your 7-Day Streak!',
                          message:
                              'You haven\'t logged any meals today yet. Log lunch or a quick bite before midnight to keep your streak!',
                          isOver: false,
                          severity: 'warning',
                        ),
                      );
                    },
                    icon: const Icon(Icons.shield_outlined, size: 14),
                    label: const Text('Streak Alert'),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

  Widget _buildAchievementsCard(BuildContext context) {
    final zen = context.zen;
    final unlocked = widget.appState.unlockedAchievementsCount;
    final total = widget.appState.totalAchievementsCount;
    final ratio = total > 0 ? (unlocked / total) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: zen.carbs.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.emoji_events_rounded, color: zen.carbs, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Achievements & Trophies',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gamified badges for habit streaks, fasting & macros',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: zen.inkMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: zen.sage.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: zen.sage.withOpacity(0.4)),
                  ),
                  child: Text(
                    '$unlocked / $total',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: zen.sage,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: zen.borderSoft,
                valueColor: AlwaysStoppedAnimation<Color>(zen.carbs),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AchievementsScreen(appState: widget.appState),
                    ),
                  );
                },
                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                label: const Text(
                  'Open Trophy Collection',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementCard(BuildContext context) {
    final zen = context.zen;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _dataManagementExpanded = !_dataManagementExpanded),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: zen.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.shield_outlined, color: zen.sage, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Backup & Privacy',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          'Offline privacy: Export or restore your entire app state anytime',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: zen.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _dataManagementExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: zen.inkMuted,
                  ),
                ],
              ),
            ),
            if (_dataManagementExpanded) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportBackupJson(context),
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Export JSON'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _importBackupJsonDialog(context),
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: const Text('Import JSON'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportMealsCsv(context),
                      icon: const Icon(Icons.table_chart_outlined, size: 18),
                      label: const Text('Export Meals (CSV)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await widget.appState.loadSampleData();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Loaded sample meals & trends'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                      label: const Text('Load Sample Day'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmReset(context),
                  icon: Icon(
                    Icons.delete_sweep_outlined,
                    size: 18,
                    color: zen.gentleClay,
                  ),
                  label: Text(
                    'Clear All Logs',
                    style: TextStyle(color: zen.gentleClay),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackupJson(BuildContext context) async {
    final jsonStr = await widget.appState.exportBackupJson();
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup Exported (JSON)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your entire BiteSize backup (profile, dietary preferences, daily targets, calorie banking, fasting history, saved combos, and meal logs) has been copied to your clipboard.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ctx.zen.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Size: ${jsonStr.length} characters (${(jsonStr.length / 1024).toStringAsFixed(1)} KB)',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _importBackupJsonDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Backup (JSON)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your exported BiteSize JSON backup below to restore your profile, targets, history, and meals:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '{"version": 1, "profile": ...}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Data'),
          ),
        ],
      ),
    );

    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      try {
        final count = await widget.appState.importBackupJson(ctrl.text.trim());
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully restored backup with $count meals!'),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import backup: $e')),
        );
      }
    }
  }

  Future<void> _exportMealsCsv(BuildContext context) async {
    final csvStr = await widget.appState.exportMealsCsv();
    await Clipboard.setData(ClipboardData(text: csvStr));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Meals CSV copied to clipboard! Ready to paste into Excel or Sheets.',
        ),
      ),
    );
  }

  Widget _buildReminderTile(
    BuildContext context, {
    required String title,
    required bool enabled,
    required int hour,
    required int minute,
    required ValueChanged<bool> onToggle,
    required void Function(int hour, int minute) onTimeChanged,
  }) {
    final zen = context.zen;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: enabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: hour, minute: minute),
                    );
                    if (picked != null) {
                      onTimeChanged(picked.hour, picked.minute);
                    }
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: enabled ? zen.surfaceSubtle : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: enabled ? zen.borderSoft : Colors.transparent,
                ),
              ),
              child: Text(
                ZenDateUtils.formatHourMinute(hour, minute),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: enabled ? zen.sage : zen.inkMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: enabled,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieBankingCard(BuildContext context) {
    final zen = context.zen;
    final bank = widget.appState.calorieBank;
    final baseTarget = widget.appState.goals.calorieTarget;
    final weekdayTarget = (baseTarget - bank.bankDailyKcal).clamp(1200, 10000);
    final weekendTarget = baseTarget + bank.weekendBonusPerDay;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _calorieBankingExpanded = !_calorieBankingExpanded),
              child: Row(
                children: [
                  Icon(Icons.savings_outlined, color: zen.sage, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekend Calorie Banking',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          bank.enabled
                              ? 'Active (-${bank.bankDailyKcal} kcal/day weekdays, +${bank.weekendBonusPerDay} kcal/day weekends)'
                              : 'Flexible weekday/weekend caloric budgeting',
                          style: TextStyle(fontSize: 11, color: zen.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: bank.enabled,
                    onChanged: (val) {
                      widget.appState.updateCalorieBankSettings(
                        bank.copyWith(enabled: val),
                      );
                    },
                  ),
                  Icon(
                    _calorieBankingExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: zen.inkMuted,
                  ),
                ],
              ),
            ),
            if (_calorieBankingExpanded) ...[
              const SizedBox(height: 6),
              Text(
                'Flexible Dieting: Save a small cushion of calories on weekdays (Mon–Fri) to enjoy a larger calorie budget on weekends (Sat–Sun) while keeping your weekly fat loss pace identical.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: zen.inkMuted),
              ),
              if (bank.enabled) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bank per weekday:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    '${bank.bankDailyKcal} kcal/day',
                    style: TextStyle(fontWeight: FontWeight.w800, color: zen.sage, fontSize: 13),
                  ),
                ],
              ),
              Slider(
                value: bank.bankDailyKcal.toDouble(),
                min: 50,
                max: 300,
                divisions: 10,
                label: '${bank.bankDailyKcal} kcal',
                onChanged: (val) {
                  widget.appState.updateCalorieBankSettings(
                    bank.copyWith(bankDailyKcal: val.round()),
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: zen.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: zen.borderSoft),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Weekday (Mon–Fri):', style: TextStyle(fontSize: 12)),
                        Text(
                          '$weekdayTarget kcal / day (-${bank.bankDailyKcal})',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: zen.inkPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Weekend (Sat–Sun):', style: TextStyle(fontSize: 12)),
                        Text(
                          '$weekendTarget kcal / day (+${bank.weekendBonusPerDay})',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: zen.sage),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    Text(
                      'Weekly deficit preserved: exactly ${baseTarget * 7} kcal/week. Zero impact on diet pacing!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: zen.inkMuted, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    ),
  );
}
}