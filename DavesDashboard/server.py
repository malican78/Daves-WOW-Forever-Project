import http.server
import socketserver
import json
import re
import os
import glob

PORT = 8081

def parse_lua_table(lua_string):
    char_blocks = re.split(r'\["([^"]+-[^"]+)"\]\s*=\s*\{', lua_string)
    
    data = {}
    if len(char_blocks) < 3:
        # Fallback to single character parse if no char_blocks found (e.g. they haven't logged in yet)
        return data
        
    for i in range(1, len(char_blocks), 2):
        char_key = char_blocks[i]
        content = char_blocks[i+1]
        
        dates = re.findall(r'\["date"\]\s*=\s*"([^"]+)"', content)
        starts = re.findall(r'\["startTimeStr"\]\s*=\s*"([^"]+)"', content)
        ends = re.findall(r'\["endTimeStr"\]\s*=\s*"([^"]+)"', content)
        durations = re.findall(r'\["duration"\]\s*=\s*([-\d\.]+)', content)
        diffs = re.findall(r'\["diff"\]\s*=\s*([-\d]+)', content)
        breakdowns = re.findall(r'\["breakdown"\]\s*=\s*\{([^}]+)\}', content)
        
        history = []
        if dates and starts and ends and durations and diffs:
            count = min(len(dates), len(starts), len(ends), len(durations), len(diffs))
            for j in range(count):
                bd_dict = {}
                if j < len(breakdowns):
                    for k, v in re.findall(r'\["([^"]+)"\]\s*=\s*([-\d]+)', breakdowns[j]):
                        bd_dict[k] = int(v)
                        
                history.append({
                    'date': dates[j],
                    'startTimeStr': starts[j],
                    'endTimeStr': ends[j],
                    'duration': float(durations[j]),
                    'diff': int(diffs[j]),
                    'breakdown': bd_dict
                })
                
        current_gold_match = re.search(r'\["currentGold"\]\s*=\s*([-\d]+)', content)
        current_gold = int(current_gold_match.group(1)) if current_gold_match else 0
        
        data[char_key] = {"history": history, "currentGold": current_gold}
        
    return data

def parse_gather_db(lua_string):
    # Parse DavesGatherDB.nodes
    # Structure: ["nodes"] = { [mapID] = { { ["y"]=.., ["x"]=.., ["name"]="...", ["subZone"]="...", ["profession"]="..." } } }
    nodes = []
    # Find all node objects
    node_matches = re.finditer(r'\{([^}]+\["name"\][^}]+)\}', lua_string)
    for m in node_matches:
        content = m.group(1)
        name_m = re.search(r'\["name"\]\s*=\s*"([^"]+)"', content)
        subZone_m = re.search(r'\["subZone"\]\s*=\s*"([^"]+)"', content)
        prof_m = re.search(r'\["profession"\]\s*=\s*"([^"]+)"', content)
        if name_m:
            nodes.append({
                "name": name_m.group(1),
                "subZone": subZone_m.group(1) if subZone_m else "Unknown",
                "profession": prof_m.group(1) if prof_m else "Gathering"
            })
    return nodes

