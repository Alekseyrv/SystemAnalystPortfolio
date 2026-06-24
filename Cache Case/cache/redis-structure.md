# Структура данных в Redis

## TTL (Time To Live)

| Тип контента | TTL | Обоснование |
|--------------|-----|-------------|
| Movie | 3600 сек (1 час) | Фильмы редко обновляются |
| Series | 1800 сек (30 мин) | Сериалы могут обновляться чаще |

## Структура значения (JSON)

### Movie
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "type": "movie",
  "title": "The Matrix",
  "releaseYear": 1999,
  "duration": 136,
  "rating": 8.7,
  "genres": ["Action", "Sci-Fi"],
  "director": "Lana Wachowski, Lilly Wachowski",
  "cachedAt": "2024-01-15T10:30:00Z"
}
```
### Series
```json
{
  "id": "660e8400-e29b-41d4-a716-446655440001",
  "type": "series",
  "title": "Breaking Bad",
  "releaseYear": 2008,
  "totalSeasons": 5,
  "totalEpisodes": 62,
  "rating": 9.5,
  "genres": ["Crime", "Drama"],
  "status": "completed",
  "cachedAt": "2024-01-15T10:30:00Z"
}
```
## Ключи кэша
### Формат ключа 
- `content:{type}:{id}`
  
**Примеры:**
- `content:movie:550e8400-e29b-41d4-a716-446655440000`
- `content:series:660e8400-e29b-41d4-a716-446655440001`
