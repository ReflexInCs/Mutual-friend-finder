-- Roblox Mutual Friends Finder
-- Created by: ReflexInCs
-- GitHub: https://github.com/ReflexInCs/Mutual-friend-finder

local HttpService = game:GetService("HttpService")
local targetUsernames = getgenv().TargetUsernames or {}

-- Configuration
local API_BASE = "https://users.roblox.com/v1"
local FRIENDS_API = "https://friends.roblox.com/v1"

-- Helper function to make HTTP requests
local function makeRequest(url)
    local success, result = pcall(function()
        return game:HttpGet(url)
    end)
    if success then
        return HttpService:JSONDecode(result)
    end
    return nil
end

-- Get user ID from username
local function getUserId(username)
    local url = API_BASE .. "/usernames/users"
    local success, result = pcall(function()
        return game:HttpPost(url, HttpService:JSONEncode({
            usernames = {username},
            excludeBannedUsers = true
        }))
    end)
    
    if success then
        local data = HttpService:JSONDecode(result)
        if data.data and #data.data > 0 then
            return {data.data[1].id}
        end
    end
    return nil
end

-- Search users by display name
local function searchByDisplayName(displayName)
    local userIds = {}
    local cursor = ""
    local count = 0
    
    print("    Searching display name: " .. displayName)
    
    repeat
        local url = API_BASE .. "/users/search?keyword=" .. HttpService:UrlEncode(displayName) .. "&limit=100"
        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end
        
        local data = makeRequest(url)
        if data and data.data then
            for _, user in ipairs(data.data) do
                if user.displayName and user.displayName:lower() == displayName:lower() then
                    table.insert(userIds, user.id)
                    count = count + 1
                    print("      → " .. user.name .. " (@" .. user.displayName .. ")")
                end
            end
            cursor = data.nextPageCursor or ""
        else
            break
        end
        
        if count >= 50 then
            print("      Limited to 50 matches")
            break
        end
    until cursor == ""
    
    return userIds
end

-- Get all friends for a user
local function getFriends(userId)
    local friends = {}
    local cursor = ""
    
    repeat
        local url = FRIENDS_API .. "/users/" .. userId .. "/friends?userSort=StatusFrequents"
        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end
        
        local data = makeRequest(url)
        if data and data.data then
            for _, friend in ipairs(data.data) do
                table.insert(friends, friend.id)
            end
            cursor = data.nextPageCursor or ""
        else
            break
        end
    until cursor == ""
    
    return friends
end

-- Find mutual friends
local function findMutuals()
    print("\n╔══════════════════════════════════════════════╗")
    print("║     Mutual Friends Finder by ReflexInCs     ║")
    print("╚══════════════════════════════════════════════╝\n")
    
    if #targetUsernames < 2 then
        print("[ERROR] Need at least 2 usernames/display names\n")
        return
    end
    
    print("[STEP 1] Resolving Identifiers\n")
    local allUserIds = {}
    
    for _, identifier in ipairs(targetUsernames) do
        local userIds
        
        if identifier:sub(1, 1) == "@" then
            local displayName = identifier:sub(2)
            userIds = searchByDisplayName(displayName)
        else
            print("    Fetching: " .. identifier)
            userIds = getUserId(identifier)
        end
        
        if userIds and #userIds > 0 then
            allUserIds[identifier] = userIds
            print("    Found: " .. #userIds .. " account(s)\n")
        else
            print("    [ERROR] Not found: " .. identifier .. "\n")
            return
        end
    end
    
    print("[STEP 2] Scanning Friend Lists\n")
    local allFriendsByUser = {}
    local totalScanned = 0
    
    for identifier, userIds in pairs(allUserIds) do
        for _, userId in ipairs(userIds) do
            local friends = getFriends(userId)
            allFriendsByUser[userId] = friends
            totalScanned = totalScanned + 1
            
            local url = API_BASE .. "/users/" .. userId
            local data = makeRequest(url)
            local displayText = data and data.name or ("ID:" .. userId)
            
            print("    " .. displayText .. " → " .. #friends .. " friends")
        end
    end
    
    print("\n[STEP 3] Finding Mutuals\n")
    
    local mutualCounts = {}
    local allUserIdsList = {}
    
    for _, userIds in pairs(allUserIds) do
        for _, userId in ipairs(userIds) do
            table.insert(allUserIdsList, userId)
        end
    end
    
    for _, userId in ipairs(allUserIdsList) do
        local friends = allFriendsByUser[userId]
        if friends then
            for _, friendId in ipairs(friends) do
                mutualCounts[friendId] = (mutualCounts[friendId] or 0) + 1
            end
        end
    end
    
    local mutuals = {}
    for friendId, count in pairs(mutualCounts) do
        if count == #allUserIdsList then
            table.insert(mutuals, friendId)
        end
    end
    
    print("    Checking " .. totalScanned .. " account(s)...\n")
    
    print("╔══════════════════════════════════════════════╗")
    print("║                   RESULTS                    ║")
    print("╚══════════════════════════════════════════════╝\n")
    
    if #mutuals > 0 then
        print("Found " .. #mutuals .. " mutual friend(s):\n")
        for i, mutualId in ipairs(mutuals) do
            local url = API_BASE .. "/users/" .. mutualId
            local data = makeRequest(url)
            if data then
                local displayInfo = data.displayName and (" (@" .. data.displayName .. ")") or ""
                print("  [" .. i .. "] " .. data.name .. displayInfo)
            end
        end
        print("\n")
    else
        print("No mutual friends found\n")
    end
    
    print("══════════════════════════════════════════════\n")
end

-- Run the script
findMutuals()
