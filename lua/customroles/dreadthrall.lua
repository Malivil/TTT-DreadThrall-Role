local ROLE = {}

ROLE.nameraw = "dreadthrall"
ROLE.name = "Dread Thrall"
ROLE.nameplural = "Dread Thralls"
ROLE.nameext = "a Dread Thrall"
ROLE.nameshort = "thr"

ROLE.desc = [[]]

ROLE.team = ROLE_TEAM_TRAITOR

ROLE.shop = nil
ROLE.loadout = {"weapon_thr_bonecharm"}

ROLE.translations = {}

ROLE.convars = {}

RegisterRole(ROLE)

if SERVER then
    AddCSLuaFile()
end