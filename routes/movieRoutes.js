const express = require('express');
const router = express.Router();
const pool = require('../db'); // Veritabanı bağlantısı

// GET /api/movies
// Kullanıcının henüz etkileşime girmediği, vizyona girmiş filmleri getirir
router.get('/', async (req, res) => {
    const MOCK_USER_ID = 1; 

    try {
        const [rows] = await pool.query(`
            SELECT 
                M.id, 
                M.title, 
                M.overview, 
                M.poster_path,
                M.vote_average,
                GROUP_CONCAT(G.name SEPARATOR ', ') AS genres_list
            FROM Movies M
            LEFT JOIN MovieGenres MG ON M.id = MG.movie_id
            LEFT JOIN Genres G ON MG.genre_id = G.id
            WHERE 
                -- 1. KURAL: Kullanıcının daha önce görmediği filmler
                NOT EXISTS (
                    SELECT 1 
                    FROM Interactions I 
                    WHERE I.user_id = ? AND I.movie_id = M.id
                )
                -- 2. KURAL: Puanı 0 olan (henüz çıkmamış) filmleri gizle
                AND M.vote_average > 0
                -- 3. KURAL: En az 10 kişi oy vermiş olsun (Çöp veriyi engeller)
                AND M.vote_count > 10
                -- 4. KURAL: Posteri olmayan (resimsiz) filmleri getirme
                AND M.poster_path IS NOT NULL
            GROUP BY M.id, M.title, M.overview, M.poster_path, M.vote_average
            ORDER BY RAND()
            LIMIT 20;
        `, [MOCK_USER_ID]);

        if (rows.length === 0) {
            return res.status(404).json({ message: 'Gösterilecek uygun film kalmadı.' });
        }

        res.json(rows);

    } catch (err) {
        console.error('Hata:', err);
        res.status(500).json({ error: 'Sunucu hatası' });
    }
});

module.exports = router;