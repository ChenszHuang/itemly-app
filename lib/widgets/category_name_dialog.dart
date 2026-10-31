import 'package:flutter/material.dart';

class CategoryNameDialog extends StatefulWidget {
  final String? initialName;

  const CategoryNameDialog({super.key, this.initialName});

  @override
  State<CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<CategoryNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  bool get _isEditing => widget.initialName != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit category' : 'New category'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Category name'),
          onFieldSubmitted: (_) => _submit(),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter a category name'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
