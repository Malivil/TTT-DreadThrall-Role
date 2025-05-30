local ROLE = {}

ROLE.nameraw = "dreadthrall"
ROLE.name = "Dread Thrall"
ROLE.nameplural = "Dread Thralls"
ROLE.nameext = "a Dread Thrall"
ROLE.nameshort = "thr"

ROLE.desc = [[You are {role}! {comrades}

Use your bone charm abilities to aid your team
in defeating your enemies.]]
ROLE.shortdesc = "Uses special abilities via their Bone Charm to distract and defeat their enemies."

ROLE.team = ROLE_TEAM_TRAITOR

ROLE.loadout = {"weapon_thr_bonecharm"}
ROLE.startingcredits = 2

ROLE.translations = {
    ["english"] = {
        ["dreadthrall_powers_title"] = "Choose an Ability",
        ["dreadthrall_powers_subtitle"] = "   All abilities cost\n{credits} credit(s) per use",
        ["dreadthrall_powers_subtitle_free"] = "All abilities are\n    free to use",
        ["dreadthrall_powers_credits"] = "{credits} credits available",
        ["dreadthrall_powers_close"] = "Close",
        ["dreadthrall_powers_spiritwalk"] = "Spirit Walk",
        ["dreadthrall_powers_spiritwalk_tooltip"] = "Become invisible and move quickly to escape",
        ["dreadthrall_powers_blizzard"] = "Summon Blizzard",
        ["dreadthrall_powers_blizzard_tooltip"] = "Summon a blizzard-like fog to reduce visibility",
        ["dreadthrall_powers_cannibal"] = "Cannibal Attack",
        ["dreadthrall_powers_cannibal_tooltip"] = "Summon aggressive cannibals near a random living enemy",
        ["bonecharm_help_pri"] = "Use {primaryfire} or {secondaryfire} to damage your enemies",
        ["bonecharm_help_sec"] = "Press {reload} to select and use a special action"
    }
}

ROLE.convars = {
    {
        cvar = "ttt_dreadthrall_ability_cost",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 0
    },
    {
        cvar = "ttt_dreadthrall_spiritwalk_cooldown",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 0
    },
    {
        cvar = "ttt_dreadthrall_spiritwalk_duration",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 0
    },
    {
        cvar = "ttt_dreadthrall_spiritwalk_speedboost",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 2
    },
    {
        cvar = "ttt_dreadthrall_blizzard_cooldown",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 0
    },
    {
        cvar = "ttt_dreadthrall_blizzard_duration",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 0
    },
    {
        cvar = "ttt_dreadthrall_blizzard_start",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 0
    },
    {
        cvar = "ttt_dreadthrall_cannibal_cooldown",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 0
    },
    {
        cvar = "ttt_dreadthrall_cannibal_count",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 0
    },
    {
        cvar = "ttt_dreadthrall_cannibal_damage",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 0
    },
    {
        cvar = "ttt_dreadthrall_cannibal_toughness",
        type = ROLE_CONVAR_TYPE_NUM,
        decimal = 2
    },
    {
        cvar = "ttt_dreadthrall_is_monster",
        type = ROLE_CONVAR_TYPE_BOOL
    }
}

RegisterRole(ROLE)

local dreadthrall_is_monster = CreateConVar("ttt_dreadthrall_is_monster", "0", FCVAR_REPLICATED)

if SERVER then
    AddCSLuaFile()

    hook.Add("TTTPlayerRoleChanged", "DreadThrall_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
        if newRole == ROLE_DREADTHRALL and IsPlayer(ply) and ply:Alive() and not ply:IsSpec() and not ply:HasWeapon("weapon_thr_bonecharm") then
            ply:Give("weapon_thr_bonecharm")
        end
    end)
end

if CLIENT then
    local keyMappingStyles = "font-size: 12px; color: black; display: inline-block; padding: 0px 3px; height: 16px; border-width: 4px; border-style: solid; border-left-color: rgb(221, 221, 221); border-bottom-color: rgb(119, 119, 102); border-right-color: rgb(119, 119, 119); border-top-color: rgb(255, 255, 255); background-color: rgb(204, 204, 187);"
    hook.Add("TTTTutorialRoleText", "DreadThrall_TutorialRoleText", function(role, titleLabel, roleIcon)
        if role == ROLE_DREADTHRALL then
            -- Use this for highlighting things like "kill"
            local traitorColor = ROLE_COLORS[ROLE_TRAITOR]
            local roleTeam = player.GetRoleTeam(ROLE_DREADTHRALL, true)
            local roleTeamString, roleColor = GetRoleTeamInfo(roleTeam, true)
            local html = "The " .. ROLE_STRINGS[ROLE_DREADTHRALL] .. " is a member of the <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>" .. string.lower(roleTeamString) .. " team</span> who can use their bone charm weapon to aid their team in defeating their enemies."

            html = html .. "<span style='display: block; margin-top: 10px;'>To use a <span style='color: rgb(" .. traitorColor.r .. ", " .. traitorColor.g .. ", " .. traitorColor.b .. ")'>special ability</span>, equip the bone charm and press the "

            local key = Key("+reload", "R")
            html = html .. "<span style='" .. keyMappingStyles .. "'>" .. key .. "</span> key.</span>"

            return html
        end
    end)
end

hook.Add("TTTUpdateRoleState", "DreadThrall_Team_TTTUpdateRoleState", function()
    local is_monster = dreadthrall_is_monster:GetBool()
    MONSTER_ROLES[ROLE_DREADTHRALL] = is_monster
    TRAITOR_ROLES[ROLE_DREADTHRALL] = not is_monster
end)