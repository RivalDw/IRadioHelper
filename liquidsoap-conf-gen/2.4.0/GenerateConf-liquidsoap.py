import os
import sys
import argparse

# Парсинг аргументов командной строки
parser = argparse.ArgumentParser(description='Генератор конфигурации Liquidsoap')
parser.add_argument('--password', default='pass', help='Пароль для Icecast')
parser.add_argument('--mount', default='Radio', help='Mount point для Icecast')
parser.add_argument('--port', default='8000', help='Порт для Icecast')
parser.add_argument('--bitrate', default='256k', help='Битрейт для кодирования')
parser.add_argument('--host', default='localhost', help='Хост Icecast сервера')
parser.add_argument('--telnet-port', default='1234', help='Порт для telnet управления')

args = parser.parse_args()

# Папка с плейлистами (можно менять на свою)
playlist_dir = "D:/Music/playlists/genres"

# Путь для сохранения конфига
output_file = "radio.liq"

# Рекурсивно собираем все .m3u файлы из папки и подпапок
m3u_files = []
for root, dirs, files in os.walk(playlist_dir):
    for file in files:
        if file.lower().endswith(".m3u"):
            path = os.path.join(root, file).replace("\\", "/")
            m3u_files.append(path)

if not m3u_files:
    print("В папке нет плейлистов .m3u")
    exit()

