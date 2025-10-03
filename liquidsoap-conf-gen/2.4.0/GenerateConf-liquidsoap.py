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
    f.write("set(\"server.telnet\",true)\n")
    f.write(f"set(\"server.telnet.port\",{args.telnet_port})\n")
    f.write("set(\"log.stdout\",true)\n")
    f.write("set(\"log.file\",false)\n\n")

    playlist_names = []

    # Создаём простые плейлисты
    for idx, pl_path in enumerate(m3u_files, start=1):
        base_name = os.path.splitext(os.path.basename(pl_path))[0]
        safe_name = base_name.replace(" ", "_").replace("-", "_")
        pl_name = f"playlist_{safe_name}"
        
        f.write(f'{pl_name} = playlist(\"{pl_path}\")\n')
        playlist_names.append(pl_name)

    # Создаем основной источник
    if len(playlist_names) >= 2:
        f.write(f'\n# Основной источник - случайный из всех плейлистов\n')
        f.write(f'main_source = random([{", ".join(playlist_names)}])\n\n')
    else:
        f.write(f'\nmain_source = {playlist_names[0]}\n\n')
    
    # Добавляем нормализацию
    f.write('# Нормализация звука\n')
    f.write('main_source = normalize(main_source)\n\n')
    
    # Добавляем кроссфейд
    f.write('# Плавные переходы между треками\n')
    f.write('main_source = crossfade(main_source)\n\n')
    
    # Обработка метаданных для логирования
    f.write('# Обработка метаданных для логирования\n')
    f.write('def log_metadata(m) =\n')
    f.write('  artist = if m[\"artist\"] == \"\" then \"Unknown\" else m[\"artist\"] end\n')
    f.write('  title = if m[\"title\"] == \"\" then \"Unknown\" else m[\"title\"] end\n')
    f.write('  log(\"Playing: #{artist} - #{title}\")\n')
    f.write('  m\n')
    f.write('end\n\n')
    
    f.write('main_source = map_metadata(log_metadata, main_source)\n\n')
    
    f.write('final_source = mksafe(main_source)\n\n')

    # Вывод на Icecast 
    f.write('# Вывод на Icecast\n')
    f.write('output.icecast(\n')
    f.write(f'  %ffmpeg(format=\"mp3\", %audio(codec=\"libmp3lame\", b=\"{args.bitrate}\")),\n')
    f.write(f'  host=\"{args.host}\",\n')
    f.write(f'  port={args.port},\n')
    f.write(f'  password=\"{args.password}\",\n')
    f.write(f'  mount=\"{args.mount}\",\n')
    f.write('  final_source\n')
    f.write(')\n\n')
    
    # Дополнительный выход для локального прослушивания
    f.write('# Локальный вывод\n')
    f.write('output.ao(final_source)\n\n')

    # Простые telnet команды
    f.write('# Telnet команды\n')
    
    # Команда skip
    f.write('def skip(_) =\n')
    f.write('  source.skip(main_source)\n')
    f.write('  \"Track skipped\"\n')
    f.write('end\n')
    
    # Команда reload 
    f.write('def reload(_) =\n')
    for pl_name in playlist_names:
        f.write(f'  {pl_name}.reload()\n')
    f.write('  \"Playlists reloaded\"\n')
    f.write('end\n')
    
    # Регистрация команд
    f.write('server.register(\"skip\", skip)\n')
    f.write('server.register(\"reload\", reload)\n\n')
    
    # Стартовое сообщение
    f.write('log(\"Radio started! Playlists: {len(playlist_names)}\")\n')

print(f"Конфиг сгенерирован и сохранён в {output_file}")
print(f"Обработано плейлистов: {len(m3u_files)}")
print(f"Параметры Icecast:")
print(f"  Хост: {args.host}")
print(f"  Порт: {args.port}")
print(f"  Mount: /{args.mount}")
print(f"  Битрейт: {args.bitrate}")
print(f"Telnet управление:")
print(f"  Порт: {args.telnet_port}")
print(f"  Команды: skip, reload")

print("\nИспользование telnet:")
print(f"telnet 127.0.0.1 {args.telnet_port}")
print("> skip          - пропустить трек")
print("> reload        - перезагрузить плейлисты")

print("\nЗапуск:")
print(f"liquidsoap radio.liq")