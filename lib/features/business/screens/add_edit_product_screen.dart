import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/categories.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../models/business.dart';
import '../../../models/product.dart';
import '../../../utils/validators.dart';
import '../../../widgets/shimmer_loading.dart';

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
  final _priceCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  String? _selectedCategory;
  bool _saving = false;
  bool _loadingProduct = false;
  bool _loadError = false;
  Product? _existingProduct;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _loadingProduct = true;
      _loadError = false;
    });
    try {
      final product = await ref
          .read(productRepositoryProvider)
          .getById(widget.productId!);
      _existingProduct = product;
      _titleCtrl.text = product.title;
      _shortTitleCtrl.text = product.shortTitle;
      _descCtrl.text = product.description;
      _selectedCategory = AppCategories.normalize(product.category);
      _priceCtrl.text = product.priceLkr.toString();
      _keywordsCtrl.text = product.keywords;
    } catch (e) {
      _loadError = true;
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _loadingProduct = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _shortTitleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _keywordsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return; // prevent double tap
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null ||
        !AppCategories.isAllowed(_selectedCategory!)) {
      context.showErrorSnackBar('Please select a category');
      return;
    }
    setState(() => _saving = true);
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
                category: _selectedCategory!,
                priceLkr: double.parse(_priceCtrl.text.trim()),
                keywords: _keywordsCtrl.text.trim(),
              ),
            );
        if (mounted) {
          _refreshBusinessProducts(business.id);
          context.showSuccessSnackBar('Product updated successfully');
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
                category: _selectedCategory!,
                priceLkr: double.parse(_priceCtrl.text.trim()),
                keywords: _keywordsCtrl.text.trim(),
                createdAt: now,
                updatedAt: now,
              ),
            );
        if (mounted) {
          _refreshBusinessProducts(business.id);
          context.showSuccessSnackBar('Product created successfully');
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _refreshBusinessProducts(String businessId) {
    ref.invalidate(businessProductsProvider(businessId));
    ref.invalidate(businessActiveProductsProvider(businessId));
    ref.invalidate(allActiveProductsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Loading state — shimmer skeleton that matches the form layout
    if (_loadingProduct) {
      return const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: _FormSkeleton(),
      );
    }

    // Error loading product — retry
    if (_loadError && _existingProduct == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline,
                    size: 32, color: theme.colorScheme.error),
              ),
              const SizedBox(height: 20),
              Text('Failed to load product',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _loadProduct,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Form
    return SingleChildScrollView(
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
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child:
                      Icon(Icons.category_outlined, size: 20),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
              items: AppCategories.all
                  .map((c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Please select a category' : null,
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 54,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Saving...'),
                        ],
                      )
                    : Text(_isEditing ? 'Save Changes' : 'Create Product'),
              ),
            ),
          ],
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

/// Shimmer skeleton that matches the add/edit form layout
class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Center(child: ShimmerBox(width: 64, height: 64, radius: 32)),
        const SizedBox(height: 24),
        ...List.generate(6, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ShimmerBox(height: i == 2 ? 110 : 56, radius: 14),
        )),
        const SizedBox(height: 20),
        const ShimmerBox(height: 54, radius: 14),
      ],
    );
  }
}
