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

    # Настройки для уменьшения латенси
    f.write("set(\"server.telnet\",true)\n")
    f.write("set(\"server.telnet.port\",1234)\n")
    f.write("set(\"log.stdout\",true)\n")
    f.write("set(\"log.file\",false)\n")
    f.write("set(\"frame.audio.size\",1024)\n\n")

    playlist_names = []

    # Создаём playlist(...) для каждого файла с правильными настройками
    for idx, pl_path in enumerate(m3u_files, start=1):
        # Извлекаем имя плейлиста из пути для лучшей читаемости
        base_name = os.path.splitext(os.path.basename(pl_path))[0]
        safe_name = base_name.replace(" ", "_").replace("-", "_")
        pl_name = f"playlist_{safe_name}"
        
        f.write(f'# Плейлист: {base_name}\n')
        f.write(f'{pl_name} = playlist(reload_mode="watch", reload=300, "{pl_path}")\n')
        f.write(f'{pl_name} = cue_cut({pl_name})\n\n')
        playlist_names.append(pl_name)

    # Создаем случайный переключатель вместо fallback
    f.write('# Создаем случайный переключатель между плейлистами\n')
    
    # Генерируем правильные веса (целые числа)
    weights = [1] * len(playlist_names)
    weights_str = "[" + ", ".join(map(str, weights)) + "]"
    sources_str = "[" + ", ".join(playlist_names) + "]"
    
    f.write(f'random_source = random(weights={weights_str}, {sources_str})\n\n')
    
    # Добавляем нормализацию и обработку
    f.write('# Нормализация звука\n')
    f.write('main_source = normalize(target = -12., random_source)\n\n')
    
    # Добавляем кроссфейд между треками
    f.write('# Плавные переходы между треками\n')
    f.write('main_source = crossfade(duration=3., main_source)\n\n')
    
    # Преобразуем в безупречный источник
    f.write('# Создаем безупречный источник\n')
    f.write('main_source = mksafe(main_source)\n\n')

    # Вывод на Icecast с MP3 через FFmpeg
    f.write(
        'output.icecast(\n'
        '  %ffmpeg(format="mp3", %audio(codec="libmp3lame", b="192k")),\n'
        '  host="localhost",\n'
        '  port=8000,\n'
        '  password="ZgnGLfHE#@M8uFXLF@dJ",\n'
        '  mount="Radio",\n'
        '  name="AutoRadio",\n'
        '  description="Автогенерируемая радиостанция",\n'
        '  genre="Various",\n'
        '  public=true,\n'
        '  main_source\n'
        ')\n'
    )

print(f"Конфиг сгенерирован и сохранён в {output_file}")
print(f"Обработано плейлистов: {len(m3u_files)}")
