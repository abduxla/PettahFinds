import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/categories.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/product.dart';
import '../../../utils/validators.dart';
import '../../../widgets/cached_image.dart';
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
  bool _acceptedListingResponsibility = false;
  Product? _existingProduct;

  // Up to 4 product images. `_existingUrls` holds already-uploaded URLs
  // (from Firestore on edit). `_newFiles` holds new picks pending upload.
  final List<String> _existingUrls = [];
  final List<XFile> _newFiles = [];
  static const int _maxImages = 4;

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
      _existingUrls
        ..clear()
        ..addAll(product.imageUrls);
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

  Future<void> _pickImage() async {
    if (_existingUrls.length + _newFiles.length >= _maxImages) {
      context.showErrorSnackBar('Maximum $_maxImages images allowed');
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;
      setState(() => _newFiles.add(picked));
    } catch (e) {
      if (mounted) context.showErrorSnackBar(e);
    }
  }

  void _removeExistingUrl(int i) =>
      setState(() => _existingUrls.removeAt(i));
  void _removeNewFile(int i) => setState(() => _newFiles.removeAt(i));

  /// Upload pending files to Storage and return their download URLs in
  /// the same order they were picked. Stores the actual file in Firebase
  /// Storage; only the https download URL goes into Firestore.
  Future<List<String>> _uploadNewImages(String businessId) async {
    if (_newFiles.isEmpty) return const [];
    final storage = ref.read(storageServiceProvider);
    final urls = <String>[];
    for (var i = 0; i < _newFiles.length; i++) {
      final file = _newFiles[i];
      final bytes = await file.readAsBytes();
      // Pick sensible contentType + extension from the picked file.
      final mime = (file.mimeType ?? '').isNotEmpty
          ? file.mimeType!
          : _mimeFromName(file.name);
      final ext = _extFromMime(mime);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final url = await storage
          .uploadBytes(
            path: 'products/$businessId/${ts}_$i.$ext',
            bytes: bytes,
            contentType: mime,
          )
          .timeout(const Duration(seconds: 45),
              onTimeout: () => throw Exception(
                  'Image upload timed out. Try a smaller image.'));
      if (url.isEmpty) {
        throw Exception('Image upload failed (empty URL)');
      }
      urls.add(url);
    }
    return urls;
  }

  String _mimeFromName(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _extFromMime(String mime) {
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      default:
        return 'jpg';
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null ||
        !AppCategories.isAllowed(_selectedCategory!)) {
      context.showErrorSnackBar('Please select a category');
      return;
    }
    if (!_acceptedListingResponsibility) {
      context.showErrorSnackBar(
          'Please confirm the listing responsibility to continue.');
      return;
    }
    setState(() => _saving = true);
    try {
      // Resolve business without blocking on a possibly-stale FutureProvider.
      final cached = ref.read(currentUserBusinessProvider).valueOrNull;
      final business = cached ??
          await ref
              .read(currentUserBusinessProvider.future)
              .timeout(const Duration(seconds: 15),
                  onTimeout: () =>
                      throw Exception('Could not load business. Try again.'));
      if (business == null) throw Exception('No business found');

      // Upload any new files first (with a per-file timeout so a hung
      // Storage request can't freeze the save forever).
      final uploaded = await _uploadNewImages(business.id);
      final allUrls = [..._existingUrls, ...uploaded];
      final img1 = allUrls.isNotEmpty ? allUrls[0] : '';
      final img2 = allUrls.length > 1 ? allUrls[1] : '';
      final img3 = allUrls.length > 2 ? allUrls[2] : '';
      final img4 = allUrls.length > 3 ? allUrls[3] : '';

      final now = DateTime.now();
      if (_isEditing && _existingProduct != null) {
        await ref
            .read(productRepositoryProvider)
            .update(
              _existingProduct!.copyWith(
                title: _titleCtrl.text.trim(),
                shortTitle: _shortTitleCtrl.text.trim(),
                description: _descCtrl.text.trim(),
                category: _selectedCategory!,
                priceLkr: double.parse(_priceCtrl.text.trim()),
                keywords: _keywordsCtrl.text.trim(),
                image1Url: img1,
                image2Url: img2,
                image3Url: img3,
                image4Url: img4,
              ),
            )
            .timeout(const Duration(seconds: 20),
                onTimeout: () =>
                    throw Exception('Saving timed out. Check connection.'));
        if (!mounted) return;
        setState(() => _saving = false);
        _refreshBusinessProducts(business.id);
        context.showSuccessSnackBar('Product updated successfully');
        context.pop();
        return;
      }

      await ref
          .read(productRepositoryProvider)
          .create(
            Product(
              id: '',
              businessId: business.id,
              title: _titleCtrl.text.trim(),
              shortTitle: _shortTitleCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              category: _selectedCategory!,
              priceLkr: double.parse(_priceCtrl.text.trim()),
              keywords: _keywordsCtrl.text.trim(),
              image1Url: img1,
              image2Url: img2,
              image3Url: img3,
              image4Url: img4,
              createdAt: now,
              updatedAt: now,
            ),
          )
          .timeout(const Duration(seconds: 20),
              onTimeout: () =>
                  throw Exception('Saving timed out. Check connection.'));
      if (!mounted) return;
      setState(() => _saving = false);
      _refreshBusinessProducts(business.id);
      context.showSuccessSnackBar('Product created successfully');
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showErrorSnackBar(e);
      }
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
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        title: Text(_isEditing ? 'Edit Product' : 'Add Product',
            style: GoogleFonts.nunito(
              color: AppColors.text1,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            )),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Loading state — shimmer skeleton that matches the form layout
    if (_loadingProduct) {
      return const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 120),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
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

            // ---- Image picker grid (up to 4 images) ----
            _ImagePickerGrid(
              existingUrls: _existingUrls,
              newFiles: _newFiles,
              maxImages: _maxImages,
              onPick: _pickImage,
              onRemoveExisting: _removeExistingUrl,
              onRemoveNew: _removeNewFile,
            ),
            const SizedBox(height: 20),

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
            const SizedBox(height: 24),
            _ListingResponsibilityCheckbox(
              accepted: _acceptedListingResponsibility,
              onChanged: (v) => setState(
                  () => _acceptedListingResponsibility = v ?? false),
            ),
            const SizedBox(height: 12),
            _ProhibitedListingsNote(),
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 54,
              child: FilledButton(
                onPressed: (_saving || !_acceptedListingResponsibility)
                    ? null
                    : _submit,
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

/// Web-safe preview for a picked XFile. Uses `readAsBytes()` +
/// `Image.memory` because `Image.file` doesn't work on Flutter Web.
class _XFilePreview extends StatelessWidget {
  final XFile file;
  const _XFilePreview({required this.file});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return Container(color: AppColors.bgSection);
        }
        return Image.memory(snap.data!, fit: BoxFit.cover);
      },
    );
  }
}

