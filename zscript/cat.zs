// The SuperIntelligent Cat: Grey Matter FC's goalkeeper, captain and manager. Far too clever for its own good:
// it slides along its goal line to stand between you and the net, dodges any kick it sees coming (and so lets
// the ball into its own goal), stops to "calculate the optimal save" while you pelt it, fires shots aimed where
// you will be, hands out red cards and calls substitutes. Every goal it concedes bruises its ego (and its health).

class SICCat : Actor
{
	SICGoal goal;
	int nextCalc, calcStart, calcUntil, dodgeReady, dodgedAt, nextSub, shots;
	bool greeted;

	const CALC_TICS = 90;

	Default
	{
		Monster;
		+BOSS
		+DONTMORPH
		+FLOORCLIP
		+NOINFIGHTING
		+DONTTHRUST
		Health 700;
		Radius 28;
		Height 80;
		Mass 600;
		Speed 6;
		PainChance 60;
		MinMissileChance 120;
		Species "GreyMatter";
		Scale 0.5;
		PainSound "sic/cathurt";
		DeathSound "sic/catdie";
		ActiveSound "sic/meow";
		Tag "SuperIntelligent Cat";
		Obituary "%o was out-thought by the SuperIntelligent Cat.";
		HitObituary "%o was out-thought by the SuperIntelligent Cat.";
	}

	States
	{
	Spawn:
		SCAT A 10 A_Look;
		SCAT C 10 A_Look;
		Loop;
	See:
		SCAT ABCD 3 A_Keep;
		Loop;
	Missile:
		SCAT E 10 A_FaceTarget;
		SCAT F 8 A_CatShot;
		SCAT E 8 A_FaceTarget;
		Goto See;
	Calc:
		SCAT E 2 A_Calc;
		Loop;
	Pain:
		SCAT G 4;
		SCAT G 4 A_Pain;
		Goto See;
	Death:
		SCAT H 6 A_CatDown;
		SCAT I 6;
		SCAT J 6 A_NoBlocking;
		SCAT K -1;
		Stop;
	}

