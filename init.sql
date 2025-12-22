CREATE DATABASE IF NOT EXISTS deal_app;
USE deal_app;

CREATE TABLE Users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Platforms (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    logo_url VARCHAR(500)
);

CREATE TABLE Movies (
    id INT PRIMARY KEY,
    tmdb_id INT UNIQUE NOT NULL,
    title VARCHAR(500) NOT NULL,
    overview TEXT,
    poster_path VARCHAR(500),
    release_date DATE,
    vote_average DECIMAL(3,1)
);

CREATE TABLE Genres (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

CREATE TABLE Movie_Genres (
    movie_id INT,
    genre_id INT,
    PRIMARY KEY (movie_id, genre_id),
    FOREIGN KEY (movie_id) REFERENCES Movies(id) ON DELETE CASCADE,
    FOREIGN KEY (genre_id) REFERENCES Genres(id) ON DELETE CASCADE
);

CREATE TABLE Friendships (
    user_id_1 INT,
    user_id_2 INT,
    status ENUM('pending', 'accepted') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id_1, user_id_2),
    FOREIGN KEY (user_id_1) REFERENCES Users(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id_2) REFERENCES Users(id) ON DELETE CASCADE
);

CREATE TABLE Interactions (
    user_id INT,
    movie_id INT,
    type TINYINT COMMENT '1:Like, 0:Pass, 2:Fav',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, movie_id),
    FOREIGN KEY (user_id) REFERENCES Users(id) ON DELETE CASCADE,
    FOREIGN KEY (movie_id) REFERENCES Movies(id) ON DELETE CASCADE
);

CREATE TABLE Matches (
    user_id_1 INT,
    user_id_2 INT,
    movie_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id_1, user_id_2, movie_id),
    FOREIGN KEY (user_id_1) REFERENCES Users(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id_2) REFERENCES Users(id) ON DELETE CASCADE,
    FOREIGN KEY (movie_id) REFERENCES Movies(id) ON DELETE CASCADE
);

