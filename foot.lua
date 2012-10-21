require("tags")
require("barrier")
require("highway")
require("transport")
--
-- Global variables required by extractor
--
ignore_areas 			= true -- future feature
traffic_signal_penalty 	= 2
u_turn_penalty 			= 2
use_restrictions        = false

--
-- Globals for profile definition
--

local access_list = { "foot", "access" }


---------------------------------------------------------------------------
--
-- NODE FUNCTION
--
-- Node-> in: lat,lon,id,tags
--       out: bollard,traffic_light

-- default is forbidden, so add allowed ones only
local barrier_access = {
    ["kerb"] = true,
    ["block"] = true,
    ["bollard"] = true,
    ["border_control"] = true,
    ["cattle_grid"] = true,
    ["entrance"] = true,
    ["sally_port"] = true,
    ["toll_both"] = true,
    ["cycle_barrier"] = true,
    ["stile"] = true,
    ["block"] = true,
    ["kissing_gate"] = true,
    ["turnstile"] = true,
    ["hampshire_gate"] = true
}

function node_function (node)
    barrier.set_bollard(node, access_list, barrier_access)

	-- flag delays	
	if node.bollard or node.tags:Find("highway") == "traffic_signals" then
		node.traffic_light = true
	end

	return 1
end


---------------------------------------------------------------------------
--
-- WAY FUNCTION
--
-- Way-> in: tags
--       out: String name,
--            double speed,
--            short type,
--            bool access,
--            bool roundabout,
--            bool is_duration_set,
--            bool is_access_restricted,
--            bool ignore_in_grid,
--            direction { notSure, oneway, bidirectional, opposite }
	
--
-- Begin of globals

local default_speed = 10
local designated_speed = 12
local speed_highway = {
    ["footway"] = 12,
	["cycleway"] = 10,
	["primary"] = 7,
	["primary_link"] = 7,
	["secondary"] = 8,
	["secondary_link"] = 8,
	["tertiary"] = 9,
	["tertiary_link"] = 9,
	["residential"] = 10,
	["unclassified"] = 10,
	["living_street"] = 11,
	["road"] = 10,
	["service"] = 10,
	["path"] = 12,
	["pedestrian"] = 12,
	["steps"] = 11,
}

local speed_track = { 11, 11, 11, 11, 11 }

local speed_path = {
    sac_scale = { mountain_hiking = 0.9,
                  demanding_mountain_hiking = 0.5,
                  alpine_hiking = 0,
                  demanding_alpine_hiking = 0
                },
    bicycle = { designated = 0.5, yes = 0.9 }
}

local surface_penalties = { 
    ["gravel"] = 0.9,
    ["sand"] = 0.7
}

local name_list = { "ref", "name" }

function way_function (way, numberOfNodesInWay)
	-- A way must have two nodes or more
	if(numberOfNodesInWay < 2) then
		return 0;
	end

    -- Check if we are allowed to access the way
    if tags.get_access_grade(way.tags, access_list) < -1 then
		return 0
    end

    -- ferries
    if transport.is_ferry(way, 5, numberOfNodesInWay) then
        return 1
    end

    -- is it a valid highway?
    if not highway.set_base_speed(way, speed_highway, speed_track) then
        -- check for designated access
        if tags.as_access_grade(way.tags:Find('foot')) > 0 then
            way.speed = default_speed
        else
            return 0
        end
    end

    if not highway.adjust_speed_for_path(way, speed_path) then
        return 0
    end
    if not highway.adjust_speed_by_surface(way, surface_penalties, 1.0) then
        return 0
    end

    -- if there is a sidewalk, the better
    local sidewalk = way.tags:Find('sidewalk')
    if sidewalk == 'both' or sidewalk == 'left' or sidewalk == 'right' then
        way.speed = math.max(designated_speed, way.speed*1.2)
    end

    if junction == "roundabout" then
        way.roundabout = true
    end
  
    way.name = tags.get_name(way.tags, name_list)
	way.type = 1
	return 1
end
