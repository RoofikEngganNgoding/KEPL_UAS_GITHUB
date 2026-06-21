const cors = require("cors");
const express = require("express");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const db = require("./db");
require("dotenv").config();

const app = express();
const SECRET_KEY = process.env.JWT_SECRET || "kunci_rahasia_bank_sampah";
const PORT = Number(process.env.PORT || 3000);
const uploadDirectory = path.join(__dirname, "uploads");
const nlpCandidates = (
  process.env.NLP_INTERNAL_URLS ||
  process.env.NLP_INTERNAL_URL ||
  "http://127.0.0.1:8001,http://127.0.0.1:8000"
)
  .split(",")
  .map((value) => value.trim().replace(/\/+$/, ""))
  .filter(Boolean);

app.use(express.json());
app.use(cors());
app.use("/uploads", express.static(uploadDirectory));

function sendError(res, status, code, message, detail) {
  return res.status(status).json({
    success: false,
    code,
    message,
    ...(detail ? { detail } : {}),
  });
}

function authenticateToken(req, res, next) {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.split(" ")[1];
  if (!token) {
    return sendError(res, 401, "TOKEN_MISSING", "Sesi login tidak ditemukan.");
  }

  jwt.verify(token, SECRET_KEY, (error, user) => {
    if (error) {
      return sendError(
        res,
        403,
        "TOKEN_INVALID",
        "Sesi login sudah tidak valid. Silakan masuk kembali.",
      );
    }
    req.user = user;
    next();
  });
}

const storage = multer.diskStorage({
  destination: (_req, _file, callback) => {
    fs.mkdirSync(uploadDirectory, { recursive: true });
    callback(null, uploadDirectory);
  },
  filename: (_req, file, callback) => {
    const extension = path.extname(file.originalname).toLowerCase() || ".jpg";
    callback(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${extension}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, callback) => {
    if (!file.mimetype.startsWith("image/")) {
      callback(new Error("File harus berupa gambar."));
      return;
    }
    callback(null, true);
  },
});

function removeUpload(fileName) {
  if (!fileName) return;
  const filePath = path.join(uploadDirectory, path.basename(fileName));
  if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
}

async function fetchWithTimeout(url, options = {}, timeoutMs = 3000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, {
      ...options,
      signal: controller.signal,
      headers: {
        "Cache-Control": "no-cache, no-store, must-revalidate",
        Pragma: "no-cache",
        ...(options.headers || {}),
      },
    });
  } finally {
    clearTimeout(timer);
  }
}

function isReadyNlpHealth(data) {
  return (
    data &&
    data.service === "bank-sampah-chatbot" &&
    data.status === "ready" &&
    data.model_loaded === true
  );
}

async function probeNlpCandidate(baseUrl) {
  try {
    const response = await fetchWithTimeout(
      `${baseUrl}/health?_proxy_check=${Date.now()}`,
      {},
      2500,
    );
    const data = await response.json();
    if (!response.ok || !isReadyNlpHealth(data)) return null;
    return { baseUrl, data };
  } catch (_error) {
    return null;
  }
}

let _cachedNlpService = null;
let _nlpCacheTimestamp = 0;
const NLP_CACHE_TTL_MS = 10_000;

async function resolveNlpService() {
  const now = Date.now();
  if (_cachedNlpService && (now - _nlpCacheTimestamp) < NLP_CACHE_TTL_MS) {
    try {
      const checkRes = await fetchWithTimeout(
        `${_cachedNlpService.baseUrl}/health?_cache_verify=${now}`,
        {},
        1500,
      );
      const checkData = await checkRes.json();
      if (checkRes.ok && isReadyNlpHealth(checkData)) {
        _cachedNlpService = { baseUrl: _cachedNlpService.baseUrl, data: checkData };
        _nlpCacheTimestamp = now;
        return _cachedNlpService;
      }
    } catch (_error) {
      _cachedNlpService = null;
    }
  }

  for (const candidate of nlpCandidates) {
    const service = await probeNlpCandidate(candidate);
    if (service) {
      _cachedNlpService = service;
      _nlpCacheTimestamp = now;
      return service;
    }
  }
  _cachedNlpService = null;
  return null;
}

