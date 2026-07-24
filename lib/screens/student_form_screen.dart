import 'package:flutter/material.dart';

import '../models/student.dart';
import '../state/app_store.dart';

class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({
    super.key,
    required this.className,
    required this.store,
    this.student,
  });

  final String className;
  final AppStore store;
  final Student? student;

  bool get isEditing => student != null;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lastNameController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _registerController;
  late final TextEditingController _phoneController;
  late final TextEditingController _guardianController;

  StudentGender? _gender;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _lastNameController = TextEditingController(text: student?.lastName ?? '');
    _firstNameController = TextEditingController(
      text: student?.firstName ?? '',
    );
    _registerController = TextEditingController(text: student?.register ?? '');
    _phoneController = TextEditingController(text: student?.phone ?? '');
    _guardianController = TextEditingController(text: student?.guardian ?? '');
    _gender = student?.gender;
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _registerController.dispose();
    _phoneController.dispose();
    _guardianController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final register = _registerController.text.trim();
    final phone = _phoneController.text.trim();
    final guardian = _guardianController.text.trim();

    if (widget.isEditing) {
      final updated = widget.student!.copyWith(
        lastName: _lastNameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        gender: _gender,
        register: register.isEmpty ? null : register,
        phone: phone.isEmpty ? null : phone,
        guardian: guardian.isEmpty ? null : guardian,
        clearRegister: register.isEmpty,
        clearPhone: phone.isEmpty,
        clearGuardian: guardian.isEmpty,
      );
      widget.store.updateStudent(updated);
    } else {
      final student = Student(
        id: widget.store.nextStudentId(widget.className),
        className: widget.className,
        lastName: _lastNameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        gender: _gender!,
        register: register.isEmpty ? null : register,
        phone: phone.isEmpty ? null : phone,
        guardian: guardian.isEmpty ? null : guardian,
      );
      widget.store.addStudent(student);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? 'Сурагчийн мэдээлэл шинэчлэгдлээ.'
              : 'Сурагч амжилттай нэмэгдлээ.',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Сурагч засах' : 'Сурагч нэмэх'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${widget.className} анги',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Овог',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Овог оруулна уу';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _firstNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Нэр',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Нэр оруулна уу';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<StudentGender>(
              initialValue: _gender,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Хүйс',
                border: OutlineInputBorder(),
              ),
              hint: const Text('Хүйс сонгох'),
              items: StudentGender.values
                  .map(
                    (gender) => DropdownMenuItem(
                      value: gender,
                      child: Text(gender.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _gender = value),
              validator: (value) {
                if (value == null) return 'Хүйсээ сонгоно уу';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _registerController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Регистр (заавал биш)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Утас (заавал биш)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _guardianController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Асран хамгаалагч (заавал биш)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(widget.isEditing ? 'Хадгалах' : '➕ Сурагч нэмэх'),
            ),
          ],
        ),
      ),
    );
  }
}
