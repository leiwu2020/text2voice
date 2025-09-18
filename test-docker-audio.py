#!/usr/bin/env python3
"""
Test script to verify audio streaming functionality in Docker container
This simulates how a Windows browser would interact with the audio endpoints
"""

import requests
import json
import time

def test_docker_audio_streaming():
    """Test the audio streaming functionality in Docker container"""
    base_url = "http://localhost:5001"  # Docker container port
    
    print("🎵 Testing Docker Container Audio Streaming Functionality")
    print("=" * 60)
    
    # Test 1: Check if the website is accessible
    print("\n1. Testing website accessibility...")
    try:
        response = requests.get(f"{base_url}/")
        if response.status_code == 200:
            print("✅ Website is accessible in Docker container")
        else:
            print(f"❌ Website returned status: {response.status_code}")
            return
    except Exception as e:
        print(f"❌ Cannot connect to Docker container: {e}")
        return
    
    # Test 2: Test text-to-speech conversion
    print("\n2. Testing text-to-speech conversion...")
    test_text = "Hello, this is a test of the audio streaming functionality in Docker."
    
    try:
        response = requests.post(
            f"{base_url}/convert",
            data={"text": test_text},
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                print("✅ Text-to-speech conversion successful in Docker")
                print(f"   Filename: {result.get('filename')}")
                print(f"   Download URL: {result.get('download_url')}")
                print(f"   Play URL: {result.get('play_url')}")
                
                # Test 3: Test audio streaming endpoint
                print("\n3. Testing audio streaming endpoint...")
                play_url = result.get('play_url')
                if play_url:
                    # Test the streaming endpoint
                    stream_response = requests.get(f"{base_url}{play_url}", stream=True)
                    if stream_response.status_code == 200:
                        print("✅ Audio streaming endpoint working in Docker")
                        
                        # Check headers
                        content_type = stream_response.headers.get('content-type', '')
                        accept_ranges = stream_response.headers.get('accept-ranges', '')
                        content_length = stream_response.headers.get('content-length', '')
                        
                        print(f"   Content-Type: {content_type}")
                        print(f"   Accept-Ranges: {accept_ranges}")
                        print(f"   Content-Length: {content_length}")
                        
                        if 'audio/mpeg' in content_type:
                            print("✅ Correct MIME type (audio/mpeg)")
                        else:
                            print("⚠️  Unexpected MIME type")
                            
                        if accept_ranges == 'bytes':
                            print("✅ Accept-Ranges header present (good for streaming)")
                        else:
                            print("⚠️  Accept-Ranges header missing")
                            
                    else:
                        print(f"❌ Audio streaming failed: {stream_response.status_code}")
                else:
                    print("❌ No play URL in response")
            else:
                print(f"❌ Text-to-speech failed: {result.get('error')}")
        else:
            print(f"❌ Conversion request failed: {response.status_code}")
            print(f"   Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Error during conversion: {e}")
    
    # Test 4: Test download endpoint
    print("\n4. Testing download endpoint...")
    try:
        # Get the filename from the previous test
        if 'result' in locals() and result.get('filename'):
            filename = result.get('filename')
            download_url = f"{base_url}/download/{filename}"
            
            download_response = requests.get(download_url)
            if download_response.status_code == 200:
                print("✅ Download endpoint working in Docker")
                print(f"   Content-Disposition: {download_response.headers.get('content-disposition', 'N/A')}")
            else:
                print(f"❌ Download failed: {download_response.status_code}")
        else:
            print("⚠️  Skipping download test (no filename available)")
            
    except Exception as e:
        print(f"❌ Error during download test: {e}")
    
    print("\n" + "=" * 60)
    print("🎯 Docker Container Testing Complete!")
    print("\n📱 To test Windows browser behavior with Docker container:")
    print("   1. Open http://localhost:5001 in Chrome/Edge")
    print("   2. Press F12 (Developer Tools)")
    print("   3. Click Device Toggle (📱)")
    print("   4. Select Windows device")
    print("   5. Test audio player functionality")
    print("\n🔧 Container Info:")
    print(f"   Container Name: text2voice-test")
    print(f"   Port: 5001 (mapped from container port 5000)")
    print(f"   Status: Running")

if __name__ == "__main__":
    test_docker_audio_streaming()

