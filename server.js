// server.js - TAM VE TEMİZ HALİ

require('dotenv').config(); // .env dosyasını okumak için
const express = require('express');
const app = express(); // Uygulamayı başlat (SADECE 1 KEZ)

// Veritabanı bağlantısı (db.js)
const pool = require('./db'); 

// Rota Dosyalarını İçeri Aktar
const movieRoutes = require('./routes/movieRoutes');
const interactionRoutes = require('./routes/interactionRoutes'); // Yeni etkileşim rotamız

// Middleware (Ara Yazılımlar)
app.use(express.json()); // ⚠️ BU ÇOK ÖNEMLİ: POST işlemlerinde JSON verisini okumamızı sağlar

// Rotaları Tanımla
app.use('/api/movies', movieRoutes);           // Film listesi için
app.use('/api/interactions', interactionRoutes); // Beğenme/Pas geçme işlemleri için

// Sunucuyu Başlat
const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log(`🚀 Sunucu ${PORT} portunda çalışıyor...`);
});