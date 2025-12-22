// routes/interactionRoutes.js - EŞLEŞME MANTIKLI VERSİYON

const express = require('express');
const router = express.Router();
const pool = require('../db');

router.post('/', async (req, res) => {
    const { movie_id, type } = req.body; 
    const CURRENT_USER_ID = 1; // Sen
    const PARTNER_USER_ID = 2; // Partnerin (Test için hayali bir kullanıcı)

    if (!movie_id || type === undefined) {
        return res.status(400).json({ error: 'Eksik veri.' });
    }

    try {
        // 1. Etkileşimi Kaydet (IGNORE: Zaten varsa hata verme)
        const insertQuery = `
            INSERT IGNORE INTO Interactions (user_id, movie_id, interaction_type)
            VALUES (?, ?, ?)
        `;
        await pool.execute(insertQuery, [CURRENT_USER_ID, movie_id, type]);

        // 2. EŞLEŞME KONTROLÜ (Sadece "Like" yani type 1 ise bakılır)
        let isMatch = false;

        if (type === 1) {
            // Partnerim de bu filme like atmış mı?
            const [rows] = await pool.query(`
                SELECT * FROM Interactions 
                WHERE user_id = ? AND movie_id = ? AND interaction_type = 1
            `, [PARTNER_USER_ID, movie_id]);

            if (rows.length > 0) {
                // EVET! Eşleşme var!
                isMatch = true;
                
                // Matches tablosuna kaydet
                await pool.execute(`
                    INSERT IGNORE INTO Matches (movie_id, user_id_1, user_id_2)
                    VALUES (?, ?, ?)
                `, [movie_id, CURRENT_USER_ID, PARTNER_USER_ID]);

                console.log(`🎉 EŞLEŞME! Film ID: ${movie_id}, Kullanıcılar: ${CURRENT_USER_ID} & ${PARTNER_USER_ID}`);
            }
        }

        res.status(201).json({ 
            message: isMatch ? "It's a Match! 🎉" : 'Etkileşim kaydedildi.',
            match: isMatch,
            movie_id: movie_id
        });

    } catch (error) {
        console.error('Hata:', error);
        res.status(500).json({ error: 'Sunucu hatası' });
    }
});

module.exports = router;