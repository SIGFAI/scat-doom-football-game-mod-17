// Grey Matter FC: blocky footballers in purple and gold kits replace Doom's monsters.
// Health and damage stay close to the monster they replace; they kick balls instead of shooting.

class SICFooty : Actor
{
	Default
	{
		Monster;
		+FLOORCLIP
		Radius 18;
		Height 56;
		Mass 100;
		Speed 9;
		PainChance 200;
		Scale 0.5;
		Species "GreyMatter";
		SeeSound "sic/mobsight";
		PainSound "sic/mobhurt";
		DeathSound "sic/mobdie";
		ActiveSound "sic/mobsight";
		Obituary "%o was tackled by Grey Matter FC.";
	}

	// One or several balls, fanned out by spread degrees.
	void A_KickAt(class<Actor> ball, double spread = 0, int n = 1)
	{
		A_StartSound("sic/kick", CHAN_WEAPON);
		for (int i = 0; i < n; i++) A_SpawnProjectile(ball, 14, 0, (i - (n - 1) / 2.) * spread);
	}

	// Gibbed by a rocket: an explosion of red and kit-coloured cubes.
	void A_Shatter()
	{
		A_StartSound("misc/gibbed", CHAN_BODY);
		SICCube.Burst(pos + (0, 0, height * 0.5), 'R', 18, 6, 0.45, 40, 0.8, 3);
		SICCube.Burst(pos + (0, 0, height * 0.5), 'P', 10, 6, 0.5, 40, 0.8, 3);
	}

	// Like a Minecraft mob, the body goes up in a puff of smoke.
	void A_Vanish()
	{
		Actor.Spawn("SICPoof", pos);
	}
}

class SICZombie : SICFooty replaces ZombieMan
{
	Default
	{
		Health 40;
		Speed 9;
		DropItem "Clip";
		Tag "Zombie Striker";
	}
	States
	{
	Spawn:
		SZOM A 10 A_Look;
		SZOM C 10 A_Look;
		Loop;
	See:
		SZOM ABCD 3 A_Chase;
		Loop;
	Missile:
		SZOM E 9 A_FaceTarget;
		SZOM F 6 A_KickAt("SICEnemyBall");
		SZOM E 6;
		Goto See;
	Pain:
		SZOM G 3;
		SZOM G 3 A_Pain;
		Goto See;
	Death:
		SZOM H 4;
		SZOM I 4 A_Scream;
		SZOM J 4 A_NoBlocking;
		SZOM K 30;
		SZOM K 1 A_Vanish;
		Stop;
	XDeath:
		SZOM H 3 A_Shatter;
		SZOM I 3 A_NoBlocking;
		SZOM JK 3;
		SZOM K 1 A_Vanish;
		Stop;
	}
}

class SICOrc : SICFooty replaces ShotgunGuy
{
	Default
	{
		Health 60;
		Speed 8;
		Radius 20;
		PainChance 170;
		DropItem "Shotgun";
		Tag "Orc Defender";
	}
	States
	{
	Spawn:
		SORC A 10 A_Look;
		SORC C 10 A_Look;
		Loop;
	See:
		SORC ABCD 3 A_Chase;
		Loop;
	Missile:
		SORC E 10 A_FaceTarget;
		SORC F 6 A_KickAt("SICEnemyBall", 9, 3);
		SORC E 8;
		Goto See;
	Pain:
		SORC G 3;
		SORC G 3 A_Pain;
		Goto See;
	Death:
		SORC H 4;
		SORC I 4 A_Scream;
		SORC J 4 A_NoBlocking;
		SORC K 30;
		SORC K 1 A_Vanish;
		Stop;
	XDeath:
		SORC H 3 A_Shatter;
		SORC I 3 A_NoBlocking;
		SORC JK 3;
		SORC K 1 A_Vanish;
		Stop;
	}
}

class SICRobot : SICFooty replaces ChaingunGuy
{
	Default
	{
		Health 70;
		Speed 8;
		PainChance 170;
		DropItem "Chaingun";
		Tag "Robo Winger";
	}
	States
	{
	Spawn:
		SROB A 10 A_Look;
		SROB C 10 A_Look;
		Loop;
	See:
		SROB ABCD 3 A_Chase;
		Loop;
	Missile:
		SROB E 8 A_FaceTarget;
		SROB F 4 A_KickAt("SICEnemyBall");
		SROB E 3 A_FaceTarget;
		SROB F 4 A_KickAt("SICEnemyBall");
		SROB E 3 A_FaceTarget;
		SROB F 4 A_KickAt("SICEnemyBall");
		SROB E 6;
		Goto See;
	Pain:
		SROB G 3;
		SROB G 3 A_Pain;
		Goto See;
	Death:
		SROB H 4;
		SROB I 4 A_Scream;
		SROB J 4 A_NoBlocking;
		SROB K 30;
		SROB K 1 A_Vanish;
		Stop;
	XDeath:
		SROB H 3 A_Shatter;
		SROB I 3 A_NoBlocking;
		SROB JK 3;
		SROB K 1 A_Vanish;
		Stop;
	}
}

