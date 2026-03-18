import 'package:flutter/material.dart';
import '../../../common/utils.dart';

Widget buildDueDatePicker(
  BuildContext context,
  DateTime? selectedDate,
  ValueChanged<DateTime?> onChanged,
) {
  return Row(
    children: [
      Expanded(
        child: InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Due Date',
              suffixIcon: Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(
              selectedDate != null ? formatDate(selectedDate) : 'No due date',
              style: TextStyle(
                color: selectedDate != null ? null : Colors.grey,
              ),
            ),
          ),
        ),
      ),
      if (selectedDate != null)
        IconButton(
          icon: const Icon(Icons.clear, size: 18),
          tooltip: 'Remove due date',
          onPressed: () => onChanged(null),
        ),
    ],
  );
}

Widget buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Text(value),
      ],
    ),
  );
}

String formatMin(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}
