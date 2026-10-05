// The player's weapon: a boot and an endless supply of cube footballs.

class SICBoot : Weapon
{
	Default
	{
		Weapon.SlotNumber 1;
		Weapon.SelectionOrder 50;
		Weapon.BobStyle "Smooth";
		Weapon.BobSpeed 1.6;
		Weapon.BobRangeX 0.6;
		Weapon.BobRangeY 0.5;
		+WEAPON.AMMO_OPTIONAL
		+WEAPON.NOALERT
		Inventory.PickupMessage "You got the Cube Football!";
		Tag "Cube Football";
	}

	States
	{
	Spawn:
		SBAL A -1;
		Stop;
	Ready:
		KICK A 0 A_SwitchFirst;
		KICK A 1 A_WeaponReady;
		Loop;
	Deselect:
		KICK A 1 A_Lower(12);
		Loop;
	Select:
		KICK A 1 A_Raise(12);
		Loop;
	Fire:
		KICK B 0 A_SwitchFirst;
		KICK B 2;
		KICK C 2 A_KickBall;
		KICK D 4;
		KICK E 3;
		TNT1 A 3 A_WeaponOffset(0, 100);
		KICK AAAAAA 1 A_WeaponOffset(0, -11.33, WOF_ADD | WOF_INTERPOLATE);
		KICK A 0 A_WeaponOffset(0, 32);
		Goto Ready;
	}

	// A pending weapon change wins over the next kick (the demo pilot fires the moment the boot is ready).
	action void A_SwitchFirst()
	{
		if (player && player.PendingWeapon != WP_NOCHANGE && player.PendingWeapon != invoker)
			player.SetPsprite(PSP_WEAPON, invoker.FindState("Deselect"));
	}

	action void A_KickBall()
	{
		A_StartSound("sic/kick", CHAN_WEAPON);
		A_AlertMonsters();
		A_FireProjectile("SICBall", frandom(-1, 1), false, 0, -14, 0, -2.5);
	}
}

// The cube football. Bounces off walls and floors, knocks mobs back, and scores when it enters a goal.
class SICBall : Actor
{
	Default
	{
		Projectile;
		-NOGRAVITY
		+FORCEXYBILLBOARD
		Gravity 0.12;
		Radius 7;
		Height 12;
		Speed 34;
		DamageFunction (SICHandler.BallDamage());
		DamageType "Football";
		BounceType "Doom";
		BounceFactor 0.55;
		WallBounceFactor 0.8;
		BounceCount 5;
		BounceSound "sic/bounce";
		DeathSound "sic/ballhit";
		Scale 0.5;
		Obituary "%o was nutmegged by a cube football.";
	}

	States
	{
	Spawn:
		SBAL ABCDEFGH 2;
		Loop;
	Death:
	XDeath:
	Crash:
		TNT1 A 1 Impact;
		Stop;
	}

	virtual bool Scores() { return true; }

	void Impact()
	{
		SICCube.Burst(pos, 'W', 10, 4, 0.35, 22, 0.5, 1);
		SICCube.Burst(pos, 'S', 4, 3, 0.3, 18, 0.5, 1);
		// The ball itself pops off the target and rolls away.
		let l = Actor.Spawn("SICLooseBall", pos);
		if (l) { l.vel = (-vel.x * 0.15 + frandom(-2, 2), -vel.y * 0.15 + frandom(-2, 2), 5); l.translation = translation; }
	}

	override int SpecialMissileHit(Actor victim)
	{
		if (victim is "SICNetBlock") return 1;
		if (victim is "SICPost")
		{
			// Off the post! It rings and bounces back onto the pitch.
			vel.xy = -vel.xy * 0.7;
			A_StartSound("sic/bounce", CHAN_AUTO, 0, 1.0, ATTN_NORM, 0.6);
			if (Scores()) SICHandler.Get().Post();
			return 1;
		}
		// A real kick: the victim is sent flying (lighter mobs fly further).
		if (victim.bShootable && !victim.player && !victim.bDormant && !victim.bDontThrust && target != victim)
		{
			double k = 900. / max(victim.mass, 60);
			victim.vel.xy += vel.xy.Unit() * min(k, 11);
			if (victim.mass < 400) victim.vel.z += min(k * 0.5, 5);
		}
		return -1;
	}