async function ensureDatabaseSchema() {
  const [faceLabelColumn] = await db.execute(
    "SHOW COLUMNS FROM users LIKE 'face_label'",
  );
  if (faceLabelColumn.length === 0) {
    await db.execute(
      "ALTER TABLE users ADD COLUMN face_label VARCHAR(100) NULL AFTER nama",
    );
  }

  const [faceLabelIndex] = await db.execute(
    "SHOW INDEX FROM users WHERE Key_name = 'users_face_label_unique'",
  );
  if (faceLabelIndex.length === 0) {
    await db.execute(
      "ALTER TABLE users ADD UNIQUE INDEX users_face_label_unique (face_label)",
    );
  }

  const [userIdColumn] = await db.execute(
    "SHOW COLUMNS FROM sampah LIKE 'user_id'",
  );

  if (userIdColumn.length === 0) {
    await db.execute("ALTER TABLE sampah ADD COLUMN user_id INT NULL AFTER id");
  }

  const [firstUserRows] = await db.execute(
    "SELECT id FROM users ORDER BY id ASC LIMIT 1",
  );
  if (firstUserRows.length === 0) {
    throw new Error("Tabel users belum memiliki akun untuk pemilik data sampah.");
  }

  const defaultFaceLabel = process.env.DEFAULT_FACE_LABEL || "daveo";
  await db.execute(
    `UPDATE users
     SET face_label = ?
     WHERE id = ?
       AND face_label IS NULL`,
    [defaultFaceLabel, firstUserRows[0].id],
  );

  await db.execute("UPDATE sampah SET user_id = ? WHERE user_id IS NULL", [
    firstUserRows[0].id,
  ]);
  await db.execute("ALTER TABLE sampah MODIFY COLUMN user_id INT NOT NULL");

  const [indexRows] = await db.execute(
    "SHOW INDEX FROM sampah WHERE Key_name = 'idx_sampah_user_id'",
  );
  if (indexRows.length === 0) {
    await db.execute(
      "ALTER TABLE sampah ADD INDEX idx_sampah_user_id (user_id)",
    );
  }

  const [foreignKeyRows] = await db.execute(
    `SELECT CONSTRAINT_NAME
     FROM information_schema.KEY_COLUMN_USAGE
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'sampah'
       AND COLUMN_NAME = 'user_id'
       AND REFERENCED_TABLE_NAME = 'users'`,
  );
  if (foreignKeyRows.length === 0) {
    await db.execute(
      `ALTER TABLE sampah
       ADD CONSTRAINT fk_sampah_user
       FOREIGN KEY (user_id) REFERENCES users(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE`,
    );
  }
}

app.get("/health", async (_req, res) => {
  try {
    await db.execute("SELECT 1");
    res.json({
      success: true,
      service: "bank-sampah-api",
      database: "connected",
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    sendError(
      res,
      503,
      "DATABASE_UNAVAILABLE",
      "API aktif, tetapi database tidak dapat dihubungi.",
      error.message,
    );
  }
});

app.get("/nlp/health", async (_req, res) => {
  const service = await resolveNlpService();
  if (!service) {
    return sendError(
      res,
      503,
      "NLP_UNAVAILABLE",
      "Model NLP belum dapat dihubungi atau belum selesai dimuat.",
      `Alamat diperiksa: ${nlpCandidates.join(", ")}`,
    );
  }

  res.set("Cache-Control", "no-store");
  res.json({
    ...service.data,
    proxied_by: "bank-sampah-api",
    upstream: service.baseUrl,
  });
});

app.post("/nlp/chat", async (req, res) => {
  const message = req.body.message?.toString().trim();
  if (!message) {
    return sendError(
      res,
      422,
      "VALIDATION_ERROR",
      "Pesan chatbot harus diisi.",
    );
  }

  const service = await resolveNlpService();
  if (!service) {
    return sendError(
      res,
      503,
      "NLP_UNAVAILABLE",
      "Model NLP belum dapat dihubungi atau belum selesai dimuat.",
    );
  }

  try {
    const response = await fetchWithTimeout(
      `${service.baseUrl}/chat`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message }),
      },
      120000,
    );
    const data = await response.json();
    if (!response.ok || !data.response) {
      return sendError(
        res,
        response.status || 502,
        "NLP_RESPONSE_FAILED",
        data.detail || "Model NLP belum menghasilkan jawaban.",
      );
    }

    res.json({
      response: data.response,
      model: data.model || service.data.model,
    });
  } catch (error) {
    sendError(
      res,
      504,
      "NLP_TIMEOUT",
      error.name === "AbortError"
        ? "Model NLP terlalu lama merespons."
        : "Koneksi ke model NLP terputus.",
    );
  }
});

