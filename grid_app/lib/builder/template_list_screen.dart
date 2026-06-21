import 'package:flutter/material.dart';

import '../controls/registry.dart';
import '../data/template_store.dart';
import '../model/template.dart';
import '../sample/sample_template.dart';
import 'builder_screen.dart';

/// Home screen: lists saved templates; create a new one (seeded from the sample
/// layout), open one to view/preview, or delete one.
class TemplateListScreen extends StatefulWidget {
  final TemplateStore store;
  final ControlRegistry registry;

  const TemplateListScreen(
      {super.key, required this.store, required this.registry});

  @override
  State<TemplateListScreen> createState() => _TemplateListScreenState();
}

class _TemplateListScreenState extends State<TemplateListScreen> {
  List<Template> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.store.all();
    if (!mounted) return;
    setState(() {
      _templates = list;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final t = sampleTemplate().copyWith(
      id: 'tpl_${DateTime.now().millisecondsSinceEpoch}',
      name: 'New Template',
    );
    await widget.store.upsert(t);
    if (!mounted) return;
    await _open(t);
  }

  Future<void> _open(Template t) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BuilderScreen(
          template: t, registry: widget.registry, store: widget.store),
    ));
    await _reload();
  }

  Future<void> _delete(Template t) async {
    await widget.store.delete(t.id);
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SCSS Templates')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? const Center(child: Text('No templates yet. Tap + to create one.'))
              : ListView(
                  children: [
                    for (final t in _templates)
                      Dismissible(
                        key: ValueKey(t.id),
                        direction: DismissDirection.endToStart,
                        background: const SizedBox.shrink(),
                        secondaryBackground: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _delete(t),
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text(
                              '${t.grid.cols}×${t.grid.rows} · ${t.cells.length} cells'),
                          onTap: () => _open(t),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        tooltip: 'New template',
        child: const Icon(Icons.add),
      ),
    );
  }
}
