import 'package:flutter/material.dart';

class VaultMenu extends StatefulWidget {
  const VaultMenu({
    super.key,
    required this.lineItems,
  });

  final List<LineItem> lineItems;

  @override
  State<VaultMenu> createState() => _VaultMenuState();
}

class _VaultMenuState extends State<VaultMenu> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < widget.lineItems.length; i += 1) ...[
          VaultLineItem(
            indentLevel: widget.lineItems[i].indentLevel,
            isContainer: widget.lineItems[i].isContainer,
            isOpen: widget.lineItems[i].isOpen,
            label: widget.lineItems[i].name,
            isActive: widget.lineItems[i].isActive,
          ),
          const SizedBox(height: 1),
        ],
      ],
    );
  }
}

class LineItem {
  LineItem({
    required this.indentLevel,
    required this.isContainer,
    this.isOpen = false,
    this.icon,
    this.name = "",
    this.value = "",
    this.isActive = false,
  }) : assert(isContainer == true || isOpen == false, "Only containers can be marked as 'open'.");

  final int indentLevel;

  bool isContainer;
  bool isOpen;

  final IconData? icon;
  final String name;
  final String value;

  final bool isActive;
}

class VaultLineItem extends StatefulWidget {
  const VaultLineItem({
    super.key,
    this.height = 28,
    required this.indentLevel,
    this.indentPixelsPerLevel = 16,
    required this.isContainer,
    this.isOpen = false,
    required this.label,
    this.isActive = false,
    this.onPressed,
  });

  final double height;

  final int indentLevel;
  final double indentPixelsPerLevel;
  final bool isContainer;
  final bool isOpen;

  final String label;

  final bool isActive;

  final VoidCallback? onPressed;

  @override
  State<VaultLineItem> createState() => _VaultLineItemState();
}

class _VaultLineItemState extends State<VaultLineItem> {
  bool _isHighlighted = false;

  @override
  void initState() {
    super.initState();

    _isHighlighted = widget.isActive;
  }

  @override
  void didUpdateWidget(VaultLineItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    _isHighlighted = widget.isActive;
  }

  void _onHoverEnter(_) {
    setState(() {
      _isHighlighted = true;
    });
  }

  void _onHoverExit(_) {
    setState(() {
      _isHighlighted = widget.isActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: _onHoverEnter,
      onExit: _onHoverExit,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: _isHighlighted ? Colors.white.withOpacity(0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: 4),
              _buildIndentLines(),
              _buildChevron(),
              const SizedBox(width: 4),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndentLines() {
    return SizedBox(
      width: widget.indentLevel * widget.indentPixelsPerLevel,
      child: CustomPaint(
        painter: _IndentPainter(
          indentSpace: widget.indentPixelsPerLevel,
          indentLevel: widget.indentLevel,
        ),
      ),
    );
  }

  Widget _buildChevron() {
    if (!widget.isContainer) {
      return SizedBox(width: widget.indentPixelsPerLevel);
    }

    return SizedBox(
      width: widget.indentPixelsPerLevel,
      child: Icon(
        widget.isOpen ? Icons.keyboard_arrow_down : Icons.chevron_right,
        color: Colors.white.withOpacity(0.3),
        size: 16,
      ),
    );
  }
}

class _IndentPainter extends CustomPainter {
  const _IndentPainter({
    required this.indentSpace,
    required this.indentLevel,
  });

  final double indentSpace;
  final int indentLevel;

  @override
  void paint(Canvas canvas, Size size) {
    if (indentLevel == 0) {
      return;
    }

    final linesPath = Path();

    // Draw vertical lines at each indentation level.
    double x = indentSpace / 2;
    for (int i = 0; i < indentLevel; i += 1) {
      linesPath.addRect(Rect.fromLTWH(x, 0, 1, size.height));

      if (i < indentLevel - 1) {
        x += indentSpace;
      }
    }

    canvas.drawPath(linesPath, Paint()..color = Colors.white.withOpacity(0.1));
  }

  @override
  bool shouldRepaint(_IndentPainter oldDelegate) {
    return oldDelegate.indentSpace != indentSpace || oldDelegate.indentLevel != indentLevel;
  }
}
