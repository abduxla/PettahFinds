import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../utils/validators.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/error_widget.dart';

class EditBusinessProfileScreen extends ConsumerStatefulWidget {
  const EditBusinessProfileScreen({super.key});

  @override
  ConsumerState<EditBusinessProfileScreen> createState() =>
      _EditBusinessProfileScreenState();
}

class _EditBusinessProfileScreenState
    extends ConsumerState<EditBusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  bool _loading = false;
  bool _initialized = false;

  void _initFields(Business business) {
    if (_initialized) return;
    _nameCtrl.text = business.businessName;
    _locationCtrl.text = business.location;
    _descCtrl.text = business.description;
    _phoneCtrl.text = business.phone;
    _emailCtrl.text = business.email;
    _categoryCtrl.text = business.category;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(Business business) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(businessRepositoryProvider).update(
            business.copyWith(
              businessName: _nameCtrl.text.trim(),
              location: _locationCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              category: _categoryCtrl.text.trim(),
            ),
          );
      if (mounted) {
        context.showSnackBar('Profile updated');
        context.pop();
      }
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessAsync = ref.watch(currentUserBusinessProvider);

    return businessAsync.when(
      data: (businessDynamic) {
        if (businessDynamic == null) {
          return const Scaffold(body: Center(child: Text('No business')));
        }
        final business = businessDynamic as Business;
        _initFields(business);

        return Scaffold(
          appBar: AppBar(title: const Text('Edit Business Profile')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Business Name'),
                    validator: (v) =>
                        Validators.required(v, 'Business name'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _categoryCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Category'),
                    validator: (v) => Validators.required(v, 'Category'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Location'),
                    validator: (v) => Validators.required(v, 'Location'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                    maxLines: 4,
                    validator: (v) =>
                        Validators.required(v, 'Description'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _loading ? null : () => _save(business),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) =>
          Scaffold(body: AppErrorWidget(message: e.toString())),
    );
  }
}
