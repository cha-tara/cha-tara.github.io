# Cha Tara

Мобильное чайное приложение на Flutter. Каталог, заметки о заваривании и дневник сессий. Данные дневника хранятся в браузере устройства. Сетевой режим добавляет общую ленту, подписки на авторов и добровольную публикацию записей дневника.

## Запуск

Установите Flutter, затем выполните `flutter create --platforms=web .`, `flutter pub get` и `flutter run -d chrome`. Для публикации GitHub Actions собирает Flutter Web и отправляет результат в GitHub Pages.


## Сетевая лента

Backend в `backend/` использует FastAPI, один процесс Uvicorn и SQLite.
Локальный запуск из папки `backend/`:

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
CHA_TARA_ORIGINS=http://localhost:8080 .venv/bin/uvicorn app:app --host 127.0.0.1 --port 18743
```

Из корня проекта запустите `flutter run -d chrome --web-port 8080 --dart-define=CHA_TARA_API_URL=http://127.0.0.1:18743`.

На сервере `cha-tara-api.service` запускает Uvicorn на `127.0.0.1:18743`
и хранит записи в `/var/lib/cha-tara/feed.sqlite3`. Для публичной ленты
нужен отдельный HTTPS-хост с обратным прокси на этот адрес. Ограничьте
тело запроса на прокси до 256 КиБ и настройте ограничение частоты записей.
После проверки HTTPS укажите адрес в переменной GitHub Actions
`CHA_TARA_API_URL` и запустите workflow публикации. Без этой переменной
разделы дневника и заваривания работают в локальном режиме.

Подписки и право удаления публикаций привязаны к профилю браузера.
Очистка данных сайта удаляет этот профиль с устройства.
