// estado_widgets.dart
import 'package:flutter/material.dart';

/// ==== KPI card compacto, blanco con acentos negros ====
class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFEFEFEF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEAEAEA)),
                ),
                child: Icon(icon, color: iconColor ?? Colors.black87),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.black54, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

/// ==== Tarjeta de sección genérica ====
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const SectionCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFEFEFEF)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.black87)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// ==== Estado vacío consistente ====
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFEFEF)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Icon(icon, color: Colors.black38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.black87)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: const TextStyle(color: Colors.black54)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// ==== Selector de periodo (Día / Mes / Año) ====
class PeriodoSelector extends StatelessWidget {
  final String value;
  final void Function(String?) onChanged;
  const PeriodoSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE6E6E6)),
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFF6F6F6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'Día', child: Text('Día')),
            DropdownMenuItem(value: 'Mes', child: Text('Mes')),
            DropdownMenuItem(value: 'Año', child: Text('Año')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// ==== Navegación del periodo (anterior/siguiente) ====
class PeriodoNav extends StatelessWidget {
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const PeriodoNav({super.key, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton(
          onPressed: onPrev,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
            foregroundColor: Colors.black87,
            minimumSize: const Size(40, 40),
          ),
          child: const Icon(Icons.chevron_left),
        ),
        const SizedBox(width: 6),
        OutlinedButton(
          onPressed: onNext,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
            foregroundColor: Colors.black87,
            minimumSize: const Size(40, 40),
          ),
          child: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// ==== (Opcional) Header listo: selector + nav + título del periodo ====
class PeriodoHeader extends StatelessWidget {
  final String periodoValue;
  final void Function(String?) onPeriodoChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final String titlePeriodo;

  const PeriodoHeader({
    super.key,
    required this.periodoValue,
    required this.onPeriodoChanged,
    required this.onPrev,
    required this.onNext,
    required this.titlePeriodo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          PeriodoSelector(value: periodoValue, onChanged: onPeriodoChanged),
          const SizedBox(width: 8),
          PeriodoNav(onPrev: onPrev, onNext: onNext),
          const Spacer(),
          Text(
            titlePeriodo.isNotEmpty
                ? titlePeriodo[0].toUpperCase() + titlePeriodo.substring(1)
                : '',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
