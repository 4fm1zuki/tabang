import 'package:flutter/material.dart';

import '../theme.dart';

/// TABANG's own dropdown, used everywhere instead of [DropdownButtonFormField].
///
/// The stock control looks plain next to the rest of the app and cannot mark
/// the selected row. This keeps the same call shape — a list of
/// [DropdownMenuItem]s, a value, a validator and an [InputDecoration] — so a
/// call site only changes its type name, while the presentation matches the
/// design:
///
/// * a bordered field with a chevron that flips while the picker is open;
/// * a rounded, shadowed panel with the options;
/// * the selected row carries a crimson bar and bold text;
/// * a search box appears once the list passes [searchThreshold] items, which
///   the barangay and moderation-keyword lists need.
///
/// The options open in a sheet rather than an inline overlay: it keeps its
/// place on a phone keyboard, needs no anchor maths, and behaves identically on
/// every width.
class TabangDropdown<T> extends StatefulWidget {
  const TabangDropdown({
    super.key,
    required this.items,
    this.value,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.decoration,
    this.enabled = true,
    this.isExpanded = true,
    this.isDense,
    this.hint,
    this.autovalidateMode,
    this.searchThreshold = 8,
    this.searchHint = 'Search',
    this.emptyLabel = 'No matches',
    this.title,
    // Accepted and ignored so a call site written for the stock control does
    // not have to drop its styling arguments: the panel look is fixed here.
    this.menuMaxHeight,
    this.dropdownColor,
    this.borderRadius,
    this.icon,
    this.focusColor,
    this.style,
  });

  final List<DropdownMenuItem<T>> items;

  /// Current value. [initialValue] is accepted as well so call sites written
  /// against different Flutter versions need no edit.
  final T? value;
  final T? initialValue;

  final ValueChanged<T?>? onChanged;

  /// Validates inside a [Form], exactly like the stock control.
  final FormFieldValidator<T>? validator;

  /// Only `labelText`, `hintText` and `helperText` are read, so a call site can
  /// keep the decoration it already passes.
  final InputDecoration? decoration;

  final bool enabled;
  final bool isExpanded;
  final bool? isDense;

  /// Placeholder shown while nothing is selected. Falls back to
  /// `decoration.hintText` and then to "Select".
  final Widget? hint;

  final AutovalidateMode? autovalidateMode;

  /// Show the search box when there are more items than this.
  final int searchThreshold;
  final String searchHint;
  final String emptyLabel;

  /// Optional heading for the picker sheet.
  final String? title;

  /// Accepted for call-site compatibility; the panel styling is fixed.
  final double? menuMaxHeight;
  final Color? dropdownColor;
  final BorderRadius? borderRadius;
  final Widget? icon;
  final Color? focusColor;

  /// Field text style; the colour is still chosen from the selection state.
  final TextStyle? style;

  @override
  State<TabangDropdown<T>> createState() => _TabangDropdownState<T>();
}

class _TabangDropdownState<T> extends State<TabangDropdown<T>> {
  bool _open = false;

  String _labelOf(DropdownMenuItem<T> item) {
    final child = item.child;
    if (child is Text) return child.data ?? '';
    if (child is RichText) return child.text.toPlainText();
    return item.value?.toString() ?? '';
  }

