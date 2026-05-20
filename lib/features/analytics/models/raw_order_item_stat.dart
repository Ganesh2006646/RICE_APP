class RawOrderItemStat {
  final String varietyName;
  final double quantity;
  final double revenue;
  final DateTime orderDate;

  RawOrderItemStat({
    required this.varietyName,
    required this.quantity,
    required this.revenue,
    required this.orderDate,
  });
}
