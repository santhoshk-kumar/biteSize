import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../state/app_state.dart';
import '../theme/zen_theme.dart';

/// Opens the modal sheet to configure user's personal details (sex, age, height, weight, body measurements).
Future<void> showUserProfileSheet(
  BuildContext context, {
  required AppState appState,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _UserProfileSheet(appState: appState),
  );
}

class _UserProfileSheet extends StatefulWidget {
  const _UserProfileSheet({required this.appState});

  final AppState appState;

  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  late bool _isMale;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _neckCtrl;
  late final TextEditingController _waistCtrl;
  late final TextEditingController _hipCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.appState.profile;
    _isMale = p.isMale;
    _ageCtrl = TextEditingController(text: p.age.toString());
    _heightCtrl = TextEditingController(text: p.heightCm.toStringAsFixed(1));
    _weightCtrl = TextEditingController(text: p.weightKg.toStringAsFixed(1));
    _neckCtrl = TextEditingController(text: p.neckCm.toStringAsFixed(1));
    _waistCtrl = TextEditingController(text: p.waistCm.toStringAsFixed(1));
    _hipCtrl = TextEditingController(text: p.hipCm.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _neckCtrl.dispose();
    _waistCtrl.dispose();
    _hipCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 26;
    final height = double.tryParse(_heightCtrl.text.trim()) ?? 172.0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 68.0;
    final neck = double.tryParse(_neckCtrl.text.trim()) ?? 38.0;
    final waist = double.tryParse(_waistCtrl.text.trim()) ?? 84.0;
    final hip = double.tryParse(_hipCtrl.text.trim()) ?? 96.0;

    final updated = UserProfile(
      isMale: _isMale,
      age: age.clamp(12, 110),
      heightCm: height.clamp(90.0, 240.0),
      weightKg: weight.clamp(30.0, 300.0),
      neckCm: neck.clamp(20.0, 70.0),
      waistCm: waist.clamp(40.0, 180.0),
      hipCm: hip.clamp(50.0, 200.0),
      isConfigured: true,
    );

    await widget.appState.updateUserProfile(updated);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Personal profile saved! All calculators now use these details.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zen;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: zen.borderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: zen.sageSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_pin_rounded, color: zen.sage, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Configured once, auto-filled in all calculators',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: zen.inkMuted,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Biological Sex Selector
            Text(
              'Biological Sex',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: zen.inkMuted,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SexSelectionCard(
                    label: 'Male',
                    icon: Icons.male_rounded,
                    isSelected: _isMale,
                    onTap: () => setState(() => _isMale = true),
                    zen: zen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SexSelectionCard(
                    label: 'Female',
                    icon: Icons.female_rounded,
                    isSelected: !_isMale,
                    onTap: () => setState(() => _isMale = false),
                    zen: zen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Age & Height Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Age (years)',
                      hintText: 'e.g. 26',
                      prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _heightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Height (cm)',
                      hintText: 'e.g. 172',
                      prefixIcon: const Icon(Icons.height_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Current Weight
            TextField(
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Current Weight (kg)',
                hintText: 'e.g. 68.0',
                prefixIcon: const Icon(Icons.monitor_weight_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Body Fat measurements expander / section
            Text(
              'Body Circumferences (for Body Fat % calculation)',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: zen.inkMuted,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _neckCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Neck (cm)',
                      hintText: '38.0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _waistCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Waist (cm)',
                      hintText: '84.0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (!_isMale) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _hipCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Hip (cm)',
                        hintText: '96.0',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton.icon(
              onPressed: _saveProfile,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text(
                'Save Profile Details',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: zen.sage,
                foregroundColor: const Color(0xFF090A0E),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SexSelectionCard extends StatelessWidget {
  const _SexSelectionCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.zen,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ZenColors zen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? zen.sageSoft : zen.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? zen.sage : zen.borderSoft,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? zen.sage : zen.inkMuted,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? zen.sage : zen.inkPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
