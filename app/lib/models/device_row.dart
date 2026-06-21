/// One row of a [FieldType.deviceList] value: a device to install with its
/// count and a free-text remark. Stored inside a Survey's `data` map as a list
/// of JSON objects under the field key.
class DeviceRow {
  final String type;
  final String number;
  final String remark;

  const DeviceRow({this.type = '', this.number = '', this.remark = ''});

  DeviceRow copyWith({String? type, String? number, String? remark}) =>
      DeviceRow(
        type: type ?? this.type,
        number: number ?? this.number,
        remark: remark ?? this.remark,
      );

  Map<String, dynamic> toJson() =>
      {'type': type, 'number': number, 'remark': remark};

  factory DeviceRow.fromJson(Map<String, dynamic> j) => DeviceRow(
        type: j['type'] as String? ?? '',
        number: j['number'] as String? ?? '',
        remark: j['remark'] as String? ?? '',
      );

  bool get isEmpty =>
      type.trim().isEmpty && number.trim().isEmpty && remark.trim().isEmpty;

  /// "Camera x3 (front pole)" — used in the PDF survey summary.
  String get summary {
    final t = type.trim().isEmpty ? '?' : type.trim();
    final n = number.trim().isEmpty ? '' : ' x${number.trim()}';
    final r = remark.trim().isEmpty ? '' : ' (${remark.trim()})';
    return '$t$n$r';
  }

  static List<DeviceRow> listFromValue(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => DeviceRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
