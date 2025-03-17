import 'package:flutter/material.dart';

class PublicationDateSelector extends StatelessWidget {
  final DateTime? initialDate;
  final ValueChanged<DateTime> onDateSelected;

  const PublicationDateSelector({
    Key? key,
    required this.initialDate,
    required this.onDateSelected,
  }) : super(key: key);

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    if (date.year == now.year) {
      return "$day/$month";
    } else {
      return "$day/$month/${date.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      color: Colors.red.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextButton(
              onPressed: () async {
                final DateTime current = DateTime(now.year, now.month, now.day);
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate:
                      initialDate != null && initialDate!.isAfter(current)
                          ? initialDate!
                          : current,
                  firstDate: current,
                  lastDate: DateTime(now.year + 5),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData(
                        colorScheme: ColorScheme.light(
                          primary: Colors.red.shade300,
                          onPrimary: Colors.white,
                          onSurface: Colors.black,
                        ),
                        dialogBackgroundColor: Colors.red.shade100,
                      ),
                      child: child!,
                    );
                  },
                );
                if (pickedDate != null) {
                  if (pickedDate.isBefore(current)) {
                    onDateSelected(current);
                  } else {
                    onDateSelected(pickedDate);
                  }
                }
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  initialDate != null
                      ? _formatDate(initialDate!)
                      : "Seleccionar fecha",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
