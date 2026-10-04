import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup/backup_models.dart';
import '../../core/backup/backup_service.dart';
import '../../core/database/providers.dart';
import '../../core/export/data_export_service.dart';
import '../history/history_controller.dart';
import '../students/students_controller.dart';
import 'backup_file_gateway.dart';
import 'safety_backup.dart';

// The two providers live with the safety-backup helper rather than here,
// because the History screen needs them too and this file already imports
// History, which would make that an import cycle.
export 'safety_backup.dart' show backupServiceProvider, backupFileGatewayProvider;

/// Where the data-management screen currently is.
enum DataManagementStatus {
  /// Nothing happening; buttons are enabled.
  idle,

  /// A backup, export, restore or clear is in flight.
  working,

  /// A backup file has been read and validated, awaiting confirmation.
  review,

  /// The last action left a message for the user.
  done,

  /// The last action failed; [DataManagementState.error] explains why.
  failed,
}

class DataManagementState {
  const DataManagementState({
    this.status = DataManagementStatus.idle,
    this.message,
    this.error,
    this.pendingBackup,
    this.pendingInfo,
    this.safetyBackupPath,
  });

  final DataManagementStatus status;

  /// A success/info line to show the user once.
  final String? message;

  /// A failure line to show the user once.
  final String? error;

  /// The validated backup awaiting a restore confirmation.
  final BackupData? pendingBackup;

  /// What [pendingBackup] contains, for the review screen.
  final BackupInfo? pendingInfo;

  /// Where the automatic safety copy was written, if one was made.
  final String? safetyBackupPath;

  bool get isBusy => status == DataManagementStatus.working;
  bool get hasPendingRestore => pendingBackup != null && pendingInfo != null;
}

final dataExportServiceProvider = Provider<DataExportService>((ref) {
  return DataExportService(ref.watch(databaseProvider));
});

/// Non-autoDispose on purpose: the restore review screen is a separate route,
/// and it must still see the backup picked on the settings screen.
final dataManagementControllerProvider =
    StateNotifierProvider<DataManagementController, DataManagementState>((ref) {
      return DataManagementController(
        backupService: ref.watch(backupServiceProvider),
        exportService: ref.watch(dataExportServiceProvider),
        gateway: ref.watch(backupFileGatewayProvider),
        reloadData: () async {
          await ref.read(studentsProvider.notifier).loadStudents();
          ref.invalidate(attendanceHistoryProvider);
          ref.invalidate(sessionDetailsProvider);
        },
      );
    });

/// Drives backup, export, restore and clear from the Settings screen.
class DataManagementController extends StateNotifier<DataManagementState> {
  DataManagementController({
    required BackupService backupService,
    required DataExportService exportService,
    required BackupFileGateway gateway,
    required Future<void> Function() reloadData,
  }) : _backup = backupService,
       _export = exportService,
       _gateway = gateway,
       _reload = reloadData,
       super(const DataManagementState());

  final BackupService _backup;
  final DataExportService _export;
  final BackupFileGateway _gateway;
  final Future<void> Function() _reload;

  /// Snapshots the database and offers it through the save dialog.
  Future<void> backUp() async {
    state = const DataManagementState(status: DataManagementStatus.working);
    try {
      final now = DateTime.now();
      final data = await _backup.snapshot();
      final bytes = _backup.encode(data);
      final location = await _gateway.saveBackup(
        bytes,
        'onboard_backup_${formatTimestamp(now)}.${BackupService.fileExtension}',
      );

      if (location == null) {
        state = const DataManagementState();
        return;
      }
      state = DataManagementState(
        status: DataManagementStatus.done,
        message: 'Backup saved to $location',
      );
    } catch (error) {
      state = DataManagementState(
        status: DataManagementStatus.failed,
        error: 'Could not create the backup.\n$error',
      );
    }
  }

  /// Builds the Excel workbook and offers it through the save dialog.
  Future<void> exportData() async {
    state = const DataManagementState(status: DataManagementStatus.working);
    try {
      final now = DateTime.now();
      final bytes = await _export.build();
      if (bytes == null) {
        state = const DataManagementState(
          status: DataManagementStatus.failed,
          error: 'Could not build the data export.',
        );
        return;
      }

      final location = await _gateway.saveExport(
        Uint8List.fromList(bytes),
        DataExportService.fileNameFor(now),
      );
      if (location == null) {
        state = const DataManagementState();
        return;
      }
      state = DataManagementState(
        status: DataManagementStatus.done,
        message: 'Data exported to $location',
      );
    } catch (error) {
      state = DataManagementState(
        status: DataManagementStatus.failed,
        error: 'Could not export the data.\n$error',
      );
    }
  }

  /// Lets the user choose a backup file, then validates it.
  ///
  /// On success the state is [DataManagementStatus.review] with
  /// [DataManagementState.pendingInfo] populated; the caller navigates to the
  /// review screen. Returns true when there is something to review.
  Future<bool> chooseBackupToRestore() async {
    state = const DataManagementState(status: DataManagementStatus.working);
    try {
      final picked = await _gateway.pickBackup();
      if (picked == null) {
        state = const DataManagementState();
        return false;
      }

      final data = _backup.decodeAndValidate(picked.bytes);
      state = DataManagementState(
        status: DataManagementStatus.review,
        pendingBackup: data,
        pendingInfo: data.info,
      );
      return true;
    } on BackupException catch (error) {
      state = DataManagementState(
        status: DataManagementStatus.failed,
        error: error.message,
      );
      return false;
    } catch (error) {
      state = DataManagementState(
        status: DataManagementStatus.failed,
        error: 'Could not read that backup file.\n$error',
      );
      return false;
    }
  }

  /// Writes a safety copy, then replaces all data with the pending backup.
  Future<void> confirmRestore() async {
    final pending = state.pendingBackup;
    if (pending == null) return;

    state = DataManagementState(
      status: DataManagementStatus.working,
      pendingBackup: pending,
      pendingInfo: state.pendingInfo,
    );

    try {
      final safetyPath = await _writeSafetyBackup();
      await _backup.restore(pending);
      await _reload();

      state = DataManagementState(
        status: DataManagementStatus.done,
        message:
            'Restored ${pending.studentCount} students and '
            '${pending.sessionCount} attendance sessions.\n'
            'A safety copy of your previous data was saved to $safetyPath',
        safetyBackupPath: safetyPath,
      );
    } catch (error) {
      state = DataManagementState(
        status: DataManagementStatus.failed,
        error: 'Restore failed, so nothing was changed.\n$error',
      );
    }
  }

  /// Writes a safety copy, then deletes every student and attendance record.
  Future<void> clearAllData() async {
    state = const DataManagementState(status: DataManagementStatus.working);

    try {
      final safetyPath = await _writeSafetyBackup();
      await _backup.clearAll();
      await _reload();

      state = DataManagementState(
        status: DataManagementStatus.done,
        message:
            'All data cleared.\n'
            'A safety copy was saved to $safetyPath',
        safetyBackupPath: safetyPath,
      );
    } catch (error) {
      state = DataManagementState(
        status: DataManagementStatus.failed,
        error: 'Could not clear the data.\n$error',
      );
    }
  }

  /// Leaves the review screen without restoring.
  void cancelRestore() => state = const DataManagementState();

  /// Clears a shown message or error line.
  void acknowledge() => state = const DataManagementState();

  Future<String> _writeSafetyBackup() =>
      writeSafetyBackup(_backup, _gateway);
}
