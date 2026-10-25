import 'package:flutter/material.dart';

const stockInColor = Color(0xFF146B45);
const stockOutColor = Color(0xFFB3261E);

String localTransactionTime(Object? value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return 'Waktu tidak tersedia';
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}.${date.minute.toString().padLeft(2, '0')}';
}

class StockMovementRow extends StatelessWidget {
  const StockMovementRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.quantity,
    required this.unit,
    required this.incoming,
  });
  final String title, unit;
  final String? subtitle;
  final int quantity;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final color = incoming ? stockInColor : stockOutColor;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
    final amount = Semantics(
      label: '${incoming ? 'Masuk' : 'Keluar'} $quantity $unit',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${incoming ? '+' : '−'}$quantity $unit',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 250 ||
              MediaQuery.textScalerOf(context).scale(14) > 22) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: amount),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 12),
              Flexible(child: amount),
            ],
          );
        },
      ),
    );
  }
}

class WarehouseMovementCard extends StatelessWidget {
  const WarehouseMovementCard({
    super.key,
    required this.warehouse,
    required this.incoming,
    required this.rows,
    this.label,
  });
  final String warehouse;
  final bool incoming;
  final String? label;
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) {
    final color = incoming ? stockInColor : stockOutColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: color.withValues(alpha: 0.07),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    incoming
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    color: color,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          warehouse,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label ?? (incoming ? 'Stok masuk' : 'Stok keluar'),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var index = 0; index < rows.length; index++) ...[
                    if (index > 0) const Divider(height: 1),
                    rows[index],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
