import '../services/location_service.dart';
import 'coordinate_control.dart';
import 'label_control.dart';
import 'number_control.dart';
import 'registry.dart';
import 'text_control.dart';
import 'title_control.dart';

/// The app's VB-toolbox control set. Add a new control by registering it here
/// (spec §10.1, §15). [location] is injected so a `coordinate` control can
/// capture GPS; tests that omit it get a text-only coordinate input.
ControlRegistry buildDefaultRegistry({LocationService? location}) {
  final r = ControlRegistry();
  r.register(TitleControl());
  r.register(LabelControl());
  r.register(TextControl());
  r.register(NumberControl());
  r.register(CoordinateControl(location: location));
  return r;
}
