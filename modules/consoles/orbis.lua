--
-- Add Orbis support to Visual Studio backend.
-- Copyright (c) 2015-2017 Blizzard Entertainment
--

--
-- Non-overrides
--

local p = premake
local vstudio = p.vstudio

p.ORBIS       = "orbis"

if vstudio.vs2010_architectures ~= nil then
	vstudio.vs2010_architectures.orbis   = "ORBIS"
	p.api.addAllowed("system", p.ORBIS)
end

filter { "system:Orbis" }
	toolset "clang"

filter { "system:Orbis", "kind:ConsoleApp or WindowedApp" }
	targetextension ".elf"

--
-- Methods.
--

local function generateDebugInformation(cfg)
	if cfg.symbols ~= nil then
		local map = {
			["On"]       = "true",
			["Off"]      = "false",
			["FastLink"] = "true",
			["Full"]     = "true",
		}
		if map[cfg.symbols] ~= nil then
			vstudio.vc2010.element("GenerateDebugInformation", nil, map[cfg.symbols])
		end
	end
end

local function fastMath(cfg)
	vstudio.vc2010.element("FastMath", nil, tostring(p.config.isOptimizedBuild(cfg)))
end

--
-- Overrides
--

p.override(vstudio.vc2010, "platformToolset", function (base, cfg)
	if cfg.system ~= p.ORBIS then
		return base(cfg)
	end
	vstudio.vc2010.element("PlatformToolset", nil, "Clang")
end)

p.override(vstudio.vc2010, "wholeProgramOptimization", function (base, cfg)
	if cfg.system ~= p.ORBIS then
		return base(cfg)
	end

	if cfg.flags.LinkTimeOptimization then
		-- Note: On the PS4, this is specified in the global flags
		vstudio.vc2010.element("LinkTimeOptimization", nil, "true")
	end
end)

p.override(vstudio.vc2010, "optimization", function (base, cfg, condition)
	if cfg.system ~= p.ORBIS then
		return base(cfg, condition)
	end

	local map = { Off="Level0", On="Level1", Debug="Level0", Full="Level2", Size="Levels", Speed="Level3" }
	local value = map[cfg.optimize]
	if levelValue or not condition then
		vstudio.vc2010.element('OptimizationLevel', condition, value or "Level0")
	end
	if cfg.flags.LinkTimeOptimization then
		-- PS4 link time optimization is specified in the CLCompile flags
		vstudio.vc2010.element("LinkTimeOptimization", nil, "true")
	end
end)


p.override(vstudio.vc2010, "treatWarningAsError", function (base, cfg)
	if cfg.system ~= p.ORBIS then
		return base(cfg)
	end

	-- PS4 uses a different tag for treating warnings as errors
	if cfg.flags.FatalLinkWarnings and cfg.warnings ~= "Off" then
		vstudio.vc2010.element("WarningsAsErrors", nil, "true")
	end
end)

p.override(vstudio.vc2010, "debuggerFlavor", function (base, cfg)
	if cfg.system ~= p.ORBIS then
		return base(cfg)
	end
	-- PS4 does not set this at all.
end)


p.override(vstudio.vc2010.elements, "clCompile", function(base, cfg)
	local calls = base(cfg)
	-- PS4 has GenerateDebugInformation and FastMath
	if cfg.system == p.ORBIS then
		table.insert(calls, generateDebugInformation)
		table.insert(calls, fastMath)
	end
	return calls
end)

p.override(vstudio.vc2010.elements, "link", function(base, cfg, explicit)
	local calls = base(cfg, explicit)
	-- PS4 has GenerateDebugInformation during linking too
	if cfg.system == p.ORBIS then
		table.insert(calls, generateDebugInformation)
	end
	return calls
end)

