import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../barcode_controller.dart';
import '../widgets/barcode_result_card.dart';

/// Developer screen for exercising the barcode matcher without a camera.
///
/// The matching rules are the same ones the camera screen uses — this only
/// swaps the input method, so a scan that fails in the field can be reproduced
/// by pasting the raw barcode that produced it.
class BarcodeDebugPage extends ConsumerStatefulWidget {
  const BarcodeDebugPage({super.key});

  @override
  ConsumerState<BarcodeDebugPage> createState() => _BarcodeDebugPageState();
}

class _BarcodeDebugPageState extends ConsumerState<BarcodeDebugPage> {
  final TextEditingController _entry = TextEditingController();

  /// Worked examples from the feature request, plus the two failure modes, so
  /// every branch of the matcher can be reached in one tap.
  static const _samples = [
    ('732924BMR016', 'prefixed card'),
    ('24BMR016', 'bare roll number'),
    (' 732924bmr016 ', 'padded + lower case'),
    ('732999BMR999', 'unknown student'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(barcodeControllerProvider.notifier).loadStudents();
    });
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ref.read(barcodeControllerProvider.notifier).submitBarcode(_entry.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(barcodeControllerProvider);
    final controller = ref.read(barcodeControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Debug')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Type a barcode exactly as the scanner would deliver it. '
            'Matching is identical to the camera screen.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _entry,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Barcode',
              hintText: 'e.g. 732924BMR016',
              prefixIcon: Icon(Icons.qr_code),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.search),
                  label: const Text('Match'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  _entry.clear();
                  controller.clearResult();
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (state.error != null)
            Text(
              state.error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else if (state.lastResult != null)
            BarcodeResultCard(
              result: state.lastResult!,
              onDismiss: controller.clearResult,
            )
          else
            Text('No barcode matched yet.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text('Roster', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${state.students.length} students loaded. '
            'Import a roster from the Students tab first if this is zero.',
            style: theme.textTheme.bodyMedium,
          ),
          if (state.students.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final student in state.students.take(20))
              Text(
                '${student.rollNo} — ${student.name}',
                style: theme.textTheme.bodyMedium,
              ),
            if (state.students.length > 20)
              Text(
                '…and ${state.students.length - 20} more',
                style: theme.textTheme.bodyMedium,
              ),
          ],
          const SizedBox(height: 24),
          Text('Sample barcodes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, description) in _samples)
                ActionChip(
                  label: Text(value),
                  tooltip: description,
                  onPressed: () {
                    _entry.text = value;
                    _submit();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
