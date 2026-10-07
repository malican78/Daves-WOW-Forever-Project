import http.server
import socketserver
import json
import re
import os
import glob

PORT = 8081

def parse_lua_table(lua_string):
    # WoW formats dense arrays differently than sparse dictionaries, which breaks block splitting.
    # Instead, we extract all individual fields and zip them together in order.
    dates = re.findall(r'\["date"\]\s*=\s*"([^"]+)"', lua_string)
    starts = re.findall(r'\["startTimeStr"\]\s*=\s*"([^"]+)"', lua_string)
    ends = re.findall(r'\["endTimeStr"\]\s*=\s*"([^"]+)"', lua_string)
    durations = re.findall(r'\["duration"\]\s*=\s*([-\d\.]+)', lua_string)
    diffs = re.findall(r'\["diff"\]\s*=\s*([-\d]+)', lua_string)
    breakdowns = re.findall(r'\["breakdown"\]\s*=\s*\{([^}]+)\}', lua_string)
    
    history = []
    if dates and starts and ends and durations and diffs:
        count = min(len(dates), len(starts), len(ends), len(durations), len(diffs))
        for i in range(count):
            bd_dict = {}
            if i < len(breakdowns):
                for k, v in re.findall(r'\["([^"]+)"\]\s*=\s*([-\d]+)', breakdowns[i]):
                    bd_dict[k] = int(v)
                    
            history.append({
                'date': dates[i],
                'startTimeStr': starts[i],
                'endTimeStr': ends[i],
                'duration': float(durations[i]),
                'diff': int(diffs[i]),
                'breakdown': bd_dict
            })
            
    current_gold_match = re.search(r'\["currentGold"\]\s*=\s*([-\d]+)', lua_string)
    current_gold = int(current_gold_match.group(1)) if current_gold_match else 0
            
    return {"history": history, "currentGold": current_gold}

CONFIG_FILE = "config.json"

def get_config_path():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r") as f:
            try:
                data = json.load(f)
                return data.get("wow_path")
            except:
                pass
    return None

def save_config_path(path):
    with open(CONFIG_FILE, "w") as f:
        json.dump({"wow_path": path}, f)

class MyHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/api/config':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            try:
                data = json.loads(post_data)
                path = data.get("path")
                # Basic validation to ensure they selected the correct file type
                if path and os.path.exists(path) and ("DavesWallet" in path or "SavedVariables" in path):
                    save_config_path(path)
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b'{"status":"ok"}')
                    return
            except:
                pass
            self.send_response(400)
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        if self.path == '/api/browse':
            file_path = None
            try:
                import subprocess
                import sys
                
                if sys.platform.startswith('linux'):
                    # Try kdialog (Bazzite/KDE)
                    try:
                        res = subprocess.run(['kdialog', '--getopenfilename', '.', '*.lua | Lua files'], capture_output=True, text=True)
                        if res.returncode == 0:
                            file_path = res.stdout.strip()
                    except FileNotFoundError:
                        # Try zenity (GNOME/GTK)
                        try:
                            res = subprocess.run(['zenity', '--file-selection', '--title=Select DavesWallet.lua', '--file-filter=*.lua'], capture_output=True, text=True)
                            if res.returncode == 0:
                                file_path = res.stdout.strip()
                        except FileNotFoundError:
                            pass

                if not file_path:
                    import tkinter as tk
                    from tkinter import filedialog
                    root = tk.Tk()
                    root.withdraw()
                    root.attributes('-topmost', True)
                    file_path = filedialog.askopenfilename(
                        title="Select DavesWallet.lua",
                        filetypes=(("Lua files", "*.lua"), ("All files", "*.*"))
                    )
                    root.destroy()
                
                if file_path:
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(json.dumps({"path": file_path}).encode())
                else:
                    self.send_response(400)
                    self.end_headers()
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode())
            return
            
        elif self.path.startswith('/api/wallet'):
            user_path = get_config_path()
            db_file = None
            
            if user_path:
                matches = glob.glob(user_path)
                if matches:
                    db_file = matches[0]
            else:
                # Auto-detect defaults if no config
                search_paths = [
                    os.path.expanduser('~/.wine/drive_c/Program Files (x86)/World of Warcraft/_retail_/WTF/Account/*/SavedVariables/DavesWallet.lua'),
                    os.path.expanduser('C:/Program Files (x86)/World of Warcraft/_retail_/WTF/Account/*/SavedVariables/DavesWallet.lua'),
                    os.path.expanduser('C:/Program Files/World of Warcraft/_retail_/WTF/Account/*/SavedVariables/DavesWallet.lua')
                ]
                for sp in search_paths:
                    matches = glob.glob(sp)
                    if matches:
                        db_file = matches[0]
                        break
            
            data = []
            if db_file and os.path.exists(db_file):
                with open(db_file, 'r', encoding='utf-8') as f:
                    data = parse_lua_table(f.read())
                resp = {"status": "ok", "data": data, "path": db_file}
            else:
                data = {
                    "history": [
                        {"date": "2026-10-01", "startTimeStr": "08:00 PM", "endTimeStr": "10:00 PM", "duration": 7200, "diff": 150000, "breakdown": {"Loot": 50000, "Auction": 100000}},
                        {"date": "2026-10-02", "startTimeStr": "07:30 PM", "endTimeStr": "09:30 PM", "duration": 7200, "diff": -50000, "breakdown": {"Vendor": -50000}},
                        {"date": "2026-10-03", "startTimeStr": "09:00 PM", "endTimeStr": "11:00 PM", "duration": 7200, "diff": 210000, "breakdown": {"Quest": 10000, "Trade": 200000}},
                        {"date": "2026-10-04", "startTimeStr": "08:15 PM", "endTimeStr": "10:45 PM", "duration": 9000, "diff": 80000, "breakdown": {"Loot": 80000}},
                        {"date": "2026-10-05", "startTimeStr": "06:00 PM", "endTimeStr": "11:00 PM", "duration": 18000, "diff": 450000, "breakdown": {"Auction": 500000, "Mail": -50000}},
                    ],
                    "currentGold": 12500000
                }
                resp = {"status": "needs_setup", "data": data}
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(resp).encode())
        else:
            return http.server.SimpleHTTPRequestHandler.do_GET(self)

if __name__ == '__main__':
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), MyHandler) as httpd:
        print(f"=========================================")
        print(f" Dave's Dashboard Server Running! ")
        print(f" -> Open http://localhost:{PORT}")
        print(f"=========================================")
        httpd.serve_forever()
