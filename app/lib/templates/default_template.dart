import '../models/field_def.dart';
import '../models/template_row.dart';

/// Name of the default template seeded into the library on first launch.
const String kDefaultTemplateName = 'Smart City Site Survey';

TemplateField _f(String label, String key,
        {FieldType type = FieldType.text, String? unit}) =>
    TemplateField(label: label, key: key, type: type, unit: unit);

/// Default table template, laid out to reproduce the real Gjirokastër
/// site-survey Excel form. The same rows drive the editor, the fill screen and
/// the PDF (WYSIWYG).
List<TemplateRow> defaultTemplateRows() => [
      TemplateRow.title('Site Survey Form'),
      TemplateRow.field(_f('Site Name', 'site_name')),
      TemplateRow.field(_f('Site City', 'site_city')),
      TemplateRow.field(_f('GPS', 'gps', type: FieldType.coordinate)),

      TemplateRow.section('Devices to Install'),
      TemplateRow.deviceTable(
          listKey: 'devices', columns: const ['Type', 'Number', 'Remark']),

      TemplateRow.section('Poles & Structures'),
      TemplateRow.field(
          _f('Number of cabinets on the poles', 'cabinets_on_poles',
              type: FieldType.number)),
      TemplateRow.field(_f('Number of new poles', 'new_poles',
          type: FieldType.number)),
      TemplateRow.field(_f('Length of the new pole arms', 'new_pole_arm_length',
          type: FieldType.number, unit: 'm')),
      TemplateRow.field(_f('Height of the new poles', 'new_pole_height',
          type: FieldType.number, unit: 'm')),
      TemplateRow.field(_f('Number of existing poles', 'existing_poles',
          type: FieldType.number)),
      TemplateRow.field(_f(
          'Length of the existing pole arms', 'existing_pole_arm_length',
          type: FieldType.number, unit: 'm')),

      TemplateRow.section('Traffic Layout'),
      TemplateRow.field(_f('Number of directions', 'directions',
          type: FieldType.number)),
      TemplateRow.field(_f('Number of lanes', 'lanes', type: FieldType.number)),
      TemplateRow.field(_f('Number of junction boxes', 'junction_boxes',
          type: FieldType.number)),
      TemplateRow.field(_f(
          'Number of traffic light detectors', 'traffic_light_detectors',
          type: FieldType.number)),

      TemplateRow.section('Network & Power'),
      TemplateRow.field(_f('Number of PoE switches', 'poe_switches',
          type: FieldType.number)),
      TemplateRow.field(_f(
          'Number of fiber optic transceivers', 'fiber_transceivers',
          type: FieldType.number)),
      TemplateRow.field(_f('Number of new UPS with battery', 'new_ups',
          type: FieldType.number)),
      TemplateRow.field(_f(
          'Power supply distribution cabinet coordinate', 'power_cabinet_coord',
          type: FieldType.coordinate)),
      TemplateRow.field(_f(
          'Fiber optic distribution cabinet coordinate', 'fiber_cabinet_coord',
          type: FieldType.coordinate)),

      TemplateRow.section('Cable Estimates'),
      TemplateRow.field(
          _f('Estimated fibre', 'est_fibre', type: FieldType.number, unit: 'm')),
      TemplateRow.field(_f('Estimated electricity', 'est_electricity',
          type: FieldType.number, unit: 'm')),
      TemplateRow.field(_f('Estimated LAN cable', 'est_lan',
          type: FieldType.number, unit: 'm')),
      TemplateRow.field(
          _f('Estimated pipe', 'est_pipe', type: FieldType.number, unit: 'm')),

      TemplateRow.section('Cameras'),
      TemplateRow.field(_f('Number of current cameras', 'current_cameras',
          type: FieldType.number)),

      TemplateRow.section('Other'),
      TemplateRow.field(_f('Other considerations', 'other')),

      TemplateRow.section('Diagrams & Photos'),
      TemplateRow.image(imageKind: 'diagram', text: 'Site diagram'),
      TemplateRow.image(imageKind: 'photos', text: 'Site photos'),
    ];