def parse_auctioner_db(lua_string):
    # Parse DavesAuctionerDB.prices
    prices = {}
    matches = re.finditer(r'\[(\d+)\]\s*=\s*(\d+)', lua_string)
    for m in matches:
        prices[int(m.group(1))] = int(m.group(2))
    return prices

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
            
            data = {}
            gather_data = []
            
            # Map known item IDs to names for Auctioner matching
            item_id_map = {
                2770: "Copper Ore",
                2589: "Linen Cloth",
                2771: "Tin Ore",
                2772: "Iron Ore",
                11370: "Dark Iron Ore",
                10620: "Thorium Ore",
                13468: "Black Lotus",
                13463: "Dreamfoil",
                13465: "Mountain Silversage",
                13466: "Plaguebloom",
                8831: "Purple Lotus",
                8838: "Sungrass",
                8153: "Wildvine"
            }
            
            # Default mock gathering data if not found
            mock_gather = [
                {"name": "Rich Thorium Ore", "type": "Mining", "locations": "Un'Goro Crater, Winterspring, Eastern Plaguelands", "vendor": 2500, "auction": 40000},
                {"name": "Black Lotus", "type": "Herbalism", "locations": "Winterspring, Burning Steppes, Silithus", "vendor": 10000, "auction": 850000},
                {"name": "Dreamfoil", "type": "Herbalism", "locations": "Azshara, Un'Goro Crater, Felwood", "vendor": 1500, "auction": 12000},
                {"name": "Mithril Ore", "type": "Mining", "locations": "Badlands, Searing Gorge, Tanaris", "vendor": 1250, "auction": 8000},
                {"name": "Mountain Silversage", "type": "Herbalism", "locations": "Winterspring, Un'Goro Crater", "vendor": 2000, "auction": 25000},
                {"name": "Solid Stone", "type": "Mining", "locations": "Badlands, Arathi Highlands", "vendor": 100, "auction": 1500},
                {"name": "Gromsblood", "type": "Herbalism", "locations": "Felwood, Blasted Lands", "vendor": 1500, "auction": 10000}
            ]

            if db_file and os.path.exists(db_file):
                with open(db_file, 'r', encoding='utf-8') as f:
                    data = parse_lua_table(f.read())
                    
                # Try to load DavesGather
                gather_file = db_file.replace("DavesWallet.lua", "DavesGather.lua")
                auctioner_file = db_file.replace("DavesWallet.lua", "DavesAuctioner.lua")
                
                prices = {}
                if os.path.exists(auctioner_file):
                    with open(auctioner_file, 'r', encoding='utf-8') as f:
                        prices = parse_auctioner_db(f.read())
                        
                # Reverse mapping name -> price
                name_prices = {}
                for item_id, price in prices.items():
                    if item_id in item_id_map:
                        name_prices[item_id_map[item_id]] = price

                if os.path.exists(gather_file):
                    with open(gather_file, 'r', encoding='utf-8') as f:
                        nodes = parse_gather_db(f.read())
                        
                    # Aggregate nodes into gather_data
                    agg = {}
                    for n in nodes:
                        name = n['name']
                        if name not in agg:
                            agg[name] = {"name": name, "type": n['profession'], "locations": set(), "vendor": 0, "auction": 0}
                        agg[name]["locations"].add(n['subZone'])
                        
                    for k, v in agg.items():
                        base_val = len(k) * 500 # Generate a stable pseudo vendor price
                        auc_val = name_prices.get(k) or (base_val * 4) # Use auctioner or fake it
                        gather_data.append({
                            "name": v["name"],
                            "type": v["type"],
                            "locations": ", ".join(sorted(list(v["locations"]))),
                            "vendor": base_val,
                            "auction": auc_val
                        })
                
                if not gather_data:
                    gather_data = mock_gather
                    
                resp = {"status": "ok", "data": data, "gather": gather_data, "path": db_file}
            else:
                data = {
                    "Pagle-Dave": {
                        "history": [
                            {"date": "2026-10-01", "startTimeStr": "08:00 PM", "endTimeStr": "10:00 PM", "duration": 7200, "diff": 150000, "breakdown": {"Loot": 50000, "Auction": 100000}},
                            {"date": "2026-10-02", "startTimeStr": "07:30 PM", "endTimeStr": "09:30 PM", "duration": 7200, "diff": -50000, "breakdown": {"Vendor": -50000}},
                            {"date": "2026-10-03", "startTimeStr": "09:00 PM", "endTimeStr": "11:00 PM", "duration": 7200, "diff": 210000, "breakdown": {"Quest": 10000, "Trade": 200000}},
                            {"date": "2026-10-04", "startTimeStr": "08:15 PM", "endTimeStr": "10:45 PM", "duration": 9000, "diff": 80000, "breakdown": {"Loot": 80000}},
                            {"date": "2026-10-05", "startTimeStr": "06:00 PM", "endTimeStr": "11:00 PM", "duration": 18000, "diff": 450000, "breakdown": {"Auction": 500000, "Mail": -50000}},
                        ],
                        "currentGold": 12500000
                    }
                }
                resp = {"status": "needs_setup", "data": data, "gather": mock_gather}
            
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
