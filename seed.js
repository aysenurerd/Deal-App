// seed.js - TAM VE DÜZELTİLMİŞ VERSİYON

require('dotenv').config();
const axios = require('axios');
const pool = require('./db'); // db.js dosyanın aynı klasörde olduğunu varsayıyoruz

const TMDB_API_KEY = process.env.TMDB_API_KEY;
const API_BASE_URL = 'https://api.themoviedb.org/3';
const LANGUAGE = 'tr-TR';

// --- 1. FONKSİYON: TÜRLERİ ÇEK ---
async function seedGenres() {
    console.log('🎬 Türler (Genres) çekiliyor...');
    try {
        const url = `${API_BASE_URL}/genre/movie/list?api_key=${TMDB_API_KEY}&language=${LANGUAGE}`;
        const response = await axios.get(url);
        const genres = response.data.genres;

        for (const genre of genres) {
            await pool.execute(
                'INSERT IGNORE INTO Genres (id, name) VALUES (?, ?)',
                [genre.id, genre.name]
            );
        }
        console.log(`✅ ${genres.length} tür başarıyla eklendi/güncellendi.`);
    } catch (error) {
        console.error('❌ Türler çekilirken hata:', error.message);
    }
}

// --- 2. FONKSİYON: FİLMLERİ VE İLİŞKİLERİ ÇEK ---
async function seedPopularMovies() {
    console.log('🍿 Popüler filmler ve Tür İlişkileri çekiliyor...');
    const PAGE_COUNT = 5; 
    let totalInsertedCount = 0;

    for (let page = 1; page <= PAGE_COUNT; page++) {
        const url = `${API_BASE_URL}/movie/popular?api_key=${TMDB_API_KEY}&language=${LANGUAGE}&page=${page}`;
        
        try {
            const response = await axios.get(url);
            const movies = response.data.results;
            
            for (const movie of movies) {
                // A) Filmi Ekle
                const movieQuery = `
                    INSERT IGNORE INTO Movies 
                    (tmdb_id, title, overview, poster_path, vote_average, release_date)
                    VALUES (?, ?, ?, ?, ?, ?)
                `;
                
                const [movieResult] = await pool.execute(movieQuery, [
                    movie.id,
                    movie.title,
                    movie.overview,
                    movie.poster_path,
                    movie.vote_average,
                    movie.release_date || null
                ]);
                
                // B) Filmin ID'sini Bul
                let insertedMovieId;
                if (movieResult.affectedRows > 0) {
                    insertedMovieId = movieResult.insertId;
                    totalInsertedCount++;
                } else {
                    const [existingMovie] = await pool.execute('SELECT id FROM Movies WHERE tmdb_id = ?', [movie.id]);
                    if (existingMovie.length > 0) insertedMovieId = existingMovie[0].id;
                    else continue; 
                }

                // C) İlişkileri (MovieGenres) Ekle
                const genreIds = movie.genre_ids;
                if (insertedMovieId && genreIds && genreIds.length > 0) {
                    const values = genreIds.map(genreId => `(${insertedMovieId}, ${genreId})`).join(', ');
                    const movieGenresQuery = `INSERT IGNORE INTO MovieGenres (movie_id, genre_id) VALUES ${values}`;
                    await pool.execute(movieGenresQuery);
                }
            } 
            console.log(`- Sayfa ${page} işlendi.`);
        } catch (error) {
            console.error(`❌ Sayfa ${page} hatası:`, error.message);
        }
    }
    console.log(`✅ Toplam ${totalInsertedCount} yeni film eklendi.`);
}

// --- ANA ÇALIŞTIRMA FONKSİYONU ---
async function runSeeder() {
    try {
        const connection = await pool.getConnection();
        console.log('✓ Veritabanı bağlantısı başarılı!');
        connection.release();

        await seedGenres();       // Önce türleri ekle
        await seedPopularMovies(); // Sonra filmleri ve ilişkileri ekle

        console.log('\n🌟 Seeding işlemi tamamlandı. Veritabanı bağlantısı kapatılıyor...');
        process.exit(0); 
    } catch (error) {
        console.error('Büyük Hata:', error);
        process.exit(1);
    }
}

// Scripti başlat
runSeeder();