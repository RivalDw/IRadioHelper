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

    playlist_names = []

    # Создаём playlist(...) для каждого файла
    for idx, pl_path in enumerate(m3u_files, start=1):
        pl_name = f"playlist_{idx}"
        f.write(f'{pl_name} = playlist(reload_mode="watch", reload=60, "{pl_path}")\n')
        playlist_names.append(pl_name)

    # Fallback для всех плейлистов
    f.write(f'\nfallback_source = fallback(track_sensitive=false, [{", ".join(playlist_names)}])\n\n')
    
    # Преобразуем в безупречный источник с помощью mksafe
    f.write('# Создаем безупречный источник\n')
    f.write('main_source = mksafe(fallback_source)\n\n')

    # Вывод на Icecast
    f.write(
        'output.icecast(\n'
        '  %ffmpeg(format="adts", %audio(codec="aac")),\n'
        '  host="localhost",\n'
        '  port=8000,\n'
        '  password="urpass",\n'
        '  mount="Radio",\n'
        '  main_source\n'
        ')\n'
    )

print(f"Конфиг сгенерирован и сохранён в {output_file}")
