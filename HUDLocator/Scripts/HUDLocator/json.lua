local M = {}

-- Lightweight JSON parser in pure Lua (handles nested tables/objects)
function M.parse(str)
    -- Strip comments if present
    str = str:gsub("//[^\n]*", ""):gsub("/%*.-%*/", "")
    
    local pos = 1
    local function skip_whitespace()
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
                pos = pos + 1
            else
                break
            end
        end
    end
    
    local parse_value
    
    local function parse_object()
        local obj = {}
        pos = pos + 1 -- skip '{'
        while pos <= #str do
            skip_whitespace()
            local c = str:sub(pos, pos)
            if c == '}' then
                pos = pos + 1
                return obj
            end
            if c == ',' then
                pos = pos + 1
                skip_whitespace()
                c = str:sub(pos, pos)
            end
            if c == '"' then
                pos = pos + 1
                local start = pos
                while pos <= #str and str:sub(pos, pos) ~= '"' do
                    pos = pos + 1
                end
                local key = str:sub(start, pos - 1)
                pos = pos + 1 -- skip '"'
                skip_whitespace()
                if str:sub(pos, pos) ~= ':' then
                    error("Expected ':' at position " .. pos)
                end
                pos = pos + 1 -- skip ':'
                skip_whitespace()
                local val = parse_value()
                obj[key] = val
            else
                pos = pos + 1
            end
        end
        return obj
    end
    
    local function parse_array()
        local arr = {}
        pos = pos + 1 -- skip '['
        while pos <= #str do
            skip_whitespace()
            local c = str:sub(pos, pos)
            if c == ']' then
                pos = pos + 1
                return arr
            end
            if c == ',' then
                pos = pos + 1
                skip_whitespace()
            end
            table.insert(arr, parse_value())
        end
        return arr
    end
    
    local function parse_string()
        pos = pos + 1 -- skip quote
        local start = pos
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == '"' and str:sub(pos - 1, pos - 1) ~= '\\' then
                break
            end
            pos = pos + 1
        end
        local val = str:sub(start, pos - 1)
        pos = pos + 1 -- skip quote
        return val
    end
    
    local function parse_number()
        local start = pos
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c:match("[%d%.%-eE%+]") then
                pos = pos + 1
            else
                break
            end
        end
        return tonumber(str:sub(start, pos - 1))
    end
    
    parse_value = function()
        skip_whitespace()
        local c = str:sub(pos, pos)
        if c == '{' then
            return parse_object()
        elseif c == '[' then
            return parse_array()
        elseif c == '"' then
            return parse_string()
        elseif c == 't' and str:sub(pos, pos + 3) == 'true' then
            pos = pos + 4
            return true
        elseif c == 'f' and str:sub(pos, pos + 4) == 'false' then
            pos = pos + 5
            return false
        elseif c == 'n' and str:sub(pos, pos + 3) == 'null' then
            pos = pos + 4
            return nil
        elseif c:match("[%d%.%-]") then
            return parse_number()
        else
            error("Unexpected character '" .. c .. "' at position " .. pos)
        end
    end
    
    local status, val = pcall(parse_value)
    if status then
        return val
    else
        return nil
    end
end

return M