  Future<void> _pick(FormFieldState<T> field) async {
    if (!widget.enabled) return;
    setState(() => _open = true);
    final value = await showModalBottomSheet<T?>(
      context: context,
      backgroundColor: context.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TabangRadius.lg),
        ),
      ),
      builder: (sheetContext) => _Picker<T>(
        items: widget.items,
        labelOf: _labelOf,
        selected: field.value,
        title: widget.title ?? widget.decoration?.labelText,
        searchThreshold: widget.searchThreshold,
        searchHint: widget.searchHint,
        emptyLabel: widget.emptyLabel,
      ),
    );
    if (!mounted) return;
    setState(() => _open = false);
    // A sheet dismissed by tapping outside returns null; only a real choice
    // changes the field.
    if (value == null) return;
    field.didChange(value);
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration ?? const InputDecoration();
    final selected = widget.value ?? widget.initialValue;

    return FormField<T>(
      initialValue: selected,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode ?? AutovalidateMode.disabled,
      builder: (field) {
        final current = field.value ?? selected;
        final chosen = widget.items.where((item) => item.value == current);
        final label = chosen.isEmpty ? null : chosen.first.child;
        final hasError = field.errorText != null;
        final caption = decoration.labelText;

        // The field is built by hand rather than with InputDecorator: feeding a
        // floating label and a custom child to that widget drew the label and
        // the value on top of each other, which is what produced the doubled
        // "Allbloodtype" text. A caption above a plain bordered box cannot
        // overlap, and it matches the design better.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (caption != null && caption.isNotEmpty) ...[
              Text(
                caption,
                style: TextStyle(fontSize: 11.5, color: context.textMuted),
              ),
              const SizedBox(height: 4),
            ],
            InkWell(
              onTap: widget.enabled ? () => _pick(field) : null,
              borderRadius: BorderRadius.circular(TabangRadius.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TabangSpace.md,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: widget.enabled ? context.surface : context.surfaceAlt,
                  borderRadius: BorderRadius.circular(TabangRadius.sm),
                  border: Border.all(
                    color: hasError ? TabangColors.danger : context.border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: (widget.style ?? const TextStyle(fontSize: 13.5))
                            .copyWith(
                              color: current == null
                                  ? context.textMuted
                                  : context.textColor,
                            ),
                        child:
                            label ??
                            widget.hint ??
                            Text(
                              decoration.hintText ?? 'Select',
                              style: TextStyle(color: context.textMuted),
                            ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 19,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (field.errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: TabangColors.danger,
                  ),
                ),
              )
            else if (decoration.helperText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text(
                  decoration.helperText!,
                  style: TextStyle(fontSize: 11.5, color: context.textMuted),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The option list: search first (for long lists), then the rows.
class _Picker<T> extends StatefulWidget {
  const _Picker({
    required this.items,
    required this.labelOf,
    required this.selected,
    required this.title,
    required this.searchThreshold,
    required this.searchHint,
    required this.emptyLabel,
  });

  final List<DropdownMenuItem<T>> items;
  final String Function(DropdownMenuItem<T>) labelOf;
  final T? selected;
  final String? title;
  final int searchThreshold;
  final String searchHint;
  final String emptyLabel;

  @override
  State<_Picker<T>> createState() => _PickerState<T>();
}

class _PickerState<T> extends State<_Picker<T>> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSearch = widget.items.length > widget.searchThreshold;
    final query = _query.trim().toLowerCase();
    final items = query.isEmpty
        ? widget.items
        : widget.items
              .where((item) => widget.labelOf(item).toLowerCase().contains(query))
              .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TabangSpace.md,
          0,
          TabangSpace.md,
          TabangSpace.md,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: TabangSpace.sm),
                  child: Text(
                    widget.title!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.textColor,
                    ),
                  ),
                ),
              if (showSearch)
                Padding(
                  padding: const EdgeInsets.only(bottom: TabangSpace.sm),
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 17),
                    ),
                  ),
                ),
              Flexible(
                child: items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(TabangSpace.md),
                        child: Text(
                          widget.emptyLabel,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.textMuted,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isSelected = item.value == widget.selected;
                          return InkWell(
                            onTap: () => Navigator.pop(context, item.value),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: TabangSpace.md,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? TabangColors.crimson.withValues(
                                        alpha: 0.08,
                                      )
                                    : null,
                                border: Border(
                                  left: BorderSide(
                                    width: 3,
                                    color: isSelected
                                        ? TabangColors.crimson
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              child: DefaultTextStyle.merge(
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? TabangColors.crimson
                                      : context.textColor,
                                ),
                                child: item.child,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
