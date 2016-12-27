local stormlib = require 'ffi.stormlib'
local progress = require 'progress'

local os_clock = os.clock

local function get_map_flag(w3i)
    if not w3i then
        return 0
    end
    return w3i['选项']['关闭预览图']       << 0
         | w3i['选项']['自定义结盟优先权'] << 1
         | w3i['选项']['对战地图']        << 2
         | w3i['选项']['大型地图']        << 3
         | w3i['选项']['迷雾区域显示地形'] << 4
         | w3i['选项']['自定义玩家分组']   << 5
         | w3i['选项']['自定义队伍']       << 6
         | w3i['选项']['自定义科技树']     << 7
         | w3i['选项']['自定义技能']       << 8
         | w3i['选项']['自定义升级']       << 9
         | w3i['选项']['地图菜单标记']     << 10
         | w3i['选项']['地形悬崖显示水波'] << 11
         | w3i['选项']['地形起伏显示水波'] << 12
         | w3i['选项']['未知1']           << 13
         | w3i['选项']['未知2']           << 14
         | w3i['选项']['未知3']           << 15
         | w3i['选项']['未知4']           << 16
         | w3i['选项']['未知5']           << 17
         | w3i['选项']['未知6']           << 18
         | w3i['选项']['未知7']           << 19
         | w3i['选项']['未知8']           << 20
         | w3i['选项']['未知9']           << 21
end

local function create_map(path, w3i)
    local hexs = {}
    hexs[#hexs+1] = ('c4'):pack('HM3W')
    hexs[#hexs+1] = ('c4'):pack('\0\0\0\0')
    hexs[#hexs+1] = ('z'):pack(w3i and w3i['地图']['地图名称'] or '未命名地图')
    hexs[#hexs+1] = ('l'):pack(get_map_flag(w3i))
    hexs[#hexs+1] = ('l'):pack(w3i and w3i['玩家']['玩家数量'] or 233)
    io.save(path, table.concat(hexs))
end

local mt = {}
mt.__index = mt

local function load_file(self, filename)
    local buf = self.handle:load_file(filename)
    if buf then
        if not self.listfile[filename] then
            self.listfile[filename] = true
            self.file_number = self.file_number + 1
        end
        return buf
    end
    return false
end

local function has_file(self, filename)
    local ok = self.handle:has_file(filename)
    if ok then
        if not self.listfile[filename] then
            self.listfile[filename] = true
            self.file_number = self.file_number + 1
        end
    end
    return ok
end

function mt:set(filename, content)
    self.cache[filename] = content
end

function mt:ignore(filename)
    local filename = filename:lower()
    self.ignore_file[filename] = true
end

function mt:get(filename)
    local filename = filename:lower()
    if self.cache[filename] ~= nil then
        if self.cache[filename] then
            return self.cache[filename]
        end
        return false, ('文件 %q 不存在'):format(filename)
    end
    local buf = load_file(self, filename)
    if buf then
        self.cache[filename] = buf
        return buf
    end
    self.cache[filename] = false
    return false, ('文件 %q 不存在'):format(filename)
end

function mt:close()
    self.handle:close()
end

function mt:save(input, slk, info, config)
    for name, buf in pairs(input) do
        self:set(name, buf)
    end
    if not input:sucess() then
        -- do nothing
    end

    create_map(self.path, slk.w3i)

    local impignore = info and info.pack.impignore
    local files = {}
    local imp = {}
    for name in pairs(self.cache) do
        files[#files+1] = name
        if not impignore[name] then
            imp[#imp+1] = name
        end
    end
    table.sort(files)
    table.sort(imp)

    self.handle = stormlib.create(self.path, #files + 8, config.remove_we_only)
    if not self.handle then
        message('创建新地图失败,可能文件被占用了')
        return
    end
    local clock = os_clock()
    for i, name in ipairs(files) do
        self.handle:save_file(name, self.cache[name])
		if os_clock() - clock >= 0.1 then
            clock = os_clock()
            progress(i / #files)
            message(('正在打包文件... (%d/%d)'):format(i, #files))
		end
    end

    if not config.remove_we_only then
        local hex = {}
        hex[1] = ('ll'):pack(1, #imp)
        for _, name in ipairs(imp) do
            hex[#hex+1] = ('z'):pack(name)
            hex[#hex+1] = '\r'
        end
        self.handle:save_file('war3map.imp', table.concat(hex))
    end
end

function mt:__pairs()
    local cache = self.cache
    local ignore = self.ignore_file
    if not self.cached_all then
        self.cached_all = true
        for filename in pairs(self.handle) do
            local filename = filename:lower()
            if not ignore[filename] and cache[filename] == nil then
                cache[filename] = load_file(self, filename)
            end
        end
    end
    local function next_file(_, key)
        local new_key, value = next(cache, key)
        if value == false then
            return next_file(cache, new_key)
        end
        return new_key, value
    end
    return next_file, cache
end

function mt:sucess()
    local total = self.handle:number_of_files()
    if self.file_number < total then
        message('-report|error', ('还有%d个文件没有读取'):format(total - self.file_number))
        message('-tip', '这些文件被丢弃了,请包含完整(listfile)')
        message('-report|error', ('读取(%d/%d)个文件'):format(self.file_number, total))
        return false
    end
    return true
end

return function (pathorhandle, tp)
    local ar = { cache = {}, path = pathorhandle }
    if tp ~= 'w' then
        if type(pathorhandle) == 'number' then
            ar.handle = stormlib.attach(pathorhandle)
        else
            ar.handle = stormlib.open(pathorhandle, true)
        end
        if not ar.handle then
            message('地图打开失败')
            return nil
        end
        if not ar.handle:has_file('(listfile)') then
            message('不支持没有(listfile)的地图')
            return nil
        end
        ar.listfile = {}
        ar.file_number = 0
        ar.ignore_file = {}
    end
    return setmetatable(ar, mt)
end
