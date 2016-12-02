require 'filesystem'
require 'sys'
require 'utility'
require 'gui.backend'
local lni = require 'lni'
local nk = require 'nuklear'
--nk:console()

NK_WIDGET_STATE_MODIFIED = 1 << 1
NK_WIDGET_STATE_INACTIVE = 1 << 2
NK_WIDGET_STATE_ENTERED  = 1 << 3
NK_WIDGET_STATE_HOVER    = 1 << 4
NK_WIDGET_STATE_ACTIVED  = 1 << 5
NK_WIDGET_STATE_LEFT     = 1 << 6

NK_TEXT_ALIGN_LEFT     = 0x01
NK_TEXT_ALIGN_CENTERED = 0x02
NK_TEXT_ALIGN_RIGHT    = 0x04
NK_TEXT_ALIGN_TOP      = 0x08
NK_TEXT_ALIGN_MIDDLE   = 0x10
NK_TEXT_ALIGN_BOTTOM   = 0x20
NK_TEXT_LEFT           = NK_TEXT_ALIGN_MIDDLE | NK_TEXT_ALIGN_LEFT
NK_TEXT_CENTERED       = NK_TEXT_ALIGN_MIDDLE | NK_TEXT_ALIGN_CENTERED
NK_TEXT_RIGHT          = NK_TEXT_ALIGN_MIDDLE | NK_TEXT_ALIGN_RIGHT

local root = fs.get(fs.DIR_EXE):remove_filename()
local config = lni:loader(io.load(root / 'config.ini'))

local window = nk.window('W3x2Lni', 400, 600)

local filetype = 'none'
local showmappath = false
local showcount = 0
local mapname = ''
local mappath = fs.path()

function window:dropfile(file)
	mappath = fs.path(file)
	mapname = mappath:filename():string()
	if fs.is_directory(mappath) then
		filetype = 'dir'
	else
		filetype = 'mpq'
	end
end

local function button_mapname(canvas)
	canvas:layout_row_dynamic(10, 1)
	canvas:layout_row_dynamic(40, 1)
	local ok, state = canvas:button(mapname)
	if ok then 
		showmappath = not showmappath
	end
	if state & NK_WIDGET_STATE_LEFT ~= 0 then
		count = count + 1
	else
		count = 0
	end
	if showmappath or count > 20 then
		canvas:edit(mappath:string(), 200, function ()
			return false
		end)
		return 44
	end
	return 0
end

local function window_none(canvas)
	canvas:layout_row_dynamic(2, 1)
	canvas:layout_row_dynamic(200, 1)
	canvas:button('把地图拖进来')
	canvas:layout_row_dynamic(280, 1)
	canvas:layout_row_dynamic(20, 2)
	canvas:label('', NK_TEXT_RIGHT) canvas:label('版本: 1.0.0', NK_TEXT_LEFT)
	canvas:label('', NK_TEXT_RIGHT) canvas:label('前端: actboy168', NK_TEXT_LEFT)
	canvas:label('', NK_TEXT_RIGHT) canvas:label('后端: 最萌小汐', NK_TEXT_LEFT)
end

local backend
local backend_lastmsg = ''

local function update_backend()
	if not backend then
		return
	end
	if not backend.closed then
		backend.closed = backend:update()
	end
	if #backend.output > 0 then
		local pos = backend.output:find('\n')
		if pos then
			local msg = backend.output:sub(1, pos):gsub("^%s*(.-)%s*$", "%1")
			if #msg > 0 then
				backend_lastmsg = msg
			end
			backend.output = backend.output:sub(pos+1)
		end
	end
end
	
local function window_mpq(canvas, height)
	update_backend()
	height = 200 - height
	local unpack = config.unpack
	canvas:layout_row_dynamic(10, 1)
	canvas:layout_row_dynamic(30, 1)
	if canvas:checkbox('分析slk文件', unpack.read_slk) then
		unpack.read_slk = not unpack.read_slk
	end
	if canvas:checkbox('删除和模板一致的数据', unpack.remove_same) then
		unpack.remove_same = not unpack.remove_same
	end
	if canvas:checkbox('删除超过最大等级的数据', unpack.remove_over_level) then
		unpack.remove_over_level = not unpack.remove_over_level
	end
	canvas:layout_row_dynamic(10, 1)
	canvas:tree('高级', 1, function()
		canvas:layout_row_dynamic(30, 1)
		if canvas:checkbox('限制搜索最优模板的次数', unpack.find_id_times ~= 0) then
			if unpack.find_id_times == 0 then
				unpack.find_id_times = 10
			else
				unpack.find_id_times = 0
			end
		end
		if unpack.find_id_times == 0 then
			canvas:edit('', 0, function ()
				return false
			end)
		else
			local r = canvas:edit(tostring(unpack.find_id_times), 10, function (c)
				return 48 <= c and c <= 57
			end)
			unpack.find_id_times = tonumber(r)
		end
		height = height - 68
	end)
	canvas:layout_row_dynamic(height, 1)
	canvas:layout_row_dynamic(30, 1)
	canvas:label(backend_lastmsg, NK_TEXT_LEFT)
	canvas:layout_row_dynamic(10, 1)
	canvas:layout_row_dynamic(30, 1)
	canvas:progress(0, 100)
	canvas:layout_row_dynamic(10, 1)
end

local function window_dir(canvas)
end

local function error_handle(msg)
    print(msg)
    print(debug.traceback())
end

function window:draw(canvas)
	if filetype == 'none' then
		window_none(canvas)
		return
	end
	local height = button_mapname(canvas)
	if filetype == 'mpq' then
		window_mpq(canvas, height)
	else
		window_dir(canvas)
	end
	canvas:layout_row_dynamic(50, 1)
	if canvas:button('开始') then
		backend = sys.async_popen(('%q -nogui %q'):format(arg[0], mappath:string()))
		print('ok' , backend)
	end
end

window:run()
