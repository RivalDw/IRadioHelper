import os

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
   
    f.write("settings.server.telnet := false\n")
    f.write("settings.server.telnet.port := 1234\n")
    f.write("settings.log.stdout := true\n")
    f.write("settings.log.file := false\n")
    f.write("settings.frame.audio.size := 1024\n\n")

    playlist_names = []

    # Создаём playlist(...) для каждого файла с правильными настройками
    for idx, pl_path in enumerate(m3u_files, start=1):
        # Извлекаем имя плейлиста из пути для лучшей читаемости
        base_name = os.path.splitext(os.path.basename(pl_path))[0]
        safe_name = base_name.replace(" ", "_").replace("-", "_")
        pl_name = f"playlist_{safe_name}"
        
        f.write(f'{pl_name} = playlist(reload_mode="watch", reload=300, "{pl_path}")\n')
        playlist_names.append(pl_name)

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
    
    # Добавляем нормализацию и обработку
    f.write('# Нормализация звука\n')
    f.write('main_source = normalize(target = -12., time_rotated_source)\n\n')
    
    # Слабый бас-фильтр (минимальное воздействие)
    f.write('# Легкая бас-фильтрация\n')
    f.write('main_source = filter.iir.butterworth.low(frequency=80., order=1, main_source)\n\n')
    
    # Добавляем компрессор для лучшего звука
    f.write('# Компрессор для плотного звука\n')
    f.write('main_source = compress(attack=10., release=100., threshold=-15., ratio=4., main_source)\n\n')
    
    # Добавляем лимитер для защиты от клиппинга
    f.write('# Лимитер для предотвращения клиппинга\n')
    f.write('main_source = limit(threshold=-1., main_source)\n\n')
    
    # Добавляем кроссфейд между треками
    f.write('# Плавные переходы между треками\n')
    f.write('main_source = crossfade(duration=3., main_source)\n\n')
    
    # Добавляем обработку тишины и fallback
    f.write('# Резервный источник на случай проблем\n')
    f.write('fallback_track = single("D:/Music/fallback/track.mp3")\n')
    f.write('main_source = fallback(track_sensitive=false, [main_source, fallback_track])\n\n')
    
    # Простая обработка метаданных через map_metadata
    f.write('# Простая обработка метаданных для логирования\n')
    f.write('def log_metadata(m) =\n')
    f.write('  artist = if m["artist"] != "" then m["artist"] else "Unknown Artist" end\n')
    f.write('  title = if m["title"] != "" then m["title"] else "Unknown Title" end\n')
    f.write('  timestamp = time.string("%Y-%m-%d %H:%M:%S")\n')
    f.write('  line = "#{timestamp} - #{artist} - #{title}"\n')
    f.write('  print(line)\n')
    f.write('  m\n')
    f.write('end\n\n')
    
    f.write('main_source = map_metadata(log_metadata, main_source)\n\n')
    
    # Преобразуем в безупречный источник
    f.write('# Создаем безупречный источник\n')
    f.write('main_source = mksafe(main_source)\n\n')

    # Вывод на Icecast с MP3 через FFmpeg (исправленный синтаксис)
    f.write('# Вывод на Icecast\n')
    f.write('output.icecast(\n')
    f.write('  %ffmpeg(format="mp3", %audio(codec="libmp3lame", b="256k")),\n')
    f.write('  host="localhost",\n')
    f.write('  port=8000,\n')
    f.write('  password="pass",\n')
    f.write('  mount="Radio",\n')
    f.write('  name="AutoRadio",\n')
    f.write('  description="Автогенерируемая радиостанция",\n')
    f.write('  genre="Various",\n')
    f.write('  public=true,\n')
    f.write('  main_source\n')
    f.write(')\n\n')
    
    # Дополнительный выход для локального прослушивания
    f.write('# Локальный вывод для тестирования\n')
    f.write('output.ao(fallible=true, main_source)\n')

print(f"Конфиг сгенерирован и сохранён в {output_file}")
print(f"Обработано плейлистов: {len(m3u_files)}")

if len(m3u_files) >= 2:
    morning_count = len(m3u_files) // 2
    print(f"Утренняя группа: {morning_count} плейлистов")
    print(f"Вечерняя группа: {len(m3u_files) - morning_count} плейлистов")
    print("Расписание: 06:00-18:00 - утренняя группа, 18:00-06:00 - вечерняя группа")