app.post("/login", async (req, res) => {
  const email = req.body.email?.trim();
  const password = req.body.password;
  if (!email || !password) {
    return sendError(
      res,
      422,
      "VALIDATION_ERROR",
      "Email dan password harus diisi.",
    );
  }

  try {
    const [rows] = await db.execute("SELECT * FROM users WHERE email = ?", [
      email,
    ]);
    const user = rows[0];
    if (!user || !(await bcrypt.compare(password, user.password))) {
      return sendError(
        res,
        400,
        "INVALID_CREDENTIALS",
        "Email atau password belum sesuai.",
      );
    }

    const token = jwt.sign({ id: user.id }, SECRET_KEY, { expiresIn: "1h" });
    res.json({
      success: true,
      token,
      user_id: user.id,
      email: user.email,
      nama: user.nama,
    });
  } catch (error) {
    sendError(res, 500, "LOGIN_FAILED", "Login belum berhasil.", error.message);
  }
});

app.post("/face-login", async (req, res) => {
  const userId = Number(req.body.user_id);
  const faceLabel = req.body.face_label?.toString().trim().toLowerCase();
  if ((!Number.isInteger(userId) || userId <= 0) && !faceLabel) {
    return sendError(
      res,
      422,
      "INVALID_FACE_IDENTITY",
      "Identitas hasil pengenalan wajah tidak valid.",
    );
  }

  try {
    const [rows] = faceLabel
      ? await db.execute(
          "SELECT * FROM users WHERE LOWER(face_label) = ? LIMIT 1",
          [faceLabel],
        )
      : await db.execute("SELECT * FROM users WHERE id = ?", [userId]);
    if (rows.length === 0) {
      return sendError(
        res,
        404,
        "FACE_USER_NOT_FOUND",
        "Wajah dikenali, tetapi belum terhubung ke akun pengguna.",
      );
    }

    const user = rows[0];
    const token = jwt.sign({ id: user.id }, SECRET_KEY, { expiresIn: "1h" });
    res.json({
      success: true,
      token,
      user_id: user.id,
      email: user.email,
      nama: user.nama,
    });
  } catch (error) {
    sendError(
      res,
      500,
      "FACE_LOGIN_FAILED",
      "Login wajah belum berhasil.",
      error.message,
    );
  }
});

app.post(
  "/sampah",
  authenticateToken,
  upload.single("pic"),
  async (req, res) => {
    const namaSampah = req.body.nama_sampah?.trim();
    if (!namaSampah) {
      removeUpload(req.file?.filename);
      return sendError(
        res,
        422,
        "VALIDATION_ERROR",
        "Nama sampah harus diisi.",
      );
    }

    try {
      const [result] = await db.execute(
        "INSERT INTO sampah (user_id, nama_sampah, pic) VALUES (?, ?, ?)",
        [req.user.id, namaSampah, req.file?.filename ?? null],
      );
      res.status(201).json({
        success: true,
        message: "Data sampah berhasil ditambahkan.",
        id: result.insertId,
      });
    } catch (error) {
      removeUpload(req.file?.filename);
      sendError(
        res,
        500,
        "CREATE_WASTE_FAILED",
        "Data sampah belum berhasil ditambahkan.",
        error.message,
      );
    }
  },
);

