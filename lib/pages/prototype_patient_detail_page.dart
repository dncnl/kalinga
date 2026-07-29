import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

class PrototypePatientDetailPage extends StatelessWidget {
  final String patientId;
  const PrototypePatientDetailPage({super.key, required this.patientId});

  static const _bg = Color(0xFFF5F0E8);
  static const _teal = Color(0xFF2BBFB3);

  // ── Hardcoded patient data (keyed by id) ──────────────────────────────────
  static const _patients = {
    'lola-rosa': _PatientData(
      initials: 'LR',
      name: 'Lola Rosa',
      age: 82,
      language: 'speaks Hokkien',
      conditions: ['dementia', 'hypertension', 'low appetite'],
      medicationCount: 3,
      scheduleCount: 4,
      linkedViewers: 'family · doctor',
      emergencyContactCount: 2,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final patient = _patients[patientId] ?? _patients.values.first;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildProfileBlock(patient),
              const SizedBox(height: 20),
              _buildConditions(patient),
              const SizedBox(height: 20),
              _buildMenuRows(patient),
              const SizedBox(height: 20),
              _buildEditButton(),
              const SizedBox(height: 12),
              _buildPreviewLink(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header (same pattern as home) ──────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
          child: Center(
            child: Text(
              'LR',
              style: AppTextStyles.bodyMedium(fontSize: 13)
                  .copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lola Rosa',
                      style: AppTextStyles.bodyMedium(fontSize: 14)
                          .copyWith(color: Colors.black87)),
                  Text('82 · speaks Hokkien',
                      style: AppTextStyles.body(fontSize: 11)
                          .copyWith(color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: Colors.grey.shade500),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.notifications_none_rounded,
              color: Colors.grey.shade700, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.settings_outlined,
              color: Colors.grey.shade700, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  // ── Profile block ──────────────────────────────────────────────────────────

  Widget _buildProfileBlock(_PatientData patient) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration:
              const BoxDecoration(color: _teal, shape: BoxShape.circle),
          child: Center(
            child: Text(
              patient.initials,
              style: AppTextStyles.bodyMedium(fontSize: 22)
                  .copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(patient.name,
                style: AppTextStyles.heading(fontSize: 26)
                    .copyWith(color: Colors.black)),
            Text('${patient.age} · ${patient.language}',
                style: AppTextStyles.body(fontSize: 13)
                    .copyWith(color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }

  // ── Conditions ─────────────────────────────────────────────────────────────

  Widget _buildConditions(_PatientData patient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONDITIONS',
          style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: patient.conditions
              .map(
                (c) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Text(
                    c,
                    style: AppTextStyles.body(fontSize: 13)
                        .copyWith(color: Colors.black87),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ── Menu rows ──────────────────────────────────────────────────────────────

  Widget _buildMenuRows(_PatientData patient) {
    final rows = [
      _MenuRow(
        icon: Icons.medication_outlined,
        label: 'Medications',
        trailing: '${patient.medicationCount}',
      ),
      _MenuRow(
        icon: Icons.schedule_rounded,
        label: 'Schedules',
        trailing: '${patient.scheduleCount}',
      ),
      _MenuRow(
        icon: Icons.remove_red_eye_outlined,
        label: 'Linked viewers',
        trailing: patient.linkedViewers,
        trailingColor: Colors.grey.shade400,
      ),
      _MenuRow(
        icon: Icons.phone_outlined,
        label: 'Emergency contacts',
        trailing: '${patient.emergencyContactCount}',
      ),
    ];

    return Column(
      children: rows
          .map(
            (row) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                onTap: () {},
                leading: Icon(row.icon,
                    color: Colors.grey.shade600, size: 22),
                title: Text(
                  row.label,
                  style: AppTextStyles.bodyMedium(fontSize: 15)
                      .copyWith(color: Colors.black87),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      row.trailing,
                      style: AppTextStyles.body(fontSize: 14).copyWith(
                        color: row.trailingColor ?? Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.grey.shade400, size: 20),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 2),
              ),
            ),
          )
          .toList(),
    );
  }

  // ── Edit profile button ────────────────────────────────────────────────────

  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(
          'Edit profile',
          style:
              AppTextStyles.bodyMedium(fontSize: 16).copyWith(color: Colors.black87),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.black87, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      ),
    );
  }

  // ── Preview link ───────────────────────────────────────────────────────────

  Widget _buildPreviewLink() {
    return Center(
      child: GestureDetector(
        onTap: () {},
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.remove_red_eye_outlined,
                size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Text(
              'Preview what family sees',
              style: AppTextStyles.bodyMedium(fontSize: 14)
                  .copyWith(color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (_) {},
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFFEF3E23),
      unselectedItemColor: Colors.grey.shade400,
      selectedLabelStyle: AppTextStyles.bodyMedium(fontSize: 11),
      unselectedLabelStyle: AppTextStyles.body(fontSize: 11),
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded), label: 'Today'),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Ask'),
        BottomNavigationBarItem(
            icon: Icon(Icons.mic_none_rounded), label: 'Log'),
        BottomNavigationBarItem(
            icon: Icon(Icons.medication_outlined), label: 'Meds'),
        BottomNavigationBarItem(
            icon: Icon(Icons.help_outline_rounded), label: 'Help'),
      ],
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _PatientData {
  final String initials;
  final String name;
  final int age;
  final String language;
  final List<String> conditions;
  final int medicationCount;
  final int scheduleCount;
  final String linkedViewers;
  final int emergencyContactCount;

  const _PatientData({
    required this.initials,
    required this.name,
    required this.age,
    required this.language,
    required this.conditions,
    required this.medicationCount,
    required this.scheduleCount,
    required this.linkedViewers,
    required this.emergencyContactCount,
  });
}

class _MenuRow {
  final IconData icon;
  final String label;
  final String trailing;
  final Color? trailingColor;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.trailingColor,
  });
}
