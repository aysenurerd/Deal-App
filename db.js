const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

pool.getConnection()
    .then(connection => {
        console.log('\x1b[32m%s\x1b[0m', '✓ Veritabanı bağlantısı başarılı!');
        connection.release();
    })
    .catch(error => {
        console.error('\x1b[31m%s\x1b[0m', '✗ Veritabanı bağlantı hatası:', error.message);
    });

module.exports = pool;

