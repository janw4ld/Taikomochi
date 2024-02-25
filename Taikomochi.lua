--- STEAMODDED HEADER
--- MOD_NAME: Taikomochi
--- MOD_ID: Taikomochi
--- MOD_AUTHOR: [Amvoled]
--- MOD_DESCRIPTION: New zen game mode, loosing is not the end of the run, just restart the ante

function SMODS.INIT.Taikomochi()
	-- Mod init
end

-------------------
-- UI Injections --
-------------------

-- Inject zen mode checkbox in new run dialog
local _old_run_setup_options = G.UIDEF.run_setup_option
function G.UIDEF.run_setup_option(type)
	t = _old_run_setup_options(type)
	if type == 'New Run' then  -- If we're starting a new game, add a "Zen Mode" checkbox
		local lastrow = #t.nodes
		local lastcol = #t.nodes[lastrow].nodes
		local lasttoggle = #t.nodes[lastrow].nodes[lastcol].nodes  -- Just in case another mod has also added something here
		local toggle = create_toggle{col = true, 
									 label = "Zen Mode", 
									 label_scale = 0.25, 
									 w = 0, 
									 scale = 0.7, 
									 ref_table = G, 
									 ref_value = 'run_zen_mode'}
		t.nodes[lastrow].nodes[lastcol].nodes[lasttoggle+1] = toggle
	elseif type == 'Continue' and saved_game.GAME.zen then  -- If we're loading a game, we add a line in the game infos box
		-- Copy pasted from the ui_definitions
		local lwidth, rwidth = 1.4, 1.8
		local scale = 0.39
		-- Number of stats already displayed, we add ourselves at the end
		local laststat = #t.nodes[1].nodes[1].nodes[1].nodes[2].nodes[2].nodes
		local zenstat = {n=G.UIT.R, 
						 config={align = "cm"}, 
						 nodes={{n=G.UIT.C, 
								 config={align = "cm", minw = lwidth, maxw = lwidth}, 
								 nodes={{n=G.UIT.T, config={text = "Zen Mode", colour = G.C.UI.TEXT_DARK, scale = scale*0.8}}}},
								{n=G.UIT.C, 
								 config={align = "cm"}, 
								 nodes={{n=G.UIT.T, config={text = ': ',colour = G.C.UI.TEXT_DARK, scale = scale*0.8}}}},
								{n=G.UIT.C, 
								config={align = "cl", minw = rwidth, maxw = lwidth}, 
								nodes={{n=G.UIT.T, config={text = "Yes",colour = G.C.RED, scale = 0.8*scale}}}}}}
		-- Trust me this is where we want to add ourselves
		t.nodes[1].nodes[1].nodes[1].nodes[2].nodes[2].nodes[laststat+1] = zenstat
	end
	return t
end

-- Callback for the start run button, adds the value of the zen mode checkbox to the game args
local _old_start_run_callback = G.FUNCS.start_run
G.FUNCS.start_run = function(e, args)
	if G.SETTINGS.current_setup == 'New Run' then
		local _zen = G.run_zen_mode
		args.zen = _zen
	end
	_old_start_run_callback(e, args)
end

-- Callback for the restart ante button of the game over screen
G.FUNCS.zen_restart_ante = function(e, args)
	G.FUNCS.exit_overlay_menu(e, args)
	G.E_MANAGER:add_event(Event({trigger = 'immediate',
								 blocking = false,
                                 blockable = false,
								 func = (function() G.zen_restart_ante(G); return true end)}))
end
	

-- Change the ante counter to not show a max ante and to be blue
local _old_create_uibox_hud = create_UIBox_HUD
function create_UIBox_HUD()
	if not G.GAME.zen then return _old_create_uibox_hud() end -- If not in zen mode, just ignore this function
	local t = _old_create_uibox_hud()
	local ante_counter = t.nodes[1].nodes[1].nodes[5].nodes[2].nodes[5].nodes[1].nodes[2]
	ante_counter.nodes = {ante_counter.nodes[1]}
	ante_counter.nodes[1].config.object.colours = {G.C.BLUE}
	return t
end

