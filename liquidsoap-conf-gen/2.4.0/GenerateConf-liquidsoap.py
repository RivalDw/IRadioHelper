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

    playlist_names = []

    # Создаём плейлисты с возможностью перезагрузки
    for idx, pl_path in enumerate(m3u_files, start=1):
        base_name = os.path.splitext(os.path.basename(pl_path))[0]
        safe_name = base_name.replace(" ", "_").replace("-", "_")
        pl_name = f"playlist_{safe_name}"
        
        f.write(f'{pl_name} = playlist(reload_mode=\"watch\", \"{pl_path}\")\n')
        playlist_names.append(pl_name)

    # Создаем основной источник с безопасным fallback
    f.write(f'\n# Основной источник с безопасным переходом\n')
    
    if len(playlist_names) >= 2:
        f.write(f'main_rotation = random([{", ".join(playlist_names)}])\n')
    else:
        f.write(f'main_rotation = {playlist_names[0]}\n')
    
    # Добавляем безопасный источник с fallback - используем простой single с явным указанием fallible
    f.write('# Резервный источник на случай проблем\n')
    f.write('safe_fallback = single(fallible=true, \"D:/Music/fallback/track.mp3\")\n')
    f.write('main_source = fallback(track_sensitive=false, [main_rotation, safe_fallback])\n\n')
    
    # Добавляем нормализацию
    f.write('# Нормализация звука\n')
    f.write('main_source = normalize(main_source)\n\n')
    
    # Добавляем кроссфейд с безопасными настройками
    f.write('# Плавные переходы между треками\n')
    f.write('main_source = crossfade(duration=3., main_source)\n\n')
    
    # Обработка метаданных для логирования
    f.write('# Обработка метаданных для логирования\n')
    f.write('def log_metadata(m) =\n')
    f.write('  artist = if m[\"artist\"] == \"\" then \"Unknown\" else m[\"artist\"] end\n')
    f.write('  title = if m[\"title\"] == \"\" then \"Unknown\" else m[\"title\"] end\n')
    f.write('  log(\"Playing: #{artist} - #{title}\")\n')
    f.write('  m\n')
    f.write('end\n\n')
    
    f.write('main_source = metadata.map(log_metadata, main_source)\n\n')
    
    # Преобразуем в безупречный источник
    f.write('final_source = mksafe(main_source)\n\n')

    # Вывод на Icecast с правильной кодировкой
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
    f.write('  source.skip(main_rotation)\n')
    f.write('  \"Track skipped\"\n')
    f.write('end\n')
    
    # Команда reload  
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
    f.write('log(\"Radio started! Playlists: {len(playlist_names)}\")\n')
    f.write('log(\"Telnet control: telnet localhost {args.telnet_port}\")\n')

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
 
print("\nВажно: Убедитесь, что файл D:/Music/fallback/track.mp3 существует")
print("Или измените путь на существующий MP3 файл")

print("\nИнструкция по использованию telnet:")
print(f"1. Откройте командную строку")
print(f"2. Введите: telnet 127.0.0.1 {args.telnet_port}")
print(f"3. Если пустой экран - просто вводите команды:")
print(f"   welcome  - приветственное сообщение")
print(f"   help     - список команд")
print(f"   status   - статус радио")
print(f"   skip     - пропустить трек")
print(f"   reload   - информация о перезагрузке плейлистов")
print(f"   quit     - выйти из telnet")

print("\nЗапуск:")
print(f"liquidsoap radio.liq")