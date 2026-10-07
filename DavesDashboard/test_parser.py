from server import parse_lua_table
lua_string = """
DavesWalletDB = {
    ["history"] = {
        {
            ["date"] = "2026-10-06",
            ["startTimeStr"] = "11:20 PM",
            ["endTimeStr"] = "11:21 PM",
            ["duration"] = 60,
            ["diff"] = -743,
            ["breakdown"] = {
                ["Loot"] = 0,
                ["Other"] = 0,
                ["Vendor"] = -743,
                ["Mail"] = 0,
                ["Auction"] = 0,
                ["Trade"] = 0,
                ["Quest"] = 0,
            },
        },
    },
    ["currentGold"] = 100000,
}
"""
print(parse_lua_table(lua_string))
