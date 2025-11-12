-- Roblox Mutual Friends Finder
-- Created by: ReflexInCs
-- GitHub: https://github.com/ReflexInCs/Mutual-friend-finder

local HttpService = game:GetService("HttpService")
local targetUsernames = getgenv().TargetUsernames or {}

-- Configuration
local API_BASE = "https://users.roblox.com/v1"
local FRIENDS_API = "https://friends.roblox.com/v1"
local REQUEST_DELAY = 1.5 -- Delay between requests in seconds

-- Helper function to wait
local function wait(seconds)
    local start = tick()
    repeat until tick() - start >= seconds
end

-- Helper function to make HTTP requests with retry logic
local function makeRequest(url, maxRetries)
    maxRetries = maxRetries or 3
    local retries = 0
    
    while retries < maxRetries do
        local success, result = pcall(function()
            return game:HttpGet(url)
        end)
        
        if success then
            local decodeSuccess, data = pcall(function()
                return HttpService:JSONDecode(result)
            end)
            
            if decodeSuccess then
                return data
            end
        end
        
        retries = retries + 1
        if retries < maxRetries then
            print("      Retrying... (" .. retries .. "/" .. maxRetries .. ")")
            wait(REQUEST_DELAY * 2)
        end
    end
    
    return nil
end

-- Helper function to make POST requests with retry logic
local function makePostRequest(url, body, maxRetries)
    maxRetries = maxRetries or 3
    local retries = 0
    
    while retries < maxRetries do
        local success, result = pcall(function()
            return game:HttpPost(url, body)
        end)
        
        if success then
            local decodeSuccess, data = pcall(function()
                return HttpService:JSONDecode(result)
            end)
            
            if decodeSuccess then
                return data
            end
        end
        
        retries = retries + 1
        if retries < maxRetries then
            print("      Retrying... (" .. retries .. "/" .. maxRetries .. ")")
            wait(REQUEST_DELAY * 2)
        end
    end
    
    return nil
end

-- Get user ID from username
local function getUserId(username)
    local url = API_BASE .. "/usernames/users"
    local data = makePostRequest(url, HttpService:JSONEncode({
        usernames = {username},
        excludeBannedUsers = true
    }))
    
    wait(REQUEST_DELAY)
    
    if data and data.data and #data.data > 0 then
        return {data.data[1].id}
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
        wait(REQUEST_DELAY)
        
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
    local pageCount = 0
    
    repeat
        local url = FRIENDS_API .. "/users/" .. userId .. "/friends?userSort=StatusFrequents&limit=50"
        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end
        
        local data = makeRequest(url)
        wait(REQUEST_DELAY)
        
        if data and data.data then
            for _, friend in ipairs(data.data) do
                table.insert(friends, friend.id)
            end
            cursor = data.nextPageCursor or ""
            pageCount = pageCount + 1
            
            -- Longer delay every 5 pages to avoid rate limits
            if pageCount % 5 == 0 then
                wait(REQUEST_DELAY * 2)
            end
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
    
    print("[STEP 2] Scanning Friend Lists (this may take a while)\n")
    local allFriendsByUser = {}
    local totalScanned = 0
    
    for identifier, userIds in pairs(allUserIds) do
        for _, userId in ipairs(userIds) do
            print("    Scanning user ID: " .. userId .. "...")
            local friends = getFriends(userId)
            allFriendsByUser[userId] = friends
            totalScanned = totalScanned + 1
            
            wait(REQUEST_DELAY)
            
            local url = API_BASE .. "/users/" .. userId
            local data = makeRequest(url)
            wait(REQUEST_DELAY)
            
            local displayText = data and data.name or ("ID:" .. userId)
            
            print("    " .. displayText .. " → " .. #friends .. " friends\n")
        end
    end
    
    print("[STEP 3] Finding Mutuals\n")
    
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
    
    print("    Analyzed " .. totalScanned .. " account(s)\n")
    
    print("╔══════════════════════════════════════════════╗")
    print("║                   RESULTS                    ║")
    print("╚══════════════════════════════════════════════╝\n")
    
    if #mutuals > 0 then
        print("Found " .. #mutuals .. " mutual friend(s):\n")
        for i, mutualId in ipairs(mutuals) do
            local url = API_BASE .. "/users/" .. mutualId
            local data = makeRequest(url)
            wait(REQUEST_DELAY)
            
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
