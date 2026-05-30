// 1. IMPORT SEMUA LIBRARY YANG DIBUTUHKAN 
const cors = require('cors');
const express = require('express'); 
const jwt = require('jsonwebtoken'); 
const bcrypt = require('bcryptjs'); 
const multer = require('multer'); 
const path = require('path'); 
const fs = require('fs'); 
const db = require('./db'); // Pastikan koneksi database sudah benar di db.js 
require('dotenv').config(); 
 
// 2. INISIALISASI APP (INI SANGAT PENTING) 
const app = express(); 
const SECRET_KEY = process.env.JWT_SECRET || "kunci_rahasia_bank_sampah"; 
 
// 3. MIDDLEWARE 
app.use(express.json()); 
app.use(cors());
app.use('/uploads', express.static('uploads')); // Akses gambar via browser 
 
// Middleware Otorisasi JWT 
const authenticateToken = (req, res, next) => { 
    const authHeader = req.headers['authorization']; 
    const token = authHeader && authHeader.split(' ')[1]; 
    if (!token) return res.status(401).json({ message: "Token hilang" }); 
 
    jwt.verify(token, SECRET_KEY, (err, user) => { 
        if (err) return res.status(403).json({ message: "Token tidak valid" }); 
        req.user = user; 
        next(); 
    }); 
}; 
 
// 4. KONFIGURASI MULTER (UPLOAD GAMBAR) 
const storage = multer.diskStorage({ 
    destination: (req, file, cb) => { 
        const dir = './uploads'; 
        if (!fs.existsSync(dir)) fs.mkdirSync(dir); 
        cb(null, dir); 
    }, 
    filename: (req, file, cb) => { 
        cb(null, Date.now() + path.extname(file.originalname)); 
    } 
}); 
const upload = multer({ storage: storage }); 
 
// 5. ROUTES LOGIN 
app.post('/login', async (req, res) => { 
    const { email, password } = req.body; 
    try { 
        const [rows] = await db.execute('SELECT * FROM users WHERE email = ?', 
[email]); 
        const user = rows[0]; 
        if (!user || !(await bcrypt.compare(password, user.password))) { 
            return res.status(400).json({ message: "Kredensial salah" }); 
        } 
        const token = jwt.sign({ id: user.id }, SECRET_KEY, { expiresIn: '1h' }); 
        res.json({ 
            token, user_id: user.id, email: user.email }); 



    } catch (err) { 
        res.status(500).json({ error: err.message }); 
    } 
}); 
app.post('/face-login', async (req, res) => {
    const { user_id } = req.body;
    try {
        const [rows] = await db.execute(
            'SELECT * FROM users WHERE id = ?',
            [user_id]
        );
        if (rows.length === 0) {
            return res.status(404).json({
                message: 'User tidak ditemukan'
            });
        }
        const user = rows[0];
        const token = jwt.sign(
            { id: user.id },
            SECRET_KEY,
            { expiresIn: '1h' }
        );
        res.json({
            token,
            user_id: user.id,
            email: user.email
        });
    } catch (err) {
        res.status(500).json({
            error: err.message
        });
    }
});
 
// 6. ROUTES CRUD SAMPAH 
app.post('/sampah', authenticateToken, upload.single('pic'), async (req, res) => 
{ 
    const { nama_sampah } = req.body; 
    const user_id = req.user.id;

    const pic = req.file ? req.file.filename : null; 
    try { 
        const [result] = await db.execute( 
            'INSERT INTO sampah (nama_sampah, pic,user_id) VALUES (?, ?, ?)',  
            [nama_sampah, pic, user_id] 
        ); 
        res.status(201).json({ message: "Data berhasil ditambah", id: 
result.insertId }); 
    } catch (err) { 
        res.status(500).json({ error: err.message }); 
    } 
}); 
 
// --- READ ALL: Ambil Semua Data Sampah --- 
app.get('/sampah', authenticateToken, async (req, res) => { 
    try { 
        const user_id = req.user.id;
        const [rows] = await db.execute('SELECT * FROM sampah WHERE user_id = ?',
         [user_id] );
         
        // Menambahkan URL lengkap untuk gambar agar bisa diakses langsung 
        const dataDenganUrl = rows.map(item => ({ 
            ...item, 
            pic_url: item.pic ? `http://192.168.1.14:3000/uploads/${item.pic}` 
            : null 
        })); 
 
        res.json(dataDenganUrl); 
    } catch (err) { 
        res.status(500).json({ error: err.message }); 
    } 
}); 
// --- READ ONE: Ambil Satu Data Sampah Berdasarkan ID --- 
app.get('/sampah/:id', authenticateToken, async (req, res) => { 
    try { 
        const [rows] = await db.execute('SELECT * FROM sampah WHERE id = ?', 
[req.params.id]); 
        if (rows.length === 0) return res.status(404).json({ message: "Data tidak ditemukan" }); 
         
        res.json(rows[0]); 
    } catch (err) { 
        res.status(500).json({ error: err.message }); 
    } 
}); 
 
// --- UPDATE: Perbarui Nama Sampah atau Gambar --- 
app.put('/sampah/:id', authenticateToken, upload.single('pic'), async (req, res) => { 
    const { id } = req.params; 
    const { nama_sampah } = req.body; 
     
    try { 
        // Cek apakah data ada 
        const [existing] = await db.execute('SELECT * FROM sampah WHERE id = ?', 
[id]); 
        if (existing.length === 0) return res.status(404).json({ message: "Data tidak ditemukan" }); 
 
        let query = 'UPDATE sampah SET nama_sampah = ?'; 
        let params = [nama_sampah || existing[0].nama_sampah]; 
 
        // Jika ada upload gambar baru 
        if (req.file) { 
            query += ', pic = ?'; 
            params.push(req.file.filename); 
 
            // Opsional: Hapus file gambar lama dari folder /uploads 
            if (existing[0].pic) { 
                const oldPath = path.join(__dirname, 'uploads', existing[0].pic); 
                if (fs.existsSync(oldPath)) fs.unlinkSync(oldPath); 
            } 
        } 
 
        query += ' WHERE id = ?'; 
        params.push(id); 
 
        await db.execute(query, params); 
        res.json({ message: "Data sampah berhasil diperbarui" }); 
    } catch (err) { 
        res.status(500).json({ error: err.message }); 
    } 
}); 
 
// --- DELETE: Hapus Data dan File Gambarnya --- 
app.delete('/sampah/:id', authenticateToken, async (req, res) => { 
    const { id } = req.params; 
    try { 
        // Ambil info gambar sebelum data dihapus dari DB 
        const [rows] = await db.execute('SELECT pic FROM sampah WHERE id = ?', 
[id]); 
        if (rows.length === 0) return res.status(404).json({ message: "Data tidak ditemukan" }); 
 
        // Hapus file fisik jika ada 
        if (rows[0].pic) { 
            const filePath = path.join(__dirname, 'uploads', rows[0].pic); 
            if (fs.existsSync(filePath)) fs.unlinkSync(filePath); 
        } 
 
        // Hapus baris di database 
        await db.execute('DELETE FROM sampah WHERE id = ?', [id]); 
        res.json({ message: "Data sampah dan file gambar berhasil dihapus" }); 
    } catch (err) { 
        res.status(500).json({ error: err.message }); 
    } 
}); 
app.get('/', (req, res) => {
    res.send('API Bank Sampah Aktif');
});
// 7. JALANKAN SERVER 
const PORT = 3000; 
app.listen(PORT, () => { 
    console.log(`Server aktif di http://localhost:${PORT}`); 
});