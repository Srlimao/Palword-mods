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
    if value_type == "boolean" then return value and "true" or "false" end
    if value_type == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error("JSON cannot encode non-finite numbers")
        end
        return tostring(value)
    end
    if value_type ~= "table" then error("JSON cannot encode " .. value_type) end
    if stack[value] then error("JSON cannot encode cyclic tables") end
    stack[value] = true

    local array, length = is_array(value)
    local pieces = {}
    local child_indent = string.rep(indent, depth + 1)
    local current_indent = string.rep(indent, depth)
    if array then
        for index = 1, length do
            pieces[#pieces + 1] = child_indent .. encode_value(value[index], stack, indent, depth + 1)
        end
        stack[value] = nil
        if #pieces == 0 then return "[]" end
        return "[\n" .. table.concat(pieces, ",\n") .. "\n" .. current_indent .. "]"
    end

    local keys = {}
    for key in pairs(value) do
        if type(key) ~= "string" then error("JSON object keys must be strings") end
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        pieces[#pieces + 1] = child_indent .. encode_string(key) .. ": "
            .. encode_value(value[key], stack, indent, depth + 1)
    end
    stack[value] = nil
    if #pieces == 0 then return "{}" end
    return "{\n" .. table.concat(pieces, ",\n") .. "\n" .. current_indent .. "}"
end

function M.Encode(value)
    local ok, encoded = pcall(encode_value, value, {}, "  ", 0)
    if not ok then return nil, encoded end
    return encoded .. "\n", nil
end

local function utf8_character(codepoint)
    if codepoint <= 0x7F then return string.char(codepoint) end
    if codepoint <= 0x7FF then
        return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + codepoint % 0x40)
    end
    if codepoint <= 0xFFFF then
        return string.char(0xE0 + math.floor(codepoint / 0x1000),
            0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
    end
    return string.char(0xF0 + math.floor(codepoint / 0x40000),
        0x80 + math.floor(codepoint / 0x1000) % 0x40,
        0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
end

local function decode(text)
    local position, length = 1, #text
    local function skip_space()
        local _, finish = text:find("^[ \t\r\n]*", position)
        position = (finish or position - 1) + 1
    end
    local parse_value
    local function parse_string()
        if text:sub(position, position) ~= '"' then error("expected string") end
        position = position + 1
        local pieces = {}
        while position <= length do
            local character = text:sub(position, position)
            if character == '"' then position = position + 1; return table.concat(pieces) end
            if character == "\\" then
                local escaped = text:sub(position + 1, position + 1)
                local simple = { ['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f', n='\n', r='\r', t='\t' }
                if simple[escaped] then pieces[#pieces + 1] = simple[escaped]; position = position + 2
                elseif escaped == "u" then
                    local hex = text:sub(position + 2, position + 5)
                    if not hex:match("^%x%x%x%x$") then error("invalid unicode escape") end
                    local codepoint = tonumber(hex, 16)
                    position = position + 6
                    if codepoint >= 0xD800 and codepoint <= 0xDBFF
                        and text:sub(position, position + 1) == "\\u" then
                        local low_hex = text:sub(position + 2, position + 5)
                        local low = low_hex:match("^%x%x%x%x$") and tonumber(low_hex, 16) or nil
                        if low and low >= 0xDC00 and low <= 0xDFFF then
                            codepoint = 0x10000 + (codepoint - 0xD800) * 0x400 + (low - 0xDC00)
                            position = position + 6
                        else error("invalid unicode surrogate pair") end
                    elseif codepoint >= 0xD800 and codepoint <= 0xDFFF then
                        error("unpaired unicode surrogate")
                    end
                    pieces[#pieces + 1] = utf8_character(codepoint)
                else error("invalid string escape") end
            else
                if string.byte(character) < 32 then error("control character in string") end
                pieces[#pieces + 1] = character
                position = position + 1
            end
        end
        error("unterminated string")
    end
    local function parse_array()
        position = position + 1
        local result = {}
        skip_space()
        if text:sub(position, position) == "]" then position = position + 1; return result end
        while true do
            result[#result + 1] = parse_value()
            skip_space()
            local separator = text:sub(position, position)
            if separator == "]" then position = position + 1; return result end
            if separator ~= "," then error("expected ',' or ']'") end
            position = position + 1
        end
    end
    local function parse_object()
        position = position + 1
        local result = {}
        skip_space()
        if text:sub(position, position) == "}" then position = position + 1; return result end
        while true do
            skip_space()
            local key = parse_string()
            skip_space()
            if text:sub(position, position) ~= ":" then error("expected ':'") end
            position = position + 1
            result[key] = parse_value()
            skip_space()
            local separator = text:sub(position, position)
            if separator == "}" then position = position + 1; return result end
            if separator ~= "," then error("expected ',' or '}'") end
            position = position + 1
        end
    end
    function parse_value()
        skip_space()
        local character = text:sub(position, position)
        if character == '"' then return parse_string() end
        if character == "{" then return parse_object() end
        if character == "[" then return parse_array() end
        local literal = text:sub(position)
        if literal:sub(1, 4) == "true" then position = position + 4; return true end
        if literal:sub(1, 5) == "false" then position = position + 5; return false end
        if literal:sub(1, 4) == "null" then position = position + 4; return M.null end
        local number = literal:match("^-?%d+%.?%d*[eE]?[+-]?%d*")
        if number and number ~= "" then
            local converted = tonumber(number)
            if converted ~= nil then position = position + #number; return converted end
        end
        error("unexpected JSON value at byte " .. tostring(position))
    end
    local result = parse_value()
    skip_space()
    if position <= length then error("trailing JSON content") end
    return result
end

function M.Decode(text)
    if type(text) ~= "string" then return nil, "JSON input must be a string" end
    local ok, value = pcall(decode, text)
    if not ok then return nil, value end
    return value, nil
end

return M