	override void Tick()
	{
		Vector3 old = pos;
		Super.Tick();
		if (bDestroyed || isFrozen()) return;
		if (level.maptime % 2 == 0) SICCube.Make(pos, 'W', 0.22, (0, 0, 0), 10, 0);
		SICGoal.CheckAll(self, old, Scores());
	}
}

// After a hit the ball drops, bounces a few times and vanishes in a puff.
class SICLooseBall : Actor
{
	Default
	{
		+NOBLOCKMAP
		+DROPOFF
		+FORCEXYBILLBOARD
		Radius 6;
		Height 12;
		Gravity 0.7;
		Scale 0.5;
	}

	States
	{
	Spawn:
		SBAL ABCDEFGH 3;
		SBAL ABCDEFGH 3;
		SBAL ABCD 4;
		SBAL E 1 { SICCube.Burst(pos, 'W', 8, 2, 0.35, 18, 0); }
		Stop;
	}

	override void Tick()
	{
		double vz = vel.z;
		Super.Tick();
		if (bDestroyed) return;
		if (pos.z <= floorz && vz < -2) { vel.z = -vz * 0.5; A_StartSound("sic/bounce", CHAN_AUTO, 0, 0.5); }
		vel.xy *= 0.97;
	}
}

// Balls the Grey Matter FC players kick back at you.
class SICEnemyBall : SICBall
{
	Default
	{
		Speed 20;
		Gravity 0.05;
		BounceCount 1;
		DamageFunction (random(2, 4) * 3);
		Scale 0.3;
		Translation "0:255=%[0.05,0.0,0.15]:[1.3,0.9,2.0]";
		Obituary "%o was nutmegged by Grey Matter FC.";
	}
	override bool Scores() { return false; }
}

// The Fire Striker's flaming ball: an orange ball trailing fire cubes.
class SICFireBall : SICEnemyBall
{
	Default
	{
		Speed 16;
		Gravity 0;
		DamageFunction (random(3, 8) * 3);
		Translation "0:255=%[0.3,0.05,0.0]:[2.0,1.4,0.3]";
		Obituary "%o took a scorcher from the Fire Striker.";
	}
	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || isFrozen()) return;
		SICCube.Make(pos + (frandom(-3, 3), frandom(-3, 3), frandom(-3, 3)), random(0, 1) ? 'O' : 'R', frandom(0.25, 0.45), (frandom(-0.5, 0.5), frandom(-0.5, 0.5), frandom(0.5, 1.5)), 14, 0);
	}
}

// The cat's calculated shot: a golden ball aimed where you are going to be.
class SICCatBall : SICEnemyBall
{
	Default
	{
		Speed 26;
		Gravity 0;
		DamageFunction (15);
		Translation "0:255=%[0.25,0.15,0.0]:[2.0,1.7,0.5]";
		Obituary "%o was out-calculated by the SuperIntelligent Cat.";
	}
	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || isFrozen()) return;
		if (level.maptime % 2) SICCube.Make(pos, 'G', 0.3, (0, 0, 0), 12, 0);
	}
}

// A red card, thrown spinning like a ninja star.
class SICRedCard : Actor
{
	Default
	{
		Projectile;
		+ROLLSPRITE
		+FORCEXYBILLBOARD
		Radius 6;
		Height 8;
		Speed 22;
		DamageFunction (20);
		Scale 0.6;
		DeathSound "sic/ballhit";
		Obituary "%o was sent off by the SuperIntelligent Cat.";
	}
	States
	{
	Spawn:
		SCRD A 1 { roll += 30; if (level.maptime % 2) SICCube.Make(pos, 'R', 0.25, (0, 0, 0), 10, 0); }
		Loop;
	Death:
		SCRD A 1 { SICCube.Burst(pos, 'R', 8, 3, 0.3, 18, 0.5); }
		Stop;
	}
}
