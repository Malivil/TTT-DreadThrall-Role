AddCSLuaFile()

local player = player

local GetAllPlayers = player.GetAll
local PlayerIterator = player.Iterator

if SERVER then
    util.AddNetworkString("TTT_DreadThrall_BoneCharmUsed")
    util.AddNetworkString("TTT_DreadThrall_Blizzard_Start")
    util.AddNetworkString("TTT_DreadThrall_Blizzard_End")
    util.AddNetworkString("TTT_DreadThrall_Cannibal_Alert")
end

SWEP.HoldType = "knife"

if CLIENT then
    SWEP.PrintName = "Bone Charm"
    SWEP.Slot = 6

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 54
    SWEP.DrawCrosshair = false

    SWEP.EquipMenuData = {type = "item_weapon", desc = "kil_knife_desc"};

    SWEP.Icon = "vgui/ttt/icon_knife"
    SWEP.IconLetter = "j"
end

SWEP.Base                   = "weapon_tttbase"
SWEP.Category               = WEAPON_CATEGORY_ROLE

SWEP.UseHands               = true
SWEP.ViewModel              = "models/weapons/c_bonecharm.mdl"
SWEP.WorldModel             = "models/weapons/w_bonecharm.mdl"

local animationLengths = {
    [ACT_VM_DRAW] = 1,
    [ACT_VM_FIDGET] = 2,
    [ACT_VM_PRIMARYATTACK] = 1.57,
    [ACT_VM_SECONDARYATTACK] = 1.34,
    [ACT_VM_THROW] = 3,
    [ACT_VM_IDLE] = 6
}

SWEP.Primary.Damage         = 20
SWEP.Primary.ClipSize       = -1
SWEP.Primary.DefaultClip    = -1
SWEP.Primary.Automatic      = true
SWEP.Primary.Delay          = animationLengths[ACT_VM_PRIMARYATTACK]
SWEP.Primary.Ammo           = "none"

SWEP.Secondary.Damage       = 15
SWEP.Secondary.ClipSize     = -1
SWEP.Secondary.DefaultClip  = -1
SWEP.Secondary.Automatic    = false
SWEP.Secondary.Ammo         = "none"
SWEP.Secondary.Delay        = animationLengths[ACT_VM_SECONDARYATTACK]

SWEP.Tertiary               = {}
SWEP.Tertiary.Delay         = animationLengths[ACT_VM_THROW]

SWEP.Kind                   = WEAPON_ROLE
SWEP.WeaponID               = AMMO_CROWBAR

SWEP.IsSilent               = true

SWEP.AllowDelete            = true -- never removed for weapon reduction
SWEP.AllowDrop              = false

if CLIENT then
    SWEP.PowersPanel = nil
end

local alert_far = Sound("npc/fast_zombie/fz_alert_far1.wav")
local scream = Sound("npc/fast_zombie/fz_scream1.wav")

local dreadthrall_ability_cost = CreateConVar("ttt_dreadthrall_ability_cost", "1", FCVAR_REPLICATED, "How many credits each ability use costs", 0, 10)

if SERVER then
    CreateConVar("ttt_dreadthrall_spiritwalk_cooldown", "30", FCVAR_NONE, "How many seconds between uses", 1, 180)
    CreateConVar("ttt_dreadthrall_spiritwalk_duration", "10", FCVAR_NONE, "How many seconds the effect lasts", 1, 180)
    CreateConVar("ttt_dreadthrall_spiritwalk_speedboost", "2", FCVAR_NONE, "How much of a speed boost to give", 1, 5)
    CreateConVar("ttt_dreadthrall_blizzard_cooldown", "30", FCVAR_NONE, "How many seconds between uses", 1, 180)
    CreateConVar("ttt_dreadthrall_blizzard_duration", "30", FCVAR_NONE, "How many seconds the effect lasts", 1, 180)
    CreateConVar("ttt_dreadthrall_blizzard_start", "50", FCVAR_NONE, "How far away from the player the visual effect should start", 1, 300)
    CreateConVar("ttt_dreadthrall_cannibal_cooldown", "30", FCVAR_NONE, "How many seconds between uses", 1, 180)
    CreateConVar("ttt_dreadthrall_cannibal_count", "3", FCVAR_NONE, "How many cannibals to summon", 1, 10)
    CreateConVar("ttt_dreadthrall_cannibal_damage", "10", FCVAR_NONE, "How much damage cannibals do", 1, 100)
    CreateConVar("ttt_dreadthrall_cannibal_toughness", "1", FCVAR_NONE, "Cannibal health multiplier", 0.1, 5)
