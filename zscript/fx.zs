// Blocky effects: every spark, drop of blood, puff of smoke and firework is a little cube, like in Minecraft.

class SICCube : Actor
{
	int life, maxLife;
	double baseScale;

	Default
	{
		+NOBLOCKMAP
		+NOTELEPORT
		+DONTSPLASH
		+NOTONAUTOMAP
		+THRUACTORS
		+FORCEXYBILLBOARD
		Radius 1;
		Height 1;
		Gravity 0.7;
		Scale 0.4;
	}

	States
	{
	Spawn:
		SQRW AB -1;
		Stop;
	R:
		SQRR AB -1;
		Stop;
	O:
		SQRO AB -1;
		Stop;
	B:
		SQRB AB -1;
		Stop;
	G:
		SQRG AB -1;
		Stop;
	P:
		SQRP AB -1;
		Stop;
	N:
		SQRN AB -1;
		Stop;
	K:
		SQRK AB -1;
		Stop;
	S:
		SQRS AB -1;
		Stop;
	}

	// col: W white, R red, O orange, B blue, G gold, P purple, N green, K pink, S grey.
	static SICCube Make(Vector3 pos, Name col, double size, Vector3 vel, int life = 35, double grav = 0.7)
	{
		let c = SICCube(Actor.Spawn("SICCube", pos));
		if (!c) return null;
		switch (col)
		{
		case 'R': c.SetStateLabel("R"); break;
		case 'O': c.SetStateLabel("O"); break;
		case 'B': c.SetStateLabel("B"); break;
		case 'G': c.SetStateLabel("G"); break;
		case 'P': c.SetStateLabel("P"); break;
		case 'N': c.SetStateLabel("N"); break;
		case 'K': c.SetStateLabel("K"); break;
		case 'S': c.SetStateLabel("S"); break;
		}
		if (random(0, 1)) c.SetState(c.CurState.NextState ? c.CurState.NextState : c.CurState);
		c.vel = vel;
		c.baseScale = size;
		c.scale = (size, size);
		c.life = c.maxLife = life;
		c.gravity = grav;
		c.bNoGravity = grav <= 0;
		return c;
	}

	// A ball of cubes flying out of pos. up adds a lift so gibs pop upward.
	static void Burst(Vector3 pos, Name col, int n, double speed, double size, int life = 35, double grav = 0.7, double up = 0)
	{
		for (int i = 0; i < n; i++)
		{
			double a = frandom(0, 360), p = frandom(-80, 80), s = speed * frandom(0.4, 1.0);
			Vector3 v = (cos(a) * cos(p) * s, sin(a) * cos(p) * s, sin(p) * s + up);
			Make(pos + (frandom(-4, 4), frandom(-4, 4), frandom(-4, 4)), col, size * frandom(0.7, 1.2), v, life + random(-8, 8), grav);
		}
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed) return;
		if (--life <= 0) { Destroy(); return; }
		if (life < 10) scale = (baseScale, baseScale) * (life / 10.);
		if (pos.z <= floorz + 1 && !bNoGravity) vel.xy *= 0.8;
	}
}

// A mob's death poof (white and grey smoke cubes rising), as in Minecraft.
class SICPoof : Actor
{
	Default { +NOINTERACTION +NOBLOCKMAP }
	States
	{
	Spawn:
		TNT1 A 1 NoDelay
		{
			A_StartSound("sic/poof", CHAN_AUTO, 0, 1.0, ATTN_NORM);
			SICCube.Burst(pos + (0, 0, 24), 'W', 22, 2.5, 0.9, 30, 0, 0.8);
			SICCube.Burst(pos + (0, 0, 16), 'S', 10, 2.0, 0.8, 26, 0, 0.6);
		}
		Stop;
	}
}

class SICBlood : Blood replaces Blood
{
	// Blood keeps three entry states (the engine picks one by damage): each throws red cubes.
	States
	{
	Spawn:
		TNT1 A 1 NoDelay Bleed(7);
		Stop;
		TNT1 A 1 Bleed(5);
		Stop;
		TNT1 A 1 Bleed(3);
		Stop;
	}

	void Bleed(int n)
	{
		SICCube.Burst(pos, 'R', n, 4, 0.35, 30, 0.8, 2);
	}
}

class SICPuff : BulletPuff replaces BulletPuff
{
	States
	{
	Spawn:
	Melee:
		TNT1 A 1 NoDelay
		{
			SICCube.Burst(pos, 'S', 5, 3, 0.3, 20, 0.6, 1);
			SICCube.Burst(pos, 'W', 2, 2, 0.25, 14, 0, 0.5);
		}
		Stop;
	}
}

// Fireworks for a goal: a rocket of cubes climbs, then bursts into a coloured sphere.
class SICFirework : Actor
{
	int fuse;
	Name col;

	Default { +NOINTERACTION +NOBLOCKMAP Scale 0.6; }
	States
	{
	Spawn:
		SQRW A -1;
		Stop;
	}

	static void Launch(Vector3 pos, int delay)
	{
		static const Name COLS[] = { 'R', 'G', 'B', 'P', 'N', 'K', 'O' };
		let f = SICFirework(Actor.Spawn("SICFirework", pos));
		if (!f) return;
		f.fuse = 22 + delay + random(0, 10);
		f.col = COLS[random(0, COLS.Size() - 1)];
		f.vel = (frandom(-1.5, 1.5), frandom(-1.5, 1.5), frandom(9, 12));
		f.bInvisible = delay > 0;
		f.reactiontime = delay;
	}

	override void Tick()
	{
		if (reactiontime > 0) { reactiontime--; if (!reactiontime) { bInvisible = false; A_StartSound("sic/firework", CHAN_AUTO, 0, 0.5); } return; }
		Super.Tick();
		vel.z -= 0.25;
		if (level.maptime % 2 == 0) SICCube.Make(pos, 'O', 0.3, (0, 0, -1), 12, 0);
		if (--fuse <= 0)
		{
			A_StartSound("sic/firework", CHAN_AUTO, 0, 1.0, ATTN_NONE);
			SICCube.Burst(pos, col, 34, 9, 0.6, 40, 0.12);
			SICCube.Burst(pos, 'W', 12, 6, 0.4, 30, 0.12);
			Destroy();
		}
	}
}
