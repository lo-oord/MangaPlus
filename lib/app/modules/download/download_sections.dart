import 'package:mangaplus/app/data/models/download_task.dart';

/// Read-only view of the download queue grouped for the downloads screen.
///
/// The manager remains the owner of each task; this only decides where a task
/// belongs so the UI and tests agree on the categories.
class DownloadSections {
  const DownloadSections({
    required this.active,
    required this.queued,
    required this.completed,
    required this.failed,
  });

  final List<DownloadTask> active;
  final List<DownloadTask> queued;
  final List<DownloadTask> completed;
  final List<DownloadTask> failed;

  bool get isEmpty =>
      active.isEmpty && queued.isEmpty && completed.isEmpty && failed.isEmpty;

  int get total => active.length + queued.length + completed.length + failed.length;

  factory DownloadSections.from(Iterable<DownloadTask> tasks) {
    final active = <DownloadTask>[];
    final queued = <DownloadTask>[];
    final completed = <DownloadTask>[];
    final failed = <DownloadTask>[];
    for (final task in tasks) {
      switch (task.status) {
        case DownloadTaskStatus.downloading:
        case DownloadTaskStatus.paused:
          active.add(task);
        case DownloadTaskStatus.queued:
          queued.add(task);
        case DownloadTaskStatus.completed:
          completed.add(task);
        case DownloadTaskStatus.failed:
        case DownloadTaskStatus.partiallyCompleted:
        case DownloadTaskStatus.cancelled:
          failed.add(task);
      }
    }
    return DownloadSections(
      active: active,
      queued: queued,
      completed: completed,
      failed: failed,
    );
  }
}
