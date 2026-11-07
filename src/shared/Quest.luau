--!strict
--[[
	Quest — l'avancement de la quete principale, jour apres jour.

	Logique pure : l'histoire et les jours arrivent en argument.

	Une etape est d'abord FERMEE ; elle s'ouvre a l'aube, pas avant son jour
	(`opensOnDay`). OUVERTE, l'evenement attendu la REUSSIT. Mara ne parle que
	la nuit : la nuit suivant une reussite, elle raconte, et l'etape suivante
	redevient fermee jusqu'a l'aube. Ainsi on ne peut pas enchainer deux
	etapes le meme jour, et l'histoire ne va pas plus vite que ses jours.

	Une etape peut avoir un BRIEFING : ce que Mara dit la nuit d'avant son
	ouverture (le survivant : ou il se cache), une seule fois.
]]

local Quest = {}

export type Status = "locked" | "open" | "solved" | "finished"

export type State = {
	index: number,
	status: Status,
	-- Le briefing de l'etape en cours a-t-il deja ete dit ?
	briefed: boolean,
}

export type Step = {
	id: string,
	event: string,
	objective: string,
	report: { string },
	briefing: { string }?,
	again: { string }?,
}

function Quest.new(): State
	return { index = 1, status = "locked", briefed = false }
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
	state.briefed = false
	state.status = if steps[state.index] then "locked" else "finished"
	return lines
end

-- La nuit du jour `day` : si l'etape suivante s'ouvre demain (ou deja), Mara
-- dit son briefing, une fois. A appeler apres `night` : une etape reussie en
-- retard se raconte et annonce la suivante la meme nuit.
function Quest.briefing(
	steps: { Step },
	opensOnDay: { [string]: number },
	state: State,
	day: number
): { string }
	local step = steps[state.index]
	if step == nil or step.briefing == nil or state.briefed or state.status == "finished" then
		return {}
	end
	if state.status == "locked" and day + 1 < opensOnDay[step.id] then
		return {}
	end
	state.briefed = true
	return step.briefing :: { string }
end

-- Remplit les trous `{cle}` d'un texte : ce qui change d'une partie a
-- l'autre (ou se cache le survivant).
function Quest.fill(lines: { string }, values: { [string]: string }): { string }
	local out: { string } = {}
	for _, line in lines do
		local filled = string.gsub(line, "{(%w+)}", function(key: string): string?
			return values[key]
		end)
		table.insert(out, filled)
	end
	return out
end

-- L'etape `id` est-elle atteinte : ouverte, reussie, ou deja derriere ? (Ce
-- qu'elle a apporte reste : Elie fabrique des fumigenes apres l'etape 4.)
function Quest.reached(steps: { Step }, state: State, id: string): boolean
	for index, step in steps do
		if step.id == id then
			return state.index > index or (state.index == index and state.status ~= "locked")
		end
	end
	return false
end

-- L'etape ouverte, celle que l'on doit faire maintenant (nil sinon).
function Quest.current(steps: { Step }, state: State): Step?
	if state.status == "open" then
		return steps[state.index]
	end
	return nil
end

return Quest
