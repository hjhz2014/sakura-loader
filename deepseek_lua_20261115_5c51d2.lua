-- whisker-loader-v27.lua (Terminal Auth + Sakura Art)
local PUBLIC_BUILD = true
local FORCE_KEY = '12345678-1234-1234-1234-123456789012'

-- ============================================================
-- 1. LuaArmor 우회 (환경 및 HTTP 전방위 후킹)
-- ============================================================
local function applyBypasses()
    local urlMatch = "luarmor%.net"
    local bypassCode = [[
        local lib = {}
        function lib.check_key(key)
            return {code = "KEY_VALID", data = {auth_expire = -1, note = "whisker_bypass"}}
        end
        return lib
    ]]
    
    local oldRequest = request or http_request or (syn and syn.request) or (http and http.request)
    if oldRequest then
        local function newRequest(req)
            if type(req) == 'table' and type(req.Url) == 'string' and string.find(req.Url, urlMatch) then
                return {StatusCode = 200, Body = bypassCode, Headers = {}}
            end
            return oldRequest(req)
        end
        pcall(function() if request then request = newRequest end end)
        pcall(function() if http_request then http_request = newRequest end end)
        pcall(function() if syn and syn.request then syn.request = newRequest end end)
        pcall(function() if http and http.request then http.request = newRequest end end)
    end

    pcall(function()
        local old = game.HttpGet
        if type(old) == 'function' then
            game.HttpGet = function(self, url, ...)
                if type(url) == "string" and string.find(url, urlMatch) then return bypassCode end
                return old(self, url, ...)
            end
        end
    end)
    
    pcall(function()
        local old = game.HttpGetAsync
        if type(old) == 'function' then
            game.HttpGetAsync = function(self, url, ...)
                if type(url) == "string" and string.find(url, urlMatch) then return bypassCode end
                return old(self, url, ...)
            end
        end
    end)
    
    pcall(function()
        local old = HttpGet
        if type(old) == 'function' then
            HttpGet = function(url, ...)
                if type(url) == "string" and string.find(url, urlMatch) then return bypassCode end
                return old(url, ...)
            end
        end
    end)

    pcall(function()
        local mt = getrawmetatable(game)
        if not mt then return end
        local isReadonly = false
        if type(isreadonly) == 'function' then
            local ok, res = pcall(isreadonly, mt)
            if ok then isReadonly = res end
        elseif type(mt.__readonly) == 'boolean' then
            isReadonly = mt.__readonly
        end
        if isReadonly and type(setreadonly) == 'function' then pcall(setreadonly, mt, false) end
        
        local oldNamecall = mt.__namecall
        if oldNamecall then
            local newNamecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == 'HttpGet' or method == 'HttpGetAsync' then
                    local url = ...
                    if type(url) == 'string' and string.find(url, urlMatch) then return bypassCode end
                end
                return oldNamecall(self, ...)
            end)
            pcall(function() mt.__namecall = newNamecall end)
        end
        if isReadonly and type(setreadonly) == 'function' then pcall(setreadonly, mt, true) end
    end)

    pcall(function()
        local _oldLoad = loadstring
        loadstring = function(code, name)
            local func = _oldLoad(code, name)
            if func then
                pcall(function()
                    local env = getfenv(func)
                    if type(env) == "table" then env.script_key = FORCE_KEY end
                end)
            end
            return func
        end
    end)

    pcall(function()
        local _oldGetfenv = getfenv
        getfenv = function(level)
            local env = _oldGetfenv(level)
            if type(env) == "table" and env.script_key == nil then
                env.script_key = FORCE_KEY
            end
            return env
        end
    end)
end
applyBypasses()

-- ============================================================
-- 2. 환경 설정 및 전역 변수
-- ============================================================
local REPO_OWNER    = 'themagicpiston'
local REPO_NAME     = 'pistonware'
local BRANCH        = 'main'
local INSTALL_DIR   = 'pistonware'
local MARKER_FILE   = 'pistonware_release.json'
local WATERMARK     = '--whisker-loader watermark: safe to delete.'

local CHANNELS = { main = 'main', beta = 'beta', nightly = 'nightly' }
local cloneref    = cloneref or function(r) return r end
local isfile      = isfile or function(p) local ok, c = pcall(readfile, p) return ok and type(c)=='string' and c ~= '' end
local delfile     = delfile or function(p) writefile(p, '') end
local httpService = function() return cloneref(game:GetService('HttpService')) end

local function safeText(v, limit)
    local s = tostring(v or '')
    s = s:gsub('[\r\n]+', ' ')
    s = s:gsub('([Ss]cript[_%s]*[Kk]ey%s*[:=]%s*)[^%s,;]+', '%1<redacted>')
    limit = limit or 1200
    if #s > limit then s = s:sub(1, limit - 3)..'...' end
    return s
end

local requested = BRANCH
pcall(function()
    local env = getgenv and getgenv() or nil
    if type(env) == 'table' and type(env.WhiskerChannel) == 'string' then requested = env.WhiskerChannel end
end)
if type(shared.WhiskerChannel) == 'string' then requested = shared.WhiskerChannel end
requested = requested:lower():gsub('^%s*(.-)%s*$', '%1')
local branch = CHANNELS[requested] or 'main'

local release = { schema = 1, channel = requested, branch = branch, resolved = false, cacheReady = false }

shared.PistonwareRelease = release
shared.PistonwareChannel = release.channel
shared.PistonwareTelemetry = { report = function() end, addFile = function() end }
shared.PistonwareKey = FORCE_KEY
shared.PistonwareAuthenticated = true
shared.PistonwareKeyExpire = -1
script_key = FORCE_KEY
pcall(function() getgenv().script_key = FORCE_KEY end)
pcall(function() _G.script_key = FORCE_KEY end)
pcall(function() shared.script_key = FORCE_KEY end)

