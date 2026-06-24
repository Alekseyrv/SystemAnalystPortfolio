```sql
-- Таблица контента (базовая)
CREATE TABLE content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(20) NOT NULL,
    title VARCHAR(255) NOT NULL,
    release_year INTEGER NOT NULL,
    rating DECIMAL(3,1) DEFAULT 0.0,
    genres JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
);

-- Таблица фильмов
CREATE TABLE movies (
    id UUID PRIMARY KEY REFERENCES content(id) ON DELETE CASCADE,
    duration INTEGER NOT NULL, -- в минутах
    director VARCHAR(255),
    budget DECIMAL(15,2),
    box_office DECIMAL(15,2),

);

-- Таблица сериалов
CREATE TABLE series (
    id UUID PRIMARY KEY REFERENCES content(id) ON DELETE CASCADE,
    total_seasons INTEGER NOT NULL,
    total_episodes INTEGER NOT NULL,
    status VARCHAR(20) DEFAULT 'ongoing',
    network VARCHAR(100),
);

CREATE INDEX idx_series_status ON series(status);

-- Таблица сезонов (для сериалов)
CREATE TABLE seasons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    series_id UUID NOT NULL REFERENCES series(id) ON DELETE CASCADE,
    season_number INTEGER NOT NULL,
    title VARCHAR(255),
    release_year INTEGER,
    
    UNIQUE(series_id, season_number)
);

CREATE INDEX idx_seasons_series_id ON seasons(series_id);

-- Таблица эпизодов
CREATE TABLE episodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    season_id UUID NOT NULL REFERENCES seasons(id) ON DELETE CASCADE,
    episode_number INTEGER NOT NULL,
    title VARCHAR(255),
    duration INTEGER, -- в минутах
    air_date DATE,
    
    UNIQUE(season_id, episode_number),
);

-- Триггер для обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_content_updated_at 
    BEFORE UPDATE ON content
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Триггер для уведомления об изменении контента
CREATE OR REPLACE FUNCTION notify_content_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Отправка уведомления в Content Watcher
    -- (реализация зависит от механизма: LISTEN/NOTIFY или внешний сервис)
    PERFORM pg_notify('content_updated', 
        json_build_object(
            'id', NEW.id,
            'type', NEW.type,
            'action', TG_OP
        )::text);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER content_change_trigger
    AFTER UPDATE ON content
    FOR EACH ROW
    EXECUTE FUNCTION notify_content_change();

-- Примеры данных
INSERT INTO content (id, type, title, release_year, rating, genres) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'movie', 'The Matrix', 1999, 8.7, '["Action", "Sci-Fi"]'),
('660e8400-e29b-41d4-a716-446655440001', 'series', 'Breaking Bad', 2008, 9.5, '["Crime", "Drama"]');

INSERT INTO movies (id, duration, director) VALUES
('550e8400-e29b-41d4-a716-446655440000', 136, 'Lana Wachowski, Lilly Wachowski');

INSERT INTO series (id, total_seasons, total_episodes, status) VALUES
('660e8400-e29b-41d4-a716-446655440001', 5, 62, 'completed');
