import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../state/selected_profile.dart';
import '../theme.dart';

const _conditions = [
  'dementia',
  'hypertension',
  'diabetes',
  'stroke',
  'low appetite',
];

const _languages = [
  'Taiwanese Hokkien',
  'Mandarin',
  'Tagalog',
  'Bisaya',
  'Bahasa Indonesia',
  'Tiếng Việt',
];

class PrototypePatientPage extends StatefulWidget {
  const PrototypePatientPage({super.key});

  @override
  State<PrototypePatientPage> createState() => _PrototypePatientPageState();
}

class _PrototypePatientPageState extends State<PrototypePatientPage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _red = Color(0xFFEF3E23);
  static const _chipSelected = Color(0xFF111111);

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedLanguage = _languages.first;
  final Set<String> _selectedConditions = {'dementia', 'hypertension'};

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Add a name.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await SelectedProfile.instance.createAndSelect(
        displayName: name,
        age: int.tryParse(_ageController.text.trim()),
        preferredLanguages: [_selectedLanguage],
        conditions: _selectedConditions.toList(),
      );
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Step label ─────────────────────────────────────────────
              Text(
                'STEP 2 OF 2',
                style: AppTextStyles.bodyMedium(fontSize: 12).copyWith(
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 8),

              // ── Title ──────────────────────────────────────────────────
              Text(
                'Who do you care for?',
                style: AppTextStyles.heading(fontSize: 32).copyWith(
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 6),

              // ── Subtitle ───────────────────────────────────────────────
              Text(
                'Add one elder now. You can add more later.',
                style: AppTextStyles.body(fontSize: 14).copyWith(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 28),

              // ── Name field ─────────────────────────────────────────────
              _FieldLabel('Name'),
              const SizedBox(height: 8),
              _InputField(
                controller: _nameController,
                hint: 'Lola Rosa',
              ),
              const SizedBox(height: 6),
              Text(
                'Use the name you call them.',
                style: AppTextStyles.body(fontSize: 12).copyWith(
                  color: Colors.grey.shade500,
                ),
              ),

              const SizedBox(height: 20),

              // ── Age field ──────────────────────────────────────────────
              _FieldLabel('Age'),
              const SizedBox(height: 8),
              _InputField(
                controller: _ageController,
                hint: '82',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),

              const SizedBox(height: 20),

              // ── Language dropdown ──────────────────────────────────────
              _FieldLabel('Language they speak'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade600,
                    ),
                    style: AppTextStyles.body(fontSize: 15).copyWith(
                      color: Colors.black87,
                    ),
                    items: _languages
                        .map(
                          (lang) => DropdownMenuItem(
                            value: lang,
                            child: Text(lang),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedLanguage = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Conditions ─────────────────────────────────────────────
              _FieldLabel('Conditions'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _conditions.map((condition) {
                  final selected = _selectedConditions.contains(condition);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedConditions.remove(condition);
                      } else {
                        _selectedConditions.add(condition);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? _chipSelected : Colors.white,
                        border: Border.all(
                          color: selected
                              ? _chipSelected
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Text(
                        condition,
                        style: AppTextStyles.body(fontSize: 14).copyWith(
                          color: selected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap what applies.',
                style: AppTextStyles.body(fontSize: 12).copyWith(
                  color: Colors.grey.shade500,
                ),
              ),

              const SizedBox(height: 32),

              if (_error != null) ...[
                Text(
                  _error!,
                  style: AppTextStyles.body(fontSize: 13).copyWith(color: _red),
                ),
                const SizedBox(height: 12),
              ],

              // ── Save and start button ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          'Save and start',
                          style: AppTextStyles.bodyMedium(fontSize: 17).copyWith(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyMedium(fontSize: 15).copyWith(
        color: Colors.black87,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: AppTextStyles.body(fontSize: 15).copyWith(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body(fontSize: 15).copyWith(
          color: Colors.grey.shade400,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2BBFB3), width: 1.5),
        ),
      ),
    );
  }
}
