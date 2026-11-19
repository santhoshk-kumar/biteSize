import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/health_log.dart';
import '../models/user_profile.dart';
import '../services/date_utils.dart';
import '../services/metabolic_analyzer.dart';
import '../services/zen_haptics.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';
import '../widgets/ai_markdown_view.dart';
import '../widgets/bitesize_logo.dart';
import '../widgets/user_profile_sheet.dart';

/// Evidence-based Fitness & Health Calculators powered by AI and user's saved personal profile.
class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Personal profile details auto-synced from AppState
  late bool _isMale;
  late double _weightKg;
  late double _heightCm;
  late int _age;

  // Body Fat specific measurements (cm)
  late double _neckCm;
  late double _waistCm;
  late double _hipCm;

  // Activity level for TDEE (1.2 to 2.2)
  double _activityFactor = 1.375;

  // Natural Language & AI Activity Profiler
  final TextEditingController _activityController = TextEditingController(
    text: 'Walk 5km every morning, desk job 8 hours, 15 min rope skip in evening',
  );
  bool _isAnalyzingActivity = false;
  AiMetabolicProfile? _activityProfile;

  // Customizable Fat Loss Planner
  late double _targetWeightKg;
  double _weeklyLossRateKg = 0.50; // 0.20 to 1.00 kg/week
  String _macroSplitType = 'high_protein'; // 'high_protein', 'balanced_indian', 'low_carb'
  bool _isGeneratingFatLossPlan = false;
  String? _fatLossPlan;
  bool _showWeeklyBreakdown = true;

  // AI South Asian Body Composition Diagnosis
  bool _isGeneratingDiagnosis = false;
  String? _bodyCompDiagnosis;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _syncFromProfile(widget.appState.profile);
  }

  @override
  void didUpdateWidget(CalculatorsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appState.profile != widget.appState.profile) {
      _syncFromProfile(widget.appState.profile);
    }
  }

  void _syncFromProfile(UserProfile p) {
    _isMale = p.isMale;
    _weightKg = p.weightKg > 0 ? p.weightKg : 68.0;
    _heightCm = p.heightCm > 0 ? p.heightCm : 172.0;
    _age = p.age > 0 ? p.age : 26;
    _neckCm = p.neckCm > 0 ? p.neckCm : 38.0;
    _waistCm = p.waistCm > 0 ? p.waistCm : 84.0;
    _hipCm = p.hipCm > 0 ? p.hipCm : 96.0;
    _targetWeightKg = math.max(35.0, _weightKg - 5.0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  // --- Calculations ---

  // BMI (WHO Standard & Asian/South Asian WHO criteria)
  double get _bmi {
    final heightM = _heightCm / 100.0;
    if (heightM <= 0) return 0.0;
    return _weightKg / (heightM * heightM);
  }

  String get _asianBmiCategory {
    final b = _bmi;
    if (b < 18.5) return 'Underweight';
    if (b < 23.0) return 'Normal (Healthy South Asian)';
    if (b < 27.5) return 'Overweight (Increased Risk)';
    return 'Obese (High Risk)';
  }

  Color _asianBmiColor(ZenColors zen) {
    final b = _bmi;
    if (b < 18.5) return zen.water;
    if (b < 23.0) return zen.sage;
    if (b < 27.5) return zen.carbs;
    return zen.gentleClay;
  }

  // Healthy weight range for height (Asian standard: 18.5 - 22.9)
  (double, double) get _healthyWeightRangeAsian {
    final heightM = _heightCm / 100.0;
    final min = 18.5 * heightM * heightM;
    final max = 22.9 * heightM * heightM;
    return (min, max);
  }

  // Body Fat % (U.S. Navy Method)
  double get _bodyFatPercentage {
    try {
      if (_isMale) {
        final diff = _waistCm - _neckCm;
        if (diff <= 0) return 15.0;
        final val = 86.010 * math.log(diff) / math.ln10 -
            70.041 * math.log(_heightCm) / math.ln10 +
            36.76;
        return val.clamp(3.0, 50.0);
      } else {
        final sum = _waistCm + _hipCm - _neckCm;
        if (sum <= 0) return 22.0;
        final val = 163.205 * math.log(sum) / math.ln10 -
            97.684 * math.log(_heightCm) / math.ln10 -
            78.387;
        return val.clamp(8.0, 55.0);
      }
    } catch (_) {
      return 18.0;
    }
  }

  double get _fatMassKg => _weightKg * (_bodyFatPercentage / 100.0);
  double get _leanMassKg => _weightKg - _fatMassKg;

  // BMR (Mifflin-St Jeor)
  double get _bmr {
    if (_isMale) {
      return (10 * _weightKg) + (6.25 * _heightCm) - (5 * _age) + 5;
    } else {
      return (10 * _weightKg) + (6.25 * _heightCm) - (5 * _age) - 161;
    }
  }

  // TDEE (Total Daily Energy Expenditure)
  double get _tdee => _bmr * _activityFactor;

  // --- Customizable Fat Loss Planner Helpers ---

  double get _fatToLoseKg => math.max(0.0, _weightKg - _targetWeightKg);
  double get _dailyDeficitKcal => (_weeklyLossRateKg * 7700.0) / 7.0; // 7700 kcal per kg of body fat
  int get _weeksToTarget => _weeklyLossRateKg > 0 ? (_fatToLoseKg / _weeklyLossRateKg).ceil() : 0;
  DateTime get _projectedTargetDate => DateTime.now().add(Duration(days: _weeksToTarget * 7));

  List<WeeklyLossForecast> get _weeklyForecasts {
    if (_weeksToTarget <= 0 || _weeklyLossRateKg <= 0) return const [];
    final list = <WeeklyLossForecast>[];
    final totalLossGoal = _fatToLoseKg;
    final numWeeks = math.min(_weeksToTarget, 52);
    final now = DateTime.now();

    for (int w = 1; w <= numWeeks; w++) {
      final weekDate = now.add(Duration(days: w * 7));
      final cumulativeLoss = math.min(totalLossGoal, w * _weeklyLossRateKg);
      final currentExpected = math.max(_targetWeightKg, _weightKg - cumulativeLoss);

      String? milestone;
      if (w == 1) {
        milestone = 'Initial shift & glycogen flush';
      } else if (currentExpected <= _targetWeightKg + 0.05 || w == numWeeks) {
        milestone = '🏆 Target Reached (${_targetWeightKg.toStringAsFixed(1)} kg)';
      } else if (totalLossGoal > 0) {
        final ratio = cumulativeLoss / totalLossGoal;
        if (ratio >= 0.75 && ratio < 0.75 + (_weeklyLossRateKg / totalLossGoal)) {
          milestone = '🥇 75% Done';
        } else if (ratio >= 0.50 && ratio < 0.50 + (_weeklyLossRateKg / totalLossGoal)) {
          milestone = '🌟 Halfway Point';
        } else if (ratio >= 0.25 && ratio < 0.25 + (_weeklyLossRateKg / totalLossGoal)) {
          milestone = '🎯 25% Achieved';
        }
      }

      list.add(WeeklyLossForecast(
        weekNumber: w,
        date: weekDate,
        expectedWeightKg: currentExpected,
        totalLostKg: cumulativeLoss,
        milestoneBadge: milestone,
      ));
    }
    return list;
  }

  double get _customDailyCalorieTarget {
    final raw = _tdee - _dailyDeficitKcal;
    return raw.clamp(1000.0, 4500.0);
  }

  // Macro split distribution
  (int, int, int) get _customMacroGrams {
    final cal = _customDailyCalorieTarget;
    switch (_macroSplitType) {
      case 'high_protein':
        final p = ((cal * 0.30) / 4).round();
        final c = ((cal * 0.40) / 4).round();
        final f = ((cal * 0.30) / 9).round();
        return (p, c, f);
      case 'low_carb':
        final p = ((cal * 0.25) / 4).round();
        final c = ((cal * 0.15) / 4).round();
        final f = ((cal * 0.60) / 9).round();
        return (p, c, f);
      case 'balanced_indian':
      default:
        final p = ((cal * 0.22) / 4).round();
        final c = ((cal * 0.48) / 4).round();
        final f = ((cal * 0.30) / 9).round();
        return (p, c, f);
    }
  }

  // --- Profile Sync Helper ---

  Future<void> _saveCurrentInputsToProfile() async {
    HapticFeedback.mediumImpact();
    final updated = UserProfile(
      isMale: _isMale,
      weightKg: _weightKg,
      heightCm: _heightCm,
      age: _age,
      neckCm: _neckCm,
      waistCm: _waistCm,
      hipCm: _hipCm,
      isConfigured: true,
    );
    await widget.appState.updateUserProfile(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved to your personal profile! All calculators will automatically use these details.'),
      ),
    );
  }

  // --- Action Handlers ---

  Future<void> _analyzeActivity() async {
    setState(() => _isAnalyzingActivity = true);
    try {
      final profile = await MetabolicAnalyzer.analyzeDailyActivity(
        description: _activityController.text,
        weightKg: _weightKg,
        bmr: _bmr,
        appState: widget.appState,
      );
      if (!mounted) return;
      setState(() {
        _activityProfile = profile;
        _activityFactor = profile.activityFactor;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Activity Analyzed! Daily Active Burn: +${profile.dailyActiveCalories.round()} kcal (Factor: ${profile.activityFactor})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity analysis error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzingActivity = false);
    }
  }

  Future<void> _generateDiagnosis() async {
    setState(() => _isGeneratingDiagnosis = true);
    try {
      final text = await MetabolicAnalyzer.generateBodyCompositionDiagnosis(
        bmi: _bmi,
        bodyFatPct: _bodyFatPercentage,
        weightKg: _weightKg,
        heightCm: _heightCm,
        isMale: _isMale,
        activityDescription: _activityController.text,
        appState: widget.appState,
      );
      if (!mounted) return;
      setState(() => _bodyCompDiagnosis = text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Diagnosis error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingDiagnosis = false);
    }
  }

  Future<void> _generateFatLossPlan() async {
    setState(() => _isGeneratingFatLossPlan = true);
    try {
      final (p, c, f) = _customMacroGrams;
      final plan = await MetabolicAnalyzer.generateFatLossPlan(
        currentWeightKg: _weightKg,
        targetWeightKg: _targetWeightKg,
        weeklyLossRateKg: _weeklyLossRateKg,
        bmr: _bmr,
        tdee: _tdee,
        dailyCalorieBudget: _customDailyCalorieTarget,
        macroSplitType: _macroSplitType,
        proteinGrams: p,
        carbsGrams: c,
        fatGrams: f,
        isMale: _isMale,
        appState: widget.appState,
      );
      if (!mounted) return;
      setState(() => _fatLossPlan = plan);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fat loss planning error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingFatLossPlan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            const BiteSizeLogo(size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Health Hub & Calculators',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: zen.sage,
          unselectedLabelColor: zen.inkMuted,
          indicatorColor: zen.sage,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.speed_rounded), text: 'BMI (Asian WHO)'),
            Tab(icon: Icon(Icons.fitness_center_rounded), text: 'Body Fat %'),
            Tab(icon: Icon(Icons.local_fire_department_rounded), text: 'BMR & TDEE'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildProfileHeaderBar(zen),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBmiTab(context, zen),
                _buildBodyFatTab(context, zen),
                _buildTdeeTab(context, zen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Persistent header bar displaying saved personal details and quick configure button.
  Widget _buildProfileHeaderBar(ZenColors zen) {
    final profile = widget.appState.profile;
    final isConfigured = profile.isConfigured;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isConfigured ? zen.surfaceSubtle : zen.gentleClay.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConfigured ? zen.sage.withOpacity(0.3) : zen.gentleClay.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isConfigured ? zen.sageSoft : zen.gentleClay.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConfigured ? Icons.verified_user_rounded : Icons.person_outline_rounded,
              size: 18,
              color: isConfigured ? zen.sage : zen.gentleClay,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isConfigured ? 'Saved Personal Profile' : 'Default Profile (Not Saved)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isConfigured ? zen.sage : zen.gentleClay,
                      ),
                    ),
                    if (isConfigured) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle_rounded, size: 13, color: zen.sage),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_isMale ? 'Male' : 'Female'} • $_age yrs • ${_heightCm.toStringAsFixed(0)} cm • ${_weightKg.toStringAsFixed(1)} kg',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () async {
              await showUserProfileSheet(context, appState: widget.appState);
              if (!mounted) return;
              setState(() => _syncFromProfile(widget.appState.profile));
            },
            icon: Icon(isConfigured ? Icons.edit_rounded : Icons.tune_rounded, size: 15),
            label: Text(isConfigured ? 'Edit' : 'Configure'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              backgroundColor: isConfigured ? zen.sageSoft : zen.gentleClay.withOpacity(0.16),
              foregroundColor: isConfigured ? zen.sage : zen.gentleClay,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveToProfileButton(ZenColors zen) {
    final isSaved = widget.appState.profile.isConfigured;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: OutlinedButton.icon(
        onPressed: _saveCurrentInputsToProfile,
        icon: Icon(isSaved ? Icons.sync_rounded : Icons.save_outlined, size: 16),
        label: Text(
          isSaved ? 'Sync adjustments to Profile' : 'Save as Default Profile',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: zen.sage,
          side: BorderSide(color: zen.sage.withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ==========================================
  // 1. BMI CALCULATOR (ASIAN WHO STANDARDS & AI LIFESTYLE)
  // ==========================================
  Widget _buildBmiTab(BuildContext context, ZenColors zen) {
    final (minWeight, maxWeight) = _healthyWeightRangeAsian;
    final bmiColor = _asianBmiColor(zen);

    return ListView(
      key: const Key('bmi_tab_listview'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'South Asian WHO BMI Calculator',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    _buildSexBadge(zen),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'WHO and ICMR establish adjusted BMI cutoff points for South Asians because of higher visceral fat and cardiovascular disease risk at lower BMIs.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: zen.inkMuted),
                ),
                const SizedBox(height: 16),

                // Biological Sex Selector
                Text('Biological Sex', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _buildSexSelector(zen),
                const SizedBox(height: 14),

                // Height slider + steppers
                _buildMetricSlider(
                  label: 'Height',
                  displayValue: '${_heightCm.toStringAsFixed(1)} cm (${(_heightCm / 30.48).toStringAsFixed(1)} ft)',
                  value: _heightCm,
                  min: 100,
                  max: 230,
                  zen: zen,
                  quickSteps: const [('-5cm', -5.0), ('-1cm', -1.0), ('+1cm', 1.0), ('+5cm', 5.0)],
                  onChanged: (val) => setState(() => _heightCm = val),
                ),
                const SizedBox(height: 10),

                // Weight slider + steppers
                _buildMetricSlider(
                  label: 'Weight',
                  displayValue: '${_weightKg.toStringAsFixed(1)} kg (${ZenDateUtils.kgToLb(_weightKg).toStringAsFixed(1)} lbs)',
                  value: _weightKg,
                  min: 30,
                  max: 220,
                  zen: zen,
                  quickSteps: const [('-1kg', -1.0), ('-0.5kg', -0.5), ('+0.5kg', 0.5), ('+1kg', 1.0)],
                  onChanged: (val) => setState(() {
                    _weightKg = val;
                    if (_targetWeightKg > _weightKg) {
                      _targetWeightKg = math.max(35.0, _weightKg - 5.0);
                    }
                  }),
                ),
                const SizedBox(height: 10),

                // Age slider + steppers
                _buildMetricSlider(
                  label: 'Age',
                  displayValue: '$_age years',
                  value: _age.toDouble(),
                  min: 14,
                  max: 95,
                  zen: zen,
                  quickSteps: const [('-1y', -1.0), ('+1y', 1.0)],
                  onChanged: (val) => setState(() => _age = val.round()),
                ),

                _buildSaveToProfileButton(zen),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Result Display Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: zen.surfaceSubtle,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: bmiColor.withOpacity(0.4), width: 1.5),
          ),
          child: Column(
            children: [
              Text('YOUR BODY MASS INDEX (BMI)', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.0)),
              const SizedBox(height: 6),
              Text(
                _bmi.toStringAsFixed(1),
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: bmiColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: bmiColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _asianBmiCategory,
                  style: TextStyle(fontWeight: FontWeight.w700, color: bmiColor, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Healthy South Asian Weight:', style: TextStyle(color: zen.inkMuted, fontSize: 13)),
                  Text(
                    '${minWeight.toStringAsFixed(1)} - ${maxWeight.toStringAsFixed(1)} kg',
                    style: TextStyle(fontWeight: FontWeight.w800, color: zen.sage),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('WHO Asian cutoff: 18.5 - 22.9 kg/m²', style: TextStyle(color: zen.inkMuted, fontSize: 11)),
                  Text('${ZenDateUtils.kgToLb(minWeight).toStringAsFixed(1)} - ${ZenDateUtils.kgToLb(maxWeight).toStringAsFixed(1)} lbs', style: TextStyle(color: zen.inkMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // AI Physical Activity & Daily Routine Profiler Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_run_rounded, color: zen.sage, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'What do you do in a day? (AI Profiler)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Instead of traditional generic checklists, describe your real physical routine. AI breaks down activities with MET exercise science.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: zen.inkMuted),
                ),
                const SizedBox(height: 12),

                // Text Input
                TextField(
                  controller: _activityController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Describe Daily Movement & Routine',
                    hintText: 'e.g. walk 5km morning, 8hr desk job, 15 min rope skip evening',
                    filled: true,
                    fillColor: zen.surfaceSubtle,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: zen.borderSoft),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Quick Add Chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildQuickTag('+ 5km Walk', 'walk 5km'),
                    _buildQuickTag('+ 15m Rope Skip', '15 min rope skipping'),
                    _buildQuickTag('+ 45m Gym Lift', '45 min gym weight training'),
                    _buildQuickTag('+ 8hr Desk Job', '8 hours sedentary desk job'),
                    _buildQuickTag('+ 30m Yoga', '30 min yoga stretching'),
                    _buildQuickTag('+ 8000 Steps', '8000 daily steps'),
                  ],
                ),
                const SizedBox(height: 12),

                // Analyze Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: zen.sage,
                      foregroundColor: const Color(0xFF090A0E),
                    ),
                    onPressed: _isAnalyzingActivity ? null : _analyzeActivity,
                    icon: _isAnalyzingActivity
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.bolt_rounded),
                    label: Text(
                      _isAnalyzingActivity ? 'Analyzing Movement...' : 'Calculate Exact Burn & Activity Factor with AI',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),

                // Profile Result Display
                if (_activityProfile != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: zen.surfaceSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: zen.sage.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: zen.sageSoft,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                _activityProfile!.usedAi ? 'AI Powered Analysis' : 'MET Exercise Science',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: zen.sage),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Factor: ${_activityProfile!.activityFactor}',
                              style: TextStyle(fontWeight: FontWeight.w900, color: zen.sage, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _activityProfile!.category,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimated Active Calorie Burn: +${_activityProfile!.dailyActiveCalories.round()} kcal/day',
                          style: TextStyle(color: zen.carbs, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const Divider(height: 20),
                        Text('IDENTIFIED ACTIVITIES & MET SCORES', style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 6),
                        ..._activityProfile!.activities.map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 14, color: zen.sage),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${a.name} (${a.volumeOrDuration})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  '+${a.estimatedBurnKcal.round()} kcal',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: zen.sage),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Icon(Icons.tips_and_updates_rounded, size: 14, color: zen.sage),
                            const SizedBox(width: 6),
                            Text('METABOLIC COACHING ADVICE', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.6)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: zen.sage.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: zen.sage.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline_rounded, size: 16, color: zen.sage),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _activityProfile!.coachingAdvice,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: zen.inkPrimary,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // AI South Asian Body Composition Diagnosis Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.biotech_rounded, color: zen.protein, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'AI South Asian Body Composition Review',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Synthesizes your BMI, body fat %, and daily routine into an expert clinical assessment addressing South Asian visceral fat and muscle preservation.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: zen.inkMuted),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isGeneratingDiagnosis ? null : _generateDiagnosis,
                    icon: _isGeneratingDiagnosis
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.health_and_safety_rounded),
                    label: Text(_isGeneratingDiagnosis ? 'Consulting AI...' : 'Generate AI Body Composition Review'),
                  ),
                ),
                if (_bodyCompDiagnosis != null) ...[
                  const SizedBox(height: 14),
                  AiMarkdownView(
                    content: _bodyCompDiagnosis!,
                    badgeLabel: 'AI South Asian Clinical Assessment',
                    badgeIcon: Icons.health_and_safety_rounded,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Asian WHO Scale Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asian WHO Classification Scale', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _buildBmiScaleRow('Underweight', '< 18.5', zen.water),
                _buildBmiScaleRow('Normal (Healthy South Asian)', '18.5 - 22.9', zen.sage),
                _buildBmiScaleRow('Overweight (Increased Risk)', '23.0 - 27.4', zen.carbs),
                _buildBmiScaleRow('Obese (High Risk)', '≥ 27.5', zen.gentleClay),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTag(String label, String insertText) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        final current = _activityController.text.trim();
        if (current.isEmpty) {
          _activityController.text = insertText;
        } else {
          _activityController.text = '$current, $insertText';
        }
      },
    );
  }

  Widget _buildSexBadge(ZenColors zen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_isMale ? Icons.male_rounded : Icons.female_rounded, size: 14, color: zen.sage),
          const SizedBox(width: 4),
          Text(
            _isMale ? 'Male' : 'Female',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: zen.inkPrimary),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. BODY FAT CALCULATOR (U.S. NAVY METHOD)
  // ==========================================
  Widget _buildBodyFatTab(BuildContext context, ZenColors zen) {
    return ListView(
      key: const Key('body_fat_tab_listview'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'U.S. Navy Body Fat Calculator',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    _buildSexBadge(zen),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Clinical tape-measurement formula estimating fat mass vs. lean muscle mass based on height, weight, and circumferences.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: zen.inkMuted),
                ),
                const SizedBox(height: 14),

                // Biological Sex Selector
                Text('Biological Sex', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _buildSexSelector(zen),
                const SizedBox(height: 14),

                // Current Weight
                _buildMetricSlider(
                  label: 'Current Weight',
                  displayValue: '${_weightKg.toStringAsFixed(1)} kg (${ZenDateUtils.kgToLb(_weightKg).toStringAsFixed(1)} lbs)',
                  value: _weightKg,
                  min: 30,
                  max: 220,
                  zen: zen,
                  quickSteps: const [('-1kg', -1.0), ('+1kg', 1.0)],
                  onChanged: (v) => setState(() {
                    _weightKg = v;
                    if (_targetWeightKg > _weightKg) {
                      _targetWeightKg = math.max(35.0, _weightKg - 5.0);
                    }
                  }),
                ),
                const SizedBox(height: 10),

                // Height (Required for Navy formula)
                _buildMetricSlider(
                  label: 'Height',
                  displayValue: '${_heightCm.toStringAsFixed(1)} cm (${(_heightCm / 30.48).toStringAsFixed(1)} ft)',
                  value: _heightCm,
                  min: 100,
                  max: 230,
                  zen: zen,
                  quickSteps: const [('-5cm', -5.0), ('-1cm', -1.0), ('+1cm', 1.0), ('+5cm', 5.0)],
                  onChanged: (v) => setState(() => _heightCm = v),
                ),
                const SizedBox(height: 10),

                // Age
                _buildMetricSlider(
                  label: 'Age',
                  displayValue: '$_age years',
                  value: _age.toDouble(),
                  min: 14,
                  max: 95,
                  zen: zen,
                  quickSteps: const [('-1y', -1.0), ('+1y', 1.0)],
                  onChanged: (v) => setState(() => _age = v.round()),
                ),
                const SizedBox(height: 10),

                // Neck
                _buildMeasurementSlider('Neck Circumference', _neckCm, 25, 60, (v) => setState(() => _neckCm = v), zen),
                // Waist
                _buildMeasurementSlider('Waist (at navel)', _waistCm, 50, 150, (v) => setState(() => _waistCm = v), zen),
                // Hip (females only)
                if (!_isMale)
                  _buildMeasurementSlider('Hips (widest point)', _hipCm, 60, 160, (v) => setState(() => _hipCm = v), zen),

                _buildSaveToProfileButton(zen),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Result
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: zen.surfaceSubtle,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: zen.borderSoft),
          ),
          child: Column(
            children: [
              Text('ESTIMATED BODY FAT', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.0)),
              const SizedBox(height: 6),
              Text(
                '${_bodyFatPercentage.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: zen.sage),
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFatMassStat('Fat Mass', '${_fatMassKg.toStringAsFixed(1)} kg', zen.gentleClay),
                  _buildFatMassStat('Lean Muscle Mass', '${_leanMassKg.toStringAsFixed(1)} kg', zen.protein),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. BMR & TDEE (CUSTOMIZABLE FAT LOSS & CALORIE TARGETER)
  // ==========================================
  Widget _buildTdeeTab(BuildContext context, ZenColors zen) {
    final (protGrams, carbGrams, fatGrams) = _customMacroGrams;
    final isAggressiveDeficit = _customDailyCalorieTarget < (_isMale ? 1500 : 1200);
    final (minWeight, maxWeight) = _healthyWeightRangeAsian;

    return ListView(
      key: const Key('tdee_tab_listview'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
      children: [
        // Standard Reference BMR & TDEE
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'BMR & TDEE Calorie Calculator',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _buildSexBadge(zen),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Mifflin-St Jeor equation determining basal metabolic burn and daily caloric maintenance.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: zen.inkMuted),
                ),
                const SizedBox(height: 16),

                // Biological Sex Selector
                Text('Biological Sex', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _buildSexSelector(zen),
                const SizedBox(height: 14),

                // Current Body Weight
                _buildMetricSlider(
                  label: 'Current Body Weight',
                  displayValue: '${_weightKg.toStringAsFixed(1)} kg (${ZenDateUtils.kgToLb(_weightKg).toStringAsFixed(1)} lbs)',
                  value: _weightKg,
                  min: 30,
                  max: 220,
                  zen: zen,
                  quickSteps: const [('-1kg', -1.0), ('-0.5kg', -0.5), ('+0.5kg', 0.5), ('+1kg', 1.0)],
                  onChanged: (v) => setState(() {
                    _weightKg = v;
                    if (_targetWeightKg > _weightKg) {
                      _targetWeightKg = math.max(35.0, _weightKg - 5.0);
                    }
                  }),
                ),
                const SizedBox(height: 10),

                // Height
                _buildMetricSlider(
                  label: 'Height',
                  displayValue: '${_heightCm.toStringAsFixed(1)} cm (${(_heightCm / 30.48).toStringAsFixed(1)} ft)',
                  value: _heightCm,
                  min: 100,
                  max: 230,
                  zen: zen,
                  quickSteps: const [('-5cm', -5.0), ('-1cm', -1.0), ('+1cm', 1.0), ('+5cm', 5.0)],
                  onChanged: (v) => setState(() => _heightCm = v),
                ),
                const SizedBox(height: 10),

                // Age
                _buildMetricSlider(
                  label: 'Age',
                  displayValue: '$_age years',
                  value: _age.toDouble(),
                  min: 14,
                  max: 95,
                  zen: zen,
                  quickSteps: const [('-1y', -1.0), ('+1y', 1.0)],
                  onChanged: (v) => setState(() => _age = v.round()),
                ),
                const SizedBox(height: 10),

                // Activity Level Dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Activity Multiplier (PAL)', style: Theme.of(context).textTheme.labelMedium),
                    if (_activityProfile != null)
                      Text(
                        'Synced from AI (${_activityFactor.toStringAsFixed(2)})',
                        style: TextStyle(color: zen.sage, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<double>(
                  value: _activityFactor,
                  isExpanded: true,
                  decoration: const InputDecoration(),
                  items: [
                    const DropdownMenuItem(value: 1.2, child: Text('Sedentary Baseline (1.20)')),
                    const DropdownMenuItem(value: 1.375, child: Text('Light Activity (1.38)')),
                    const DropdownMenuItem(value: 1.55, child: Text('Moderate Activity (1.55)')),
                    const DropdownMenuItem(value: 1.725, child: Text('Very Active Athletic (1.73)')),
                    const DropdownMenuItem(value: 1.9, child: Text('Extra Active / Heavy Physical (1.90)')),
                    if (_activityFactor != 1.2 &&
                        _activityFactor != 1.375 &&
                        _activityFactor != 1.55 &&
                        _activityFactor != 1.725 &&
                        _activityFactor != 1.9)
                      DropdownMenuItem(
                        value: _activityFactor,
                        child: Text('AI Computed Dynamic Factor (${_activityFactor.toStringAsFixed(2)})'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _activityFactor = v ?? 1.375),
                ),
                _buildSaveToProfileButton(zen),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Reference Targets Container
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: zen.surfaceSubtle,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: zen.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DAILY CALORIE TARGETS', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.0)),
              const SizedBox(height: 10),
              _buildTargetRow('Basal Metabolic Rate (BMR)', '${_bmr.round()} kcal', 'Burned at total rest', zen.inkMuted),
              const Divider(),
              _buildTargetRow('Maintenance (TDEE)', '${_tdee.round()} kcal', 'Stay same weight', zen.sage),
              const Divider(),
              _buildTargetRow('Fat Loss (-500 kcal)', '${(_tdee - 500).round()} kcal', 'Lose ~0.5 kg / week', zen.carbs),
              const Divider(),
              _buildTargetRow('Lean Muscle Gain (+300 kcal)', '${(_tdee + 300).round()} kcal', 'Build muscle with minimal fat', zen.protein),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final target = (_tdee - 500).round().clamp(1200, 4500);
                    final balanced = DailyGoals.balancedForCalories(target);
                    await widget.appState.updateGoals(balanced);
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text('Updated BiteSize daily target to $target kcal!')),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Apply Fat Loss Target to BiteSize'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // USER-DECIDED CUSTOMIZABLE FAT LOSS PLANNER
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: zen.carbs, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Customizable Fat Loss Planner',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Set your personal goal weight and desired weekly pace. Automatically computes deficits, target calories, and macro grams.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: zen.inkMuted),
                ),
                const SizedBox(height: 16),

                // Current vs Target Weight Summary Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: zen.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: zen.borderSoft),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Weight', style: TextStyle(color: zen.inkMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${_weightKg.toStringAsFixed(1)} kg',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            Text(
                              '${ZenDateUtils.kgToLb(_weightKg).toStringAsFixed(1)} lbs',
                              style: TextStyle(color: zen.inkMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: zen.borderSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: zen.sage),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Target Goal Weight', style: TextStyle(color: zen.inkMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${_targetWeightKg.toStringAsFixed(1)} kg',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: zen.sage),
                            ),
                            Text(
                              '${ZenDateUtils.kgToLb(_targetWeightKg).toStringAsFixed(1)} lbs',
                              style: TextStyle(color: zen.sage.withValues(alpha: 0.8), fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Target Weight UI-Friendly Stepper & Presets (No slider)
                _buildTargetWeightStepper(zen, minWeight, maxWeight),
                const SizedBox(height: 14),

                // Total Fat Loss Required Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: zen.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: zen.borderSoft),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Fat Loss Required:', style: TextStyle(color: zen.inkMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        '${_fatToLoseKg.toStringAsFixed(1)} kg (${(_fatToLoseKg * 7700).round()} kcal energy)',
                        style: TextStyle(fontWeight: FontWeight.w800, color: zen.carbs, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Weekly Rate UI-Friendly Pace Cards & Steppers (No slider)
                _buildWeeklyPaceSelector(zen),
                const SizedBox(height: 16),

                // Milestone Projection Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: zen.surfaceSubtle,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: zen.borderSoft),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Target Reached In:', style: TextStyle(color: zen.inkMuted, fontSize: 13)),
                          Text('$_weeksToTarget weeks', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Projected Date:', style: TextStyle(color: zen.inkMuted, fontSize: 13)),
                          Text(
                            ZenDateUtils.friendlyDateLabel(_projectedTargetDate),
                            style: TextStyle(fontWeight: FontWeight.w800, color: zen.sage),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Required Daily Deficit:', style: TextStyle(color: zen.inkMuted, fontSize: 13)),
                          Text(
                            '-${_dailyDeficitKcal.round()} kcal/day',
                            style: TextStyle(fontWeight: FontWeight.w800, color: zen.carbs),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Personalized Calorie Budget:', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            '${_customDailyCalorieTarget.round()} kcal',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: zen.sage),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isAggressiveDeficit) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: zen.gentleClay.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: zen.gentleClay.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: zen.gentleClay, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Very aggressive deficit: Eating under ${_isMale ? 1500 : 1200} kcal may cause lean muscle loss. Consider increasing daily steps instead of cutting calories deeper.',
                            style: TextStyle(color: zen.gentleClay, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Option for Week-by-Week Weight Loss Prediction Roadmap
                _buildWeeklyPredictionCard(zen),
                const SizedBox(height: 16),

                // Macro Ratio Distribution
                Text('Macro Split Distribution', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('High Protein (30P/40C/30F)'),
                      selected: _macroSplitType == 'high_protein',
                      onSelected: (v) => setState(() => _macroSplitType = 'high_protein'),
                    ),
                    ChoiceChip(
                      label: const Text('Balanced Indian (22P/48C/30F)'),
                      selected: _macroSplitType == 'balanced_indian',
                      onSelected: (v) => setState(() => _macroSplitType = 'balanced_indian'),
                    ),
                    ChoiceChip(
                      label: const Text('Low Carb (25P/15C/60F)'),
                      selected: _macroSplitType == 'low_carb',
                      onSelected: (v) => setState(() => _macroSplitType = 'low_carb'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMacroStat('Protein', '${protGrams}g', zen.protein),
                    _buildMacroStat('Carbs', '${carbGrams}g', zen.carbs),
                    _buildMacroStat('Fat', '${fatGrams}g', zen.fat),
                  ],
                ),
                const SizedBox(height: 16),

                // Set as My Target Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: zen.sage,
                      foregroundColor: const Color(0xFF090A0E),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final cal = _customDailyCalorieTarget.round();
                      final newGoals = DailyGoals(
                        calorieTarget: cal,
                        proteinTargetG: protGrams,
                        carbsTargetG: carbGrams,
                        fatTargetG: fatGrams,
                        targetWeightKg: _targetWeightKg,
                      );
                      await widget.appState.updateGoals(newGoals);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Updated BiteSize Daily Target to $cal kcal (Target: ${_targetWeightKg.toStringAsFixed(1)} kg by ${ZenDateUtils.friendlyDateLabel(_projectedTargetDate)})',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.rocket_launch_rounded),
                    label: const Text('Set as My Live BiteSize Target', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isGeneratingFatLossPlan ? null : _generateFatLossPlan,
                    icon: _isGeneratingFatLossPlan
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.psychology_rounded),
                    label: Text(_isGeneratingFatLossPlan ? 'Consulting AI Coach...' : 'Generate AI Fat Loss Plan & Roadmap'),
                  ),
                ),
                if (_fatLossPlan != null) ...[
                  const SizedBox(height: 14),
                  AiMarkdownView(
                    content: _fatLossPlan!,
                    badgeLabel: 'Personalized Fat Loss Roadmap',
                    badgeIcon: Icons.rocket_launch_rounded,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Helper UI Widgets ---

  Widget _buildSexSelector(ZenColors zen) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: true,
            label: Text('Male'),
            icon: Icon(Icons.male_rounded, size: 16),
          ),
          ButtonSegment(
            value: false,
            label: Text('Female'),
            icon: Icon(Icons.female_rounded, size: 16),
          ),
        ],
        selected: {_isMale},
        onSelectionChanged: (val) {
          HapticFeedback.selectionClick();
          setState(() => _isMale = val.first);
        },
      ),
    );
  }

  // --- Target Weight UI-Friendly Stepper (No Slider) ---

  Widget _buildTargetWeightStepper(ZenColors zen, double minWeight, double maxWeight) {
    final maxGoal = math.max(40.0, _weightKg > 40.0 ? _weightKg : 80.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target Goal Weight',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              InkWell(
                onTap: () => _showDirectNumberInputDialog(
                  title: 'Target Goal Weight',
                  unit: 'kg',
                  initialValue: _targetWeightKg,
                  min: 35.0,
                  max: maxGoal,
                  onConfirm: (val) => setState(() => _targetWeightKg = val),
                ),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 13, color: zen.sage),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to type',
                        style: TextStyle(fontSize: 11, color: zen.sage, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Large Stepper Row: [-] Value [+]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Minus 0.5kg
              IconButton.filledTonal(
                onPressed: _targetWeightKg > 35.0
                    ? () {
                        ZenHaptics.light();
                        setState(() => _targetWeightKg = math.max(35.0, _targetWeightKg - 0.5));
                      }
                    : null,
                icon: const Icon(Icons.remove_rounded, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              // Center Display & Tap-to-type
              InkWell(
                onTap: () => _showDirectNumberInputDialog(
                  title: 'Target Goal Weight',
                  unit: 'kg',
                  initialValue: _targetWeightKg,
                  min: 35.0,
                  max: maxGoal,
                  onConfirm: (val) => setState(() => _targetWeightKg = val),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      Text(
                        '${_targetWeightKg.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: zen.sage,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        '${ZenDateUtils.kgToLb(_targetWeightKg).toStringAsFixed(1)} lbs',
                        style: TextStyle(fontSize: 12, color: zen.inkMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              // Plus 0.5kg
              IconButton.filledTonal(
                onPressed: _targetWeightKg < maxGoal
                    ? () {
                        ZenHaptics.light();
                        setState(() => _targetWeightKg = math.min(maxGoal, _targetWeightKg + 0.5));
                      }
                    : null,
                icon: const Icon(Icons.add_rounded, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Quick Steps: -1kg, -0.5kg, +0.5kg, +1kg
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStepButton('-1kg', -1.0, 35.0, maxGoal, zen),
              _buildStepButton('-0.5kg', -0.5, 35.0, maxGoal, zen),
              _buildStepButton('+0.5kg', 0.5, 35.0, maxGoal, zen),
              _buildStepButton('+1kg', 1.0, 35.0, maxGoal, zen),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          // Quick Goal Presets
          Text('Quick Goal Presets:', style: TextStyle(color: zen.inkMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ActionChip(
                label: const Text('-2 kg quick cut', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  ZenHaptics.selection();
                  setState(() => _targetWeightKg = math.max(35.0, _weightKg - 2.0));
                },
              ),
              ActionChip(
                label: const Text('-5 kg steady cut', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  ZenHaptics.selection();
                  setState(() => _targetWeightKg = math.max(35.0, _weightKg - 5.0));
                },
              ),
              ActionChip(
                label: const Text('-10 kg cut', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  ZenHaptics.selection();
                  setState(() => _targetWeightKg = math.max(35.0, _weightKg - 10.0));
                },
              ),
              ActionChip(
                label: Text('Healthy BMI (${((minWeight + maxWeight) / 2).toStringAsFixed(0)} kg)', style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  ZenHaptics.selection();
                  setState(() => _targetWeightKg = ((minWeight + maxWeight) / 2).clamp(35.0, math.max(40.0, _weightKg)));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton(String label, double step, double min, double max, ZenColors zen) {
    return InkWell(
      onTap: () {
        ZenHaptics.light();
        final newVal = (_targetWeightKg + step).clamp(min, max);
        setState(() => _targetWeightKg = newVal);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: zen.borderSoft),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: zen.inkPrimary,
          ),
        ),
      ),
    );
  }

  // --- Weekly Rate Friendly Pace Cards & Steppers (No Slider) ---

  Widget _buildWeeklyPaceSelector(ZenColors zen) {
    const paceOptions = [
      (
        paceName: 'Gentle',
        rateKg: 0.25,
        dailyDeficitKcal: 275,
        tag: 'Easiest',
        desc: 'Zero hunger, 100% muscle retention',
      ),
      (
        paceName: 'Optimal',
        rateKg: 0.50,
        dailyDeficitKcal: 550,
        tag: 'Recommended ⭐',
        desc: 'Gold-standard steady fat burning',
      ),
      (
        paceName: 'Active',
        rateKg: 0.75,
        dailyDeficitKcal: 825,
        tag: 'Fast Pace',
        desc: 'Noticeable weekly drop, high protein',
      ),
      (
        paceName: 'Intense',
        rateKg: 1.00,
        dailyDeficitKcal: 1100,
        tag: 'Aggressive',
        desc: 'Strict short-term cut for deadline',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: zen.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Fat Loss Pace',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: zen.carbs.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_weeklyLossRateKg.toStringAsFixed(2)} kg / week (-${_dailyDeficitKcal.round()} kcal/day)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: zen.carbs,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: paceOptions.map((opt) {
              final isSelected = (_weeklyLossRateKg - opt.rateKg).abs() < 0.04;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    ZenHaptics.selection();
                    setState(() => _weeklyLossRateKg = opt.rateKg);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? zen.sageSoft
                          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? zen.sage : zen.borderSoft,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? zen.sage : zen.inkMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${opt.paceName} (${opt.rateKg.toStringAsFixed(2)} kg/wk)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: isSelected ? zen.sage : zen.inkPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? zen.sage.withValues(alpha: 0.2)
                                          : zen.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      opt.tag,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? zen.sage : zen.inkMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${opt.desc} • -${opt.dailyDeficitKcal} kcal/day',
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
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          // Fine-tuning micro adjustments
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Custom Fine-Tuning:',
                style: TextStyle(fontSize: 11, color: zen.inkMuted, fontWeight: FontWeight.w600),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: _weeklyLossRateKg > 0.20
                        ? () {
                            ZenHaptics.light();
                            setState(() => _weeklyLossRateKg = math.max(0.20, _weeklyLossRateKg - 0.05));
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('− 0.05 kg', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _weeklyLossRateKg < 1.20
                        ? () {
                            ZenHaptics.light();
                            setState(() => _weeklyLossRateKg = math.min(1.20, _weeklyLossRateKg + 0.05));
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('+ 0.05 kg', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Week-by-Week Weight Loss Prediction Roadmap Card ---

  Widget _buildWeeklyPredictionCard(ZenColors zen) {
    final forecasts = _weeklyForecasts;
    final hasForecasts = forecasts.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: zen.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: zen.sage.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Toggle & Copy
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: zen.sageSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_month_rounded, color: zen.sage, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Weekly Weight Loss Prediction',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: zen.sageSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$_weeksToTarget wks',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: zen.sage,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Projected body weight for every 7 days',
                        style: TextStyle(fontSize: 11, color: zen.inkMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _showWeeklyBreakdown ? 'Hide Breakdown' : 'Show Breakdown',
                  icon: Icon(
                    _showWeeklyBreakdown
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: zen.sage,
                  ),
                  onPressed: () {
                    ZenHaptics.selection();
                    setState(() => _showWeeklyBreakdown = !_showWeeklyBreakdown);
                  },
                ),
              ],
            ),
          ),

          // Action Buttons: Toggle view & Copy Roadmap
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      ZenHaptics.selection();
                      setState(() => _showWeeklyBreakdown = !_showWeeklyBreakdown);
                    },
                    icon: Icon(
                      _showWeeklyBreakdown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 16,
                    ),
                    label: Text(
                      _showWeeklyBreakdown ? 'Collapse Prediction' : 'Expand Weekly Forecast',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (hasForecasts) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _copyWeeklyRoadmapToClipboard(forecasts),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Forecast', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),

          // Expanded Content
          if (_showWeeklyBreakdown) ...[
            const Divider(height: 1),
            if (!hasForecasts)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    _fatToLoseKg <= 0
                        ? '🎉 You are already at or below your target weight!'
                        : 'Set a weekly rate above to see week-by-week predictions.',
                    style: TextStyle(color: zen.inkMuted, fontSize: 12),
                  ),
                ),
              )
            else ...[
              // Summary Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 65,
                      child: Text(
                        'WEEK',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: zen.inkMuted),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'DATE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: zen.inkMuted),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'WEIGHT',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: zen.inkMuted),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'LOST',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: zen.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Forecast List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: forecasts.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 14, endIndent: 14),
                itemBuilder: (ctx, idx) {
                  final item = forecasts[idx];
                  final isLast = idx == forecasts.length - 1;
                  final dateStr = '${ZenDateUtils.weekdayShort(item.date)}, ${ZenDateUtils.shortMonthDay(item.date)}';
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 65,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isLast ? zen.sageSoft : zen.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(6),
                                  border: isLast ? Border.all(color: zen.sage.withValues(alpha: 0.5)) : null,
                                ),
                                child: Text(
                                  'Wk ${item.weekNumber}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isLast ? zen.sage : zen.inkPrimary,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: zen.inkPrimary,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${item.expectedWeightKg.toStringAsFixed(1)} kg',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isLast ? zen.sage : zen.inkPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${ZenDateUtils.kgToLb(item.expectedWeightKg).toStringAsFixed(1)} lbs',
                                    style: TextStyle(fontSize: 10, color: zen.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: zen.sageSoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '-${item.totalLostKg.toStringAsFixed(1)} kg',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: zen.sage,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (item.milestoneBadge != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const SizedBox(width: 65),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isLast ? zen.sage : zen.carbs.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.milestoneBadge!,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: isLast ? const Color(0xFF090A0E) : zen.carbs,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _copyWeeklyRoadmapToClipboard(List<WeeklyLossForecast> forecasts) {
    final buffer = StringBuffer();
    buffer.writeln('🎯 My BiteSize Fat Loss Prediction & Roadmap');
    buffer.writeln('• Starting Weight: ${_weightKg.toStringAsFixed(1)} kg (${ZenDateUtils.kgToLb(_weightKg).toStringAsFixed(1)} lbs)');
    buffer.writeln('• Goal Target Weight: ${_targetWeightKg.toStringAsFixed(1)} kg (${ZenDateUtils.kgToLb(_targetWeightKg).toStringAsFixed(1)} lbs)');
    buffer.writeln('• Weekly Pace: ${_weeklyLossRateKg.toStringAsFixed(2)} kg/week (-${_dailyDeficitKcal.round()} kcal/day deficit)');
    buffer.writeln('• Estimated Completion: $_weeksToTarget weeks (${ZenDateUtils.friendlyDateLabel(_projectedTargetDate)})');
    buffer.writeln('');
    buffer.writeln('📅 WEEK-BY-WEEK FORECAST:');
    for (final f in forecasts) {
      final dateStr = '${ZenDateUtils.weekdayShort(f.date)}, ${ZenDateUtils.shortMonthDay(f.date)}';
      final milestone = f.milestoneBadge != null ? ' — ${f.milestoneBadge}' : '';
      buffer.writeln('Week ${f.weekNumber} ($dateStr): ${f.expectedWeightKg.toStringAsFixed(1)} kg (-${f.totalLostKg.toStringAsFixed(1)} kg)$milestone');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ZenHaptics.medium();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied Week-by-Week Weight Loss Prediction to Clipboard!'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showDirectNumberInputDialog({
    required String title,
    required String unit,
    required double initialValue,
    required double min,
    required double max,
    required ValueChanged<double> onConfirm,
  }) async {
    final controller = TextEditingController(
      text: initialValue % 1 == 0
          ? initialValue.toInt().toString()
          : initialValue.toStringAsFixed(1),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter value between ${min.toStringAsFixed(1)} and ${max.toStringAsFixed(1)} $unit:'.trim(),
              style: TextStyle(fontSize: 12, color: context.zen.inkMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                suffixText: unit.isNotEmpty ? unit : null,
                hintText: initialValue.toStringAsFixed(1),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null) {
                Navigator.of(ctx).pop(val.clamp(min, max));
              } else {
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result != null) {
      ZenHaptics.selection();
      onConfirm(result);
    }
  }

  Widget _buildMetricSlider({
    required String label,
    required String displayValue,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required ZenColors zen,
    int? divisions,
    List<(String, double)> quickSteps = const [],
    Color? activeColor,
  }) {
    final color = activeColor ?? zen.sage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _showDirectNumberInputDialog(
                title: label,
                unit: '',
                initialValue: value,
                min: min,
                max: max,
                onConfirm: onChanged,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayValue,
                      style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_outlined, size: 12, color: color.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                activeColor: color,
                onChanged: onChanged,
              ),
            ),
            if (quickSteps.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: quickSteps.map((step) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        final newVal = (value + step.$2).clamp(min, max);
                        onChanged(newVal);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: zen.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: zen.borderSoft),
                        ),
                        child: Text(
                          step.$1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: zen.inkPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildMeasurementSlider(String label, double val, double min, double max, ValueChanged<double> onChanged, ZenColors zen) {
    return _buildMetricSlider(
      label: label,
      displayValue: '${val.toStringAsFixed(1)} cm',
      value: val,
      min: min,
      max: max,
      onChanged: onChanged,
      zen: zen,
      quickSteps: const [('-1cm', -1.0), ('+1cm', 1.0)],
    );
  }

  Widget _buildFatMassStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _buildTargetRow(String title, String val, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          Text(val, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
        ],
      ),
    );
  }

  Widget _buildMacroStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
      ],
    );
  }

  Widget _buildBmiScaleRow(String cat, String range, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(cat, style: const TextStyle(fontSize: 13))),
          Text(range, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Structured weekly projection item for the customizable fat loss roadmap.
class WeeklyLossForecast {
  const WeeklyLossForecast({
    required this.weekNumber,
    required this.date,
    required this.expectedWeightKg,
    required this.totalLostKg,
    this.milestoneBadge,
  });

  final int weekNumber;
  final DateTime date;
  final double expectedWeightKg;
  final double totalLostKg;
  final String? milestoneBadge;
}
