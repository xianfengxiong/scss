import '../services/location_service.dart';
import 'field_control.dart';
import 'registry.dart';
import 'title_control.dart';

/// The app's starting control set. Add new controls by registering them here.
/// [location] is injected so a `coordinate` field can capture GPS; tests that
/// omit it get text-only coordinate fields.
ControlRegistry buildDefaultRegistry({LocationService? location}) {
  final r = ControlRegistry();
  r.register(TitleControl());
  r.register(FieldControl(location: location));
  return r;
}
