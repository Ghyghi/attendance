import 'package:flutter/material.dart';

/// Generic search-and-pick screen for any list of items.
///
/// Design note on the search behavior: this filters CLIENT-SIDE over a
/// list that's already been scoped SERVER-SIDE (e.g. "teachers in my
/// school", "classrooms I teach") — it does not issue a new network
/// request per keystroke. The server-side scoping is what enforces "the
/// client shouldn't have access to info that isn't theirs"; the search
/// box on top of that is purely a client-side convenience for narrowing
/// an already-authorized list, not a second access-control boundary.
///
/// Generic over [T] so one widget serves the teacher picker, student
/// picker, and classroom picker without duplicating the search/filter/
/// selection-state logic three times — callers supply how to label and
/// identify each item via [labelBuilder]/[subtitleBuilder]/[idOf].
class SearchPickerScreen<T> extends StatefulWidget {
  const SearchPickerScreen({
    super.key,
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.idOf,
    this.subtitleBuilder,
    this.multiSelect = false,
    this.initiallySelectedIds = const {},
    this.emptyMessage = 'No results.',
  });

  final String title;
  final List<T> items;
  final String Function(T item) labelBuilder;
  final String? Function(T item)? subtitleBuilder;
  final String Function(T item) idOf;
  final bool multiSelect;
  final Set<String> initiallySelectedIds;
  final String emptyMessage;

  @override
  State<SearchPickerScreen<T>> createState() => _SearchPickerScreenState<T>();
}

class _SearchPickerScreenState<T> extends State<SearchPickerScreen<T>> {
  late Set<String> _selectedIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = {...widget.initiallySelectedIds};
  }

  List<T> get _filteredItems {
    if (_query.trim().isEmpty) return widget.items;
    final lowerQuery = _query.trim().toLowerCase();
    return widget.items
        .where((item) => widget.labelBuilder(item).toLowerCase().contains(lowerQuery))
        .toList();
  }

  void _toggle(String id) {
    if (widget.multiSelect) {
      setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      });
    } else {
      // Single-select: tapping immediately returns the pick rather than
      // requiring a separate confirm action — fewer taps for the common
      // case (classroom picker, single-teacher-ish flows).
      Navigator.of(context).pop(<String>{id});
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.multiSelect
            ? [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selectedIds),
            // Use onPrimary (AppBar foreground) instead of hardcoded
            // white — hardcoded white is invisible on light themes.
            style: TextButton.styleFrom(
              foregroundColor:
              Theme.of(context).appBarTheme.foregroundColor ??
                  Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(
              _selectedIds.isEmpty
                  ? 'Done'
                  : 'Done (${_selectedIds.length})',
            ),
          ),
        ]
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(widget.emptyMessage))
                : ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = filtered[index];
                final id = widget.idOf(item);
                final subtitle = widget.subtitleBuilder?.call(item);
                final isSelected = _selectedIds.contains(id);

                return ListTile(
                  title: Text(widget.labelBuilder(item)),
                  subtitle: subtitle != null ? Text(subtitle) : null,
                  trailing: widget.multiSelect
                      ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggle(id),
                  )
                      : const Icon(Icons.chevron_right),
                  onTap: () => _toggle(id),
                );
              },
            ),
          ),
          // Sticky confirm bar — only shown in multi-select mode.
          // Provides a large, always-visible confirm action in addition
          // to the AppBar "Done" button.
          if (widget.multiSelect)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_selectedIds),
                  child: Text(
                    _selectedIds.isEmpty
                        ? 'Confirm selection'
                        : 'Confirm (${_selectedIds.length} selected)',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}