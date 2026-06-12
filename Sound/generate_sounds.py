import os
import subprocess
import sys
import time

def install_and_import(package, import_name=None):
    if import_name is None:
        import_name = package
    try:
        __import__(import_name)
    except ImportError:
        print(f"Installing {package}...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])

# Pastikan yt-dlp dan imageio-ffmpeg terinstal
install_and_import("yt_dlp")
install_and_import("imageio-ffmpeg", "imageio_ffmpeg")

import yt_dlp
import imageio_ffmpeg

# Dapatkan lokasi ffmpeg dari imageio_ffmpeg supaya gak error
ffmpeg_path = imageio_ffmpeg.get_ffmpeg_exe()

# Daftar sound effect yang akan didownload otomatis dari YouTube
# Format: { "nama_file_output": "Query Pencarian YouTube" }
sounds_to_download = {
    "1_orang_purba_ngomong": "ytsearch1:funny caveman talking ooga booga sound effect",
    "2_orang_purba_bingung": "ytsearch1:huh sound effect",
    "3_masuk_kendaraan": "ytsearch1:car door sound effect",
    "4_persneling": "ytsearch1:gear shifting sound effect",
    "5_ngebut": "ytsearch1:car acceleration sound effect",
    "6_ledakan_teleportasi": "ytsearch1:goku instant transmission teleport sound effect",
    "7_suara_lab_bingung": "ytsearch1:sci-fi laboratory ambience sound effect",
    "8_professor_ngamuk": "ytsearch1:man screaming angrily sound effect",
    "9_mobil_nabrak": "ytsearch1:car crash sound effect"
}

output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "IntroSounds")
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

print(f"Mulai mendownload sound effect ke: {output_dir}")
print(f"Menggunakan FFmpeg dari: {ffmpeg_path}")
print("Mencari di YouTube dan mengubah ke format MP3...\n")

for filename, query in sounds_to_download.items():
    output_path = os.path.join(output_dir, f"{filename}.%(ext)s")
    
    ydl_opts = {
        'format': 'bestaudio/best',
        'ffmpeg_location': ffmpeg_path,
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }],
        'outtmpl': output_path,
        'quiet': False,
        'noplaylist': True,
        'extract_audio': True,
    }
    
    print(f"Mengunduh: {filename}...")
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([query])
        print(f"Berhasil: {filename}.mp3\n")
    except Exception as e:
        print(f"Gagal mengunduh {filename}: {e}\n")
    
    time.sleep(1)

print("Semua download selesai! Silakan jalankan gamenya.")