local function projectRawUrl(path, ref)
    path = tostring(path or ''):gsub('^/', '')
    return 'https://raw.githubusercontent.com/themagicpiston/pistonware/'..(ref or release.sourceRef or release.branch)..'/'..path
end

local function protectedRawUrl(ref)
    return 'https://gitlab.com/pistonware/pistonware/-/raw/'..(ref or release.branch)..'/bedwars.lua'
end

local function rewriteProjectUrl(url)
    local value = tostring(url or '')
    local ref = release.sourceRef or release.branch
    value = value:gsub('https://raw%.githubusercontent%.com/themagicpiston/pistonware/refs/heads/main/', function() return projectRawUrl('', ref) end)
    value = value:gsub('https://raw%.githubusercontent%.com/themagicpiston/pistonware/main/', function() return projectRawUrl('', ref) end)
    value = value:gsub('https://gitlab%.com/pistonware/pistonware/%-/raw/main/', function() return protectedRawUrl(release.branch):gsub('/bedwars%.lua$', '/') end)
    return value
end

shared.PistonwareRawUrl = projectRawUrl
shared.PistonwareProtectedRawUrl = protectedRawUrl
shared.PistonwareRewriteUrl = rewriteProjectUrl
shared.PistonwareDevHttpGet = function(url, nocache) return game:HttpGet(rewriteProjectUrl(url), nocache) end
shared.PistonwareDevProtectedHttpGet = function(url, nocache) return game:HttpGet(rewriteProjectUrl(url), nocache) end

-- ============================================================
-- 3. 다운로드 및 릴리즈 로직
-- ============================================================
local function validCommit(s) return type(s) == 'string' and #s == 40 and s:match('^%x+$') ~= nil end

local function githubGet(url)
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if ok and type(body) == 'string' and body ~= '' then return body end
    return nil, 'GitHub failed'
end

local function fetchBranchCommit()
    local body = githubGet(('https://api.github.com/repos/%s/%s/branches/%s'):format(REPO_OWNER, REPO_NAME, release.branch))
    if body then
        local ok, decoded = pcall(function() return httpService():JSONDecode(body) end)
        local commit = ok and type(decoded) == 'table' and type(decoded.commit) == 'table' and decoded.commit.sha
        if validCommit(commit) then return commit end
    end
    local refBody = githubGet(('https://github.com/%s/%s.git/info/refs?service=git-upload-pack'):format(REPO_OWNER, REPO_NAME))
    if refBody then
        local wanted = 'refs/heads/'..release.branch
        for line in refBody:gmatch('[^\n]+') do
            local hex, ref = line:match('^(%x+) (%S+)')
            if ref then local nul = ref:find('\0', 1, true); if nul then ref = ref:sub(1, nul - 1) end end
            if ref == wanted and #hex >= 40 then return hex:sub(-40) end
        end
    end
    return nil
end

local _repoTree, _repoTreeTried, _repoTreeDone
local function fetchRepoTree()
    if _repoTreeTried then while not _repoTreeDone do task.wait(0.05) end; return _repoTree end
    _repoTreeTried = true
    pcall(function()
        local body = githubGet(('https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1'):format(REPO_OWNER, REPO_NAME, release.sourceRef or release.branch))
        if body then
            local decoded = httpService():JSONDecode(body)
            if type(decoded) == 'table' and type(decoded.tree) == 'table' and type(decoded.sha) == 'string' then
                _repoTree = decoded; shared.PistonwareRepoTree = decoded
            end
        end
    end)
    _repoTreeDone = true
    return _repoTree
end

local function readMarker()
    if not isfile(MARKER_FILE) then return nil end
    local ok, body = pcall(readfile, MARKER_FILE)
    if not ok or type(body) ~= 'string' then return nil end
    local ok2, decoded = pcall(function() return httpService():JSONDecode(body) end)
    return ok2 and type(decoded) == 'table' and decoded or nil
end

local function writeMarker()
    if not release.resolved or not validCommit(release.commit) then return false end
    local marker = { schema = 1, channel = release.channel, branch = release.branch, commit = release.commit, version = release.version, savedAt = os.time() }
    local ok = pcall(function() writefile(MARKER_FILE, httpService():JSONEncode(marker)) end)
    if ok then release.cacheReady = true; shared.PistonwareRelease = release end
    return ok
end

local function markerMatches(m)
    return type(m) == 'table' and m.schema == 1 and m.channel == release.channel and m.branch == release.branch and validCommit(m.commit)
end

local function resolveRelease()
    local marker = readMarker()
    local commit = fetchBranchCommit()
    if validCommit(commit) then
        release.commit = commit; release.sourceRef = commit; release.version = release.channel..'@'..commit:sub(1, 12)
        release.resolved = true; release.cacheReady = markerMatches(marker) and marker.commit == commit; shared.PistonwareRelease = release
        return true
    end
    local tree = fetchRepoTree()
    if tree and validCommit(tree.sha) then
        release.commit = tree.sha; release.sourceRef = tree.sha; release.version = release.channel..'@'..tree.sha:sub(1, 12)
        release.resolved = true; release.cacheReady = markerMatches(marker) and marker.commit == tree.sha; shared.PistonwareRelease = release
        return true
    end
    if markerMatches(marker) then
        release.commit = marker.commit; release.sourceRef = marker.commit; release.version = release.channel..'@'..marker.commit:sub(1, 12)
        release.resolved = true; release.cacheReady = true; release.fromMarker = true; shared.PistonwareRelease = release
        return true
    end
    release.commit = nil; release.sourceRef = release.branch; release.version = release.channel..'@'..release.branch
    release.resolved = true; release.cacheReady = false; shared.PistonwareRelease = release
    return true