	SICHandler H() { return SICHandler.Get(); }

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		// It calculated a blast shield: explosions and bullets barely bother it. Footballs and goals do.
		if (mod != 'Football' && mod != 'Ego') damage = max(1, damage * 3 / 10);
		int r = Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
		return r;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		let h = H();
		if (h && !h.cat) h.cat = self;
		if (goal) return;
		// Placed in a map: it keeps the nearest opponents' goal.
		let it = ThinkerIterator.Create("SICGoal");
		SICGoal g;
		while (g = SICGoal(it.Next()))
			if (g.args[0] != 1 && Distance2D(g) < 256 && (!goal || Distance2D(g) < Distance2D(goal))) goal = g;
	}

	clearscope bool Calculating() { return InStateSequence(CurState, FindState("Calc")); }

	void A_Keep()
	{
		let st = CurState;
		A_Chase(null, "Missile", goal ? CHF_DONTMOVE : 0);
		if (CurState != st || !target || health <= 0) return;
		if (!greeted)
		{
			greeted = true;
			nextCalc = level.maptime + 35 * 7;
			nextSub = level.maptime + 35 * 10;
			H().CatLine(1, self, true);
		}
		if (goal && level.maptime > dodgedAt + 20) KeepGoal();
		if (level.maptime >= nextSub && H().FootiesNear(self, 1500) < 2) { Substitute(); return; }
		if (level.maptime >= nextCalc)
		{
			nextCalc = level.maptime + 35 * 9;
			calcStart = level.maptime;
			calcUntil = level.maptime + CALC_TICS;
			A_StartSound("sic/meow", CHAN_VOICE, 0, 1, ATTN_NONE, 0.8);
			SetStateLabel("Calc");
		}
	}

	// Stand on the line between the ball's owner and the middle of the goal.
	void KeepGoal()
	{
		Vector2 f = goal.Fwd(), l = goal.Lat();
		Vector2 d = target.pos.xy - goal.pos.xy;
		double tf = d dot f, tl = d dot l;
		double want = tf > 40 ? tl * 30 / tf : 0;
		want = clamp(want, -52, 52);
		Vector2 dest = goal.pos.xy + f * 46 + l * want;
		Vector2 mv = dest - pos.xy;
		double dist = mv.Length();
		if (dist > 2) TryMove(pos.xy + mv / dist * min(speed, dist), 0);
		A_FaceTarget();
	}

	void A_Calc()
	{
		A_FaceTarget();
		// Thinking hard, but it never wanders into its own net.
		if (goal && ((pos.xy - goal.pos.xy) dot goal.Fwd()) < 44) TryMove(pos.xy + goal.Fwd() * 2, 0);
		double t = level.maptime * 18;
		SICCube.Make(pos + (cos(t) * 34, sin(t) * 34, height + 6), 'G', 0.35, (0, 0, 0.6), 14, 0);
		SICCube.Make(pos + (cos(t + 180) * 34, sin(t + 180) * 34, height + 6), 'W', 0.3, (0, 0, 0.6), 14, 0);
		if (level.maptime >= calcUntil)
		{
			if (random(0, 1)) SetStateLabel("Missile"); else SetStateLabel("See");
		}
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || health <= 0 || isFrozen() || !target) return;
		if (level.maptime >= dodgeReady && !Calculating()) TryDodge();
	}

	// A kick is coming: the cat sees it, computes it, and jumps out of the way of its own goal.
	void TryDodge()
	{
		// (Projectiles are not returned by BlockThingsIterator here: walk the few balls in play instead.)
		let it = ThinkerIterator.Create("SICBall");
		SICBall b;
		while (b = SICBall(it.Next()))
		{
			if (!b || !b.Scores() || b.bDestroyed) continue;
			Vector3 to = pos + (0, 0, height * 0.5) - b.pos;
			double dist = to.Length(), sp = b.vel.Length();
			if (dist > 320 || sp < 4 || (b.vel dot to) < 0.9 * sp * dist) continue;
			dodgeReady = level.maptime + 80;
			if (random(0, 99) >= 80) return; // misjudged it: takes the ball in the face
			Vector2 lat = goal ? goal.Lat() : AngleToVector(angle + 90);
			double side = random(0, 1) ? 1 : -1;
			if (goal)
			{
				// Jump toward the side with more room on the goal line.
				double off = (pos.xy - goal.pos.xy) dot lat;
				side = off > 0 ? -1 : 1;
				if (abs(off) < 15) side = random(0, 1) ? 1 : -1;
			}
			vel.xy += lat * side * 12;
			vel.z += 6;
			dodgedAt = level.maptime;
			A_StartSound("sic/meow", CHAN_VOICE, 0, 1, ATTN_NORM, 1.2);
			H().Shout("DODGED!", Font.CR_WHITE, 30);
			H().CatLine(3, self);
			return;
		}
	}

	void A_CatShot()
	{
		if (!target) return;
		shots++;
		if (shots % 3 == 0 || (Distance2D(target) < 240 && shots % 2 == 0))
		{
			// Red card, thrown spinning.
			A_StartSound("sic/whistle", CHAN_AUTO, 0, 1, ATTN_NONE);
			A_SpawnProjectile("SICRedCard", 44);
			H().CatLine(5, self);
			return;
		}
		// The calculated shot: aimed where the target will be, with two more covering both dodges.
		A_StartSound("sic/kick", CHAN_WEAPON);
		double t = Distance3D(target) / 26.;
		Vector3 aim = target.pos + target.vel * t + (0, 0, target.height * 0.5);
		angle = VectorAngle(aim.x - pos.x, aim.y - pos.y);
		double pt = -VectorAngle((aim.xy - pos.xy).Length(), aim.z - (pos.z + 40));
		int spread = shots % 4 == 1 ? 1 : 0;   // now and then two more cover both dodges
		for (int i = -spread; i <= spread; i++) A_SpawnProjectile("SICCatBall", 40, 0, i * 9, CMF_AIMDIRECTION, pt);
	}

	void Substitute()
	{
		nextSub = level.maptime + 35 * 18;
		A_StartSound("sic/whistle", CHAN_AUTO, 0, 1, ATTN_NONE);
		H().CatLine(2, self, true);
		static const Name SUBS[] = { 'SICZombie', 'SICOrc', 'SICRobot', 'SICFireStriker', 'SICZombie', 'SICOrc', 'SICPig' };
		Vector2 f = goal ? goal.Fwd() : AngleToVector(angle);
		Vector2 l = goal ? goal.Lat() : AngleToVector(angle + 90);
		for (int s = -1; s <= 1; s += 2)
		{
			Vector2 xy = pos.xy + f * 110 + l * s * 80;
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			let m = Actor.Spawn(SUBS[random(0, SUBS.Size() - 1)], (xy, z), ALLOW_REPLACE);
			if (!m) continue;
			if (!m.TestMobjLocation()) { m.Destroy(); continue; }
			Actor.Spawn("SICPoof", m.pos);
			m.target = target;
			m.angle = angle;
			m.SetState(m.SeeState);
		}
	}

	void A_CatDown()
	{
		A_Scream();
		H().FullTime(self);
	}
}
