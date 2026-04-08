import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../utils/validators.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final String? productId;
  const AddEditProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _shortTitleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  bool _loading = false;
  bool _loadingProduct = false;
  Product? _existingProduct;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() => _loadingProduct = true);
    try {
      final product = await ref
          .read(productRepositoryProvider)
          .getById(widget.productId!);
      _existingProduct = product;
      _titleCtrl.text = product.title;
      _shortTitleCtrl.text = product.shortTitle;
      _descCtrl.text = product.description;
      _categoryCtrl.text = product.category;
      _priceCtrl.text = product.priceLkr.toString();
      _keywordsCtrl.text = product.keywords;
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loadingProduct = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _shortTitleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _keywordsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final businessDynamic =
          await ref.read(currentUserBusinessProvider.future);
      if (businessDynamic == null) throw Exception('No business found');
      final business = businessDynamic as Business;

      final now = DateTime.now();
      if (_isEditing && _existingProduct != null) {
        await ref.read(productRepositoryProvider).update(
              _existingProduct!.copyWith(
                title: _titleCtrl.text.trim(),
                shortTitle: _shortTitleCtrl.text.trim(),
                description: _descCtrl.text.trim(),
                category: _categoryCtrl.text.trim(),
                priceLkr: double.parse(_priceCtrl.text.trim()),
                keywords: _keywordsCtrl.text.trim(),
              ),
            );
        if (mounted) {
          context.showSnackBar('Product updated');
          context.pop();
        }
      } else {
        await ref.read(productRepositoryProvider).create(
              Product(
                id: '',
                businessId: business.id,
                title: _titleCtrl.text.trim(),
                shortTitle: _shortTitleCtrl.text.trim(),
                description: _descCtrl.text.trim(),
                category: _categoryCtrl.text.trim(),
                priceLkr: double.parse(_priceCtrl.text.trim()),
                keywords: _keywordsCtrl.text.trim(),
                createdAt: now,
                updatedAt: now,
              ),
            );
        if (mounted) {
          context.showSnackBar('Product created');
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProduct) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Product Title'),
                validator: (v) => Validators.required(v, 'Title'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _shortTitleCtrl,
                decoration:
                    const InputDecoration(labelText: 'Short Title (optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
                validator: (v) => Validators.required(v, 'Description'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (v) => Validators.required(v, 'Category'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceCtrl,
                decoration:
                    const InputDecoration(labelText: 'Price (LKR)', prefixText: 'LKR '),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: Validators.price,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _keywordsCtrl,
                decoration: const InputDecoration(
                    labelText: 'Keywords',
                    hintText: 'Comma separated keywords for search'),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Save Changes' : 'Create Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
