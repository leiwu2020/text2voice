import os
import uuid
import time
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
    """Convert text to speech using espeak (cross-platform)."""
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
        
        try:
            # Use espeak directly for text-to-speech
            wav_path = os.path.join(app.config['OUTPUT_FOLDER'], f"speech_{unique_id}.wav")
            
            # Generate WAV file using espeak
            subprocess.run([
                'espeak',
                '-w', wav_path,
                '-v', 'en',  # English voice
                '-s', '150',  # Speed
                '-p', '50',   # Pitch
                text
            ], check=True, capture_output=True)
            
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
                'play_url': url_for('stream_audio', filename=audio_filename)
            })
            
        except Exception as e:
            print(f"Text-to-speech conversion failed: {e}")
            return jsonify({'error': 'Text-to-speech conversion failed'}), 500
        
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

@app.route('/stream/<filename>')
def stream_audio(filename):
    """Stream an audio file for playback."""
    try:
        file_path = os.path.join(app.config['OUTPUT_FOLDER'], filename)
        if os.path.exists(file_path):
            # Set proper headers for audio streaming
            response = send_file(
                file_path,
                mimetype='audio/mpeg',
                as_attachment=False
            )
            # Add headers for better browser compatibility
            response.headers['Accept-Ranges'] = 'bytes'
            response.headers['Cache-Control'] = 'no-cache'
            return response
        else:
            return jsonify({'error': 'File not found'}), 404
    except Exception as e:
        return jsonify({'error': f'Streaming failed: {str(e)}'}), 500

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
    app.run(debug=False, host='0.0.0.0', port=5000)