class SICFireStriker : SICFooty replaces DoomImp
{
	Default
	{
		Health 60;
		Speed 8;
		Tag "Fire Striker";
		Obituary "%o was burned by the Fire Striker.";
		HitObituary "%o was slide-tackled by the Fire Striker.";
	}
	States
	{
	Spawn:
		SRBT A 10 A_Look;
		SRBT C 10 A_Look;
		Loop;
	See:
		SRBT ABCD 3 A_Chase;
		Loop;
	Melee:
	Missile:
		SRBT E 8 A_FaceTarget;
		SRBT F 6 A_SlideOrFire;
		SRBT E 6;
		Goto See;
	Pain:
		SRBT G 3;
		SRBT G 3 A_Pain;
		Goto See;
	Death:
		SRBT H 4;
		SRBT I 4 A_Scream;
		SRBT J 4 A_NoBlocking;
		SRBT K 30;
		SRBT K 1 A_Vanish;
		Stop;
	XDeath:
		SRBT H 3 A_Shatter;
		SRBT I 3 A_NoBlocking;
		SRBT JK 3;
		SRBT K 1 A_Vanish;
		Stop;
	}

	void A_SlideOrFire()
	{
		if (target && CheckMeleeRange()) { A_CustomMeleeAttack(random(1, 8) * 3, "sic/ballhit", "sic/kick"); return; }
		A_KickAt("SICFireBall");
	}
}

class SICPig : SICFooty replaces Demon
{
	Default
	{
		Health 150;
		Speed 12;
		Radius 28;
		Height 48;
		Mass 400;
		PainChance 180;
		SeeSound "sic/pigsquee";
		PainSound "sic/pigsquee";
		DeathSound "sic/pigsquee";
		ActiveSound "sic/pigsquee";
		Tag "Pig Tackler";
		Obituary "%o was flattened by the Pig Tackler.";
		HitObituary "%o was flattened by the Pig Tackler.";
	}
	States
	{
	Spawn:
		SPIG A 10 A_Look;
		SPIG C 10 A_Look;
		Loop;
	See:
		SPIG ABCD 2 A_Chase;
		Loop;
	Melee:
		SPIG E 6 A_FaceTarget;
		SPIG F 6 A_CustomMeleeAttack(random(1, 10) * 4, "sic/ballhit");
		SPIG E 4;
		Goto See;
	Pain:
		SPIG G 3;
		SPIG G 3 A_Pain;
		Goto See;
	Death:
		SPIG H 4;
		SPIG I 4 A_Scream;
		SPIG J 4 A_NoBlocking;
		SPIG K 30;
		SPIG K 1 A_Vanish;
		Stop;
	XDeath:
		SPIG H 3 A_Shatter;
		SPIG I 3 A_NoBlocking;
		SPIG JK 3;
		SPIG K 1 A_Vanish;
		Stop;
	}
}

class SICGhostPig : SICPig replaces Spectre
{
	Default
	{
		RenderStyle "Translucent";
		Alpha 0.4;
		+SHADOW
		Tag "Ghost Pig";
	}
	States
	{
	Spawn:
		SPIG A 10 A_Look;
		SPIG C 10 A_Look;
		Loop;
	See:
		SPIG ABCD 2 A_Chase;
		Loop;
	Melee:
		SPIG E 6 A_FaceTarget;
		SPIG F 6 A_CustomMeleeAttack(random(1, 10) * 4, "sic/ballhit");
		SPIG E 4;
		Goto See;
	Pain:
		SPIG G 3;
		SPIG G 3 A_Pain;
		Goto See;
	Death:
		SPIG H 4;
		SPIG I 4 A_Scream;
		SPIG J 4 A_NoBlocking;
		SPIG K 30;
		SPIG K 1 A_Vanish;
		Stop;
	XDeath:
		SPIG H 3 A_Shatter;
		SPIG I 3 A_NoBlocking;
		SPIG JK 3;
		SPIG K 1 A_Vanish;
		Stop;
	}}

