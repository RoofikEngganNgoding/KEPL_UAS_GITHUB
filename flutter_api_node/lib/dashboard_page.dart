import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'chat_page.dart';
import 'sampah_form_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.apiService});

  final ApiService? apiService;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  final _searchController = TextEditingController();

  int _selectedIndex = 0;
  bool _loading = true;
  bool _hasError = false;
  bool _databaseOnline = false;
  String _dataErrorMessage = '';
  String _userName = 'Pengguna';
  String _userEmail = '';
  List<Map<String, dynamic>> _allSampah = [];

  List<Map<String, dynamic>> get _filteredSampah {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _allSampah;
    return _allSampah.where((item) {
      return _wasteName(item).toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
    refreshData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? '';
    final savedName = prefs.getString('nama')?.trim();
    final emailName = email.contains('@') ? email.split('@').first : '';

    if (!mounted) return;
    setState(() {
      _userEmail = email;
      _userName = savedName?.isNotEmpty == true
          ? savedName!
          : emailName.isNotEmpty
          ? emailName
          : 'Pengguna';
    });
  }

  Future<void> refreshData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }

    final result = await _apiService.fetchSampahResult();
    if (!mounted) return;

    if (result.unauthorized) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    setState(() {
      _loading = false;
      _hasError = !result.success;
      _databaseOnline = result.success;
      _dataErrorMessage = result.message;
      if (result.data != null) _allSampah = result.data!;
    });
  }

  Future<void> _openSampahForm([Map<String, dynamic>? sampah]) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => SampahFormPage(sampah: sampah)),
    );
    if (updated == true && mounted) await refreshData();
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final id = _parseId(item['id']);
    if (id == null) {
      _showMessage('ID data sampah tidak valid.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppTheme.error,
            size: 34,
          ),
          title: const Text('Hapus data sampah?'),
          content: Text(
            '"${_wasteName(item)}" dan foto terkait akan dihapus dari database.',
            textAlign: TextAlign.center,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Hapus'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final result = await _apiService.deleteSampahResult(id);
    if (!mounted) return;

    if (result.success) {
      _showMessage(result.message);
      await refreshData();
    } else {
      _showMessage(result.message, isError: true);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.logout_rounded, color: AppTheme.primary),
          title: const Text('Keluar dari akun?'),
          content: const Text(
            'Kamu perlu masuk kembali untuk mengakses data sampah.',
            textAlign: TextAlign.center,
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Keluar'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Tetap Masuk'),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('email');
    await prefs.remove('nama');

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  int? _parseId(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _wasteName(Map<String, dynamic> item) {
    return item['nama_sampah']?.toString().trim().isNotEmpty == true
        ? item['nama_sampah'].toString()
        : 'Sampah tanpa nama';
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
    final showingWaste = _selectedIndex == 0;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppTheme.heroGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                showingWaste
                    ? Icons.recycling_rounded
                    : Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(showingWaste ? 'Bank Sampah' : 'Asisten AI'),
                  Text(
                    showingWaste
                        ? (_userEmail.isEmpty ? 'Data akunmu' : _userEmail)
                        : 'Tanya seputar pengelolaan sampah',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.greyText,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu akun',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'logout') _confirmLogout();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: AppTheme.darkText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_userEmail.isNotEmpty)
                      Text(
                        _userEmail,
                        style: const TextStyle(
                          color: AppTheme.greyText,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: AppTheme.error),
                    SizedBox(width: 10),
                    Text('Keluar'),
                  ],
                ),
              ),
            ],
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryContainer,
              child: Text(
                _userName.isEmpty ? 'U' : _userName[0].toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _WasteDataPage(
            userName: _userName,
            loading: _loading,
            hasError: _hasError,
            databaseOnline: _databaseOnline,
            errorMessage: _dataErrorMessage,
            allCount: _allSampah.length,
            items: _filteredSampah,
            searchController: _searchController,
            imageUrlFor: _apiService.imageUrlFor,
            onSearchChanged: (_) => setState(() {}),
            onClearSearch: _clearSearch,
            onRefresh: refreshData,
            onAdd: () => _openSampahForm(),
            onEdit: _openSampahForm,
            onDelete: _confirmDelete,
          ),
          const ChatPage(embedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Data Sampah',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Asisten AI',
          ),
        ],
      ),
      floatingActionButton: showingWaste
          ? FloatingActionButton.extended(
              onPressed: () => _openSampahForm(),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 3,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Tambah Sampah',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }
}

class _WasteDataPage extends StatelessWidget {
  const _WasteDataPage({
    required this.userName,
    required this.loading,
    required this.hasError,
    required this.databaseOnline,
    required this.errorMessage,
    required this.allCount,
    required this.items,
    required this.searchController,
    required this.imageUrlFor,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String userName;
  final bool loading;
  final bool hasError;
  final bool databaseOnline;
  final String errorMessage;
  final int allCount;
  final List<Map<String, dynamic>> items;
  final TextEditingController searchController;
  final String? Function(Map<String, dynamic>) imageUrlFor;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
            children: [
              _DatabaseHero(
                userName: userName,
                count: allCount,
                online: databaseOnline,
                checking: loading,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Jenis sampah',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  if (!loading && !hasError)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$allCount data',
                        style: const TextStyle(
                          color: AppTheme.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Kelola data sampahmu.',
                style: TextStyle(color: AppTheme.greyText),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outline),
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari nama sampah...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: onClearSearch,
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (loading)
                const _WasteLoadingList()
              else if (hasError)
                _ActionState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Gagal memuat data',
                  description: errorMessage.isEmpty
                      ? 'Periksa koneksi ke server, lalu coba lagi.'
                      : errorMessage,
                  actionLabel: 'Coba Lagi',
                  onAction: onRefresh,
                )
              else if (items.isEmpty && searchController.text.isNotEmpty)
                _ActionState(
                  icon: Icons.search_off_rounded,
                  title: 'Tidak ditemukan',
                  description: 'Tidak ada sampah yang cocok.',
                  actionLabel: 'Hapus Pencarian',
                  onAction: onClearSearch,
                )
              else if (items.isEmpty)
                _ActionState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Belum ada data',
                  description: 'Tambahkan data sampah pertamamu.',
                  actionLabel: 'Tambah Sampah',
                  onAction: onAdd,
                )
              else
                _WasteCollection(
                  maxWidth: constraints.maxWidth,
                  items: items,
                  imageUrlFor: imageUrlFor,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DatabaseHero extends StatelessWidget {
  const _DatabaseHero({
    required this.userName,
    required this.count,
    required this.online,
    required this.checking,
  });

  final String userName;
  final int count;
  final bool online;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(45),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -14,
            child: Icon(
              Icons.eco_rounded,
              color: Colors.white.withAlpha(28),
              size: 132,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withAlpha(45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      checking
                          ? Icons.sync_rounded
                          : online
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      checking
                          ? 'MEMERIKSA'
                          : online
                          ? 'TERHUBUNG'
                          : 'TERPUTUS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Halo, ${_capitalize(userName)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Text(
                        'jenis sampah',
                        maxLines: 2,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WasteCollection extends StatelessWidget {
  const _WasteCollection({
    required this.maxWidth,
    required this.items,
    required this.imageUrlFor,
    required this.onEdit,
    required this.onDelete,
  });

  final double maxWidth;
  final List<Map<String, dynamic>> items;
  final String? Function(Map<String, dynamic>) imageUrlFor;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) {
    if (maxWidth >= 720) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 174,
        ),
        itemBuilder: (context, index) => _WasteCard(
          item: items[index],
          imageUrl: imageUrlFor(items[index]),
          onEdit: () => onEdit(items[index]),
          onDelete: () => onDelete(items[index]),
        ),
      );
    }

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WasteCard(
              item: item,
              imageUrl: imageUrlFor(item),
              onEdit: () => onEdit(item),
              onDelete: () => onDelete(item),
            ),
          ),
      ],
    );
  }
}

class _WasteCard extends StatelessWidget {
  const _WasteCard({
    required this.item,
    required this.imageUrl,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final String? imageUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = item['nama_sampah']?.toString() ?? 'Sampah';
    final createdAt = _formatDate(item['created_at']);

    return Container(
      height: 174,
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(bordered: true),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 112,
              child: imageUrl == null
                  ? const _ImagePlaceholder()
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const _ImagePlaceholder();
                      },
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.darkText,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      tooltip: 'Aksi data',
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 10),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: AppTheme.error),
                              SizedBox(width: 10),
                              Text(
                                'Hapus',
                                style: TextStyle(color: AppTheme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: AppTheme.greyText,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        createdAt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.greyText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      tooltip: 'Edit $name',
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryContainer,
                        minimumSize: const Size(38, 38),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 19),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.lightGreen,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.recycling_rounded, color: AppTheme.primary, size: 34),
          SizedBox(height: 7),
          Text(
            'Tanpa foto',
            style: TextStyle(
              color: AppTheme.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WasteLoadingList extends StatelessWidget {
  const _WasteLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          height: 150,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.cardDecoration(bordered: true),
          child: Row(
            children: [
              Container(
                width: 108,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLow,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonLine(width: index.isEven ? 130 : 180),
                    const SizedBox(height: 12),
                    const _SkeletonLine(width: 78, height: 24),
                    const Spacer(),
                    const _SkeletonLine(width: 150),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, this.height = 16});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _ActionState extends StatelessWidget {
  const _ActionState({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: AppTheme.cardDecoration(bordered: true),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppTheme.lightGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 7),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.greyText, height: 1.45),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 220,
            child: OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

String _formatDate(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return 'Tersimpan di database';

  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return 'Tersimpan di database';

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return 'Dibuat ${date.day} ${months[date.month - 1]} ${date.year}';
}
