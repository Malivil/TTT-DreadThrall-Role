AddCSLuaFile()

if SERVER then
    util.AddNetworkString("TTT_DreadThrall_BoneCharmUsed")
    util.AddNetworkString("TTT_DreadThrall_Blizzard_Start")
    util.AddNetworkString("TTT_DreadThrall_Blizzard_End")
    util.AddNetworkString("TTT_DreadThrall_Cannibal_Alert")

    resource.AddSingleFile("vgui/ttt/thr_spiritwalk.png")
    resource.AddSingleFile("vgui/ttt/thr_spiritwalk_hover.png")
    resource.AddSingleFile("vgui/ttt/thr_spiritwalk_disabled.png")
    resource.AddSingleFile("vgui/ttt/thr_blizzard.png")
    resource.AddSingleFile("vgui/ttt/thr_blizzard_hover.png")
    resource.AddSingleFile("vgui/ttt/thr_blizzard_disabled.png")
    resource.AddSingleFile("vgui/ttt/thr_cannibal.png")
    resource.AddSingleFile("vgui/ttt/thr_cannibal_hover.png")
    resource.AddSingleFile("vgui/ttt/thr_cannibal_disabled.png")
    resource.AddSingleFile("vgui/ttt/thr_credits.png")

    resource.AddSingleFile("sound/weapons/ttt/dreadthrall/fade.wav")
    resource.AddSingleFile("sound/weapons/ttt/dreadthrall/unfade.wav")
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

if CLIENT then
    function SWEP:Initialize()
        self:AddHUDHelp("bonecharm_help_pri", "bonecharm_help_sec", true)

        hook.Add("TTTEndRound", "DreadThrall_BoneCharm_TTTEndRound", self.ClosePowersPanel)
        hook.Add("TTTPrepareRound", "DreadThrall_BoneCharm_TTTPrepareRound", self.ClosePowersPanel)

        return self.BaseClass.Initialize(self)
    end
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
    if IsValid(self) and timer.Exists("BoneCharmSpiritWalk_" .. self:EntIndex()) then
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
    if SERVER then
        if timer.Exists("BoneCharmSpiritWalk_" .. self:EntIndex()) then
            timer.Remove("BoneCharmSpiritWalk_" .. self:EntIndex())
            local owner = self:GetOwner()
            owner:SetColor(Color(255, 255, 255, 255))
            owner:SetMaterial("models/glass")
            owner:EmitSound("weapons/ttt/dreadthrall/unfade.wav")
            owner:SetNWInt("DreadThrall_SpiritWalking", 0)
        end
    end
    if CLIENT then
        self:ClosePowersPanel()
    end
end

local function IsCannibal(ent)
    return IsValid(ent) and ent:IsNPC() and ent:GetNWBool("DreadThrallCannibal", false)
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
            local cooldownTime = client:GetNWInt("DreadThrallCooldown_" .. name, 0)
            local offCooldown = cooldownTime <= CurTime()
            local hasCredits = client:GetCredits() > 0
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
            local cooldown = cooldownsPerPower[name]
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

            creditsIcon:MoveLeftOf(creditsLabel)
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
        subtitle:SetText(LANG.GetTranslation("dreadthrall_powers_subtitle"))
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
        -- Ignore dead and non-traitor players
        if not IsPlayer(client) or not client:Alive() or client:IsSpec() or not client:IsTraitorTeam() then return end

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
    local function HasPassiveWin(role)
        return ROLE_HAS_PASSIVE_WIN and ROLE_HAS_PASSIVE_WIN[role]
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
            ply:SetColor(Color(255, 255, 255, 255))
            ply:SetMaterial("models/glass")
            ply:EmitSound("weapons/ttt/dreadthrall/unfade.wav")
            ply:SetNWInt("DreadThrall_SpiritWalking", 0)
        end)
    end

    local function DoBlizzard(ply, entIndex)
        local start = GetConVar("ttt_dreadthrall_blizzard_start"):GetInt()
        net.Start("TTT_DreadThrall_Blizzard_Start")
        net.WriteUInt(start, 12)
        net.Broadcast()

        for _, p in ipairs(player.GetAll()) do
            p:PrintMessage(HUD_PRINTTALK, "A blizzard approaches...")
            p:PrintMessage(HUD_PRINTCENTER, "A blizzard approaches...")
        end

        local duration = GetConVar("ttt_dreadthrall_blizzard_duration"):GetInt()
        timer.Create("BoneCharmBlizzard_" .. entIndex, duration, 1, function()
            net.Start("TTT_DreadThrall_Blizzard_End")
            net.Broadcast()

            for _, p in ipairs(player.GetAll()) do
                p:PrintMessage(HUD_PRINTTALK, "The blizzard has subsided")
                p:PrintMessage(HUD_PRINTCENTER, "The blizzard has subsided")
            end
        end)
    end

    local function DoCannibals(ply, entIndex)
        local target = nil
        for _, p in RandomPairs(player.GetAll()) do
            -- Ignore dead people, spectators, traitors, jesters, and people who win passively (like the Old Man)
            if p:Alive() and not p:IsSpec() and not p:IsTraitorTeam() and not p:ShouldActLikeJester() and not HasPassiveWin(p:GetRole()) then
                target = p
                break
            end
        end

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
            zombie:SetPos(Vector(pos[1], pos[2], pos[3] + 10))
            zombie:Spawn()
            zombie:PhysWake()
            zombie:SetSchedule(SCHED_ALERT_WALK)
            zombie:NavSetWanderGoal(100, 100)
            zombie:SetNWBool("DreadThrallCannibal", true)
        end

        net.Start("TTT_DreadThrall_Cannibal_Alert")
        net.Broadcast()

        ply:PrintMessage(HUD_PRINTTALK, "Summoned " .. count .. " cannibals near " .. target:Nick())
        ply:PrintMessage(HUD_PRINTCENTER, "Summoned " .. count .. " cannibals near " .. target:Nick())
    end

    local nextRelationshipUpdate = CurTime()
    hook.Add("Think", "DreadThrall_Cannibal_Think", function()
        if CurTime() < nextRelationshipUpdate then return end
        nextRelationshipUpdate = CurTime() + 0.08

        -- Update the zombie relationship so they don't attack traitors
        for _, ent in ipairs(ents.FindByClass("npc_fastzombie")) do
            if IsCannibal(ent) then
                for _, ply in ipairs(player.GetAll()) do
                    if ply:Alive() and not ply:IsSpec() then
                        if ply:IsTraitorTeam() or HasPassiveWin(ply:GetRole()) then
                            ent:AddEntityRelationship(ply, D_LI, 99)
                        else
                            ent:AddEntityRelationship(ply, D_HT, 99)
                        end
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

        if ply:GetCredits() < 1 then
            ErrorNoHalt("Player attempted to use DreadThrall power (" .. power .. ") without credits: " .. ply:Nick() .. " (" .. ply:SteamID() .. ")\n")
            return
        end

        ply:SetNWInt(cooldownId, CurTime() + GetConVar(convarId):GetInt())
        ply:SubtractCredits(1)

        if power == "spiritwalk" then
            DoSpiritWalk(ply, entIndex)
        elseif power == "blizzard" then
            DoBlizzard(ply, entIndex)
        elseif power == "cannibal" then
            DoCannibals(ply, entIndex)
        end
    end)

    hook.Add("TTTPrepareRound", "DreadThrall_BoneCharm_TTTPrepareRound", function()
        for _, v in pairs(player.GetAll()) do
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