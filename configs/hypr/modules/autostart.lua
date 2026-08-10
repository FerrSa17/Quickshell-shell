-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 20")
	hl.exec_cmd("hyprpm reload")
	-- Quickshell bar + lock screen (no hyprlock).
	hl.exec_cmd("qs -d -n")
	-- Lock after the shell finishes loading.
	hl.exec_cmd("bash -lc 'for i in $(seq 1 30); do qs ipc show 2>/dev/null | grep -q \"target lock\" && break; sleep 0.3; done; qs ipc call lock lock'")
end)
