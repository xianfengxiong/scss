import 'field_control.dart';
import 'registry.dart';
import 'title_control.dart';

/// The app's starting control set. Add new controls by registering them here.
ControlRegistry buildDefaultRegistry() {
  final r = ControlRegistry();
  r.register(TitleControl());
  r.register(FieldControl());
  return r;
}
