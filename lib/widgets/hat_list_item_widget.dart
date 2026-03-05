import 'package:flutter/material.dart';

class HatListItemWidget extends StatelessWidget {
  final Map<String, dynamic> hat;
  final Color categoryColor;
  final String categoryIcon;
  final VoidCallback? onTap;

  const HatListItemWidget({
    Key? key,
    required this.hat,
    required this.categoryColor,
    required this.categoryIcon,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final kat = hat['kat']?.toString() ?? 'otobus';
    final code = hat['code']?.toString() ?? '';
    final name = hat['name']?.toString() ?? code;

    Widget leadingIcon;
    if (kat == 'havalimani') {
      leadingIcon = Image.asset('assets/samair.png', width: 28, height: 28, fit: BoxFit.contain);
    } else if (kat == 'tekne') {
      leadingIcon = Text(categoryIcon, style: const TextStyle(fontSize: 20));
    } else if (kat == 'otobus' || kat == 'ring' || kat == 'ekspres' || kat == 'tramvay') {
      leadingIcon = Image.asset('assets/SBB Logo 9.png', width: 28, height: 28, fit: BoxFit.contain);
    } else {
      leadingIcon = Text(categoryIcon, style: const TextStyle(fontSize: 20));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF152238),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryColor.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [categoryColor, categoryColor.withValues(alpha: 0.6)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: leadingIcon),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
        subtitle: Text(code, style: TextStyle(color: categoryColor, fontWeight: FontWeight.bold, fontSize: 11)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: categoryColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(kat.toUpperCase(), style: TextStyle(color: categoryColor, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
        onTap: onTap,
      ),
    );
  }
}
