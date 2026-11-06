--!strict
--[[
	Quest — l'avancement de la quete principale, jour apres jour.

	Logique pure : l'histoire et les jours arrivent en argument.

	Une etape est d'abord FERMEE ; elle s'ouvre a l'aube, pas avant son jour
	(`opensOnDay`). OUVERTE, l'evenement attendu la REUSSIT. Mara ne parle que
	la nuit : la nuit suivant une reussite, elle raconte, et l'etape suivante
	redevient fermee jusqu'a l'aube. Ainsi on ne peut pas enchainer deux
	etapes le meme jour, et l'histoire ne va pas plus vite que ses jours.
]]

local Quest = {}

export type Status = "locked" | "open" | "solved" | "finished"

export type State = {
	index: number,
	status: Status,
}

export type Step = {
	id: string,
	event: string,
	objective: string,
	report: { string },
}

function Quest.new(): State
	return { index = 1, status = "locked" }
end

-- A l'aube du jour `day` : ouvre l'etape en cours si son jour est venu.
-- Rend vrai si elle vient de s'ouvrir.
function Quest.dawn(
	steps: { Step },
	opensOnDay: { [string]: number },
	state: State,
	day: number
): boolean
	if state.status ~= "locked" then
		return false
	end
	local step = steps[state.index]
	if step == nil then
		state.status = "finished"
		return false
	end
	if day < opensOnDay[step.id] then
		return false
	end
	state.status = "open"
	return true
end

-- Un evenement du jeu : il reussit l'etape ouverte qui l'attend.
function Quest.complete(steps: { Step }, state: State, event: string): boolean
	local step = steps[state.index]
	if state.status ~= "open" or step == nil or step.event ~= event then
		return false
	end
	state.status = "solved"
	return true
end

-- La nuit : Mara raconte l'etape reussie, et l'on passe a la suivante.
-- Rend ce qu'elle dit (rien si rien n'a ete reussi).
function Quest.night(steps: { Step }, state: State): { string }
	if state.status ~= "solved" then
		return {}
	end
	local lines = steps[state.index].report
	state.index += 1
	state.status = if steps[state.index] then "locked" else "finished"
	return lines
end

-- L'etape ouverte, celle que l'on doit faire maintenant (nil sinon).
function Quest.current(steps: { Step }, state: State): Step?
	if state.status == "open" then
		return steps[state.index]
	end
	return nil
end

return Quest