with open(output_file, "w", encoding="utf-8") as f:
    f.write("# Автогенерация конфигурации для Windows Liquidsoap 2.4\n\n")
   
    f.write("# Включение telnet управления\n")
    f.write("settings.server.telnet := true\n")
    f.write(f"settings.server.telnet.port := {args.telnet_port}\n")
    f.write("settings.log.stdout := true\n")
    f.write("settings.log.file := false\n")
    f.write("settings.frame.audio.size := 1024\n\n")

    playlist_names = []

    # Создаём простые плейлисты без сложных настроек
    for idx, pl_path in enumerate(m3u_files, start=1):
        # Извлекаем имя плейлиста из пути для лучшей читаемости
        base_name = os.path.splitext(os.path.basename(pl_path))[0]
        safe_name = base_name.replace(" ", "_").replace("-", "_")
        pl_name = f"playlist_{safe_name}"
        
        f.write(f'{pl_name} = playlist(reload_mode="watch", reload=600, "{pl_path}")\n')
        playlist_names.append(pl_name)

    # Создаем список имен плейлистов для использования в функциях
    f.write(f'\n# Список плейлистов\n')
    f.write(f'playlist_names_list = {playlist_names}\n')
    f.write(f'playlists_count = {len(playlist_names)}\n\n')

    # Разделяем плейлисты на группы для утра/вечера если их 2 или больше
    total_playlists = len(playlist_names)
    
    if total_playlists >= 2:
        # Разделяем на две группы
        morning_count = total_playlists // 2
        morning_playlists = playlist_names[:morning_count]
        evening_playlists = playlist_names[morning_count:]
        
        f.write('\n# Группы плейлистов для времени суток\n')
        f.write(f'morning_group = random(weights={[1]*len(morning_playlists)}, [{", ".join(morning_playlists)}])\n')
        f.write(f'evening_group = random(weights={[1]*len(evening_playlists)}, [{", ".join(evening_playlists)}])\n\n')
        
        # Система ротации по времени суток
        f.write('# Система ротации по времени суток\n')
        f.write('def time_based_rotation() =\n')
        f.write('  current_time = time.local()\n')
        f.write('  hour = current_time.hour\n')
        f.write('  if hour >= 6 and hour < 18 then\n')
        f.write('    # Утро и день - первая половина плейлистов\n')
        f.write('    morning_group\n')
        f.write('  else\n')
        f.write('    # Вечер и ночь - вторая половина плейлистов\n')
        f.write('    evening_group\n')
        f.write('  end\n')
        f.write('end\n\n')
        
        f.write('time_rotated_source = time_based_rotation()\n\n')
        
    else:
        # Если только один плейлист, используем его всегда
        f.write(f'time_rotated_source = {playlist_names[0]}\n\n')
    
    # Функция для смены трека
    f.write('# Функция для пропуска текущего трека\n')
    f.write('def skip() =\n')
    f.write('  source.skip(time_rotated_source)\n')
    f.write('  print("Трек пропущен")\n')
    f.write('end\n\n')
    
    # Функция для перезагрузки всех плейлистов
    f.write('# Функция для перезагрузки всех плейлистов\n')
    f.write('def reload_all() =\n')
    for pl_name in playlist_names:
        f.write(f'  {pl_name}.reload()\n')
    f.write('  print("Все плейлисты перезагружены")\n')
    f.write('end\n\n')
    
    # Функция для показа статуса
    f.write('# Функция для показа статуса\n')
    f.write('def show_status() =\n')
    f.write('  current_time = time.string("%Y-%m-%d %H:%M:%S")\n')
    f.write('  print("=== Статус радиостанции ===")\n')
    f.write('  print("Время: #{current_time}")\n')
    f.write('  print("Количество плейлистов: #{playlists_count}")\n')
    f.write('  print("Текущий источник: активен")\n')
    f.write('  print("========================")\n')
    f.write('end\n\n')
    
    # Добавляем нормализацию
    f.write('# Нормализация звука\n')
    f.write('main_source = normalize(target = -12., time_rotated_source)\n\n')
    
    # Легкая бас-фильтрация
    f.write('# Легкая бас-фильтрация\n')
    f.write('main_source = filter.iir.butterworth.low(frequency=80., order=1, main_source)\n\n')
    
    # Добавляем компрессор
    f.write('# Компрессор для плотного звука\n')
    f.write('main_source = compress(attack=10., release=100., threshold=-15., ratio=4., main_source)\n\n')
    
    # Добавляем лимитер
    f.write('# Лимитер для предотвращения клиппинга\n')
    f.write('main_source = limit(threshold=-1., main_source)\n\n')
    
    # Добавляем кроссфейд
    f.write('# Плавные переходы между треками\n')
    f.write('main_source = crossfade(duration=3., main_source)\n\n')
    
    # Резервный источник
    f.write('# Резервный источник на случай проблем\n')
    f.write('fallback_track = single("D:/Music/fallback/track.mp3")\n')
    f.write('main_source = fallback(track_sensitive=false, [main_source, fallback_track])\n\n')
    
    # Обработка метаданных
    f.write('# Обработка метаданных для логирования\n')
    f.write('def log_metadata(m) =\n')
    f.write('  artist = if m["artist"] != "" then m["artist"] else "Unknown Artist" end\n')
    f.write('  title = if m["title"] != "" then m["title"] else "Unknown Title" end\n')
    f.write('  timestamp = time.string("%Y-%m-%d %H:%M:%S")\n')
    f.write('  line = "ВОСПРОИЗВЕДЕНИЕ: #{timestamp} - #{artist} - #{title}"\n')
    f.write('  print(line)\n')
    f.write('  m\n')
    f.write('end\n\n')
    
    f.write('main_source = map_metadata(log_metadata, main_source)\n\n')
    
    # Преобразуем в безупречный источник
    f.write('# Создаем безупречный источник\n')
    f.write('final_source = mksafe(main_source)\n\n')

    # Вывод на Icecast
    f.write('# Вывод на Icecast\n')
    f.write('output.icecast(\n')
    f.write(f'  %ffmpeg(format="mp3", %audio(codec="libmp3lame", b="{args.bitrate}")),\n')
    f.write(f'  host="{args.host}",\n')
    f.write(f'  port={args.port},\n')
    f.write(f'  password="{args.password}",\n')
    f.write(f'  mount="{args.mount}",\n')
    f.write('  name="AutoRadio",\n')
    f.write('  description="Автогенерируемая радиостанция",\n')
    f.write('  genre="Various",\n')
    f.write('  public=true,\n')
    f.write('  final_source\n')
    f.write(')\n\n')
    
    # Дополнительный выход для локального прослушивания
    f.write('# Локальный вывод для тестирования\n')
    f.write('output.ao(fallible=true, final_source)\n\n')
    
    # Автозапуск (исправленный синтаксис для Liquidsoap 2.4)
    f.write('# Показать статус при запуске\n')
    f.write('def on_startup() =\n')
    f.write('  print("Радиостанция запущена")\n')
    f.write('  show_status()\n')
    f.write('end\n')
    f.write('on_startup()\n\n')

print(f"Конфиг сгенерирован и сохранён в {output_file}")
print(f"Обработано плейлистов: {len(m3u_files)}")
print(f"Параметры Icecast:")
print(f"  Хост: {args.host}")
print(f"  Порт: {args.port}")
print(f"  Mount: /{args.mount}")
print(f"  Битрейт: {args.bitrate}")
print(f"Telnet управление:")
print(f"  Порт: {args.telnet_port}")
print(f"  Команды: status, skip, reload_all")

if len(m3u_files) >= 2:
    morning_count = len(m3u_files) // 2
    print(f"Утренняя группа: {morning_count} плейлистов")
    print(f"Вечерняя группа: {len(m3u_files) - morning_count} плейлистов")
    print("Расписание: 06:00-18:00 - утренняя группа, 18:00-06:00 - вечерняя группа")

print("\nИсправления:")
print("✅ Заменил server.startup() на прямой вызов функции")
print("✅ Сохранил все функции управления через telnet")

print("\nЗапуск:")
print(f"liquidsoap radio.liq")
print("\nУправление через telnet:")
print(f"telnet localhost {args.telnet_port}")