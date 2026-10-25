import 'package:flutter/material.dart';

import 'app_style.dart';

const stockInColor = Color(0xFF146B45);
const stockOutColor = Color(0xFFB3261E);

class ItemStockPreview extends StatelessWidget {
  const ItemStockPreview({super.key, required this.changes});
  final List<Map<String, dynamic>> changes;
  @override
  Widget build(BuildContext context) {
    final groups = <Object, List<Map<String, dynamic>>>{};
    for (final row in changes) {
      groups.putIfAbsent(row['item_id'] ?? row['item_name'], () => []).add(row);
    }
    return Column(
      children: [
        for (final rows in groups.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      rows.first['item_name'] as String,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    for (final row
                        in [...rows]..sort(
                          (a, b) => (b['quantity_out'] as int).compareTo(
                            a['quantity_out'] as int,
                          ),
                        ))
                      StockMovementRow(
                        title: row['warehouse_name'] as String,
                        incoming: (row['quantity_in'] as int) > 0,
                        quantity: (row['quantity_in'] as int) > 0
                            ? row['quantity_in'] as int
                            : row['quantity_out'] as int,
                        unit: row['unit'] as String,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: forest,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    incoming
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded,
                    color: incoming ? leaf : const Color(0xFFFF8A80),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          warehouse,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label ?? (incoming ? 'Stok masuk' : 'Stok keluar'),
                          style: TextStyle(
                            color: const Color(0xFFC3DDD4),
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
