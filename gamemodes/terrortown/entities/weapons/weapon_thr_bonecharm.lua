AddCSLuaFile()

if SERVER then
    util.AddNetworkString("TTT_DreadThrall_BoneCharmUsed")
    util.AddNetworkString("TTT_DreadThrall_Blizzard_Start")
    util.AddNetworkString("TTT_DreadThrall_Blizzard_End")

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

SWEP.Kind                   = WEAPON_NONE
SWEP.WeaponID               = AMMO_CROWBAR

SWEP.IsSilent               = true

SWEP.AllowDelete            = true -- never removed for weapon reduction
SWEP.AllowDrop              = false

if CLIENT then
    SWEP.PowersPanel = nil
end

if SERVER then
    CreateConVar("ttt_dreadthrall_spiritwalk_cooldown", "30", FCVAR_NONE, "How many seconds between uses", 1, 180)
    CreateConVar("ttt_dreadthrall_spiritwalk_duration", "30", FCVAR_NONE, "How many seconds the effect lasts", 1, 180)
    CreateConVar("ttt_dreadthrall_blizzard_cooldown", "30", FCVAR_NONE, "How many seconds between uses", 1, 180)
    CreateConVar("ttt_dreadthrall_blizzard_duration", "30", FCVAR_NONE, "How many seconds the effect lasts", 1, 180)
    CreateConVar("ttt_dreadthrall_cannibal_cooldown", "30", FCVAR_NONE, "How many seconds between uses", 1, 180)
    CreateConVar("ttt_dreadthrall_cannibal_count", "3", FCVAR_NONE, "How many cannibals to summon", 1, 10)
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
        if IsValid(self.PowersPanel) then
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

    net.Receive("TTT_DreadThrall_Blizzard_Start", function()
        --Limits the player's view distance like in among us
        hook.Add("SetupWorldFog", "DreadThrall_SetupWorldFog", function()
            render.FogMode(MATERIAL_FOG_LINEAR)
            render.FogColor(255, 255, 255)
            render.FogMaxDensity(1)
            render.FogStart(200)
            render.FogEnd(600)

            return true
        end)

        --If a map has a 3D skybox, apply a fog effect to that too
        hook.Add("SetupSkyboxFog", "DreadThrall_SetupSkyboxFog", function(scale)
            render.FogMode(MATERIAL_FOG_LINEAR)
            render.FogColor(255, 255, 255)
            render.FogMaxDensity(1)
            render.FogStart(200 * scale)
            render.FogEnd(600 * scale)

            return true
        end)
    end)

    net.Receive("TTT_DreadThrall_Blizzard_End", function()
        hook.Remove("SetupWorldFog", "DreadThrall_SetupWorldFog")
        hook.Remove("SetupSkyboxFog", "DreadThrall_SetupSkyboxFog")
    end)
else
    function DoSpiritWalk(ply, entIndex)
    end

    function DoBlizzard(ply, entIndex)
        net.Start("TTT_DreadThrall_Blizzard_Start")
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

    function DoCannibals(ply, entIndex)
    end

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

        -- TODO: Replace this with actually doing something
        print(ply:Nick() .. " used DT power: " .. power)

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
        end
    end)
end