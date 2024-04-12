local wezterm = require("wezterm")
local act = wezterm.action
local mux = wezterm.mux

local function isViProcess(pane)
	return pane:get_user_vars().PROG == "nvim"
end

local function conditionalActivatePane(window, pane, pane_direction, vim_direction, enable)
	if enable and isViProcess(pane) then
		window:perform_action(
			-- This should match the keybinds you set in Neovim.
			act.SendKey({ key = vim_direction, mods = "CTRL" }),
			pane
		)
	else
		window:perform_action(act.ActivatePaneDirection(pane_direction), pane)
	end
end

wezterm.on("gui-startup", function(cmd)
	local _, _, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

wezterm.on("ActivatePaneDirection-right", function(window, pane)
	conditionalActivatePane(window, pane, "Right", "l", true)
end)
wezterm.on("ActivatePaneDirection-left", function(window, pane)
	conditionalActivatePane(window, pane, "Left", "h", true)
end)
wezterm.on("ActivatePaneDirection-up", function(window, pane)
	conditionalActivatePane(window, pane, "Up", "k", true)
end)
wezterm.on("ActivatePaneDirection-down", function(window, pane)
	conditionalActivatePane(window, pane, "Down", "j", true)
end)
wezterm.on("ActivatePaneDirection-right-abs", function(window, pane)
	conditionalActivatePane(window, pane, "Right", "l", false)
end)
wezterm.on("ActivatePaneDirection-left-abs", function(window, pane)
	conditionalActivatePane(window, pane, "Left", "h", false)
end)
wezterm.on("ActivatePaneDirection-up-abs", function(window, pane)
	conditionalActivatePane(window, pane, "Up", "k", false)
end)
wezterm.on("ActivatePaneDirection-down-abs", function(window, pane)
	conditionalActivatePane(window, pane, "Down", "j", false)
end)
wezterm.on("Detach", function(_, pane)
	local domain = mux.get_domain(pane:get_domain_name())
	domain:detach()
end)

local direction_keys = {
	h = "Left",
	j = "Down",
	k = "Up",
	l = "Right",
}

local function split_nav(resize_or_move, key)
	return {
		key = key,
		mods = resize_or_move == "resize" and "CTRL|SHIFT" or "CTRL",
		action = wezterm.action_callback(function(win, pane)
			if isViProcess(pane) then
				-- pass the keys through to vim/nvim
				win:perform_action({
					SendKey = { key = key, mods = resize_or_move == "resize" and "CTRL|SHIFT" or "CTRL" },
				}, pane)
			else
				if resize_or_move == "resize" then
					win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
				else
					win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
				end
			end
		end),
	}
end

local config = wezterm.config_builder()
config.color_scheme = "Catppuccin Mocha"
config.window_background_opacity = 0.75
config.inactive_pane_hsb = {
	saturation = 0.5,
	brightness = 0.5,
}

config.window_decorations = "RESIZE"

config.use_fancy_tab_bar = true

config.font = wezterm.font_with_fallback({
	{ family = "FiraCode Nerd Font Mono", weight = "Bold" },
	{ family = "Hei", weight = "Bold" },
})
config.font_size = 18

config.leader = { key = " ", mods = "CTRL", timeout_milliseconds = 1000 }

config.keys = {
	{ key = "h", mods = "CTRL", action = act.EmitEvent("ActivatePaneDirection-left") },
	{ key = "j", mods = "CTRL", action = act.EmitEvent("ActivatePaneDirection-down") },
	{ key = "k", mods = "CTRL", action = act.EmitEvent("ActivatePaneDirection-up") },
	{ key = "l", mods = "CTRL", action = act.EmitEvent("ActivatePaneDirection-right") },
	{ key = "h", mods = "LEADER|CTRL", action = act.EmitEvent("ActivatePaneDirection-left-abs") },
	{ key = "j", mods = "LEADER|CTRL", action = act.EmitEvent("ActivatePaneDirection-down-abs") },
	{ key = "k", mods = "LEADER|CTRL", action = act.EmitEvent("ActivatePaneDirection-up-abs") },
	{ key = "l", mods = "LEADER|CTRL", action = act.EmitEvent("ActivatePaneDirection-right-abs") },
	{ key = "l", mods = "LEADER", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "j", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "c", mods = "LEADER", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
	{ key = "n", mods = "LEADER", action = wezterm.action.ActivateTabRelative(1) },
	{ key = "N", mods = "LEADER", action = wezterm.action.ActivateTabRelative(-1) },
	{ key = "t", mods = "CTRL|CMD", action = wezterm.action.SpawnTab("DefaultDomain") },
	{ key = "d", mods = "LEADER", action = act.EmitEvent("Detach") },
	-- move between split panes
	split_nav("move", "h"),
	split_nav("move", "j"),
	split_nav("move", "k"),
	split_nav("move", "l"),
	-- resize panes
	split_nav("resize", "h"),
	split_nav("resize", "j"),
	split_nav("resize", "k"),
	split_nav("resize", "l"),
	{
		key = "l",
		mods = "CMD",
		action = wezterm.action_callback(function(window, pane)
			local pos = pane:get_cursor_position()
			local dims = pane:get_dimensions()
			local move_viewport_to_scrollback = string.rep("\r\n", pos.y - dims.physical_top)
			pane:inject_output(move_viewport_to_scrollback)
			pane:send_text("\x0c") -- CTRL-L
		end),
	},
}

return config
