/// Direction of the communication with the Antigravity subprocess.
enum LogDirection { inbound, outbound, system, error }

/// Represents a single captured log event from or to the Antigravity subprocess.
class ProcessLogEntry {
  final String id;
  final DateTime timestamp;
  final String message;
  final LogDirection direction;
  final String? level;
  final String? loggerName;

  ProcessLogEntry({
    required this.id,
    required this.timestamp,
    required this.message,
    required this.direction,
    this.level,
    this.loggerName,
  });

  bool get isInbound => direction == LogDirection.inbound;
  bool get isOutbound => direction == LogDirection.outbound;
  bool get isSystem => direction == LogDirection.system;
  bool get isError => direction == LogDirection.error;

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
