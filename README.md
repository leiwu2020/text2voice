# Text to Voice Converter

A web application that converts text input or uploaded text files into speech audio files. Built with Flask and gTTS (Google Text-to-Speech).

## Features

- **Text Input**: Type or paste text directly into the web interface
- **File Upload**: Upload .txt files for conversion
- **Drag & Drop**: Support for drag and drop file uploads
- **Audio Playback**: Built-in audio player to preview the generated speech
- **Download**: Download the generated MP4 audio files
- **Responsive Design**: Modern, mobile-friendly interface
- **Auto-cleanup**: Automatic cleanup of old files

## Installation

### Prerequisites

- Python 3.11
- Conda (recommended) or pip

### Setup

1. **Clone or navigate to the project directory:**
   ```bash
   cd text2voice
   ```

2. **Create and activate the conda environment:**
   ```bash
   conda create -n text2voice python=3.11 -y
   conda activate text2voice
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

## Usage

### Starting the Application

1. **Make sure you're in the text2voice environment:**
   ```bash
   conda activate text2voice
   ```

2. **Run the Flask application:**
   ```bash
   python app.py
   ```

3. **Open your web browser and navigate to:**
   ```
   http://localhost:5000
   ```

### Using the Web Interface

1. **Text Input Method:**
   - Type or paste your text in the text area
   - Click "Convert to Speech"

2. **File Upload Method:**
   - Click the upload area or drag and drop a .txt file
   - Only .txt files are supported
   - Click "Convert to Speech"

3. **After Conversion:**
   - Use the built-in audio player to preview the speech
   - Click "Download MP4" to save the file

## File Structure

```
text2voice/
├── app.py              # Main Flask application
├── templates/
│   └── index.html     # Web interface template
├── uploads/           # Temporary upload directory
├── outputs/           # Generated audio files
├── requirements.txt   # Python dependencies
└── README.md         # This file
```

## Technical Details

- **Backend**: Flask web framework
- **Text-to-Speech**: Google Text-to-Speech (gTTS)
- **Audio Processing**: pydub for audio manipulation
- **Frontend**: HTML5, CSS3, JavaScript (ES6+)
- **File Formats**: Input: .txt, Output: .mp4 (audio)

## API Endpoints

- `GET /` - Main web interface
- `POST /convert` - Convert text to speech
- `GET /download/<filename>` - Download generated files
- `POST /cleanup` - Clean up old files

## Configuration

The application can be configured by modifying the following in `app.py`:

- **Upload folder**: `UPLOAD_FOLDER = 'uploads'`
- **Output folder**: `OUTPUT_FOLDER = 'outputs'`
- **Max file size**: `MAX_CONTENT_LENGTH = 16 * 1024 * 1024` (16MB)
- **Server settings**: Host, port, debug mode

## Troubleshooting

### Common Issues

1. **Port already in use:**
   - Change the port in `app.py` or kill the process using the port

2. **Audio not playing:**
   - Check if the file was generated successfully
   - Verify browser supports the audio format

3. **File upload errors:**
   - Ensure the file is a .txt file
   - Check file size (max 16MB)

### Dependencies Issues

If you encounter issues with audio processing:

```bash
# On macOS, you might need to install ffmpeg
brew install ffmpeg

# On Ubuntu/Debian
sudo apt-get install ffmpeg

# On Windows, download ffmpeg from the official website
```

## Development

### Adding New Features

1. **New Text-to-Speech Engines:**
   - Modify the `convert_text_to_speech` function in `app.py`
   - Add new engine options to the frontend

2. **Additional File Formats:**
   - Extend file validation in the upload handler
   - Add format conversion logic

3. **Voice Customization:**
   - Add language selection options
   - Implement speed and pitch controls

### Testing

```bash
# Run with debug mode
python app.py

# Test the API endpoints
curl -X POST http://localhost:5000/convert \
  -F "text=Hello, this is a test message"
```

## License

This project is open source and available under the MIT License.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review the Flask and gTTS documentation
3. Open an issue in the repository