end

local cacheWriteFailed = false
local refreshedThisBoot = {}

local function writeChecked(path, content)
    local wrote = pcall(writefile, path, content)
    if wrote then local rok, back = pcall(readfile, path); if not (rok and back == content) then wrote = false end end
    if not wrote then cacheWriteFailed = true end
    return wrote
end

local function hasContent(path, chunkName)
    if not isfile(path) then return nil end
    local ok, body = pcall(readfile, path)
    if not ok or type(body) ~= 'string' or body == '' then return nil end
    if path:match('%.lua$') then
        local cOk, chunk = pcall(loadstring, body, chunkName or path)
        if not (cOk and type(chunk) == 'function') then return nil end
        return body, chunk
    end
    return body
end

local function unusableBody(path, body)
    if type(body) ~= 'string' or body == '' or body == '404: Not Found' then return true end
    local head = body:sub(1, 200):lower()
    if body:match('^%d%d%d: ') or head:find('<!doctype html', 1, true) or head:find('<html', 1, true) then return true end
    if path:match('%.json$') then
        local ok, decoded = pcall(function() return httpService():JSONDecode(body) end)
        return not (ok and type(decoded) == 'table')
    end
    return false
end

local function downloadFile(path, chunkName)
    if release.cacheReady or refreshedThisBoot[path] then
        local body, chunk = hasContent(path, chunkName)
        if body and not path:find('%.lua$') and unusableBody(path, body) then body, chunk = nil, nil end
        if body then
            if chunkName then return body, chunk end
            return body
        end
    end
    local rel = select(1, path:gsub(INSTALL_DIR..'/', ''))
    local isLua = path:find('%.lua$') ~= nil
    local isBedwars = rel:find('bedwars%.lua') ~= nil
    local content, chunk
    for attempt = 1, 4 do
        local suc, res = pcall(function()
            if isBedwars then return game:HttpGet(protectedRawUrl(release.sourceRef), true) end
            return game:HttpGet(projectRawUrl(rel, release.sourceRef), true)
        end)
        if suc and res and res ~= '' and res ~= '404: Not Found' then
            if isLua then
                local keyInject = string.format([[
local _k = "%s"
script_key = _k
if getgenv then getgenv().script_key = _k end
if _G then _G.script_key = _k end
if shared then shared.script_key = _k; shared.PistonwareKey = _k; shared.PistonwareAuthenticated = true end
]], FORCE_KEY)
                
                local body = WATERMARK..'\n'..keyInject..'\n'..res
                local cOk, c = pcall(loadstring, body, chunkName or rel)
                if cOk and type(c) == 'function' then content, chunk = body, c; break end
            else
                if not unusableBody(path, res) then content = res; break end
            end
        end
        if attempt < 4 then task.wait(attempt) end
    end
    if not content then error('failed to download '..path, 2) end
    writeChecked(path, content)
    if chunkName then return content, chunk end
    return content
end

shared.PistonwareDevLoadSource = function(path, chunkName) return downloadFile(path, chunkName) end

