AddCSLuaFile()

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
end

function SWEP:OnDrop()
    self:Remove()
end