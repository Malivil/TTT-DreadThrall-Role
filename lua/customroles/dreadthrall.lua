local ROLE = {}

ROLE.nameraw = "dreadthrall"
ROLE.name = "Dread Thrall"
ROLE.nameplural = "Dread Thralls"
ROLE.nameext = "a Dread Thrall"
ROLE.nameshort = "thr"

ROLE.desc = [[You are {role}! {comrades}

Use your bone charm to aid your team
in defeating your enemies.

Press {menukey} to receive your special equipment!]]

ROLE.team = ROLE_TEAM_TRAITOR

ROLE.loadout = {"weapon_thr_bonecharm"}
ROLE.startingcredits = 2

ROLE.translations = {
    ["english"] = {
        ["dreadthrall_powers_title"] = "Choose an Ability",
        ["dreadthrall_powers_subtitle"] = "All abilities cost\n1 credit per use",
        ["dreadthrall_powers_credits"] = "{credits} credits available",
        ["dreadthrall_powers_close"] = "Close",
        ["dreadthrall_powers_spiritwalk"] = "Spirit Walk",
        ["dreadthrall_powers_spiritwalk_tooltip"] = "Become invisible and move quickly to escape",
        ["dreadthrall_powers_blizzard"] = "Summon Blizzard",
        ["dreadthrall_powers_blizzard_tooltip"] = "Summon a blizzard-like fog to reduce visibility",
        ["dreadthrall_powers_cannibal"] = "Cannibal Attack",
        ["dreadthrall_powers_cannibal_tooltip"] = "Summon cannibals to randomly attack one of your living enemies",
        ["bonecharm_help_pri"] = "Use {primaryfire} or {secondaryfire} to damage your enemies",
        ["bonecharm_help_sec"] = "Press {reload} to select and use a special action"
    }
}

ROLE.convars = {}
table.insert(ROLE.convars, {
    cvar = "ttt_dreadthrall_spiritwalk_cooldown",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
table.insert(ROLE.convars, {
    cvar = "ttt_dreadthrall_spiritwalk_duration",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
table.insert(ROLE.convars, {
    cvar = "ttt_dreadthrall_spiritwalk_speedboost",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})
table.insert(ROLE.convars, {
    cvar = "ttt_dreadthrall_blizzard_cooldown",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
table.insert(ROLE.convars, {
    cvar = "ttt_dreadthrall_blizzard_duration",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
table.insert(ROLE.convars, {
    cvar = "ttt_dreadthrall_blizzard_start",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
table.insert(ROLE.convars, {
    cvar = "ttt_dreadthrall_cannibal_cooldown",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
table.insert(ROLE.convars, {
    cvar = "ttt_dreadthrall_cannibal_count",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})

RegisterRole(ROLE)

if SERVER then
    AddCSLuaFile()
end

if CLIENT then
    hook.Add("TTTTutorialRoleText", "DreadThrall_TutorialRoleText", function(role, titleLabel, roleIcon)
        if role == ROLE_DREADTHRALL then
            local roleColor = ROLE_COLORS[ROLE_TRAITOR]
            return "The " .. ROLE_STRINGS[ROLE_DREADTHRALL] .. " is a member of the <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>traitor team</span> who can use their bone charm weapon to aid their team in defeating their enemies."
        end
    end)
end