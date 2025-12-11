#pragma once

/**
 * Ability flags describe what a class can do.
 * These are kept generic so PRD/RHA/SM modules can branch on capabilities.
 */
enum MSTAbilityFlags
{
    MSTAbility_None              = 0,
    MSTAbility_Revive            = 1 << 0, // Can revive self or others (medic-type)
    MSTAbility_Turret            = 1 << 1, // Can place turrets or sentries
    MSTAbility_Barricade         = 1 << 2, // Can place barriers/cover
    MSTAbility_GrenadeLauncher   = 1 << 3, // Has a grenade launcher / explosive charges
    MSTAbility_SpecialVision     = 1 << 4, // Has alternate vision modes (e.g., red NVG/thermal)
    MSTAbility_FlashlightForce   = 1 << 5, // Forces flashlight / custom lamp behavior
    MSTAbility_SpeedScout        = 1 << 6, // Move speed bonus (scout/recon)
    MSTAbility_ShieldCarrier     = 1 << 7, // Uses ballistic shield
    MSTAbility_GasImmunity       = 1 << 8, // Immune to chemical/gas effects
    MSTAbility_EngineerToolset   = 1 << 9  // Has repair/build tools (turret/barricade helpers)
};

// Skin type enumeration for different skin categories
enum SkinType
{
    SkinType_Regular = 0,     // Обычный/стандартный скин
    SkinType_Female,          // Женский скин
    SkinType_Robot,           // Робот/киборг скин
    SkinType_LongSleeve,      // Скин с длинным рукавом
    SkinType_Animal,          // Животное
    SkinType_Monster          // Чудовище
};

#define ZH_MST_LIBRARY "zh_mst"

/**
 * Registers or updates a class definition.
 * @param classId       Unique numeric id.
 * @param name          Internal name.
 * @param modelPath     Player model path (may be empty).
 * @param soundProfile  Optional sound tag/profile (for SoundManifest or other systems).
 * @param abilityFlags  Bitmask of MSTAbilityFlags.
 * @return true on success.
 */
native bool MST_DefineClass(int classId, const char[] name, const char[] modelPath, const char[] soundProfile, int abilityFlags);

/**
 * Sets the active class for a client and fires MST_OnClassChanged forward.
 */
native bool MST_SetClientClass(int client, int classId, const char[] reason = "");

/**
 * Gets the current class id for a client. Returns -1 if unset.
 */
native int MST_GetClientClass(int client);

/**
 * Returns ability flags for a class. 0 if unknown.
 */
native int MST_GetClassAbilityFlags(int classId);

/**
 * Returns the class model into buffer; false if unknown or empty.
 */
native bool MST_GetClassModel(int classId, char[] buffer, int maxlen);

/**
 * Returns the class name into buffer; false if unknown.
 */
native bool MST_GetClassName(int classId, char[] buffer, int maxlen);

/**
 * Returns the class sound profile into buffer; false if unknown or empty.
 */
native bool MST_GetClassSoundProfile(int classId, char[] buffer, int maxlen);

/**
 * Registers a model file for download/precaching via the centralized loader.
 */
native void MST_RegisterModel(const char[] path);

/**
 * Registers a sound file for download/precaching via the centralized loader.
 */
native void MST_RegisterSound(const char[] path);

/**
 * Sets glove information for a class (model and skin).
 * @param classId       Class identifier.
 * @param gloveModel    Path to the glove model.
 * @param gloveSkin     Skin index for the gloves.
 * @return true on success.
 */
native bool MST_SetClassGloveInfo(int classId, const char[] gloveModel, int gloveSkin);

/**
 * Gets glove information for a class (model and skin).
 * @param classId       Class identifier.
 * @param buffer        Buffer to store the glove model path.
 * @param maxlen        Maximum length of the buffer.
 * @param gloveSkin     Variable to store the glove skin index.
 * @return true on success.
 */
native bool MST_GetClassGloveInfo(int classId, char[] buffer, int maxlen, int& gloveSkin);

/**
 * Sets the skin type for a class.
 * @param classId       Class identifier.
 * @param skinType      Skin type from SkinType enum.
 * @return true on success.
 */
native bool MST_SetClassSkinType(int classId, int skinType);

/**
 * Gets the skin type for a class.
 * @param classId       Class identifier.
 * @return Skin type from SkinType enum.
 */
native int MST_GetClassSkinType(int classId);

/**
 * Forward fired after a class is changed.
 */
forward void MST_OnClassChanged(int client, int newClassId, int oldClassId, const char[] reason);