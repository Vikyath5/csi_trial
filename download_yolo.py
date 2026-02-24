import urllib.request
import os

def download_yolo():
    os.makedirs('assets/models', exist_ok=True)
    urls = [
        'https://github.com/freedomtan/tensorflow-lite-yolov8-models/blob/main/yolov8n.tflite?raw=true',
        'https://github.com/m-m-m-m-m/yolo-v8-tflite-models/raw/main/yolov8n_float32.tflite',
        'https://github.com/amulya-sah/yolov8_tflite_flutter/raw/main/assets/yolov8n.tflite'
    ]
    
    for url in urls:
        try:
            print(f"Trying to download from: {url}")
            path = 'assets/models/yolov8n.tflite'
            urllib.request.urlretrieve(url, path)
            size = os.path.getsize(path)
            if size > 1000000:
                print(f"Success! Model downloaded: {size} bytes")
                return True
            else:
                print(f"File too small ({size} bytes), likely a pointer. Trying next source...")
        except Exception as e:
            print(f"Error downloading from {url}: {e}")
    
    print("All sources failed to provide a full model binary.")
    return False

if __name__ == "__main__":
    download_yolo()
