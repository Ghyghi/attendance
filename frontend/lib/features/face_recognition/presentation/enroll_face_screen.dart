import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/search_picker_screen.dart';
import '../../auth/domain/user.dart';
import '../../auth/domain/user_role.dart';
import '../../users/data/users_repository.dart';
import '../../users/presentation/users_providers.dart';
import '../data/face_recognition_repository.dart';
import 'face_recognition_providers.dart';

/// Admin: enroll a student's face from a camera-captured photo.
/// Student is picked via the school-scoped search picker rather than
/// a raw manual ID entry.
class EnrollFaceScreen extends ConsumerStatefulWidget {
  const EnrollFaceScreen({super.key});

  @override
  ConsumerState<EnrollFaceScreen> createState() => _EnrollFaceScreenState();
}

class _EnrollFaceScreenState extends ConsumerState<EnrollFaceScreen> {
  final _picker = ImagePicker();
  User? _selectedStudent;
  bool _isSubmitting = false;

  Future<void> _pickStudent(BuildContext context) async {
    final List<User> students;
    try {
      students = await ref
          .read(usersRepositoryProvider)
          .listUsers(role: UserRole.student);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }

    if (!context.mounted) return;
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No students in your school yet. Create one first.'),
      ));
      return;
    }

    final picked = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => SearchPickerScreen<User>(
          title: 'Select Student',
          items: students,
          labelBuilder: (u) => u.fullName,
          subtitleBuilder: (u) => u.username,
          idOf: (u) => u.id,
          emptyMessage: 'No students found.',
        ),
      ),
    );

    if (picked == null || picked.isEmpty) return;
    final studentId = picked.first;
    setState(() {
      _selectedStudent = students.firstWhere((u) => u.id == studentId);
    });
  }

  Future<void> _enroll(BuildContext context) async {
    if (_selectedStudent == null) {
      _showMessage('Select a student first.', isError: true);
      return;
    }

    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (photo == null) return;

    setState(() => _isSubmitting = true);
    try {
      final bytes = await File(photo.path).readAsBytes();
      final base64Photo = base64Encode(bytes);

      await ref.read(faceRecognitionRepositoryProvider).enroll(
        studentId: _selectedStudent!.id,
        photoBase64: base64Photo,
      );

      if (!mounted) return;
      _showMessage(
          'Face enrolled for ${_selectedStudent!.fullName}.');
      setState(() => _selectedStudent = null);
    } on FaceRecognitionException catch (e) {
      if (!mounted) return;
      _showMessage(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enroll Face')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.face_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select a student, then capture their reference photo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed:
                  _isSubmitting ? null : () => _pickStudent(context),
                  icon: const Icon(Icons.person_search_outlined),
                  label: Text(_selectedStudent == null
                      ? 'Select Student'
                      : _selectedStudent!.fullName),
                ),
                if (_selectedStudent != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _selectedStudent!.username,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: (_isSubmitting || _selectedStudent == null)
                      ? null
                      : () => _enroll(context),
                  icon: _isSubmitting
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.camera_alt_outlined),
                  label: Text(
                      _isSubmitting ? 'Enrolling...' : 'Capture & Enroll'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}