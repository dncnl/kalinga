import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

class PrototypeCheckinPage extends StatefulWidget {
  final String scheduleId;
  const PrototypeCheckinPage({super.key, required this.scheduleId});

  @override
  State<PrototypeCheckinPage> createState() => _PrototypeCheckinPageState();
}

class _PrototypeCheckinPageState extends State<PrototypeCheckinPage> {
  static const _bg = Color(0xFFF5F0E8);
  static const _teal = Color(0xFF2BBFB3);
  static const _red = Color(0xFFEF3E23);

  // Hardcoded schedule data keyed by id
  static const _schedules = {
    'morning-walk': _ScheduleData(
      label: 'Morning walk · 10:00',
      question: 'Did Lola Rosa walk today?',
    ),
    'breakfast': _ScheduleData(
      label: 'Breakfast · 08:00',
      question: 'Did Lola Rosa eat breakfast today?',
    ),
    'medicine': _ScheduleData(
      label: 'Medicine · 09:00',
      question: 'Did Lola Rosa take her medicine?',
    ),
  };

  int? _selectedResponse; // 0=Yes, 1=Partly, 2=No
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _schedules[widget.scheduleId] ?? _schedules.values.first;

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

              // ── Alert card ────────────────────────────────────────────
              _buildAlertCard(schedule.label),
              const SizedBox(height: 24),

              // ── Question ──────────────────────────────────────────────
              Text(
                schedule.question,
                style: AppTextStyles.heading(fontSize: 26)
                    .copyWith(color: Colors.black),
              ),
              const SizedBox(height: 20),

              // ── Response buttons ──────────────────────────────────────
              Row(
                children: [
                  _ResponseButton(
                    label: 'Yes',
                    selected: _selectedResponse == 0,
                    onTap: () => setState(() => _selectedResponse = 0),
                  ),
                  const SizedBox(width: 10),
                  _ResponseButton(
                    label: 'Partly',
                    selected: _selectedResponse == 1,
                    onTap: () => setState(() => _selectedResponse = 1),
                  ),
                  const SizedBox(width: 10),
                  _ResponseButton(
                    label: 'No',
                    selected: _selectedResponse == 2,
                    onTap: () => setState(() => _selectedResponse = 2),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Note field ────────────────────────────────────────────
              Text(
                'Anything else in mind?',
                style: AppTextStyles.bodyMedium(fontSize: 14)
                    .copyWith(color: Colors.black87),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 5,
                style: AppTextStyles.body(fontSize: 14)
                    .copyWith(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Add a note in your own language…',
                  hintStyle: AppTextStyles.body(fontSize: 14).copyWith(
                    color: Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: _teal, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Speak / Photo row ─────────────────────────────────────
              Row(
                children: [
                  _ActionChip(
                    icon: Icons.mic_none_rounded,
                    label: 'Speak instead',
                    onTap: () {},
                  ),
                  const SizedBox(width: 12),
                  _ActionChip(
                    icon: Icons.camera_alt_outlined,
                    label: 'Add photo',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Confirm button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4917E),
                    disabledBackgroundColor: const Color(0xFFF4917E),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Confirm',
                    style: AppTextStyles.bodyMedium(fontSize: 17)
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Snooze link ───────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/home'),
                  child: Text(
                    'Ask me again in 1 hour',
                    style: AppTextStyles.bodyMedium(fontSize: 14)
                        .copyWith(color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Alert card ─────────────────────────────────────────────────────────────

  Widget _buildAlertCard(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _red, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_none_rounded,
                  size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                'SCHEDULED CHECK-IN',
                style: AppTextStyles.bodyMedium(fontSize: 11).copyWith(
                  color: Colors.grey.shade500,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.bodyMedium(fontSize: 16)
                .copyWith(color: Colors.black87),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '30 seconds.',
                  style: AppTextStyles.body(fontSize: 13)
                      .copyWith(color: _red),
                ),
                TextSpan(
                  text: ' Then it is off your list.',
                  style: AppTextStyles.body(fontSize: 13)
                      .copyWith(color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.push('/patients/lola-rosa'),
          child: Container(
            width: 38,
            height: 38,
            decoration:
                const BoxDecoration(color: _teal, shape: BoxShape.circle),
            child: Center(
              child: Text('LR',
                  style: AppTextStyles.bodyMedium(fontSize: 13)
                      .copyWith(color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/patients/lola-rosa'),
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
        ),
        IconButton(
          onPressed: () => context.push('/activity'),
          icon: Icon(Icons.notifications_none_rounded,
              color: Colors.grey.shade700, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: Icon(Icons.settings_outlined,
              color: Colors.grey.shade700, size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (i) {
        switch (i) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/ask');
            break;
          case 2:
            context.go('/log');
            break;
          case 3:
            context.go('/meds');
            break;
          case 4:
            context.go('/help');
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: _red,
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ResponseButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ResponseButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.black87 : Colors.white,
            border: Border.all(
              color: selected ? Colors.black87 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium(fontSize: 14).copyWith(
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.black87),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.body(fontSize: 13)
                  .copyWith(color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _ScheduleData {
  final String label;
  final String question;
  const _ScheduleData({required this.label, required this.question});
}
