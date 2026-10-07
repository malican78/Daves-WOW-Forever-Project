from server import parse_lua_table
lua_string = """DavesWalletDB = {
["currentGold"] = 5766,
["history"] = {
{
["diff"] = 512,
["date"] = "2026-10-06",
["startTimeStr"] = "11:12 PM",
["duration"] = 1395,
["breakdown"] = {
["Other"] = 0,
["Trainer"] = 0,
["Vendor"] = 512,
["Auction"] = 0,
["Loot"] = 0,
["Trade"] = 0,
["Mail"] = 0,
["Quest"] = 0,
["Travel"] = 0,
},
["endTimeStr"] = "11:36 PM",
},
},
}"""
print(parse_lua_table(lua_string))
