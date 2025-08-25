import os
import uuid
import time
import pyttsx3
import subprocess
import tempfile
from flask import Flask, render_template, request, jsonify, send_file, url_for

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['OUTPUT_FOLDER'] = 'outputs'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Create necessary directories
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs(app.config['OUTPUT_FOLDER'], exist_ok=True)

@app.route('/')
def index():
    """Render the main page."""
    return render_template('index.html')

@app.route('/convert', methods=['POST'])
def convert_text_to_speech():
    """Convert text to speech using Google TTS."""
    try:
        text = request.form.get('text', '').strip()
        uploaded_file = request.files.get('file')
        
        if not text and not uploaded_file:
            return jsonify({'error': 'Please provide text or upload a file'}), 400
        
        # If file is uploaded, read its content
        if uploaded_file and uploaded_file.filename:
            if not uploaded_file.filename.endswith('.txt'):
                return jsonify({'error': 'Please upload a .txt file'}), 400
            
            # Read file content
            file_content = uploaded_file.read().decode('utf-8')
            text = file_content.strip()
        
        if not text:
            return jsonify({'error': 'No text content found'}), 400
        
        # Generate unique filename
        unique_id = str(uuid.uuid4())
        audio_filename = f"speech_{unique_id}.mp3"
        
        # Use macOS native speech synthesis for local processing
        try:
            # Create a temporary WAV file first
            temp_wav = os.path.join(app.config['OUTPUT_FOLDER'], f"temp_{unique_id}.wav")
            
            # Use macOS 'say' command to generate speech (this is completely local)
            # The 'say' command generates high-quality, browser-compatible audio
            subprocess.run([
                'say', 
                '-o', temp_wav,
                '-v', 'Samantha',  # Use a high-quality voice
                '--file-format', 'WAVE',
                '--data-format', 'LEI16@22050',  # 16-bit, 22.05kHz, little-endian
                text
            ], check=True, capture_output=True)
            
            # Convert WAV to MP3 using ffmpeg (which we already have installed)
            mp3_path = os.path.join(app.config['OUTPUT_FOLDER'], audio_filename)
            subprocess.run([
                'ffmpeg', '-y',  # Overwrite output file
                '-i', temp_wav,  # Input WAV file
                '-acodec', 'libmp3lame',  # Use MP3 codec
                '-ab', '128k',  # 128kbps bitrate
                '-ar', '22050',  # 22.05kHz sample rate
                '-ac', '1',  # Mono audio
                mp3_path  # Output MP3 file
            ], check=True, capture_output=True)
            
            # Clean up temporary WAV file
            os.remove(temp_wav)
            
            return jsonify({
                'success': True,
                'filename': audio_filename,
                'download_url': url_for('download_file', filename=audio_filename),
                'play_url': url_for('download_file', filename=audio_filename)
            })
            
        except subprocess.CalledProcessError as e:
            print(f"Speech synthesis failed: {e}")
            # Fallback to pyttsx3 if native speech fails
            try:
                engine = pyttsx3.init()
                engine.setProperty('rate', 150)
                engine.setProperty('volume', 0.9)
                
                # Try to use a good quality voice
                voices = engine.getProperty('voices')
                if voices:
                    for voice in voices:
                        if 'female' in voice.name.lower() or 'samantha' in voice.name.lower():
                            engine.setProperty('voice', voice.id)
                            break
                    else:
                        engine.setProperty('voice', voices[0].id)
                
                # Generate WAV file
                wav_path = os.path.join(app.config['OUTPUT_FOLDER'], f"speech_{unique_id}.wav")
                engine.save_to_file(text, wav_path)
                engine.runAndWait()
                
                # Convert to MP3 using ffmpeg
                mp3_path = os.path.join(app.config['OUTPUT_FOLDER'], audio_filename)
                subprocess.run([
                    'ffmpeg', '-y',
                    '-i', wav_path,
                    '-acodec', 'libmp3lame',
                    '-ab', '128k',
                    '-ar', '22050',
                    '-ac', '1',
                    mp3_path
                ], check=True, capture_output=True)
                
                # Clean up WAV file
                os.remove(wav_path)
                
                return jsonify({
                    'success': True,
                    'filename': audio_filename,
                    'download_url': url_for('download_file', filename=audio_filename),
                    'play_url': url_for('download_file', filename=audio_filename)
                })
                
            except Exception as fallback_error:
                print(f"Fallback also failed: {fallback_error}")
                return jsonify({'error': 'Text-to-speech conversion failed on all methods'}), 500
        
    except Exception as e:
        return jsonify({'error': f'Conversion failed: {str(e)}'}), 500

@app.route('/download/<filename>')
def download_file(filename):
    """Download a generated audio file."""
    try:
        file_path = os.path.join(app.config['OUTPUT_FOLDER'], filename)
        if os.path.exists(file_path):
            return send_file(file_path, as_attachment=True, download_name=filename)
        else:
            return jsonify({'error': 'File not found'}), 404
    except Exception as e:
        return jsonify({'error': f'Download failed: {str(e)}'}), 500

@app.route('/cleanup', methods=['POST'])
def cleanup_files():
    """Clean up old files (older than 1 hour)."""
    try:
        current_time = time.time()
        
        for folder in [app.config['OUTPUT_FOLDER'], app.config['UPLOAD_FOLDER']]:
            for filename in os.listdir(folder):
                file_path = os.path.join(folder, filename)
                if os.path.isfile(file_path):
                    file_age = current_time - os.path.getmtime(file_path)
                    if file_age > 3600:  # 1 hour
                        os.remove(file_path)
        
        return jsonify({'success': True, 'message': 'Cleanup completed'})
    except Exception as e:
        return jsonify({'error': f'Cleanup failed: {str(e)}'}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
