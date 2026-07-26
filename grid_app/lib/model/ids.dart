import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Template/survey IDs must stay unique across devices (desktop designs a
/// template while the phone creates surveys), so they are UUID-based. The
/// prefix keeps rows recognizable when debugging; legacy timestamp IDs
/// (tpl_/srv_ + epoch millis) remain valid alongside these.
String newTemplateId() => 'tpl_${_uuid.v4()}';
String newSurveyId() => 'srv_${_uuid.v4()}';
