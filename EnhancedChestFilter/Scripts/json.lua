-- Small dependency-free JSON codec for versioned local persistence. It never
-- executes imported content and preserves a distinct JSON null value.
local M = {}
M.null = {}

local escapes = {
    ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
    ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function encode_string(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(character)
        return escapes[character] or string.format('\\u%04X', string.byte(character))
    end) .. '"'
end

local function is_array(value)
    local count, maximum = 0, 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
        count = count + 1
        if key > maximum then maximum = key end
    end
    return count == maximum, maximum
end

local function encode_value(value, stack, indent, depth)
    if value == M.null or value == nil then return "null" end
    local value_type = type(value)
    if value_type == "string" then return encode_string(value) end
    if value_type == "number" or value_type == "boolean" then return tostring(value) end

    if value_type ~= "table" then
        error("Cannot encode JSON type: " .. value_type)
    end

    if stack[value] then
        error("Circular reference detected while encoding JSON")
    end
    stack[value] = true

    local parts = {}
    local array_mode, max_index = is_array(value)

    if array_mode then
        for index = 1, max_index do
            table.insert(parts, encode_value(value[index], stack, indent, depth + 1))
        end
        stack[value] = nil
        return "[" .. table.concat(parts, ",") .. "]"
    else
        for key, item in pairs(value) do
            if type(key) ~= "string" then
                error("JSON table keys must be strings, got: " .. type(key))
            end
            table.insert(parts, encode_string(key) .. ":" .. encode_value(item, stack, indent, depth + 1))
        end
        stack[value] = nil
        return "{" .. table.concat(parts, ",") .. "}"
    end
end

function M.encode(value)
    return encode_value(value, {}, "", 0)
end
M.Encode = M.encode

local function create_parser(str)
    local index = 1
    local length = #str

    local function skip_whitespace()
        while index <= length do
            local char = str:sub(index, index)
            if char == " " or char == "\t" or char == "\n" or char == "\r" then
                index = index + 1
            else
                break
            end
        end
    end

    local parse_value

    local function parse_string()
        index = index + 1 -- Skip opening "
        local start = index
        local result = ""
        while index <= length do
            local char = str:sub(index, index)
            if char == '"' then
                result = result .. str:sub(start, index - 1)
                index = index + 1
                return result
            elseif char == '\\' then
                result = result .. str:sub(start, index - 1)
                local next_char = str:sub(index + 1, index + 1)
                if next_char == '"' or next_char == '\\' or next_char == '/' then
                    result = result .. next_char
                elseif next_char == 'b' then result = result .. '\b'
                elseif next_char == 'f' then result = result .. '\f'
                elseif next_char == 'n' then result = result .. '\n'
                elseif next_char == 'r' then result = result .. '\r'
                elseif next_char == 't' then result = result .. '\t'
                elseif next_char == 'u' then
                    local hex_code = str:sub(index + 2, index + 5)
                    local char_code = tonumber(hex_code, 16)
                    if char_code then result = result .. string.char(char_code) end
                    index = index + 4
                end
                index = index + 2
                start = index
            else
                index = index + 1
            end
        end
        error("Unterminated string in JSON")
    end

    local function parse_number()
        local start = index
        if str:sub(index, index) == '-' then index = index + 1 end
        while index <= length and str:sub(index, index):find("[%d%.eE%+%─]") do
            index = index + 1
        end
        local num_str = str:sub(start, index - 1)
        local num = tonumber(num_str)
        if not num then error("Invalid JSON number: " .. num_str) end
        return num
    end

    local function parse_object()
        index = index + 1 -- Skip {
        skip_whitespace()
        local obj = {}
        if str:sub(index, index) == '}' then
            index = index + 1
            return obj
        end
        while index <= length do
            skip_whitespace()
            if str:sub(index, index) ~= '"' then error("Expected string key in object") end
            local key = parse_string()
            skip_whitespace()
            if str:sub(index, index) ~= ':' then error("Expected ':' after key") end
            index = index + 1 -- Skip :
            local val = parse_value()
            obj[key] = val
            skip_whitespace()
            local char = str:sub(index, index)
            if char == '}' then
                index = index + 1
                return obj
            elseif char == ',' then
                index = index + 1
            else
                error("Expected ',' or '}' in object")
            end
        end
    end

    local function parse_array()
        index = index + 1 -- Skip [
        skip_whitespace()
        local arr = {}
        if str:sub(index, index) == ']' then
            index = index + 1
            return arr
        end
        while index <= length do
            local val = parse_value()
            table.insert(arr, val)
            skip_whitespace()
            local char = str:sub(index, index)
            if char == ']' then
                index = index + 1
                return arr
            elseif char == ',' then
                index = index + 1
            else
                error("Expected ',' or ']' in array")
            end
        end
    end

    parse_value = function()
        skip_whitespace()
        local char = str:sub(index, index)
        if char == '"' then return parse_string()
        elseif char == '{' then return parse_object()
        elseif char == '[' then return parse_array()
        elseif char == 't' and str:sub(index, index + 3) == "true" then index = index + 4; return true
        elseif char == 'f' and str:sub(index, index + 4) == "false" then index = index + 5; return false
        elseif char == 'n' and str:sub(index, index + 3) == "null" then index = index + 4; return M.null
        elseif char:find("[%d%-]") then return parse_number()
        else error("Unexpected character in JSON: " .. char) end
    end

    return parse_value()
end

function M.decode(str)
    if type(str) ~= "string" or #str == 0 then return {} end
    local ok, res = pcall(create_parser, str)
    if ok then return res end
    return {}
end
M.Decode = M.decode

return M
