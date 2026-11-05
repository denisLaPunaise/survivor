--!strict
--[[
	La manette decide (Josh, 5 novembre 2026). Deux reglages qui doivent
	s'accorder se testent ensemble : dans un contexte, un bouton ou une touche
	ne porte qu'UNE action, et seuls les boutons qu'un jeu peut prendre servent.
]]

local Config = require("../../src/shared/Config")

local harness = require("../harness")

return function(t: harness.Harness)
	local allowed: { [string]: boolean } = {}
	for _, button in Config.controls.gamepadButtons do
		allowed[button] = true
	end

	t.section("Les boutons reserves a Roblox restent libres")

	t.equal("ButtonStart n'est pas pris (menu Roblox)", allowed["ButtonStart"], nil)
	t.equal("ButtonSelect n'est pas pris (navigation)", allowed["ButtonSelect"], nil)

	t.section("Aucune collision dans un contexte")

	local contextCount = 0
	for contextName, actions in Config.controls.contexts do
		contextCount += 1
		local byButton: { [string]: string } = {}
		local byKey: { [string]: string } = {}
		for actionName, binding in actions do
			t.check(
				string.format(
					"%s.%s utilise un bouton libre (%s)",
					contextName,
					actionName,
					binding.gamepad
				),
				allowed[binding.gamepad] == true
			)

			local buttonOwner = byButton[binding.gamepad]
			t.check(
				string.format(
					"%s : %s n'est pas deja pris (%s / %s)",
					contextName,
					binding.gamepad,
					actionName,
					tostring(buttonOwner)
				),
				buttonOwner == nil
			)
			byButton[binding.gamepad] = actionName

			local keyOwner = byKey[binding.keyboard]
			t.check(
				string.format(
					"%s : la touche %s n'est pas deja prise (%s / %s)",
					contextName,
					binding.keyboard,
					actionName,
					tostring(keyOwner)
				),
				keyOwner == nil
			)
			byKey[binding.keyboard] = actionName
		end
	end

	t.check("au moins un contexte est declare", contextCount > 0)
end
