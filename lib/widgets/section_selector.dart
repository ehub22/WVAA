import 'package:flutter/material.dart';

/// Material 3 replacement for the old swiping card "carousel" used above the
/// Calendars / Newsletters / Publications lists.
///
/// Design goals:
///  * One consistent, theme-driven look in light and dark mode (the old cards
///    hardcoded white/black text that failed contrast in dark mode).
///  * 48dp minimum tap targets.
///  * Text scales with the system font size: labels wrap and the row scrolls
///    horizontally instead of clipping.
///  * Screen-reader friendly: each pill announces as a button with its label
///    and selected/unselected state.
class SectionSelector extends StatelessWidget {
  const SectionSelector({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  })  : assert(labels.length > 0),
        assert(selectedIndex >= 0 && selectedIndex < labels.length);

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            _SelectorPill(
              label: labels[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
              selectedColor: scheme.primary,
              selectedContentColor: scheme.onPrimary,
              unselectedColor: scheme.surfaceContainerHigh,
              unselectedContentColor: scheme.onSurfaceVariant,
              outlineColor: scheme.outlineVariant,
            ),
        ],
      ),
    );
  }
}

class _SelectorPill extends StatelessWidget {
  const _SelectorPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
    required this.selectedContentColor,
    required this.unselectedColor,
    required this.unselectedContentColor,
    required this.outlineColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color selectedContentColor;
  final Color unselectedColor;
  final Color unselectedContentColor;
  final Color outlineColor;

  @override
  Widget build(BuildContext context) {
    final background = selected ? selectedColor : unselectedColor;
    final foreground =
        selected ? selectedContentColor : unselectedContentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          // The Text child supplies the label; this adds the selected state
          // so screen readers announce the active section.
          child: Semantics(
            selected: selected,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An [IndexedStack] that only builds children once they have been visited.
///
/// Used instead of swapping children by index so each section keeps its state
/// (scroll position, loaded WebView content, fetched data) when the student
/// switches back and forth — while a tab that is never opened costs nothing
/// (no eager network fetches on flaky school Wi-Fi).
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.itemCount,
    required this.itemBuilder,
  })  : assert(itemCount > 0),
        assert(index >= 0 && index < itemCount);

  final int index;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _visited = <int>{};

  @override
  void initState() {
    super.initState();
    _visited.add(widget.index);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.itemCount; i++)
          if (_visited.contains(i)) widget.itemBuilder(context, i) else const SizedBox.shrink(),
      ],
    );
  }
}