end

function SWEP:Initialize()
    if CLIENT then
        self:AddHUDHelp("bonecharm_help_pri", "bonecharm_help_sec", true)

        hook.Add("TTTEndRound", "DreadThrall_BoneCharm_TTTEndRound", self.ClosePowersPanel)
        hook.Add("TTTPrepareRound", "DreadThrall_BoneCharm_TTTPrepareRound", self.ClosePowersPanel)
    end

    if SERVER then
        local timerId = "BoneCharmBlizzard_" .. self:EntIndex()
        local function ClearBlizzard()
            if not timer.Exists(timerId) then return end
            timer.Remove(timerId)

            net.Start("TTT_DreadThrall_Blizzard_End")
            net.Broadcast()
        end
        hook.Add("TTTEndRound", "DreadThrall_BoneCharm_Blizzard_TTTEndRound", ClearBlizzard)
        hook.Add("TTTPrepareRound", "DreadThrall_BoneCharm_Blizzard_TTTPrepareRound", ClearBlizzard)
    end

    return self.BaseClass.Initialize(self)
end

function SWEP:GoIdle(anim)
    timer.Create("BoneCharmIdle_" .. self:EntIndex(), animationLengths[anim], 1, function()
        self:SendWeaponAnim(ACT_VM_IDLE)
    end)
end

function SWEP:Deploy()
    local anim
    if math.random(0, 1) == 1 then
        anim = ACT_VM_DRAW
    else
        anim = ACT_VM_FIDGET
    end

    -- Don't let the user use the dagger until the animation finishes
    self:SetNextPrimaryFire(CurTime() + animationLengths[anim])
    self:SendWeaponAnim(anim)
    self:GoIdle(anim)
end

function SWEP:Holster()
    -- Don't let the user holster their weapon while they are spirit walking
    if SERVER and IsValid(self) and timer.Exists("BoneCharmSpiritWalk_" .. self:EntIndex()) then
        return false
    end
    return true
end

function SWEP:DoAttack(owner, damage)
    local spos = owner:GetShootPos()
    local sdest = spos + (owner:GetAimVector() * 70)

    local kmins = Vector(1, 1, 1) * -10
    local kmaxs = Vector(1, 1, 1) * 10

    local tr = util.TraceHull({start=spos, endpos=sdest, filter=owner, mask=MASK_SHOT_HULL, mins=kmins, maxs=kmaxs})

    -- Hull might hit environment stuff that line does not hit
    if not IsValid(tr.Entity) then
        tr = util.TraceLine({start=spos, endpos=sdest, filter=owner, mask=MASK_SHOT_HULL})
    end

    local hitEnt = tr.Entity

    -- effects
    if IsValid(hitEnt) and (hitEnt:IsPlayer() or hitEnt:GetClass() == "prop_ragdoll") then
        local edata = EffectData()
        edata:SetStart(spos)
        edata:SetOrigin(tr.HitPos)
        edata:SetNormal(tr.Normal)
        edata:SetEntity(hitEnt)
        util.Effect("BloodImpact", edata)
    end

    if SERVER and tr.Hit and tr.HitNonWorld and IsPlayer(hitEnt) then
        local dmg = DamageInfo()
        dmg:SetDamage(damage)
        dmg:SetAttacker(owner)
        dmg:SetInflictor(self)
        dmg:SetDamageForce(owner:GetAimVector() * 5)
        dmg:SetDamagePosition(owner:GetPos())
        dmg:SetDamageType(DMG_SLASH)

        hitEnt:DispatchTraceAttack(dmg, spos + (owner:GetAimVector() * 3), sdest)
    end
end

function SWEP:PrimaryAttack()
    if self:GetNextPrimaryFire() > CurTime() then return end
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    owner:LagCompensation(true)

    self:DoAttack(owner, self.Primary.Damage)
    owner:SetAnimation(PLAYER_ATTACK1)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self:GoIdle(ACT_VM_PRIMARYATTACK)

    owner:LagCompensation(false)
end

