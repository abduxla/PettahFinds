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
    final theme = Theme.of(context);

    if (_loadingProduct) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header icon
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isEditing
                        ? Icons.edit_rounded
                        : Icons.add_shopping_cart_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
              ),

              _buildField(
                controller: _titleCtrl,
                label: 'Product Title',
                icon: Icons.shopping_bag_outlined,
                validator: (v) => Validators.required(v, 'Title'),
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _shortTitleCtrl,
                label: 'Short Title (optional)',
                icon: Icons.short_text_rounded,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _descCtrl,
                label: 'Description',
                icon: Icons.description_outlined,
                maxLines: 4,
                validator: (v) => Validators.required(v, 'Description'),
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _categoryCtrl,
                label: 'Category',
                icon: Icons.category_outlined,
                validator: (v) => Validators.required(v, 'Category'),
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _priceCtrl,
                label: 'Price (LKR)',
                icon: Icons.attach_money_rounded,
                prefixText: 'LKR ',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: Validators.price,
              ),
              const SizedBox(height: 16),
              _buildField(
                controller: _keywordsCtrl,
                label: 'Keywords',
                icon: Icons.tag_rounded,
                hint: 'Comma separated keywords for search',
              ),
              const SizedBox(height: 36),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Save Changes' : 'Create Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? prefixText,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}
