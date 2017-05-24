--
-- option.lua
-- Work with the list of registered options.
-- Copyright (c) 2002-2014 Jason Perkins and the Premake project
--

	local p = premake
	p.option = {}
	local m = p.option


--
-- We can't control how people will type in the command line arguments, or how
-- project scripts will define their custom options, so case becomes an issue.
-- To mimimize issues, set up the _OPTIONS table to always use lowercase keys.
--

	local _OPTIONS_metatable = {
		__index = function(tbl, key)
			if type(key) == "string" then
				key = key:lower()
			end
			return rawget(tbl, key)
		end,
		__newindex = function(tbl, key, value)
			if type(key) == "string" then
				key = key:lower()
			end
			rawset(tbl, key, value)
		end
	}

	_OPTIONS = {}
	setmetatable(_OPTIONS, _OPTIONS_metatable)

	local _OPTIONS_SET = {}
	setmetatable(_OPTIONS_SET, _OPTIONS_metatable)


--
-- Process the raw command line arguments from _ARGV to populate
-- the _OPTIONS table
--

	for i, arg in ipairs(_ARGV) do
		local key, value
		local i = arg:find("=", 1, true)
		if i then
			key = arg:sub(1, i - 1)
			value = arg:sub(i + 1)
		else
			key = arg
			value = ""
		end

		if key:startswith("/") then
			key = key:sub(2)
			_OPTIONS[key] = value
			_OPTIONS_SET[key] = true
		elseif key:startswith("--") then
			key = key:sub(3)
			_OPTIONS[key] = value
			_OPTIONS_SET[key] = true
		end
	end



--
-- The list of registered options. Calls to newoption() will add
-- new entries here.
--

	m.list = {}


--
-- Register a new option.
--
-- @param opt
--    The new option object.
--

	function m.add(opt)
		-- some sanity checking
		local missing
		for _, field in ipairs({ "description", "trigger" }) do
			if (not opt[field]) then
				missing = field
			end
		end

		if (missing) then
			error("option needs a " .. missing, 3)
		end

		-- add it to the master list
		p.option.list[opt.trigger:lower()] = opt

		-- if it was not set from the commandline, set it to the default.
		if not _OPTIONS_SET[opt.trigger] then
			_OPTIONS[opt.trigger] = opt.default
		end
	end



--
-- Retrieve an option by name.
--
-- @param name
--    The name of the option to retrieve.
-- @returns
--    The requested option, or nil if the option does not exist.
--

	function m.get(name)
		return p.option.list[name:lower()]
	end



--
-- Iterator for the list of options.
--

	function m.each()
		-- sort the list by trigger
		local keys = { }
		for _, option in pairs(p.option.list) do
			table.insert(keys, option.trigger)
		end
		table.sort(keys)

		local i = 0
		return function()
			i = i + 1
			return p.option.list[keys[i]]
		end
	end


--
-- Test if an options was set from the command line.
--

	function m.isset(name)
		return _OPTIONS_SET[name]
	end


--
-- Override the default of an option.
--

	function m.setDefault(name, value)
		local opt = m.get(name)
		if (not opt) then
			error("invalid option '" .. name .. "'.")
		end

		-- set default.
		opt.default = value

		-- if it was not set from the commandline, set it to the default.
		if not _OPTIONS_SET[opt.trigger] then
			_OPTIONS[opt.trigger] = opt.default
		end
	end



--
-- Validate a list of user supplied key/value pairs against the list of registered options.
--
-- @param values
--    The list of user supplied key/value pairs.
-- @returns
---   True if the list of pairs are valid, false and an error message otherwise.
--

	function m.validate(values)
		for key, value in pairs(values) do
			-- does this option exist
			local opt = p.option.get(key)
			if (not opt) then
				return false, "invalid option '" .. key .. "'"
			end

			-- does it need a value?
			if (opt.value and value == "") then
				return false, "no value specified for option '" .. key .. "'"
			end

			-- is the value allowed?
			if opt.allowed then
				local found = false
				for _, match in ipairs(opt.allowed) do
					if match[1] == value then
						found = true
						break
					end
				end
				if not found then
					return false, string.format("invalid value '%s' for option '%s'", value, key)
				end
			end
		end
		return true
	end