-- Generate the UI for the game over popup
local _old_create_uibox_game_over = create_UIBox_game_over
function create_UIBox_game_over()
	if not G.GAME.zen then return _old_create_uibox_game_over() end  -- If not in zen mode, just ignore this function
	local dyntext = DynaText({string = {"Ante Failed"},  -- Custom text to replace "Game Over"
							  colours = {G.C.BLUE}, 
							  shadow = true, 
							  float = true, 
							  scale = 1.5, 
							  pop_in = 0.4,
							  maxw = 6.5})
	t = _old_create_uibox_game_over()
	-- If you see this dev, this is why you add a tag to nearly every ui object
	local gameover_textbox = t.nodes[1].nodes[2].nodes[1].nodes[1].nodes[1]
	gameover_textbox.nodes[1].nodes[1].config.object:remove()
	gameover_textbox.nodes[1].nodes[1].config.object = dyntext
	-- Remplacing the new game button by restart ante
	gameover_textbox.nodes[2].nodes[1].nodes[2].nodes[1].config.colour = G.C.BLUE
	gameover_textbox.nodes[2].nodes[1].nodes[2].nodes[1].config.button = "zen_restart_ante"
	gameover_textbox.nodes[2].nodes[1].nodes[2].nodes[1].nodes[1].nodes[1].config.text = "Retry Ante"
	return t
end

---------------------------
-- Game Logic Injections --
---------------------------

-- Add a "zen" bool to true when we start a run
local _old_game_start_run = Game.start_run
function Game:start_run(args)
	if not args.zen then _old_game_start_run(self, args) return end  -- If not in zen mode, just ignore this function
	-- We dynamically monkeypatch the initialization function
	local _old_init_game_object = Game.init_game_object -- Reference value for the original game values initialization function
	Game.init_game_object = function ()
		local game = _old_init_game_object(self)
		game.zen = true
		game.win_ante = -8  -- No winning ante in zen mode. -8 Maintains the final boss draw every 8th ante
		return game
	end
	_old_game_start_run(self, args)  -- Call to the vanilla run start function
	Game.init_game_object = _old_init_game_object  -- And then we put back the original init from the reference
end

-- This function is just everything I found in the code to reset an ante. I probably forgot some things, but it seems to work
function Game:zen_restart_ante()
	G.GAME.chips = 0
    if self.GAME_OVER_UI then self.GAME_OVER_UI:remove(); self.GAME_OVER_UI = nil end
	G.GAME.blind:defeat(true)  -- We have to "defeat" the blind to clear the top of the siedebar
	G.GAME.round_resets.blind_states = {Small = 'Select', Big = 'Upcoming', Boss = 'Upcoming'}
	G.FUNCS.draw_from_hand_to_discard()
	G.FUNCS.draw_from_discard_to_deck()
	if G.GAME.round_resets.temp_handsize then G.hand:change_size(-G.GAME.round_resets.temp_handsize); G.GAME.round_resets.temp_handsize = nil end
    if G.GAME.round_resets.temp_reroll_cost then G.GAME.round_resets.temp_reroll_cost = nil; calculate_reroll_cost(true) end
    reset_idol_card()
    reset_mail_rank()
    reset_ancient_card()
    reset_castle_card()
    for k, v in ipairs(G.playing_cards) do
        v.ability.discarded = nil
        v.ability.forced_selection = nil
    end
	G.GAME.current_round.discards_left = math.max(0, G.GAME.round_resets.discards + G.GAME.round_bonus.discards)
    G.GAME.current_round.hands_left = (math.max(1, G.GAME.round_resets.hands + G.GAME.round_bonus.next_hands))
    G.GAME.current_round.hands_played = 0
    G.GAME.current_round.discards_used = 0
    G.GAME.current_round.reroll_cost_increase = 0
    G.GAME.current_round.used_packs = {}
	G.STATE = G.STATES.BLIND_SELECT
	G.E_MANAGER:add_event(Event({
                trigger = 'immediate',
                func = function()
                    G.STATE_COMPLETE = false
                    return true
                end
            }))
end

-- Game Over injection
local _old_game_update_game_over = Game.update_game_over
function Game:update_game_over(dt)
	if not G.GAME.zen then _old_game_update_game_over(dt) return end  -- If not in zen mode, just ignore this function
	local _old_remove_save = remove_save
	remove_save = function () end  -- We dummy the delete save function, so you can leave and resume your zen run later
	_old_game_update_game_over(self, dt)
	remove_save = _old_remove_save  -- Restoring the delete save function
end