app.get("/sampah", authenticateToken, async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT id, user_id, nama_sampah, pic, created_at
       FROM sampah
       WHERE user_id = ?
       ORDER BY created_at DESC, id DESC`,
      [req.user.id],
    );

    const baseUrl = process.env.PUBLIC_BASE_URL || `${req.protocol}://${req.get("host")}`;
    const data = rows.map((item) => ({
      ...item,
      pic_url: item.pic ? `${baseUrl}/uploads/${item.pic}` : null,
    }));
    res.json({ success: true, data });
  } catch (error) {
    sendError(
      res,
      500,
      "FETCH_WASTE_FAILED",
      "Data sampah belum dapat dimuat.",
      error.message,
    );
  }
});

app.get("/sampah/:id", authenticateToken, async (req, res) => {
  try {
    const [rows] = await db.execute(
      "SELECT * FROM sampah WHERE id = ? AND user_id = ?",
      [req.params.id, req.user.id],
    );
    if (rows.length === 0) {
      return sendError(
        res,
        404,
        "WASTE_NOT_FOUND",
        "Data sampah tidak ditemukan.",
      );
    }
    res.json({ success: true, data: rows[0] });
  } catch (error) {
    sendError(
      res,
      500,
      "FETCH_WASTE_FAILED",
      "Data sampah belum dapat dimuat.",
      error.message,
    );
  }
});

app.put(
  "/sampah/:id",
  authenticateToken,
  upload.single("pic"),
  async (req, res) => {
    const namaSampah = req.body.nama_sampah?.trim();

    try {
      const [existingRows] = await db.execute(
        "SELECT * FROM sampah WHERE id = ? AND user_id = ?",
        [req.params.id, req.user.id],
      );
      if (existingRows.length === 0) {
        removeUpload(req.file?.filename);
        return sendError(
          res,
          404,
          "WASTE_NOT_FOUND",
          "Data sampah tidak ditemukan.",
        );
      }

      const existing = existingRows[0];
      const nextName = namaSampah || existing.nama_sampah;
      const nextPic = req.file?.filename || existing.pic;

      await db.execute(
        "UPDATE sampah SET nama_sampah = ?, pic = ? WHERE id = ? AND user_id = ?",
        [nextName, nextPic, req.params.id, req.user.id],
      );

      if (req.file && existing.pic) removeUpload(existing.pic);
      res.json({ success: true, message: "Data sampah berhasil diperbarui." });
    } catch (error) {
      removeUpload(req.file?.filename);
      sendError(
        res,
        500,
        "UPDATE_WASTE_FAILED",
        "Data sampah belum berhasil diperbarui.",
        error.message,
      );
    }
  },
);

app.delete("/sampah/:id", authenticateToken, async (req, res) => {
  try {
    const [rows] = await db.execute(
      "SELECT pic FROM sampah WHERE id = ? AND user_id = ?",
      [req.params.id, req.user.id],
    );
    if (rows.length === 0) {
      return sendError(
        res,
        404,
        "WASTE_NOT_FOUND",
        "Data sampah tidak ditemukan.",
      );
    }

    await db.execute("DELETE FROM sampah WHERE id = ? AND user_id = ?", [
      req.params.id,
      req.user.id,
    ]);
    removeUpload(rows[0].pic);
    res.json({ success: true, message: "Data sampah berhasil dihapus." });
  } catch (error) {
    sendError(
      res,
      500,
      "DELETE_WASTE_FAILED",
      "Data sampah belum berhasil dihapus.",
      error.message,
    );
  }
});

app.get("/", (_req, res) => {
  res.send("API Bank Sampah Aktif");
});

app.use((error, _req, res, _next) => {
  if (error instanceof multer.MulterError && error.code === "LIMIT_FILE_SIZE") {
    return sendError(
      res,
      413,
      "IMAGE_TOO_LARGE",
      "Ukuran foto maksimal 5 MB.",
    );
  }
  return sendError(
    res,
    400,
    "REQUEST_FAILED",
    error.message || "Permintaan belum dapat diproses.",
  );
});

async function startServer() {
  await ensureDatabaseSchema();
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server aktif di http://0.0.0.0:${PORT}`);
  });
}

if (require.main === module) {
  startServer().catch((error) => {
    console.error("Gagal menjalankan API:", error);
    process.exit(1);
  });
}

module.exports = { app, ensureDatabaseSchema, startServer };
