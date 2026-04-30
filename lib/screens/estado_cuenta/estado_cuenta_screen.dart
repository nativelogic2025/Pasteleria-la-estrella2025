// estado_cuenta_screen.dart
import 'package:flutter/material.dart';

import 'estado_cuenta_dinero.dart';
import 'estado_cuenta_productos.dart';
import 'estado_cuenta_ia.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EstadoCuentaScreen extends StatefulWidget {
  const EstadoCuentaScreen({super.key});

  @override
  State<EstadoCuentaScreen> createState() => _EstadoCuentaScreenState();
}

class _EstadoCuentaScreenState extends State<EstadoCuentaScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pantallas = const [
    EstadoCuentaDineroScreen(),
    EstadoCuentaProductosScreen(),
    EstadoCuentaIaScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.bar_chart_rounded, color: Color(0xFF8C5535)),
            const SizedBox(width: 12),
            const Text('Estado de Cuenta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =======================
          // PANEL IZQUIERDO (Menú Lateral)
          // =======================
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 12),
                  child: Text(
                    'REPORTES FINANCIEROS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                _MenuItem(
                  title: 'Flujo de Caja Real',
                  icon: Icons.account_balance_wallet_rounded,
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ).animate().fade().slideX(begin: -0.1),
                const SizedBox(height: 8),
                _MenuItem(
                  title: 'Desempeño de Productos',
                  icon: Icons.inventory_2_rounded,
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ).animate().fade(delay: 100.ms).slideX(begin: -0.1),
                const SizedBox(height: 8),
                _MenuItem(
                  title: 'Asistente Financiero IA',
                  icon: Icons.auto_awesome,
                  isSelected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ).animate().fade(delay: 200.ms).slideX(begin: -0.1),
              ],
            ),
          ),
          
          // =======================
          // PANEL DERECHO (Reporte)
          // =======================
          Expanded(
            child: IndexedStack(
              key: ValueKey(_selectedIndex),
              index: _selectedIndex,
              children: _pantallas,
            ).animate().fade(duration: 400.ms).slideY(begin: 0.02),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFCF5EE) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF8C5535).withValues(alpha: 0.5) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF8C5535) : Colors.grey.shade600, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? const Color(0xFF8C5535) : Colors.black87,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