local function updateCachedFiles(onProgress)
    local tree = fetchRepoTree()
    if not tree then return false end
    local manifest = {}
    pcall(function()
        if isfile(INSTALL_DIR..'/filecheck.json') then
            local d = httpService():JSONDecode(readfile(INSTALL_DIR..'/filecheck.json'))
            if type(d) == 'table' then manifest = d end
        end
    end)
    local remote = {}
    for _, v in ipairs(tree.tree) do
        if v.type == 'blob' and v.path:sub(-4) == '.lua' then remote[v.path] = v.sha end
    end
    local toUpdate = {}
    for path, sha in pairs(remote) do
        local p = INSTALL_DIR..'/'..path
        if manifest[path] ~= sha and isfile(p) then toUpdate[#toUpdate+1] = path end
    end
    local changed = false
    if not tree.truncated then
        for path in pairs(manifest) do
            if not remote[path] then
                pcall(function() delfile(INSTALL_DIR..'/'..path) end)
                manifest[path] = nil; changed = true
            end
        end
    end
    local completed, failed, total = 0, 0, #toUpdate
    if total > 0 then
        for _, path in ipairs(toUpdate) do
            task.spawn(function()
                local done = false
                for attempt = 1, 4 do
                    local suc, res = pcall(function() return game:HttpGet(projectRawUrl((path:gsub(' ', '%%20')), tree.sha), true) end)
                    if suc and res and res ~= '' and res ~= '404: Not Found' and loadstring(res) ~= nil then
                        local p = INSTALL_DIR..'/'..path
                        local keyInject = string.format('local _k = "%s" script_key = _k if getgenv then getgenv().script_key = _k end if _G then _G.script_key = _k end\n', FORCE_KEY)
                        if writeChecked(p, WATERMARK..'\n'..keyInject..'\n'..res) then
                            refreshedThisBoot[p] = true; manifest[path] = remote[path]; done = true; changed = true; break
                        end
                    end
                    if attempt < 4 then task.wait(attempt) end
                end
                if not done then failed = failed + 1 end
                completed = completed + 1
                if onProgress then pcall(onProgress, completed, total) end
            end)
        end
        local deadline = os.clock() + 60
        while completed < total and os.clock() < deadline do task.wait(0.05) end
    end
    if changed then pcall(writefile, INSTALL_DIR..'/filecheck.json', httpService():JSONEncode(manifest)) end
    return failed == 0
end

-- ============================================================
-- 4. 콘솔 UI (Thick Sakura Art)
-- ============================================================
local SakuraFace = {
    '▄████▄   ▄▄▄       ██ ▄█▀ █    ██  ██▀███   ▄▄▄       ',
    '▒██▀ ▀█  ▒████▄     ██▄█▒  ██  ▓██▒▓██ ▒ ██▒▒████▄     ',
    '▒▓█    ▄ ▒██  ▀█▄  ▓███▄░ ▓██  ▒██░▓██ ░▄█ ▒▒██  ▀█▄   ',
    '▒▓▓▄ ▄██▒░██▄▄▄▄██ ▓██ █▄ ▓▓█  ░██░▒██▀▀█▄  ░██▄▄▄▄██  ',
    '▒ ▓███▀ ░ ▓█   ▓██▒▒██▒ █▄▒▒█████▓ ░██▓ ▒██▒ ▓█   ▓██▒ ',
    '░ ░▒ ▒  ░ ▒▒   ▓▒█░▒ ▒▒ ▓▒░▒▓▒▒░  ░ ▒▓ ░▒▓░ ▒▒   ▓▒█░ ',
    '  ░  ▒     ▒   ▒▒ ░░ ░▒ ▒░░ ░▒ ░     ░▒ ░ ▒░  ▒   ▒▒ ░ ',
    '░          ░   ▒   ░ ░░ ░   ░░       ░░   ░   ░   ▒    ',
    '░ ░            ░  ░  ░  ░   ░         ░           ░  ░ ',
    '░                                                      '
}

local WindowWidth, TitleBarHeight, ContentPadding = 1000, 44, 26
local AsciiTextSize = 20
local AsciiLineHeight = 22
local AsciiTop = TitleBarHeight + 20
local StatusY = AsciiTop + #SakuraFace * AsciiLineHeight + 20
local LineY = StatusY + 32
local AnswersY = LineY + 30
local WindowHeight = AnswersY + 34 + 30 + 22 + 16

local Palette = {
    Window = Color3.fromRGB(10, 10, 10), TitleBar = Color3.fromRGB(38, 38, 38), Border = Color3.fromRGB(52, 52, 52),
    Title = Color3.fromRGB(232, 232, 232), Glyph = Color3.fromRGB(190, 190, 190), Accent = Color3.fromRGB(255, 105, 180),
    Line = Color3.fromRGB(237, 237, 237), Footer = Color3.fromRGB(110, 110, 110), Error = Color3.fromRGB(225, 80, 70),
    ButtonIdle = Color3.fromRGB(200, 200, 200), ButtonBorder = Color3.fromRGB(60, 60, 60), Ok = Color3.fromRGB(120, 225, 150)
}

local AsciiShades = { 
    ['█'] = '#FF1493', ['▓'] = '#FF69B4', ['▒'] = '#FFB6C1', ['▄'] = '#FFB6C1', ['▀'] = '#FFB6C1', ['░'] = '#FFD1DC',
}

-- ★ 픽스: 파라미터명 '그만' → 'stop' (U+ADF8 파서 에러 해결)
local function asciiRichText(line)
    local out, color, start = {}, nil, 1
    local function flush(stop)
        if stop < start then return end
        local chunk = line:sub(start, stop)
        out[#out+1] = color and ('<font color="'..color..'">'..chunk..'</font>') or chunk
    end
    for i = 1, #line do
        local c = AsciiShades[line:sub(i,i)]
        if i > 1 and c ~= color then flush(i - 1); start = i end
        color = c
    end
    flush(#line)
    return table.concat(out)
end

local function createConsole()
    local ts = cloneref(game:GetService('TweenService'))
    local uis = cloneref(game:GetService('UserInputService'))
    local players = cloneref(game:GetService('Players'))
    pcall(function() if type(shared.WhiskerLoaderTeardown) == 'function' then shared.WhiskerLoaderTeardown() end end)
    local connections = {}
    local function track(c) connections[#connections+1] = c; return c end

    local screen = Instance.new('ScreenGui')
    screen.Name = 'WhiskerLoader'; screen.DisplayOrder = 999999999; screen.IgnoreGuiInset = true; screen.ResetOnSpawn = false
    if not pcall(function() screen.Parent = (gethui and gethui()) or cloneref(game:GetService('CoreGui')) end) then
        pcall(function() screen.Parent = players.LocalPlayer:FindFirstChildOfClass('PlayerGui') end)
    end

    local window = Instance.new('Frame')
    window.AnchorPoint = Vector2.new(0.5, 0.5); window.Position = UDim2.fromScale(0.5, 0.5)
    window.Size = UDim2.fromOffset(WindowWidth, WindowHeight); window.BackgroundColor3 = Palette.Window
    window.BorderSizePixel = 0; window.ClipsDescendants = true; window.Parent = screen
    local wc = Instance.new('UICorner'); wc.CornerRadius = UDim.new(0, 10); wc.Parent = window
    local ws = Instance.new('UIStroke'); ws.Color = Palette.Border; ws.Thickness = 1; ws.Parent = window

    local uiscale = Instance.new('UIScale'); uiscale.Parent = window
    local camera = workspace.CurrentCamera
    local minimized, maximized = false, false
    local restorePosition = window.Position
    local windowHeight = WindowHeight

    local function applyWindowState(animate)
        local viewport = camera and camera.ViewportSize or Vector2.new(WindowWidth, windowHeight)
        local width = maximized and (viewport.X / uiscale.Scale) or WindowWidth
        local height = maximized and (viewport.Y / uiscale.Scale) or windowHeight
        local size = UDim2.fromOffset(width, minimized and TitleBarHeight or height)
        local position = maximized and UDim2.fromScale(0.5, 0.5) or restorePosition
        if animate then ts:Create(window, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {Size = size, Position = position}):Play()
        else window.Size, window.Position = size, position end
    end

    local function applyScale()
        local viewport = camera and camera.ViewportSize or Vector2.new(WindowWidth, windowHeight)
        if viewport.X <= 0 or viewport.Y <= 0 then return end
        local fit = math.min(viewport.X * 0.94 / WindowWidth, viewport.Y * 0.92 / windowHeight)
        local scale = math.min(fit, viewport.Y / 1080)
        if uis.TouchEnabled and not uis.KeyboardEnabled then scale = math.max(scale, math.min(fit, 0.7)) end
        uiscale.Scale = math.clamp(scale, 0.25, 1.4)
        applyWindowState(false)
    end
    applyScale()
    if camera then track(camera:GetPropertyChangedSignal('ViewportSize'):Connect(applyScale)) end

    local titlebar = Instance.new('Frame')
    titlebar.Size = UDim2.new(1, 0, 0, TitleBarHeight); titlebar.BackgroundColor3 = Palette.TitleBar
    titlebar.BorderSizePixel = 0; titlebar.Parent = window
    local tc = Instance.new('UICorner'); tc.CornerRadius = UDim.new(0, 10); tc.Parent = titlebar
    local fill = Instance.new('Frame'); fill.Position = UDim2.new(0, 0, 1, -10); fill.Size = UDim2.new(1, 0, 0, 10)
    fill.BackgroundColor3 = Palette.TitleBar; fill.BorderSizePixel = 0; fill.Parent = titlebar

    local icon = Instance.new('TextLabel'); icon.Position = UDim2.fromOffset(10, 10); icon.Size = UDim2.fromOffset(24, 24)
    icon.BackgroundColor3 = Color3.fromRGB(22, 22, 22); icon.BorderSizePixel = 0; icon.Text = '>_'
    icon.TextColor3 = Palette.Accent; icon.TextSize = 13; icon.Font = Enum.Font.Code; icon.Parent = titlebar
    local ic = Instance.new('UICorner'); ic.CornerRadius = UDim.new(0, 5); ic.Parent = icon

    local title = Instance.new('TextLabel'); title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -220, 1, 0); title.Position = UDim2.fromOffset(110, 0)
    title.Text = './sakura-loader'; title.TextColor3 = Palette.Title; title.TextSize = 18; title.Font = Enum.Font.Code; title.Parent = titlebar

    local closed, aborted, finished = false, false, false
    local console
    local function destroy()
        if closed then return end; closed = true
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        table.clear(connections); pcall(function() screen:Destroy() end)
        if shared.WhiskerLoaderTeardown == destroy then shared.WhiskerLoaderTeardown = nil end
    end
    local function cancel() if finished then destroy(); return end; if aborted then return end; aborted = true; destroy() end

    local function drawGlyph(parent, kind)
        local function bar(len, x, y, rot)
            local p = Instance.new('Frame'); p.AnchorPoint = Vector2.new(0.5, 0.5); p.Position = UDim2.fromOffset(x, y)
            p.Size = UDim2.fromOffset(len, 2); p.BackgroundColor3 = Palette.Glyph; p.BorderSizePixel = 0; p.Rotation = rot; p.Parent = parent
            local c = Instance.new('UICorner'); c.CornerRadius = UDim.new(0, 1); c.Parent = p
        end
        if kind == 'minimize' then bar(10, 13.5, 17, 45); bar(10, 20.5, 17, -45)
        elseif kind == 'maximize' then bar(10, 13.5, 17, -45); bar(10, 20.5, 17, 45)
        else bar(15, 17, 17, 45); bar(15, 17, 17, -45) end
    end

    for index, kind in ipairs({'minimize', 'maximize', 'close'}) do
        local btn = Instance.new('TextButton'); btn.AnchorPoint = Vector2.new(1, 0.5)
        btn.Position = UDim2.new(1, -14 - (3 - index) * 38, 0.5, 0); btn.Size = UDim2.fromOffset(34, 34)
        btn.BackgroundTransparency = 1; btn.AutoButtonColor = false; btn.Text = ''; btn.Modal = true; btn.Parent = titlebar
        local c = Instance.new('UICorner'); c.CornerRadius = UDim.new(0, 6); c.Parent = btn; drawGlyph(btn, kind)
        btn.MouseButton1Click:Connect(function()
            if kind == 'close' then cancel() elseif kind == 'minimize' then minimized = not minimized; applyWindowState(true)
            else maximized = not maximized; minimized = false; applyWindowState(true) end
        end)
    end

    local dragging, dragStart, dragOrigin
    titlebar.InputBegan:Connect(function(input)
        if maximized then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, dragOrigin = true, input.Position, window.Position
            local release
            release = track(input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false; release:Disconnect() end end))
        end
    end)
    track(uis.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            window.Position = UDim2.new(dragOrigin.X.Scale, dragOrigin.X.Offset + d.X, dragOrigin.Y.Scale, dragOrigin.Y.Offset + d.Y)
            restorePosition = window.Position
        end
    end))

    local ascii = Instance.new('Frame'); ascii.BackgroundTransparency = 1
    ascii.Position = UDim2.fromOffset(ContentPadding, AsciiTop)
    ascii.Size = UDim2.fromOffset(WindowWidth - ContentPadding * 2, #SakuraFace * AsciiLineHeight); ascii.Parent = window

    local rows = {}
    for i, line in ipairs(SakuraFace) do
        local label = Instance.new('TextLabel'); label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(0, (i - 1) * AsciiLineHeight)
        label.Size = UDim2.new(1, 0, 0, AsciiLineHeight)
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.RichText = true; label.Text = asciiRichText(line); label.TextColor3 = Color3.new(1, 1, 1)
        label.TextSize = AsciiTextSize; label.TextXAlignment = Enum.TextXAlignment.Left; label.TextTransparency = 1
        label.Font = Enum.Font.Code; label.Visible = false; label.Parent = ascii; rows[i] = label
    end

    local status = Instance.new('TextLabel'); status.BackgroundTransparency = 1
    status.Position = UDim2.fromOffset(ContentPadding, StatusY); status.Size = UDim2.new(1, -ContentPadding * 2, 0, 28)
    status.RichText = true; status.TextColor3 = Palette.Line; status.TextSize = 22; status.TextXAlignment = Enum.TextXAlignment.Left
    status.Font = Enum.Font.Code; status.Parent = window

    local line = Instance.new('TextLabel'); line.BackgroundTransparency = 1
    line.Position = UDim2.fromOffset(ContentPadding, LineY); line.Size = UDim2.new(1, -ContentPadding * 2, 0, 24)
    line.Text = ''; line.TextColor3 = Palette.Line; line.TextSize = 17; line.TextXAlignment = Enum.TextXAlignment.Left
    line.Font = Enum.Font.Code; line.Parent = window

    local answers = Instance.new('Frame'); answers.BackgroundTransparency = 1
    answers.Position = UDim2.fromOffset(ContentPadding, AnswersY); answers.Size = UDim2.new(1, -ContentPadding * 2, 0, 34)
    answers.Visible = false; answers.Parent = window
    local answersLayout = Instance.new('UIListLayout'); answersLayout.SortOrder = Enum.SortOrder.LayoutOrder
    answersLayout.FillDirection = Enum.FillDirection.Horizontal; answersLayout.Padding = UDim.new(0, 12)
    answersLayout.Parent = answers

    local footer = Instance.new('TextLabel'); footer.AnchorPoint = Vector2.new(0, 1); footer.BackgroundTransparency = 1
    footer.Position = UDim2.new(0, ContentPadding, 1, -16); footer.Size = UDim2.new(1, -ContentPadding * 2, 0, 22)
    footer.Text = (uis.TouchEnabled and not uis.KeyboardEnabled) and 'Tap [x] to exit' or 'Press [CTRL+C] to exit'
    footer.TextColor3 = Palette.Footer; footer.TextSize = 17; footer.TextXAlignment = Enum.TextXAlignment.Left; footer.Font = Enum.Font.Code; footer.Parent = window

    track(uis.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.C and uis:IsKeyDown(Enum.KeyCode.LeftControl) then cancel() end
    end))

    local revealed, revealTarget, halted = 0, 0, false
    task.spawn(function()
        while not closed and not halted do
            if revealed < revealTarget then
                revealed = revealed + 1; local row = rows[revealed]; row.Visible = true
                ts:Create(row, TweenInfo.new(0.18), {TextTransparency = 0}):Play()
            end
            task.wait(0.07)
        end
    end)

    local function answerButton(text, width, order)
        local button = Instance.new('TextButton')
        button.LayoutOrder = order; button.Size = UDim2.fromOffset(width, 34)
        button.BackgroundColor3 = Color3.fromRGB(18, 18, 18); button.BorderSizePixel = 0; button.AutoButtonColor = false
        button.Modal = true; button.Text = text; button.TextColor3 = Palette.ButtonIdle
        button.TextSize = 17; button.Font = Enum.Font.Code; button.Parent = answers
        local corner = Instance.new('UICorner'); corner.CornerRadius = UDim.new(0, 4); corner.Parent = button
        local stroke = Instance.new('UIStroke'); stroke.Color = Palette.ButtonBorder; stroke.Thickness = 1; stroke.Parent = button
        button.MouseEnter:Connect(function() stroke.Color = Palette.Accent; button.TextColor3 = Palette.Accent end)
        button.MouseLeave:Connect(function() stroke.Color = Palette.ButtonBorder; button.TextColor3 = Palette.ButtonIdle end)
        return button
    end

    local function clearAnswers()
        for _, child in answers:GetChildren() do
            if child:IsA('TextButton') or child:IsA('TextBox') then child:Destroy() end
        end
    end

    console = {}
    function console:SetStatus(text, color, chevron)
        status.Text = '<font color="#9E9E9E">'..(chevron == '<' and '&lt;' or '&gt;')..'</font> <font color="'..(color or '#FF69B4')..'">'..text..'</font>'
    end
    function console:SetLine(text, color) line.Text = text; line.TextColor3 = color or Palette.Line end
    function console:SetProgress(alpha)
        local count = math.clamp(math.floor(alpha * #SakuraFace + 0.5), 0, #SakuraFace); revealTarget = math.max(revealTarget, count)
    end
    function console:IsAborted() return aborted end

    function console:AskKey(opts)
        if closed then return nil end
        clearAnswers()
        local function say(message, kind) self:SetLine(message or '', kind == 'err' and Palette.Error or (kind == 'ok' and Palette.Ok or Palette.Line)) end
        say(opts.message)
        
        local previousFooter = footer.Text
        if opts.footer then footer.Text = opts.footer end

        local box = Instance.new('TextBox'); box.LayoutOrder = 1; box.Size = UDim2.fromOffset(260, 34)
        box.BackgroundColor3 = Color3.fromRGB(18, 18, 18); box.BorderSizePixel = 0; box.ClearTextOnFocus = false
        box.Text = ''; box.PlaceholderText = opts.placeholder or ''; box.PlaceholderColor3 = Palette.Footer
        box.TextColor3 = Palette.Line; box.TextSize = 16; box.TextXAlignment = Enum.TextXAlignment.Left
        box.Font = Enum.Font.Code; box.Parent = answers
        local boxCorner = Instance.new('UICorner'); boxCorner.CornerRadius = UDim.new(0, 4); boxCorner.Parent = box
        local boxStroke = Instance.new('UIStroke'); boxStroke.Color = Palette.ButtonBorder; boxStroke.Thickness = 1; boxStroke.Parent = box
        local boxPadding = Instance.new('UIPadding'); boxPadding.PaddingLeft = UDim.new(0, 10); boxPadding.PaddingRight = UDim.new(0, 10); boxPadding.Parent = box
        box.Focused:Connect(function() boxStroke.Color = Palette.Accent end)
        box.FocusLost:Connect(function() boxStroke.Color = Palette.ButtonBorder end)

        local accepted, busy = nil, false
        local function submit()
            if busy or closed or accepted then return end
            busy = true
            if opts.onSubmit(box.Text, say) then accepted = box.Text end
            busy = false
        end

        local order = 1
        for _, link in ipairs(opts.links or {}) do
            order = order + 1
            local button = answerButton(link.text, link.width or 105, order)
            button.MouseButton1Click:Connect(function() link.onClick(say) end)
        end

        order = order + 1
        local submitButton = answerButton(opts.submitText, 115, order)
        submitButton.MouseButton1Click:Connect(submit)

        order = order + 1
        local help = answerButton(opts.helpText, 110, order)
        help.MouseButton1Click:Connect(function() opts.onHelp(say) end)

        box.FocusLost:Connect(function(enter) if enter then submit() end end)

        answers.Visible = true
        repeat task.wait() until accepted or closed
        answers.Visible = false
        clearAnswers()
        footer.Text = previousFooter
        self:SetLine('')
        return accepted
    end

    function console:Finish(message, seconds)
        finished = true; if closed then return end; self:SetProgress(1)
        local drawn = os.clock() + 2; while revealed < #SakuraFace and not closed and os.clock() < drawn do task.wait() end
        task.wait(0.2); if closed then return end; self:SetStatus('DONE')
        seconds = seconds or 5; local deadline = os.clock() + seconds
        task.spawn(function()
            while not closed do
                local left = math.max(0, math.ceil(deadline - os.clock())); self:SetLine(message..' Loader will close in '..left..'s.')
                if left <= 0 then break end; task.wait(0.2)
            end
            destroy()
        end)
    end
    function console:Halt() halted = true end
    function console:Fail(err)
        if closed then return end; self:SetStatus('FAILED', '#E15046')
        line.TextWrapped = true; line.TextYAlignment = Enum.TextYAlignment.Top; line.Size = UDim2.new(1, -ContentPadding * 2, 0, 64)
        self:SetLine(err, Palette.Error); self:Halt()
    end
    shared.WhiskerLoaderTeardown = destroy; return console
end

local function createHeadlessConsole()
    local console = {}
    function console:SetStatus() end
    function console:SetLine() end
    function console:SetProgress() end
    function console:Finish() end
    function console:Halt() end
    function console:IsAborted() return false end
    function console:AskKey() return nil end
    function console:Fail(err)
        pcall(function() game:GetService('StarterGui'):SetCore('SendNotification', {Title = 'Sakura', Text = safeText(err, 180), Duration = 15}) end)
    end
    return console
end

-- ============================================================
-- 5. 부팅 시작
-- ============================================================
local isReload = shared.vapereload and true or false
local console = isReload and createHeadlessConsole() or createConsole()

if shared.WhiskerLoaderBoot and os.clock() - shared.WhiskerLoaderBoot < 180 then return end
shared.WhiskerLoaderBoot = os.clock()
local bootStamp = shared.WhiskerLoaderBoot

local function releaseBoot() if shared.WhiskerLoaderBoot ~= bootStamp then return end; shared.WhiskerLoaderBoot = nil; shared.vapereload = nil end
local function bootFailure(stage, err) 
    local msg = 'Loader stopped: '..safeText(err, 300)
    console:Fail(msg)
    warn('[Sakura Error] '..msg)
    print('[Sakura Traceback]', err)
    releaseBoot()
    return false 
end

console:SetStatus('AUTHENTICATING', nil, '<')
console:SetLine('Checking your key...')
console:SetProgress(0.08)

-- ============================================================
-- 6. 커스텀 키 인증 루프 (저장된 키 우선 사용)
-- ============================================================
do
    local function decryptKey()
        local data = {6, 20, 30, 0, 7, 20, 120, 97, 101, 109, 101, 120, 3, 28, 5}
        local str = ""
        for _, byte in ipairs(data) do str = str .. string.char(bit32.bxor(byte, 85)) end
        return str
    end
    local CUSTOM_KEY = decryptKey()

    -- ★ 저장 파일 경로 / 저장·불러오기
    local KEY_SAVE_FILE = 'sakura_saved_key.txt'
    local function saveKey(key)
        pcall(function() writefile(KEY_SAVE_FILE, key) end)
    end
    local function loadSavedKey()
        local ok, body = pcall(function() return readfile(KEY_SAVE_FILE) end)
        if ok and type(body) == 'string' then
            body = body:gsub('%s+$', '')
            if body ~= '' then return body end
        end
        return nil
    end

    local function clipboardSet(text)
        local fn = setclipboard or toclipboard or (Clipboard and Clipboard.set)
        if not fn then return false end
        return (pcall(fn, text))
    end

    local authenticated = false

    -- ★ 저장된 키가 있으면 프롬프트 생략
    local savedKey = loadSavedKey()
    if savedKey and savedKey == CUSTOM_KEY then
        authenticated = true
        console:SetLine('Saved key found - skipping prompt.', Palette.Ok)
        task.wait(0.4)
    end

    while not authenticated do
        local key = console:AskKey({
            message = 'Enter your key below to continue.',
            placeholder = 'Paste your key here',
            footer = 'No key? Pick a link -> finish the checkpoints -> paste the key above.',
            submitText = 'Submit',
            helpText = 'Need Help?',
            links = {
                {text = 'Work.ink (Recommended)', width = 200, onClick = function(say)
                    if clipboardSet('https://ads.luarmor.net/get_key?for=Pistonware_Workink-cjPVCqOPPBCJ') then say('Copied Work.ink link!') else say('Copy failed.', 'err') end
                end},
                {text = 'LootLabs', onClick = function(say)
                    if clipboardSet('https://ads.luarmor.net/get_key?for=Pistonware_LootLabs-xnpnovpEljPO') then say('Copied LootLabs link!') else say('Copy failed.', 'err') end
                end}
            },
            onHelp = function(say)
                if clipboardSet('https://discord.gg/pistonware') then say('Help link copied!') else say('Copy failed.', 'err') end
            end,
            onSubmit = function(keyText, say)
                if keyText == CUSTOM_KEY then
                    authenticated = true
                    saveKey(keyText)  -- ★ 성공 시 저장
                    say('Key valid - loading...', 'ok')
                    return true
                else
                    say('Invalid key. Access denied.', 'err')
                    return false
                end
            end
        })
        if console:IsAborted() or not key then
            local msg = 'Key entry cancelled.'
            console:Fail(msg)
            releaseBoot()
            return
        end
    end
end

console:SetStatus('INJECTING')
console:SetLine('Injecting into ROBLOX...')
console:SetProgress(0.12)

local freshInstall = not isfolder(INSTALL_DIR)
for _, folder in ipairs({ INSTALL_DIR, INSTALL_DIR..'/games', INSTALL_DIR..'/profiles', INSTALL_DIR..'/assets', INSTALL_DIR..'/libraries', INSTALL_DIR..'/guis' }) do
    if not isfolder(folder) then makefolder(folder) end
end

console:SetLine('Resolving release...')
if not pcall(resolveRelease) then bootFailure('release.resolve', 'resolve failed'); return end
console:SetLine(('Loading %s...'):format(release.version)); console:SetProgress(0.15)

local updateDone = isReload and release.cacheReady or false
if not updateDone then
    task.spawn(function()
        pcall(function() updateCachedFiles(function(done, total) console:SetLine(('Updating files (%d/%d)...'):format(done, total)); console:SetProgress(0.4 + 0.06 * (done / math.max(total, 1))) end) end)
        updateDone = true
    end)
elseif not isReload then task.spawn(fetchRepoTree) end

do
    local players = cloneref(game:GetService('Players'))
    local deadline = os.clock() + 120
    while not game:IsLoaded() and not console:IsAborted() and os.clock() < deadline do task.wait() end
    console:SetProgress(0.24)
    while not players.LocalPlayer and not console:IsAborted() and os.clock() < deadline do task.wait() end
    if shared.vape then task.wait(0.25) end
    console:SetProgress(0.4)
end
if console:IsAborted() then releaseBoot(); return end

if not updateDone then
    console:SetLine('Checking for updates...')
    local deadline = os.clock() + 60; while not updateDone and os.clock() < deadline do task.wait(0.05) end
    console:SetLine(''); if console:IsAborted() then releaseBoot(); return end
end
console:SetProgress(0.55)

pcall(function()
    local profiles = listfiles(INSTALL_DIR..'/profiles')
    if #profiles < 3 then
        console:SetLine('Downloading starter configs...')
        local tree = fetchRepoTree()
        if tree then
            for _, v in ipairs(tree.tree) do
                if v.type == 'blob' and v.path:sub(1, 9) == 'profiles/' then
                    task.spawn(function() pcall(function() downloadFile(INSTALL_DIR..'/'..v.path) end) end)
                end
            end
            task.wait(3)
        end
    end
end)
if console:IsAborted() then releaseBoot(); return end
console:SetProgress(0.72)

local bootPendingPath
pcall(function()
    local player = cloneref(game:GetService('Players')).LocalPlayer
    if player then
        bootPendingPath = INSTALL_DIR..'/bootpending_'..tostring(player.UserId)..'.txt'
        writefile(bootPendingPath, tostring(os.time())..' '..tostring(release.version))
    end
end)
shared.PistonwareBootPending = bootPendingPath

console:SetLine('Loading sakura...'); console:SetProgress(0.85)
local injecting = true
task.spawn(function()
    local alpha = 0.85
    while injecting and alpha < 0.93 do task.wait(0.6); if not injecting then break end; alpha = alpha + 0.02; console:SetProgress(alpha) end
end)

local mainOk, mainResult = xpcall(function()
    local source, chunk = downloadFile(INSTALL_DIR..'/main.lua', 'main')
    if not chunk then
        local compileErr
        chunk, compileErr = loadstring(source, 'main')
        if not chunk then error(compileErr or 'main.lua did not compile', 0) end
    end
    return chunk()
end, function(e)
    local tb; pcall(function() tb = debug.traceback(tostring(e), 2) end); return tb or tostring(e)
end)
injecting = false; shared.vapereload = nil; shared.WhiskerLoaderBoot = nil

if console:IsAborted() then
    if shared.vape then pcall(function() shared.vape:Uninject() end) end
    shared.VapeCustomProfile = nil; return
end

if mainOk then
    if (release.cacheReady) and not cacheWriteFailed then writeMarker() end
    console:Finish('Injected successfully.', 5); return mainResult
end

bootFailure('main.load', mainResult)