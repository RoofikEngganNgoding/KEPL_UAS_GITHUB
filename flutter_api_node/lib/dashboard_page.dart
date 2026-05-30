import 'package:flutter/material.dart';
import 'package:flutter_api_node/chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'sampah_form_page.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List allSampah = [];
  List filteredSampah = [];
  TextEditingController searchController = TextEditingController();

  Future<void> refreshData() async {
    final data = await ApiService().fetchSampah();
    setState(() {
      allSampah = data;
      filteredSampah = data;
    });
  }

  void filterData(String query) {
    setState(() {
      filteredSampah = allSampah
          .where(
            (item) =>
                item['nama_sampah'].toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Apakah yakin ingin keluar dari aplikasi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Menutup dialog
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              // 1. Hapus token dari memori HP
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              await prefs.remove('user_id');
              // 2. Kembali ke halaman login dan hapus riwayat navigasi
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Berhasil keluar")),
                );
              }
            },
            child: const Text("Keluar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // VALIDASI: Dialog Konfirmasi Hapus
  void _confirmDelete(int id, String nama) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Konfirmasi Hapus"),
      content: Text(
        "Apakah yakin ingin menghapus data '$nama'?",
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
          },
          child: const Text("Batal"),
        ),
        TextButton(
          onPressed: () async {
            try {
              await ApiService().deleteSampah(id);
              // tutup dialog dulu
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              // refresh data terbaru
              await refreshData();
              // snackbar
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Data berhasil dihapus",
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Gagal menghapus data: $e",
                    ),
                  ),
                );
              }
            }
          },
          child: const Text(
            "Hapus",
            style: TextStyle(
              color: Colors.red,
            ),
          ),
        ),
      ],
    ),
  );
}

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Bank Sampah",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () =>
                _confirmLogout(context), // Memanggil dialog konfirmasi
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: filterData,
              decoration: InputDecoration(
                hintText: "Cari jenis sampah...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredSampah.length,
              itemBuilder: (context, index) {
                final item = filteredSampah[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: item['pic'] != null
                          ? Image.network(
                              "${ApiService().baseUrl}/uploads/${item['pic']}",
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.green[100],
                              width: 60,
                              height: 60,
                              child: const Icon(
                                Icons.recycling,
                                color: Colors.green,
                              ),
                            ),
                    ),
                    title: Text(
                      item['nama_sampah'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                          ),
                          onPressed: () async {
                            bool? updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SampahFormPage(sampah: item),
                              ),
                            );
                            if (updated == true) refreshData();
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              _confirmDelete(item['id'], item['nama_sampah']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Tombol Chatbot NLP
          FloatingActionButton.small(
            heroTag: "btnChat",
            backgroundColor: Colors.blueAccent,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChatPage()),
              );
            },
            child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
          ),
          const SizedBox(height: 12),
          // Tombol Tambah Sampah (Utama)
          FloatingActionButton(
            heroTag: "btnAdd",
            backgroundColor: Colors.green,
            onPressed: () async {
              bool? added = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SampahFormPage()),
              );
              if (added == true) refreshData();
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
