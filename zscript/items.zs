// Minecraft things: TNT instead of barrels, food and diamonds instead of medkits and armor bonuses, XP orbs.

class SICTNT : ExplosiveBarrel replaces ExplosiveBarrel
{
	Default
	{
		Radius 14;
		Height 30;
		Scale 0.5;
		DeathSound "sic/tnt";
		Obituary "%o was blown up by TNT.";
	}
	States
	{
	Spawn:
		STNT A -1;
		Stop;
	Death:
		// It flashes white a few times before it blows, like the real thing.
		STNT B 3;
		STNT A 3;
		STNT B 3;
		STNT A 2;
		STNT B 2;
		TNT1 A 0 A_Boom;
		TNT1 A 1050 A_BarrelDestroy;
		TNT1 A 5 A_Respawn;
		Wait;
	}

	void A_Boom()
	{
		A_StartSound("sic/tnt", CHAN_BODY, 0, 1, ATTN_NORM);
		A_Explode(128, 128);
		A_QuakeEx(2, 2, 2, 12, 0, 400, "");
		Vector3 c = pos + (0, 0, 16);
		SICCube.Burst(c, 'O', 24, 10, 0.7, 30, 0.3, 2);
		SICCube.Burst(c, 'R', 16, 8, 0.6, 30, 0.3, 2);
		SICCube.Burst(c, 'W', 10, 6, 0.6, 22, 0, 1);
		SICCube.Burst(c, 'S', 18, 3, 1.0, 50, 0, 1.5);
	}
}

class SICApple : Stimpack replaces Stimpack
{
	Default
	{
		Scale 0.7;
		Inventory.PickupMessage "Ate an apple. Crunchy! (+10 health)";
	}
	States
	{
	Spawn:
		SAPL A -1;
		Stop;
	}
}

class SICStew : Medikit replaces Medikit
{
	Default
	{
		Scale 0.8;
		Inventory.PickupMessage "Ate a mushroom stew. (+25 health)";
		Health.LowMessage 25, "Ate a mushroom stew you REALLY needed!";
	}
	States
	{
	Spawn:
		SSTW A -1;
		Stop;
	}
}

class SICDiamond : ArmorBonus replaces ArmorBonus
{
	Default
	{
		Scale 0.7;
		Inventory.PickupMessage "Found a diamond! (+1 armor)";
	}
	States
	{
	Spawn:
		SDIA A -1 Bright;
		Stop;
	}
}

// Experience orbs: they pop out of a beaten mob, then fly to you. Levels make your kicks stronger.
class SICXPOrb : Actor
{
	int age;

	Default
	{
		+NOBLOCKMAP
		+DROPOFF
		+NOTELEPORT
		+FORCEXYBILLBOARD
		+DONTSPLASH
		Radius 4;
		Height 8;
		Gravity 0.6;
		Scale 0.6;
	}
	States
	{
	Spawn:
		SXPO AB 4 Bright;
		Loop;
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || isFrozen()) return;
		age++;
		let mo = players[consoleplayer].mo;
		if (age > 35 * 25 || !mo) { Destroy(); return; }
		if (age < 14) return;
		Vector3 to = mo.pos + (0, 0, mo.height * 0.5) - pos;
		double d = to.Length();
		if (d < 28)
		{
			let h = SICHandler.Get();
			if (h) h.AddXP(1);
			mo.A_StartSound("sic/xp", CHAN_AUTO, CHANF_OVERLAP, 0.6, ATTN_NONE, frandom(0.9, 1.4));
			Destroy();
			return;
		}
		if (d < 900)
		{
			bNoGravity = true;
			double sp = min(4 + age * 0.15, 16);
			vel = to / d * sp;
		}
	}
}

// Doom's rocket launcher now fires blocks of TNT (same gun, plus a weapon-change check before each shot).
class SICTNTLauncher : RocketLauncher replaces RocketLauncher
{
	Default
	{
		Weapon.AmmoType "RocketAmmo";
		Tag "TNT Launcher";
		Inventory.PickupMessage "You got the TNT launcher!";
	}
	States
	{
	Ready:
		MISG A 0 A_SwitchFirst;
		MISG A 1 A_WeaponReady;
		Loop;
	Fire:
		MISG B 0 A_SwitchFirst;
		MISG B 8 A_GunFlash;
		MISG B 12 A_FireMissile;
		MISG B 0 A_ReFire;
		Goto Ready;
	}
	action void A_SwitchFirst()
	{
		if (player && player.PendingWeapon != WP_NOCHANGE && player.PendingWeapon != invoker)
			player.SetPsprite(PSP_WEAPON, invoker.FindState("Deselect"));
	}
}

// Doom's rocket launcher now fires blocks of TNT.
class SICTNTRocket : Rocket replaces Rocket
{
	Default
	{
		Scale 0.25;
		+FORCEXYBILLBOARD
		+ROLLSPRITE
		SeeSound "weapons/rocklf";
		DeathSound "sic/tnt";
		Obituary "%o caught %k's flying TNT.";
	}
	States
	{
	Spawn:
		STNT A 1 Bright
		{
			roll += 12;
			SICCube.Make(pos, random(0, 1) ? 'O' : 'S', frandom(0.3, 0.5), (frandom(-0.4, 0.4), frandom(-0.4, 0.4), 0.6), 18, 0);
		}
		Loop;
	Death:
		TNT1 A 1
		{
			A_Explode(128, 128);
			A_StartSound("sic/tnt", CHAN_BODY, 0, 1, ATTN_NORM);
			SICCube.Burst(pos, 'O', 20, 9, 0.6, 28, 0.3, 2);
			SICCube.Burst(pos, 'R', 12, 7, 0.5, 28, 0.3, 2);
			SICCube.Burst(pos, 'S', 14, 3, 0.9, 45, 0, 1.2);
		}
		Stop;
	}
}
