// The goal: white block posts and a net, built from wall sprites so it has real depth.
// The mouth faces the goal's angle; a cube football that crosses the mouth line between the posts is a GOAL.

class SICGoal : Actor
{
	const GW = 160;   // width between the outer edges of the posts
	const GH = 72;
	const GD = 48;
	const POST = 8;

	Actor back, roof;
	int shakeUntil;
	bool home;   // Doom FC's own goal (map arg 0 = 1): a Grey Matter ball in here scores for the cat

	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+DONTSPLASH
		Radius 1;
		Height 1;
	}

	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}

	Vector2 Fwd() { return AngleToVector(angle); }
	Vector2 Lat() { return AngleToVector(angle + 90); }

	Actor Part(Vector2 off, double z, double ang, StateLabel st, bool flat = false)
	{
		Vector2 p = pos.xy + Fwd() * off.x + Lat() * off.y;
		let a = Actor.Spawn("SICGoalPart", (p, pos.z + z));
		a.angle = ang;
		a.SetStateLabel(st);
		if (flat) { a.bWallSprite = false; a.bFlatSprite = true; }
		return a;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		SetZ(floorz);
		home = args[0] == 1;
		Part((0, 0), 0, angle, "Front");
		back = Part((-GD, 0), 0, angle, "Back");
		Part((-GD / 2, GW / 2 - 1), 0, angle + 90, "Side");
		Part((-GD / 2, -GW / 2 + 1), 0, angle + 90, "Side");
		roof = Part((-GD / 2, 0), GH, angle + 90, "Roof", true);
		// Solid posts (balls ring off them, players and mobs bump into them).
		for (int s = -1; s <= 1; s += 2)
		{
			Vector2 lat = Lat() * s * (GW / 2 - POST / 2);
			Actor.Spawn("SICPost", (pos.xy + lat, pos.z));
			Actor.Spawn("SICPost", (pos.xy + lat - Fwd() * (GD - 4), pos.z));
			// The side nets: nobody walks through them.
			for (double d = 12; d < GD - 6; d += 10) Actor.Spawn("SICNetBlock", (pos.xy + lat - Fwd() * d, pos.z));
		}
		for (double l = -GW / 2 + 10; l < GW / 2 - 6; l += 10) Actor.Spawn("SICNetBlock", (pos.xy + Lat() * l - Fwd() * (GD - 2), pos.z));
		let h = SICHandler.Get();
		if (h) h.goals.Push(self);
	}

	// Local coordinates of a point: x along the mouth's facing (negative = inside), y across, z up.
	Vector3 Local(Vector3 p)
	{
		Vector2 d = p.xy - pos.xy;
		return (d dot Fwd(), d dot Lat(), p.z - pos.z);
	}

	bool Between(Vector3 l) { return abs(l.y) < GW / 2 - POST && l.z < GH - 4 && l.z > -8; }

	static void CheckAll(Actor ball, Vector3 old, bool playerBall)
	{
		let h = SICHandler.Get();
		if (!h) return;
		for (int i = 0; i < h.goals.Size(); i++)
		{
			let g = h.goals[i];
			if (!g || (!playerBall && !g.home)) continue;
			Vector3 a = g.Local(old), b = g.Local(ball.pos);
			if (a.x >= 0 && b.x < 0 && g.Between(b) && b.x > -GD - 8)
			{
				g.Scored(ball);
				return;
			}
		}
	}

	void Scored(Actor ball)
	{
		shakeUntil = level.maptime + 24;
		SICCube.Burst(ball.pos, 'W', 16, 5, 0.4, 30, 0.4);
		SICCube.Burst(ball.pos, 'G', 10, 5, 0.4, 30, 0.4);
		ball.Destroy();
		for (int s = -1; s <= 1; s += 2)
			for (int k = 0; k < 3; k++)
				SICFirework.Launch((pos.xy + Lat() * s * (GW / 2), pos.z + GH), k * 9);
		let h = SICHandler.Get();
		if (h) h.Goal(self, !home);
	}

	override void Tick()
	{
		Super.Tick();
		// The net bulges when the ball hits it.
		if (back && level.maptime < shakeUntil)
		{
			double t = (shakeUntil - level.maptime) / 24.;
			Vector2 base = pos.xy - Fwd() * GD;
			back.SetOrigin((base - Fwd() * sin(level.maptime * 70) * 6 * t, back.pos.z), true);
		}
	}
}

class SICGoalPart : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+WALLSPRITE
		+DONTSPLASH
		Scale 0.5;
		Radius 1;
		Height 1;
	}
	States
	{
	Spawn:
	Front:
		SGOL A -1;
		Stop;
	Back:
		SGOL B -1;
		Stop;
	Side:
		SGOL C -1;
		Stop;
	Roof:
		SGOL D -1;
		Stop;
	}
}

// The net: solid for players and mobs, but footballs fly into it.
class SICNetBlock : Actor
{
	Default
	{
		+SOLID
		+NOTAUTOAIMED
		+DONTSPLASH
		+NOBLOOD
		Radius 6;
		Height 72;
	}
	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}
}

// Invisible but solid goal posts.
class SICPost : Actor
{
	Default
	{
		+SOLID
		+NOTAUTOAIMED
		+DONTSPLASH
		Radius 5;
		Height 72;
	}
	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}
}

// A fan in the stands. Waves now and then, and the whole stadium jumps and cheers when a goal goes in.
class SICFan : Actor
{
	int phase, hop;
	double baseZ;
	static const Name LOOKS[] = { 'FANA', 'FANB', 'FANC', 'FAND', 'FANE', 'FANF', 'FANG', 'FANH' };

	Default
	{
		+NOBLOCKMAP
		+NOINTERACTION
		+NOTONAUTOMAP
		Scale 0.5;
		Radius 8;
		Height 56;
	}
	States
	{
	Spawn:
		FANA A -1;
		FANB A -1;
		FANC A -1;
		FAND A -1;
		FANE A -1;
		FANF A -1;
		FANG A -1;
		FANH A -1;
	Cheer:
		FANA B -1;
		FANB B -1;
		FANC B -1;
		FAND B -1;
		FANE B -1;
		FANF B -1;
		FANG B -1;
		FANH B -1;
		Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		baseZ = floorz;
		SetZ(baseZ);
		phase = random(0, 99);
		sprite = GetSpriteIndex(LOOKS[random(0, LOOKS.Size() - 1)]);
		frame = 0;
	}

	override void Tick()
	{
		// No physics: just arms and hops, read from the match excitement.
		let h = SICHandler.Get();
		int ex = h ? h.excite : 0;
		int t = level.maptime + phase;
		if (ex > 0)
		{
			frame = (t / 5) % 2;
			double z = baseZ + abs(sin(t * 20)) * 10 * min(ex, 70) / 70.;
			SetZ(z);
		}
		else
		{
			frame = (t % 140) < 12 ? 1 : 0;
			if (pos.z != baseZ) SetZ(baseZ);
		}
	}
}