function SWEP:SecondaryAttack()
    if self:GetNextPrimaryFire() > CurTime() then return end
    self:SetNextPrimaryFire(CurTime() + self.Secondary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    owner:LagCompensation(true)

    self:DoAttack(owner, self.Secondary.Damage)
    owner:SetAnimation(PLAYER_ATTACK1)
    self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
    self:GoIdle(ACT_VM_SECONDARYATTACK)

    owner:LagCompensation(false)
end

function SWEP:Reload()
    if self:GetNextPrimaryFire() > CurTime() then return end
    self:SetNextPrimaryFire(CurTime() + self.Tertiary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    owner:LagCompensation(true)

    owner:SetAnimation(PLAYER_IDLE)
    self:SendWeaponAnim(ACT_VM_THROW)
    self:GoIdle(ACT_VM_THROW)

    owner:LagCompensation(false)

    if CLIENT then
        self:ShowPowerUI()
    end
end

function SWEP:OnDrop()
    self:Remove()
end

function SWEP:OnRemove()
    timer.Remove("BoneCharmIdle_" .. self:EntIndex())
    if CLIENT then
        self:ClosePowersPanel()
    end
end

local function IsCannibal(ent)
    return IsValid(ent) and ent:IsNPC() and ent:GetNWBool("DreadThrallCannibal", false)
end

local function IsOurTeam(ply)
    return ply:GetRoleTeam(true) == player.GetRoleTeam(ROLE_DREADTHRALL, true)
end

if CLIENT then
    surface.CreateFont("DreadThrallTitle", {
        font = "Trebuchet MS",
        size = 22,
        weight = 900 })
    surface.CreateFont("DreadThrallSubTitle", {
        font = "Trebuchet MS",
        size = 16,
        weight = 900 })

    local creditsLabel
    local creditsIcon
    local cooldownsPerPower = {}
    function SWEP:ClosePowersPanel()
        if IsValid(self) and IsValid(self.PowersPanel) then
            self.PowersPanel:Remove()
            self.PowersPanel = nil
        end

        if IsValid(creditsLabel) then
            creditsLabel = nil
        end

        if IsValid(creditsIcon) then
            creditsIcon = nil
        end

        table.Empty(cooldownsPerPower)
    end

    function SWEP:AddOnClick(btn, entIndex)
        btn.DoClick = function()
            self:ClosePowersPanel()

            net.Start("TTT_DreadThrall_BoneCharmUsed")
            net.WriteString(btn:GetName())
            net.WriteUInt(entIndex, 16)
            net.SendToServer()
        end
    end

    local client
    function SWEP:AddThink(btn)
        btn.Think = function()
            self.PowersPanel:MoveToFront()

            local name = btn:GetName()

            -- Make sure this power exists (and that the panel hasn't been closed)
            local cooldown = cooldownsPerPower[name]
            if not cooldown then return end

            local cooldownTime = client:GetNWInt("DreadThrallCooldown_" .. name, 0)
            local offCooldown = cooldownTime <= CurTime()
            local credits = dreadthrall_ability_cost:GetInt()
            local hasCredits = client:GetCredits() >= credits
            local disabled = not hasCredits or not offCooldown or not client:IsActiveDreadThrall()

            local image = "vgui/ttt/thr_" .. name
            if disabled then
                image = image .. "_disabled"
            elseif btn:IsHovered() then
                image = image .. "_hover"
            end
            btn:SetImage(image .. ".png")
            btn:SetEnabled(not disabled)

            -- Update cooldown status
            if offCooldown then
                cooldown:SetVisible(false)
            else
                local time = util.SimpleTime(math.max(0, cooldownTime - CurTime()), "%02i:%02i")
                cooldown:SetText(time)
                cooldown:SizeToContents()
                cooldown:CenterHorizontal()
                cooldown:SetVisible(true)
            end

            creditsLabel:SetText(LANG.GetParamTranslation("dreadthrall_powers_credits", { credits = client:GetCredits() }))
            creditsLabel:SizeToContents()
            creditsLabel:CenterHorizontal()
            creditsLabel:SetVisible(credits > 0)

            creditsIcon:MoveLeftOf(creditsLabel)
            creditsIcon:SetVisible(credits > 0)
        end
    end

    function SWEP:AddLabel(pnl, btn)
        local name = btn:GetName()
        local label = vgui.Create("DLabel", pnl)
        label:SetText(LANG.GetTranslation("dreadthrall_powers_" .. name))
        label:SizeToContents()
        label:MoveBelow(btn)
        label:CenterHorizontal()

        return label
    end

    function SWEP:AddCooldown(pnl, btn, lbl)
        local name = btn:GetName()
        local cooldown = vgui.Create("DLabel", pnl)
        cooldown:SetVisible(false)
        cooldown:SizeToContents()
        cooldown:MoveBelow(lbl)
        cooldown:CenterHorizontal()
        cooldownsPerPower[name] = cooldown
    end

    function SWEP:AddPower(name)
        local panel = vgui.Create("DPanel", self.PowersPanel)
        panel:SetSize(128, 155)
        panel:SetPaintBackground(false)

        local button = vgui.Create("DImageButton", panel)
        button:SetSize(128, 128)
        button:SetName(name)
        button:SetImage("vgui/ttt/thr_" .. name .. ".png")
        button:SetTooltip(LANG.GetTranslation("dreadthrall_powers_" .. name .. "_tooltip"))
        self:AddThink(button)
        self:AddOnClick(button, self:EntIndex())

        local label = self:AddLabel(panel, button)
        self:AddCooldown(panel, button, label)

        return panel
    end

    function SWEP:ShowPowerUI()
        if IsValid(self.PowersPanel) then return end

        client = LocalPlayer()

        local width, height, margin = 400, 340, 10

        self.PowersPanel = vgui.Create("DPanel")
        self.PowersPanel:SetSize(width, height)
        self.PowersPanel:Center()
        self.PowersPanel:MakePopup()
        self.PowersPanel:SetKeyboardInputEnabled(false)
        self.PowersPanel.Paint = function(pnl, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 10, 200))
        end

        local title = vgui.Create("DLabel", self.PowersPanel)
        title:SetText(LANG.GetTranslation("dreadthrall_powers_title"))
        title:SetFont("DreadThrallTitle")
        title:SizeToContents()
        title:CenterHorizontal()

        local subtitle = vgui.Create("DLabel", self.PowersPanel)
        local credits = dreadthrall_ability_cost:GetInt()
        if credits > 0 then
            subtitle:SetText(LANG.GetParamTranslation("dreadthrall_powers_subtitle", { credits = credits }))
        else
            subtitle:SetText(LANG.GetTranslation("dreadthrall_powers_subtitle_free"))
        end
        subtitle:SetFont("DreadThrallSubTitle")
        subtitle:SizeToContents()
        subtitle:MoveBelow(title)
        subtitle:CenterHorizontal()

        local spiritPanel = self:AddPower("spiritwalk")
        spiritPanel:MoveBelow(title)
        spiritPanel:AlignLeft(margin)

        local blizPanel = self:AddPower("blizzard")
        blizPanel:MoveBelow(title)
        blizPanel:AlignRight(margin)

        local cannibalPanel = self:AddPower("cannibal")
        cannibalPanel:MoveBelow(blizPanel)
        cannibalPanel:CenterHorizontal()

        creditsLabel = vgui.Create("DLabel", self.PowersPanel)
        creditsLabel:SetText(LANG.GetParamTranslation("dreadthrall_powers_credits", { credits = 0 }))
        creditsLabel:SetFont("DreadThrallSubTitle")
        creditsLabel:SizeToContents()
        creditsLabel:CenterHorizontal()
        creditsLabel:CenterVertical(0.45)

        creditsIcon = vgui.Create("DImage", self.PowersPanel)
        creditsIcon:SetSize(24, 24)
        creditsIcon:MoveLeftOf(creditsLabel)
        creditsIcon:CenterVertical(0.45)
        creditsIcon:SetImage("vgui/ttt/thr_credits.png")

        local closeButton = vgui.Create("DButton", self.PowersPanel)
        closeButton:SetText(LANG.GetTranslation("dreadthrall_powers_close"))
        closeButton:SizeToContentsX(margin)
        closeButton:SizeToContentsY(margin)
        local close_w, close_y = closeButton:GetSize()
        closeButton:SetPos(width - close_w - margin, height - close_y - margin)
        closeButton.DoClick = function()
            self:ClosePowersPanel()
        end
    end

    local function IsHidden(cli, ply, start)
        -- Magic number to scale this distance to the fog distance even though they supposedly use the same unit
        local scale = 12.4
        local dist = cli:GetPos():Distance(ply:GetPos())
        return dist / scale > start
    end

    net.Receive("TTT_DreadThrall_Blizzard_Start", function()
        local start = net.ReadUInt(12)

        -- Hide all of the info shown in the target ID on mouse over
        hook.Add("TTTTargetIDPlayerBlockInfo", "DreadThrall_TTTTargetIDPlayerBlockInfo", function(ply, cli)
            if IsHidden(cli, ply, start) then
                return true
            end
        end)

        --Limits the player's view distance like in among us
        hook.Add("SetupWorldFog", "DreadThrall_SetupWorldFog", function()
            render.FogMode(MATERIAL_FOG_LINEAR)
            render.FogColor(255, 255, 255)
            render.FogMaxDensity(1)
            render.FogStart(start)
            render.FogEnd(600)

            return true
        end)

        --If a map has a 3D skybox, apply a fog effect to that too
        hook.Add("SetupSkyboxFog", "DreadThrall_SetupSkyboxFog", function(scale)
            render.FogMode(MATERIAL_FOG_LINEAR)
            render.FogColor(255, 255, 255)
            render.FogMaxDensity(1)
            render.FogStart(start * scale)
            render.FogEnd(600 * scale)

            return true
        end)
    end)

    net.Receive("TTT_DreadThrall_Blizzard_End", function()
        hook.Remove("TTTTargetIDPlayerBlockInfo", "DreadThrall_TTTTargetIDPlayerBlockInfo")
        hook.Remove("SetupWorldFog", "DreadThrall_SetupWorldFog")
        hook.Remove("SetupSkyboxFog", "DreadThrall_SetupSkyboxFog")
    end)

    net.Receive("TTT_DreadThrall_Cannibal_Alert", function()
        surface.PlaySound(alert_far)
        surface.PlaySound(scream)
    end)

    -- Highlight active cannibals
    hook.Add("PreDrawHalos", "DreadThrall_Highlight_PreDrawHalos", function()
        if not IsPlayer(client) then
            client = LocalPlayer()
        end
        -- Ignore the dead and players who aren't on our team
        if not IsPlayer(client) or not client:Alive() or client:IsSpec() or not IsOurTeam(client) then return end

        local cannibals = {}
        for _, ent in ipairs(ents.FindByClass("npc_fastzombie")) do
            if IsCannibal(ent) then
                table.insert(cannibals, ent)
            end
        end

        if #cannibals == 0 then return end

        halo.Add(cannibals, ROLE_COLORS[ROLE_TRAITOR], 1, 1, 1, true, true)
    end)
else
    function SWEP:PreDrop()
        if timer.Exists("BoneCharmSpiritWalk_" .. self:EntIndex()) then
            timer.Remove("BoneCharmSpiritWalk_" .. self:EntIndex())
            local owner = self:GetOwner()
            if IsPlayer(owner) then
                owner:SetColor(COLOR_WHITE)
                owner:SetMaterial("")
                owner:EmitSound("weapons/ttt/dreadthrall/unfade.wav")
                owner:SetNWInt("DreadThrall_SpiritWalking", 0)
            end
        end
        return self.BaseClass.PreDrop(self)
    end

    local function DoSpiritWalk(ply, entIndex)
        ply:SetColor(Color(255, 255, 255, 0))
        ply:SetMaterial("sprites/heatwave")
        ply:EmitSound("weapons/ttt/dreadthrall/fade.wav")

        local speed = GetConVar("ttt_dreadthrall_spiritwalk_speedboost"):GetInt()
        ply:SetNWInt("DreadThrall_SpiritWalking", speed)

        local duration = GetConVar("ttt_dreadthrall_spiritwalk_duration"):GetInt()
        timer.Create("BoneCharmSpiritWalk_" .. entIndex, duration, 1, function()
            -- Remove the timer so the player can switch weapons again
            timer.Remove("BoneCharmSpiritWalk_" .. entIndex)
            if IsPlayer(ply) then
                ply:SetColor(COLOR_WHITE)
                ply:SetMaterial("")
                ply:EmitSound("weapons/ttt/dreadthrall/unfade.wav")
                ply:SetNWInt("DreadThrall_SpiritWalking", 0)
            end
        end)
    end

    local function DoBlizzard(ply, entIndex)
        local start = GetConVar("ttt_dreadthrall_blizzard_start"):GetInt()
        net.Start("TTT_DreadThrall_Blizzard_Start")
        net.WriteUInt(start, 12)
        net.Broadcast()

        for _, p in PlayerIterator() do
            p:QueueMessage(MSG_PRINTBOTH, "A blizzard approaches...")
        end

        local duration = GetConVar("ttt_dreadthrall_blizzard_duration"):GetInt()
        timer.Create("BoneCharmBlizzard_" .. entIndex, duration, 1, function()
            net.Start("TTT_DreadThrall_Blizzard_End")
            net.Broadcast()

            for _, p in PlayerIterator() do
                p:QueueMessage(MSG_PRINTBOTH, "The blizzard has subsided")
            end
        end)
    end

    local function DoCannibals(ply, entIndex)
        local target = nil
        local alt_target = nil
        for _, p in RandomPairs(GetAllPlayers()) do
            -- Ignore dead people, spectators, team members, glitches (if the Dread Thrall is a traitor), jesters, and people who win passively (like the Old Man)
            if p:Alive() and not p:IsSpec() and not IsOurTeam(p) and not p:ShouldActLikeJester() and not ROLE_HAS_PASSIVE_WIN[p:GetRole()] then
                if TRAITOR_ROLES[ROLE_DREADTHRALL] and p:IsGlitch() then
                    alt_target = p
                else
                    target = p
                    break
                end
            end
        end

        -- Allow the glitch as a backup
        if not IsPlayer(target) then
            target = alt_target
        end

        -- This should not be possible, but just in case
        if not IsPlayer(target) then return end

        local tgt_pos = target:GetPos()
        local spawns = {}
        for _, e in ipairs(ents.GetAll()) do
            local entity_class = e:GetClass()
            -- Find spawn entities without parents
            if (string.StartWith(entity_class, "info_") or string.StartWith(entity_class, "weapon_") or string.StartWith(entity_class, "item_")) and not IsValid(e:GetParent()) then
                table.insert(spawns, {
                    ent = e,
                    dist = e:GetPos():Distance(tgt_pos)
                })
            end
        end

        -- Find the N nearest spawns corresponding to the number of cannibals to spawn
        local count = GetConVar("ttt_dreadthrall_cannibal_count"):GetInt()
        local nearest_spawns = {}
        for _, spawn in SortedPairsByMemberValue(spawns, "dist") do
            -- Don't let them spawn too close
            if IsValid(spawn.ent) and spawn.dist > 300 then
                table.insert(nearest_spawns, spawn.ent:GetPos())
                if #nearest_spawns == count then
                    break
                end
            end
        end

        -- If we didn't find any spawns, generate random accessible points around the target
        if #nearest_spawns == 0 then
            local target_pos = target:GetPos()
            target_pos = FindRespawnLocation(target_pos) or target_pos
            for i = 1, count do
                -- Move this point around a bit randomly
                local x_mod = math.random(300, 700)
                if math.random(0, 1) == 1 then
                    x_mod = x_mod * -1
                end
                local y_mod = math.random(300, 700)
                if math.random(0, 1) == 1 then
                    y_mod = y_mod * -1
                end
                local mod_pos = Vector(target_pos[1] + x_mod, target_pos[2] + y_mod, target_pos[3] + 10)
                table.insert(nearest_spawns, FindRespawnLocation(mod_pos) or mod_pos)
            end
        end

        -- Spawn 1 zombie for each of the chosen spawn locations
        for _, pos in ipairs(nearest_spawns) do
            local zombie = ents.Create("npc_fastzombie")

            local spawn_pos = Vector(pos[1], pos[2], pos[3] + 10)
            local dir = (spawn_pos - zombie:GetPos()):GetNormal()
            zombie:SetPos(spawn_pos)
            zombie:SetAngles(Angle(dir[1], dir[2], dir[3]))
            zombie:Spawn()
            zombie:PhysWake()
            zombie:SetSchedule(SCHED_ALERT_WALK)
            zombie:SetNPCState(NPC_STATE_ALERT)
            zombie:NavSetWanderGoal(100, 100)
            zombie:SetNWBool("DreadThrallCannibal", true)
        end

        net.Start("TTT_DreadThrall_Cannibal_Alert")
        net.Broadcast()

        ply:QueueMessage(MSG_PRINTBOTH, "Summoned " .. count .. " cannibals near " .. target:Nick())
    end

    local nextRelationshipUpdate = CurTime()
    hook.Add("Think", "DreadThrall_Cannibal_Think", function()
        if CurTime() < nextRelationshipUpdate then return end
        nextRelationshipUpdate = CurTime() + 0.08

        -- Update the zombie relationship so they don't attack team members
        for _, ent in ipairs(ents.FindByClass("npc_fastzombie")) do
            if IsCannibal(ent) then
                local glitches = {}
                local found_target = false
                for _, ply in PlayerIterator() do
                    if ply:Alive() and not ply:IsSpec() then
                        if IsOurTeam(ply) or (TRAITOR_ROLES[ROLE_DREADTHRALL] and ply:IsGlitch()) or ROLE_HAS_PASSIVE_WIN[ply:GetRole()] then
                            if ply:IsGlitch() then table.insert(glitches, ply) end
                            ent:AddEntityRelationship(ply, D_LI, 99)
                        else
                            found_target = true
                            ent:AddEntityRelationship(ply, D_HT, 99)
                        end
                    end
                end

                if not found_target then
                    for _, ply in ipairs(glitches) do
                        ent:AddEntityRelationship(ply, D_HT, 99)
                    end
                end
            end
        end
    end)

    -- Adjust damage given and taken based on convars
    hook.Add("EntityTakeDamage", "DreadThrall_Cannibal_EntityTakeDamage", function(ent, dmginfo)
        local attacker = dmginfo:GetAttacker()
        if IsCannibal(attacker) and IsPlayer(ent) then
            dmginfo:SetDamage(GetConVar("ttt_dreadthrall_cannibal_damage"):GetFloat())
        elseif IsPlayer(attacker) and IsCannibal(ent) then
            dmginfo:SetDamage(dmginfo:GetDamage() * GetConVar("ttt_dreadthrall_cannibal_toughness"):GetFloat())
        end
    end)

    net.Receive("TTT_DreadThrall_BoneCharmUsed", function(len, ply)
        if not IsPlayer(ply) or not ply:IsActiveDreadThrall() then return end

        local power = net.ReadString()
        if #power == 0 then return end

        local entIndex = net.ReadUInt(16)
        if entIndex < 0 then return end

        local convarId = "ttt_dreadthrall_" .. power .. "_cooldown"
        if not ConVarExists(convarId) then
            ErrorNoHalt("Player attempted to use DreadThrall power (" .. power .. ") that doesn't exist: " .. ply:Nick() .. " (" .. ply:SteamID() .. ")\n")
            return
        end

        local cooldownId = "DreadThrallCooldown_" .. power
        local cooldown = ply:GetNWInt(cooldownId, 0)
        if cooldown > CurTime() then
            ErrorNoHalt("Player attempted to use DreadThrall power (" .. power .. ") before cooldown: " .. ply:Nick() .. " (" .. ply:SteamID() .. ")\n")
            return
        end

        local credits = dreadthrall_ability_cost:GetInt()
        if ply:GetCredits() < credits then
            ErrorNoHalt("Player attempted to use DreadThrall power (" .. power .. ") without enough credits (" .. ply:GetCredits() .. "/" .. credits .. "): " .. ply:Nick() .. " (" .. ply:SteamID() .. ")\n")
            return
        end

        hook.Call("TTTDreadThrallPowerUsed", nil, ply, power)

        ply:SetNWInt(cooldownId, CurTime() + GetConVar(convarId):GetInt())
        ply:SubtractCredits(credits)

        if ply.IsRoleAbilityDisabled and ply:IsRoleAbilityDisabled() then return end

        if power == "spiritwalk" then
            DoSpiritWalk(ply, entIndex)
        elseif power == "blizzard" then
            DoBlizzard(ply, entIndex)
        elseif power == "cannibal" then
            DoCannibals(ply, entIndex)
        end
    end)

    hook.Add("TTTPrepareRound", "DreadThrall_BoneCharm_TTTPrepareRound", function()
        for _, v in PlayerIterator() do
            v:SetNWInt("DreadThrallCooldown_spiritwalk", 0)
            v:SetNWInt("DreadThrallCooldown_blizzard", 0)
            v:SetNWInt("DreadThrallCooldown_cannibal", 0)
            v:SetNWInt("DreadThrall_SpiritWalking", 0)
        end
    end)
end

hook.Add("TTTSpeedMultiplier", "DreadThrall_BoneCharm_TTTSpeedMultiplier", function(ply, mults)
    local speed = ply:GetNWInt("DreadThrall_SpiritWalking", 0)
    if speed > 1 then
        table.insert(mults, speed)
    end
end)