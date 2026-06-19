import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api_service.dart';
import 'app_theme.dart';

class SampahFormPage extends StatefulWidget {
  const SampahFormPage({super.key, this.sampah});

  final Map<String, dynamic>? sampah;

  @override
  State<SampahFormPage> createState() => _SampahFormPageState();
}

class _SampahFormPageState extends State<SampahFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _image;
  Uint8List? _imageBytes;
  bool _saving = false;
  bool _loadingImage = false;

  bool get _isEdit => widget.sampah != null;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.sampah?['nama_sampah']?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 76,
        maxWidth: 1600,
      );
      if (pickedFile == null || !mounted) return;

      setState(() => _loadingImage = true);
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      setState(() {
        _image = pickedFile;
        _imageBytes = bytes;
        _loadingImage = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingImage = false);
      _showMessage('Gagal mengambil foto sampah.', isError: true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    setState(() => _saving = true);
    final result = await ApiService().saveSampahResult(
      _nameController.text.trim(),
      _image,
      id: _parseId(widget.sampah?['id']),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success) {
      _showMessage(result.message);
      Navigator.pop(context, true);
      return;
    }

    _showMessage(result.message, isError: true);
  }

  int? _parseId(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.primaryDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existingImage = widget.sampah == null
        ? null
        : ApiService().imageUrlFor(widget.sampah!);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Data Sampah' : 'Tambah Data Sampah'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.outline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isEdit
                              ? Icons.save_outlined
                              : Icons.add_circle_outline_rounded,
                        ),
                  label: Text(
                    _saving
                        ? 'Menyimpan...'
                        : _isEdit
                        ? 'Simpan'
                        : 'Tambah Data',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FormHero(isEdit: _isEdit),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.cardDecoration(bordered: true),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informasi utama',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Nama ini akan ditampilkan pada daftar sampah.',
                            style: TextStyle(
                              color: AppTheme.greyText,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Nama sampah',
                            style: TextStyle(
                              color: AppTheme.darkText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            enabled: !_saving,
                            textInputAction: TextInputAction.done,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'Contoh: Plastik PET',
                              prefixIcon: Icon(Icons.recycling_outlined),
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
                            ),
                            validator: (value) {
                              final name = value?.trim() ?? '';
                              if (name.isEmpty) {
                                return 'Nama sampah harus diisi';
                              }
                              if (name.length < 3) {
                                return 'Nama minimal 3 karakter';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.cardDecoration(bordered: true),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Foto sampah',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLow,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'OPSIONAL',
                                  style: TextStyle(
                                    color: AppTheme.greyText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Gunakan foto yang jelas agar data mudah dikenali.',
                            style: TextStyle(
                              color: AppTheme.greyText,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: _saving ? null : _pickImage,
                            borderRadius: BorderRadius.circular(
                              AppTheme.cardRadius,
                            ),
                            child: Ink(
                              height: 230,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppTheme.lightGreen,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.cardRadius,
                                ),
                                border: Border.all(
                                  color: AppTheme.primary.withAlpha(70),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.cardRadius - 1,
                                ),
                                child: _buildImagePreview(existingImage),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _pickImage,
                            icon: const Icon(Icons.image_outlined),
                            label: Text(
                              _imageBytes != null || existingImage != null
                                  ? 'Ganti Foto'
                                  : 'Pilih dari Galeri',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(String? existingImage) {
    if (_loadingImage) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_imageBytes != null) {
      return Image.memory(_imageBytes!, fit: BoxFit.cover);
    }

    if (existingImage != null) {
      return Image.network(
        existingImage,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _EmptyImageState(),
      );
    }

    return const _EmptyImageState();
  }
}

class _FormHero extends StatelessWidget {
  const _FormHero({required this.isEdit});

  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isEdit ? Icons.edit_rounded : Icons.add_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Perbarui data' : 'Data baru',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEdit
                      ? 'Perubahan akan langsung tersimpan di database.'
                      : 'Tambahkan nama dan foto jenis sampah.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyImageState extends StatelessWidget {
  const _EmptyImageState();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          color: AppTheme.primary,
          size: 48,
        ),
        SizedBox(height: 10),
        Text(
          'Ketuk untuk memilih foto',
          style: TextStyle(
            color: AppTheme.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'JPG atau PNG',
          style: TextStyle(color: AppTheme.greyText, fontSize: 12),
        ),
      ],
    );
  }
}
