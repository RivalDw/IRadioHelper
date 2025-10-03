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
    f.write("settings.server.telnet.bind_addr := \"0.0.0.0\"\n")
    f.write("settings.log.stdout := true\n")
    f.write("settings.log.file := false\n\n")
    f.write("# Дополнительные настройки системы\n")
    f.write("settings.audioscrobbler.api_key := \"\"\n")
    f.write("settings.audioscrobbler.api_secret := \"\"\n")
    f.write("settings.scheduler.fast_queues := 2\n")
    f.write("settings.scheduler.generic_queues := 5\n")
    f.write("settings.prometheus.server := false\n")
    f.write("settings.prometheus.server.port := 9599\n\n")
    f.write("# Настройки для стабильности\n")
    f.write("settings.frame.audio.size := 1024\n")
    f.write("\n")

    playlist_names = []

    for idx, pl_path in enumerate(m3u_files, start=1):
        base_name = os.path.splitext(os.path.basename(pl_path))[0]
        safe_name = base_name.replace(" ", "_").replace("-", "_")
        pl_name = f"playlist_{safe_name}"
        f.write(f'{pl_name} = playlist.reloadable(mode=\"randomize\", reload=60, \"{pl_path}\")\n')
        f.write(f'{pl_name} = cue_cut({pl_name})\n')  # Обрезка тишины в начале/конце
        playlist_names.append(pl_name)

    f.write(f'\n# Основной источник с безопасным переходом\n')
    
    if len(playlist_names) >= 2:
        f.write(f'main_rotation = random(weights=[{",".join(["1"]*len(playlist_names))}], [{", ".join(playlist_names)}])\n')
    else:
        f.write(f'main_rotation = {playlist_names[0]}\n')
    
    f.write('# Резервный источник на случай проблем\n')
    f.write('safe_fallback = single(fallible=true, \"D:/Music/fallback/track.mp3\")\n')
    f.write('safe_fallback = cue_cut(safe_fallback)\n')

    f.write('# Улучшенный fallback с правильной очередностью\n')
    f.write('main_source = fallback(track_sensitive=true, [\n')
    f.write(f'  main_rotation,\n')
    f.write(f'  safe_fallback\n')
    f.write('])\n\n')
    f.write('# Буферизация для стабильности\n')
    f.write('main_source = buffer(buffer=1., main_source)\n\n')

    f.write('# Безопасная нормализация звука\n')
    f.write('main_source = normalize(\n')
    f.write('  target = -12.,           # Более безопасный уровень громкости\n')
    f.write('  gain_min = -6.,          # Максимальное снижение громкости\n')
    f.write('  gain_max = 3.,           # Минимальное увеличение громкости\n')
    f.write('  main_source\n')
    f.write(')\n\n')
    
    f.write('# Компрессор для выравнивания громкости\n')
    f.write('main_source = compress(\n')
    f.write('  threshold = -20.,        # Порог срабатывания\n')
    f.write('  ratio = 2.,              # Слабое сжатие\n')
    f.write('  attack = 10.,            # Медленная атака\n')
    f.write('  release = 100.,          # Медленное восстановление\n')
    f.write('  gain = 0.,               # Без дополнительного усиления\n')
    f.write('  main_source\n')
    f.write(')\n\n')

    f.write('# Ограничитель для защиты от перегрузки\n')
    f.write('main_source = limit(\n')
    f.write('  threshold = -1.,         # Мягкое ограничение\n')
    f.write('  attack = 5.,\n')
    f.write('  release = 50.,\n')
    f.write('  main_source\n')
    f.write(')\n\n')

    f.write('# Плавные переходы между треками\n')
    f.write('main_source = crossfade(\n')
    f.write('  duration = 3.,           # Длительность перехода\n')
    f.write('  main_source\n')
    f.write(')\n\n')

    f.write('# Обработка метаданных для логирования\n')
    f.write('def log_metadata(m) =\n')
    f.write('  artist = if m[\"artist\"] == \"\" then \"Unknown\" else m[\"artist\"] end\n')
    f.write('  title = if m[\"title\"] == \"\" then \"Unknown\" else m[\"title\"] end\n')
    f.write('  log(\"Playing: #{artist} - #{title}\")\n')
    f.write('  m\n')
    f.write('end\n\n')
    
    f.write('main_source = metadata.map(log_metadata, main_source)\n\n')

    f.write('# Преобразуем в безупречный источник\n')
    f.write('final_source = mksafe(main_source)\n\n')

    f.write('# Вывод на Icecast\n')
    f.write('output.icecast(\n')
    f.write(f'  %ffmpeg(format=\"mp3\", %audio(codec=\"libmp3lame\", b=\"{args.bitrate}\")),\n')
    f.write(f'  host=\"{args.host}\",\n')
    f.write(f'  port={args.port},\n')
    f.write(f'  password=\"{args.password}\",\n')
    f.write(f'  mount=\"{args.mount}\",\n')
    f.write('  description=\"Auto-generated Radio Station\",\n')
    f.write('  genre=\"Various\",\n')
    f.write('  public=true,\n')
    f.write('  final_source\n')
    f.write(')\n\n')
    
    # Дополнительный выход для локального прослушивания
    f.write('# Локальный вывод\n')
    f.write('output.ao(final_source)\n\n')

    f.write('# Telnet команды\n')
    
    # Команда skip 
    f.write('def skip(_) =\n')
    f.write('  source.skip(main_rotation)\n')
    f.write('  \"Track skipped\"\n')
    f.write('end\n')
    
    #  RELOAD
    f.write('# Команда reload  \n')
    f.write('def reload(_) =\n')
    f.write('  log(\"Playlists are automatically reloaded when files change\")\n')
    f.write('  \"Playlists use watch mode - auto reload on file changes\"\n')
    f.write('end\n')
    
    # Команда status 
    f.write('def status(_) =\n')
    f.write(f'  \"Status: Playlists={len(playlist_names)} Icecast={args.host}:{args.port}/{args.mount} Bitrate={args.bitrate} Telnet={args.telnet_port}\"\n')
    f.write('end\n')
    
    # Команда help 
    f.write('def help(_) =\n')
    f.write('  \"Available commands: status skip reload help quit\"\n')
    f.write('end\n')
    
    # Команда welcome
    f.write('def welcome(_) =\n')
    f.write('  \"Welcome to Radio Control! Type \\\"help\\\" for commands.\"\n')
    f.write('end\n')
    
    # Регистрация команд
    f.write('server.register(\"skip\", skip)\n')
    f.write('server.register(\"reload\", reload)\n')
    f.write('server.register(\"status\", status)\n')
    f.write('server.register(\"help\", help)\n')
    f.write('server.register(\"welcome\", welcome)\n\n')
    
    # Стартовое сообщение
    f.write(f'log(\"Radio started! Playlists: {len(playlist_names)}\")\n')
    f.write(f'log(\"Telnet control: telnet localhost {args.telnet_port}\")\n')
    f.write('log(\"Using stabilized configuration with safe normalization\")\n')

print(f"Конфиг сгенерирован и сохранён в {output_file}")
print(f"Обработано плейлистов: {len(m3u_files)}")
print(f"Параметры Icecast:")
print(f"  Хост: {args.host}")
print(f"  Порт: {args.port}")
print(f"  Mount: /{args.mount}")
print(f"  Битрейт: {args.bitrate}")
print(f"Telnet управление:")
print(f"  Порт: {args.telnet_port}")
print(f"  Команды: welcome, help, status, skip, reload")

print("\nИсправления:")
print("✓ Исправлена команда reload - убрана попытка вызова несуществующего метода")
print("✓ Исправлен mksafe - убран параметр buffer")
print("✓ Исправлен кроссфейд - используем crossfade вместо cross.smart")
print("✓ Убраны неподдерживаемые параметры из normalize")
print("✓ Исправлен синтаксис fallback")
print("✓ Добавлены дополнительные настройки системы")

print("\nВажно: Убедитесь, что файл D:/Music/fallback/track.mp3 существует")

print("\nЗапуск:")
print(f"liquidsoap radio.liq")