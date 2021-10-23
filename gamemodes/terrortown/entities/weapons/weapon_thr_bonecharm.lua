AddCSLuaFile()

if SERVER then
    util.AddNetworkString("TTT_DreadThrall_BoneCharmUsed")
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

local DREADTHRALL_POWER_SPIRITWALK = 1
local DREADTHRALL_POWER_BLIZZARD = 2
local DREADTHRALL_POWER_CANNIBAL = 3

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
    local buttonToType = {
        ["spiritwalk"] = DREADTHRALL_POWER_SPIRITWALK,
        ["blizzard"] = DREADTHRALL_POWER_BLIZZARD,
        ["cannibal"] = DREADTHRALL_POWER_CANNIBAL
    }
    local panel
    local function AddOnClick(btn)
        btn.DoClick = function()
            panel:Remove()
            panel = nil

            net.Start("TTT_DreadThrall_BoneCharmUsed")
            net.WriteUInt(buttonToType[btn:GetName()], 2)
            net.SendToServer()
        end
    end

    local function AddOnHover(btn)
        btn.Think = function()
            local image = "vgui/ttt/thr_" .. btn:GetName()
            if btn:IsHovered() then
                image = image .. "_hover"
            end
            btn:SetImage(image .. ".png")
        end
    end

    function SWEP:ShowPowerUI()
        if IsValid(panel) then return end

        panel = vgui.Create("DPanel")
        panel:SetSize(500, 500)
        panel:SetPos(ScrW()/2, ScrH()/2)
        panel:SetBackgroundColor(COLOR_GREY)

        local spirit_button = vgui.Create("DImageButton", panel)
        spirit_button:SetSize(128, 128)
        spirit_button:SetPos(0, 0)
        spirit_button:SetName("spiritwalk")
        spirit_button:SetImage("vgui/ttt/thr_spiritwalk.png")
        AddOnHover(spirit_button)
        AddOnClick(spirit_button)

        local bliz_button = vgui.Create("DImageButton", panel)
        bliz_button:SetSize(128, 128)
        bliz_button:SetPos(128, 0)
        bliz_button:SetName("blizzard")
        bliz_button:SetImage("vgui/ttt/thr_blizzard.png")
        AddOnHover(bliz_button)
        AddOnClick(bliz_button)

        local cannibal_button = vgui.Create("DImageButton", panel)
        cannibal_button:SetSize(128, 128)
        cannibal_button:SetPos(256, 0)
        cannibal_button:SetName("cannibal")
        cannibal_button:SetImage("vgui/ttt/thr_cannibal.png")
        AddOnHover(cannibal_button)
        AddOnClick(cannibal_button)
    end
else
    net.Receive("TTT_DreadThrall_BoneCharmUsed", function(len, ply)
        if not IsPlayer(ply) or not ply:IsActiveDreadThrall() then return end

        local power = net.ReadUInt(2)
        if power == 0 then return end

        print(ply:Nick() .. " used DT power: " .. power)
    end)
end