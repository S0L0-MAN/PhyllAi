import os
import sys
from flask import Flask, request, jsonify
# Import your existing function from your watchdog script
from processor_watchdog import process_scan

app = Flask(__name__)

@app.route('/process', methods=['POST'])
def handle_processing():
    data = request.json
    scan_id = data.get('scanId')
    
    if not scan_id:
        return jsonify({"error": "No scanId provided"}), 400

    try:
        print(f"🚀 Remote Request received for Scan ID: {scan_id}")
        process_scan(scan_id) # Your existing AI logic
        return jsonify({"status": "success", "message": f"Processed {scan_id}"}), 200
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    # host='0.0.0.0' allows devices on your Wi-Fi to see this PC
    app.run(host='0.0.0.0', port=5000, debug=True)