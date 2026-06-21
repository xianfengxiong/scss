import 'package:flutter/material.dart';

import '../models/gps_data.dart';

/// Shows the current GPS fix with a status chip and Capture / Manual buttons.
class GpsCaptureTile extends StatelessWidget {
  final GpsData? gps;
  final bool loading;
  final VoidCallback onCapture;
  final VoidCallback onManual;

  const GpsCaptureTile({
    super.key,
    required this.gps,
    required this.onCapture,
    required this.onManual,
    this.loading = false,
  });

  Color _statusColor(GpsStatus s) {
    switch (s) {
      case GpsStatus.valid:
        return Colors.green;
      case GpsStatus.weak:
        return Colors.orange;
      case GpsStatus.unavailable:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = gps;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, size: 20),
                const SizedBox(width: 8),
                const Text('GPS', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (g != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(g.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      g.status.name,
                      style: TextStyle(
                          color: _statusColor(g.status), fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              g != null ? g.display : 'Not captured',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: loading ? null : onCapture,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text('Capture GPS'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onManual,
                  icon: const Icon(Icons.edit_location_alt),
                  label: const Text('Manual'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