/// Image picker grid — shows existing uploaded URLs and newly-picked
/// local files in a 4-slot grid. Tapping an empty slot opens the picker;
/// the × on a tile removes it.
class _ImagePickerGrid extends StatelessWidget {
  final List<String> existingUrls;
  final List<XFile> newFiles;
  final int maxImages;
  final VoidCallback onPick;
  final void Function(int) onRemoveExisting;
  final void Function(int) onRemoveNew;

  const _ImagePickerGrid({
    required this.existingUrls,
    required this.newFiles,
    required this.maxImages,
    required this.onPick,
    required this.onRemoveExisting,
    required this.onRemoveNew,
  });

  @override
  Widget build(BuildContext context) {
    final totalFilled = existingUrls.length + newFiles.length;
    final slots = <Widget>[];

    for (var i = 0; i < existingUrls.length; i++) {
      slots.add(_ImageTile(
        child: CachedImage(
          imageUrl: existingUrls[i],
          width: double.infinity,
          height: double.infinity,
          placeholderIcon: Icons.image_outlined,
        ),
        onRemove: () => onRemoveExisting(i),
      ));
    }
    for (var i = 0; i < newFiles.length; i++) {
      slots.add(_ImageTile(
        child: _XFilePreview(file: newFiles[i]),
        onRemove: () => onRemoveNew(i),
      ));
    }
    if (totalFilled < maxImages) {
      slots.add(_AddImageTile(onTap: onPick));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Images',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.text1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add up to $maxImages images. First image is the cover.',
          style: GoogleFonts.dmSans(
            fontSize: 11.5,
            color: AppColors.text3,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: slots,
        ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _ImageTile({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(color: AppColors.bgSection, child: child),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddImageTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.teal, size: 24),
            SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.teal,
              ),
            ),
          ],
        ),
      ),
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

/// Inline note shown above the submit button. Reminds the seller that the
/// Content and Prohibited Listings Policy applies to every listing without
/// blocking the upload (acceptance happens once at business setup).
class _ProhibitedListingsNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.dmSans(
      fontSize: 11.5,
      color: AppColors.text3,
      height: 1.45,
    );
    final link = GoogleFonts.dmSans(
      fontSize: 11.5,
      color: AppColors.teal,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      height: 1.45,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: AppColors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: base,
                children: [
                  const TextSpan(
                      text: 'By listing products, you agree to follow the '),
                  TextSpan(
                    text: 'Content and Prohibited Listings Policy',
                    style: link,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () =>
                          context.push('/legal/prohibited-listings'),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingResponsibilityCheckbox extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool?> onChanged;
  const _ListingResponsibilityCheckbox({
    required this.accepted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!accepted),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accepted ? AppColors.teal : AppColors.border,
            width: accepted ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: accepted,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeColor: AppColors.teal,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 11, bottom: 4),
                    child: Text(
                      'By listing products, you confirm that:',
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text1,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Text(
                    '• items are legal\n'
                    '• information is accurate\n'
                    '• you accept full responsibility',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.text2,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
