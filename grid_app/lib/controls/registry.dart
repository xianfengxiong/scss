import 'control_spec.dart';

class ControlRegistry {
  final Map<String, ControlSpec> _byType = {};

  void register(ControlSpec spec) => _byType[spec.type] = spec;

  ControlSpec? specFor(String type) => _byType[type];

  List<ControlSpec> get all => _byType.values.toList(growable: false);

  bool get isEmpty => _byType.isEmpty;
}
