local header_name = "xdg-mime"

local notify = function(content, level)
    ya.notify {
        title = header_name,
        content = content,
        level = level,
        timeout = 5
    }
end

local info = function(content)
    notify(content, "info")
end

local error = function(content)
    notify(content, "error")
end


local open_ui_if_not_open = ya.sync(function(self)
    if not self.children then
        self.children = Modal:children_add(self, 10)
    end
end)

local close_ui_if_open = ya.sync(function(self)
    if self.children then
        Modal:children_remove(self.children)
        self.children = nil
    end
end)

--shamelessly stolen from https://github.com/yazi-rs/plugins/tree/main/chmod.yazi
local selected_or_hovered = ya.sync(function()
    local tab, paths = cx.active, {}
    for _, u in pairs(tab.selected) do
        paths[#paths + 1] = tostring(u)
    end
    if #paths == 0 and tab.current.hovered then
        paths[1] = tostring(tab.current.hovered.url)
    end
    return paths
end)

--requires aync context to run
local retrieve_mime_types = function()
    local selected_files = selected_or_hovered()
    if #selected_files == 0 then
        error("no file(s) selected")
        return {}
    end
    local mime_types = {}
    for i, f in pairs(selected_files) do
        local command = Command("xdg-mime"):args({ "query", "filetype" }):arg(f)
        local output, err = command:output()
        if err then
            error(tostring(err))
            return {}
        else
            local clean_mime = string.gsub(output.stdout, "\n", "")
            mime_types[i] = {
                file = f,
                mime = clean_mime
            }
        end
    end
    return mime_types
end

local update_mime_data = ya.sync(function(self, mime_data)
    self.mime_types = mime_data
    ya.render()
end)

local update_cursor = ya.sync(function(self, offset)
    local new_cursor = self.cursor + offset
    local max_pos = (#self.mime_types or 0)
    if (new_cursor < 0) then
        self.cursor = 0
    elseif (new_cursor > max_pos) then
        self.cursor = max_pos
    else
        self.cursor = new_cursor
    end
end)

local retrieve_selected_mimetype = ya.sync(function(self)
    update_cursor(0)
    return self.mime_types[self.cursor + 1]
end)

local sc = function(on, run)
    return { on = on, run = run }
end


local M = {
    keys = {
        sc("q", "quit"),
        sc("<Escape>", "quit"),
        sc("<Up>", "up"),
        sc("<Down>", "down"),
        sc("y", "copy")
    },
    cursor = 0
}

--entry point, async
function M:entry(job)
    open_ui_if_not_open()
    update_mime_data(retrieve_mime_types())
    self.user_input(self)
end

function M:user_input()
    while true do
        local action = (self.keys[ya.which { cands = self.keys, silent = true }] or { run = "invalid" }).run
        if action == "quit" then
            close_ui_if_open()
            return
        end
        self.act_user_input(self, action)
    end
end

function M:act_user_input(action)
    if action == "up" then
        update_cursor(-1)
    elseif action == "down" then
        update_cursor(1)
    elseif action == "copy" then
        local cont = retrieve_selected_mimetype().mime
        ya.clipboard(cont)
        info("Successfully copied mimetype: "..cont)
    end
end

-- Modal functions
function M:new(area)
    self:layout(area)
    return self
end

-- Not a modal function but a helper to get the layout
function M:layout(area)
    local h_chunks = ui.Layout()
        :direction(ui.Layout.HORIZONTAL)
        :constraints({
            ui.Constraint.Percentage(25),
            ui.Constraint.Percentage(50),
            ui.Constraint.Percentage(25)
        })
        :split(area)
    local v_chunks = ui.Layout()
        :direction(ui.Layout.VERTICAL)
        :constraints({
            ui.Constraint.Percentage(10),
            ui.Constraint.Percentage(80),
            ui.Constraint.Percentage(10)
        })
        :split(h_chunks[2])

    self.draw_area = v_chunks[2]
end

function M:reflow()
    return { self }
end

-- actually draw the content, is synced, so cannot use Command
function M:redraw()
    local rows = {}
    for i, mime_info in pairs(self.mime_types or {}) do
        rows[i] = ui.Row { mime_info.file, mime_info.mime }
    end
    -- basically stolen from https://github.com/yazi-rs/plugins/blob/a1738e8088366ba73b33da5f45010796fb33221e/mount.yazi/main.lua#L144
    return {
        ui.Clear(self.draw_area),
        ui.Border(ui.Border.ALL)
            :area(self.draw_area)
            :type(ui.Border.ROUNDED)
            :style(ui.Style():fg("blue"))
            :title(ui.Line("XDG-Mimetype"):align(ui.Line.CENTER)),
        ui.Table(rows)
            :area(self.draw_area:pad(ui.Pad(1, 2, 1, 2)))
            :header(ui.Row({ "File", "Mimetype" }):style(ui.Style():bold()))
            :row(self.cursor)
            :row_style(ui.Style():fg("blue"):underline())
            :widths {
                ui.Constraint.Percentage(80),
                ui.Constraint.Percentage(20)
            },
    }
end

return M
