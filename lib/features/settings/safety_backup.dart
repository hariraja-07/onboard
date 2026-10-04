import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup/backup_service.dart';
import '../../core/database/providers.dart';
import '../../core/export/data_export_service.dart' show formatTimestamp;
import 'backup_file_gateway.dart';

/// Lets tests swap the real picker/disk for a fake.
final backupFileGatewayProvider = Provider<BackupFileGateway>((ref) {
  return const FilePickerBackupGateway();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(databaseProvider));
});

/// Writes a safety copy of the whole database without asking, and returns where
/// it went.
///
/// Shared by every destructive action, so that a mistaken session deletion,
/// restore or clear can always be undone by restoring the file this wrote. The
/// copy is written before the destructive step, never after, so that a failure
/// part way through still leaves the original recoverable.
Future<String> writeSafetyBackup(
  BackupService backup,
  BackupFileGateway gateway, {
  DateTime? at,
}) async {
  final now = at ?? DateTime.now();
  final data = await backup.snapshot();
  return gateway.writeSafetyBackup(
    backup.encode(data),
    'onboard_safety_backup_${formatTimestamp(now)}.'
    '${BackupService.fileExtension}',
  );
}
