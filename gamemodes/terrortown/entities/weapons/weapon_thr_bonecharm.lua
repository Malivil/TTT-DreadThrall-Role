AddCSLuaFile()

if SERVER then
    util.AddNetworkString("TTT_DreadThrall_BoneCharmUsed")

    resource.AddSingleFile("vgui/ttt/thr_spiritwalk.png")
    resource.AddSingleFile("vgui/ttt/thr_spiritwalk_hover.png")
    resource.AddSingleFile("vgui/ttt/thr_spiritwalk_disabled.png")
    resource.AddSingleFile("vgui/ttt/thr_blizzard.png")
    resource.AddSingleFile("vgui/ttt/thr_blizzard_hover.png")
    resource.AddSingleFile("vgui/ttt/thr_blizzard_disabled.png")
    resource.AddSingleFile("vgui/ttt/thr_cannibal.png")
    resource.AddSingleFile("vgui/ttt/thr_cannibal_hover.png")
    resource.AddSingleFile("vgui/ttt/thr_cannibal_disabled.png")
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

SWEP.Primary.Damage         = 65
SWEP.Primary.ClipSize       = -1
SWEP.Primary.DefaultClip    = -1
SWEP.Primary.Automatic      = true
SWEP.Primary.Delay          = animationLengths[ACT_VM_PRIMARYATTACK]
SWEP.Primary.Ammo           = "none"

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

if SERVER then
    CreateConVar("ttt_dreadthrall_spiritwalk_cooldown", "30")
    CreateConVar("ttt_dreadthrall_blizzard_cooldown", "30")
    CreateConVar("ttt_dreadthrall_cannibal_cooldown", "30")
end

function SWEP:GoIdle(anim)
    timer.Create("BoneCharmIdle", animationLengths[anim], 1, function()
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

function SWEP:PrimaryAttack()
    if self:GetNextPrimaryFire() > CurTime() then return end
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    owner:LagCompensation(true)

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

    owner:SetAnimation(PLAYER_ATTACK1)
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

if CLIENT then
    local client
    local panel
    local function AddOnClick(btn)
        btn.DoClick = function()
            panel:Remove()
            panel = nil

            net.Start("TTT_DreadThrall_BoneCharmUsed")
            net.WriteString(btn:GetName())
            net.SendToServer()
        end
    end

    local function AddThink(btn)
        btn.Think = function()
            local name = btn:GetName()
            local offCooldown = client:GetNWInt("DreadThrallCooldown_" .. name, 0) <= CurTime()
            local hasCredits = client:GetCredits() > 0
            local disabled = not hasCredits or not offCooldown

            local image = "vgui/ttt/thr_" .. name
            if disabled then
                image = image .. "_disabled"
            elseif btn:IsHovered() then
                image = image .. "_hover"
            end
            btn:SetImage(image .. ".png")
            btn:SetDisabled(disabled)
        end
    end

    function SWEP:ShowPowerUI()
        if IsValid(panel) then return end

        client = LocalPlayer()

        panel = vgui.Create("DPanel")
        panel:SetSize(500, 500)
        panel:SetPos(ScrW()/2, ScrH()/2)
        panel:SetBackgroundColor(COLOR_GREY)

        local spirit_button = vgui.Create("DImageButton", panel)
        spirit_button:SetSize(128, 128)
        spirit_button:SetPos(0, 0)
        spirit_button:SetName("spiritwalk")
        spirit_button:SetImage("vgui/ttt/thr_spiritwalk.png")
        AddThink(spirit_button)
        AddOnClick(spirit_button)

        local bliz_button = vgui.Create("DImageButton", panel)
        bliz_button:SetSize(128, 128)
        bliz_button:SetPos(128, 0)
        bliz_button:SetName("blizzard")
        bliz_button:SetImage("vgui/ttt/thr_blizzard.png")
        AddThink(bliz_button)
        AddOnClick(bliz_button)

        local cannibal_button = vgui.Create("DImageButton", panel)
        cannibal_button:SetSize(128, 128)
        cannibal_button:SetPos(256, 0)
        cannibal_button:SetName("cannibal")
        cannibal_button:SetImage("vgui/ttt/thr_cannibal.png")
        AddThink(cannibal_button)
        AddOnClick(cannibal_button)

        -- TODO: Add cooldown (and disable button during)
        -- TODO: Add cost (and disable buttons when not enough credits)
        -- TODO: Add close button (or figure out if it can be closed by pressing R again?)
        -- TODO: Try to prevent "reload" if the window is still open (somehow?)
    end
else
    net.Receive("TTT_DreadThrall_BoneCharmUsed", function(len, ply)
        if not IsPlayer(ply) or not ply:IsActiveDreadThrall() then return end

        local power = net.ReadString()
        if #power == 0 then return end

        local cooldownId = "DreadThrallCooldown_" .. power
        local cooldown = ply:GetNWInt(cooldownId)
        if cooldown > CurTime() then
            ErrorNoHalt("Player attempted to use DreadThrall power (" .. power .. ") before cooldown: " .. ply:Nick() .. " (" .. ply:SteamID() .. ")\n")
            return
        end

        if ply:GetCredits() < 1 then
            ErrorNoHalt("Player attempted to use DreadThrall power (" .. power .. ") without credits: " .. ply:Nick() .. " (" .. ply:SteamID() .. ")\n")
            return
        end

        ply:SetNWInt(cooldownId, CurTime() + GetConVar("ttt_dreadthrall_" .. power .. "_cooldown"):GetInt())
        ply:SubtractCredits(1)

        -- TODO: Replace this with actually doing something
        print(ply:Nick() .. " used DT power: " .. power)
    end)

    hook.Add("TTTPrepareRound", "DreadThrall_BoneCharm_TTTPrepareRound", function()
        for _, v in pairs(player.GetAll()) do
            v:SetNWInt("DreadThrallCooldown_spiritwalk", 0)
            v:SetNWInt("DreadThrallCooldown_blizzard", 0)
            v:SetNWInt("DreadThrallCooldown_cannibal", 0)
        end
    end)
end