// The match: kick-off, the cat's goal in every map, score, XP levels, the cat's lines, and the TV-style HUD.

class SICHandler : EventHandler
{
	Array<SICGoal> goals;
	SICCat cat;
	int doomScore, catScore, lastCatGoal;
	int xp, xpLevel;
	String shoutText;
	int shoutColor, shoutAt, shoutTics;
	String sub;
	int subAt, subTics, lineAt;
	int fullTimeAt;
	int excite;   // the crowd jumps and cheers while this counts down

	static const String LINES[] = {
		"",
		"I have simulated fourteen million matches. You lose all of them.",
		"Substitution! Fresh legs, please.",
		"Predictable. I saw that shot three moves ago.",
		"That was... statistically impossible.",
		"Red card. For you. For existing.",
		"Impossible! My calculations were perfect!"
	};
	static const int LINE_TICS[] = { 0, 160, 105, 115, 95, 125, 110 };

	static SICHandler Get() { return SICHandler(EventHandler.Find("SICHandler")); }

	static int BallDamage()
	{
		let h = Get();
		return 25 + 3 * (h ? h.xpLevel : 0);
	}

	clearscope int XPNeed() { return 6 + 3 * xpLevel; }

	void AddXP(int n)
	{
		xp += n;
		if (xp >= XPNeed())
		{
			xp -= XPNeed();
			xpLevel++;
			Shout("LEVEL UP!", Font.CR_GREEN, 55);
			let mo = players[consoleplayer].mo;
			if (mo) mo.A_StartSound("sic/xp", CHAN_AUTO, CHANF_OVERLAP, 1, ATTN_NONE, 0.7);
		}
	}

	int postAt;
	void Post()
	{
		if (level.maptime - postAt < 105) return;
		postAt = level.maptime;
		Shout("OFF THE POST!", Font.CR_WHITE, 50);
		excite = max(excite, 25);
	}

	void Shout(String t, int col, int tics)
	{
		shoutText = t;
		shoutColor = col;
		shoutAt = level.maptime;
		shoutTics = tics;
	}

	// One of the cat's voice lines, with its subtitle. force: even if it spoke a moment ago.
	int lineLast[7];
	void CatLine(int n, Actor who, bool force = false)
	{
		if (!force && (level.maptime < lineAt || (lineLast[n] && level.maptime - lineLast[n] < 35 * 20))) return;
		lineLast[n] = level.maptime;
		lineAt = level.maptime + LINE_TICS[n] + 70;
		sub = LINES[n];
		subAt = level.maptime;
		subTics = LINE_TICS[n] + 20;
		if (who) who.A_StartSound(String.Format("sic/cat%d", n), CHAN_VOICE, 0, 1, ATTN_NONE);
	}

	void Goal(SICGoal g, bool forDoom)
	{
		let mo = players[consoleplayer].mo;
		if (!forDoom)
		{
			if (level.maptime - lastCatGoal < 175) return;
			lastCatGoal = level.maptime;
			catScore++;
			Shout("GREY MATTER FC SCORES", Font.CR_PURPLE, 70);
			if (mo) mo.A_StartSound("sic/boo", CHAN_AUTO, CHANF_OVERLAP, 1, ATTN_NONE);
			return;
		}
		doomScore++;
		excite = 150;
		if (mo)
		{
			mo.A_StartSound("sic/goal", CHAN_AUTO, CHANF_OVERLAP, 1, ATTN_NONE);
			mo.A_StartSound("sic/whistle", CHAN_AUTO, CHANF_OVERLAP, 0.8, ATTN_NONE);
		}
		Shout("GOAL!", Font.CR_GOLD, 80);
		if (cat && cat.health > 0)
		{
			// Every goal bruises the genius's ego.
			cat.DamageMobj(null, null, 50, 'Ego', DMG_NO_ARMOR | DMG_FORCED);
			if (cat && cat.health > 0) CatLine(level.maptime - cat.dodgedAt < 60 ? 4 : random(0, 1) ? 4 : 3, cat, true);
		}
	}

	void FullTime(Actor c)
	{
		fullTimeAt = level.maptime;
		excite = 400;
		CatLine(6, c, true);
		Shout("FULL TIME!", Font.CR_GOLD, 140);
		let mo = players[consoleplayer].mo;
		if (mo)
		{
			mo.A_StartSound("sic/whistle3", CHAN_AUTO, CHANF_OVERLAP, 1, ATTN_NONE);
			mo.A_StartSound("sic/goal", CHAN_AUTO, CHANF_OVERLAP, 1, ATTN_NONE);
		}
		for (int k = 0; k < 10; k++)
			SICFirework.Launch(c.pos + (frandom(-120, 120), frandom(-120, 120), 0), k * 6);
	}

	int FootiesNear(Actor a, double r)
	{
		int n = 0;
		let it = ThinkerIterator.Create("SICFooty");
		Actor m;
		while (m = Actor(it.Next())) if (m.health > 0 && a.Distance2D(m) < r) n++;
		return n;
	}

	// ---- The pitch: a goal with the cat in it ----

	// Free distance from p (24 units up) toward yaw.
	double Free(Actor probe, Vector3 p, double yaw, double maxd)
	{
		probe.SetOrigin(p, false);
		FLineTraceData d;
		if (!probe.LineTrace(yaw, maxd, 0, TRF_THRUACTORS, 24, data: d)) return maxd;
		return d.Distance;
	}

	// Room for a goal at p with its mouth facing yaw?
	bool Fits(Actor probe, Vector3 p, double yaw)
	{
		Vector2 f = Actor.AngleToVector(yaw), l = Actor.AngleToVector(yaw + 90);
		Vector3 backc = (p.xy - f * SICGoal.GD, p.z);
		for (int s = -1; s <= 1; s += 2)
		{
			if (Free(probe, p, yaw + 90 * s, 110) < 100) return false;
			if (Free(probe, backc, yaw + 90 * s, 110) < 100) return false;
		}
		return Free(probe, p, yaw + 180, 80) >= 70 && Free(probe, p, yaw, 260) >= 250;
	}

	void SpawnPitch(Vector3 p, double yaw, Actor tgt)
	{
		for (int i = 0; i < goals.Size(); i++) if (goals[i]) goals[i].Destroy();
		goals.Clear();
		if (cat) cat.Destroy();
		let g = SICGoal(Actor.Spawn("SICGoal", p));
		g.angle = yaw;
		Vector2 f = Actor.AngleToVector(yaw);
		cat = SICCat(Actor.Spawn("SICCat", (p.xy + f * 46, p.z)));
		cat.goal = g;
		cat.angle = yaw;
		if (tgt) { cat.target = tgt; cat.SetState(cat.SeeState); }
	}

	// Demo and console: put the pitch in front of the player, in the most open direction.
	void KickOff(PlayerPawn mo)
	{
		if (goals.Size())
		{
			Shout("KICK OFF!", Font.CR_GOLD, 70);
			mo.A_StartSound("sic/whistle", CHAN_AUTO, CHANF_OVERLAP, 1, ATTN_NONE);
			excite = 60;
			let it = ThinkerIterator.Create("Actor");
			Actor a;
			while (a = Actor(it.Next()))
				if (a.bIsMonster && a.health > 0 && !a.target) { a.target = mo; a.SetState(a.SeeState); }
			return;
		}
		let probe = Actor.Spawn("SICProbe", mo.pos);
		double bestYaw = mo.angle, bestDist = -1;
		Vector3 best;
		for (int i = 0; i < 16; i++)
		{
			double yaw = mo.angle + (i % 2 ? 1 : -1) * ((i + 1) / 2) * 22.5;
			double run = Free(probe, mo.pos, yaw, 900);
			for (double d = min(run - 90, 720); d >= 380; d -= 40)
			{
				Vector2 xy = mo.pos.xy + Actor.AngleToVector(yaw) * d;
				double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
				Vector3 p = (xy, z);
				if (abs(z - mo.pos.z) > 32 || !Fits(probe, p, yaw + 180)) continue;
				if (d > bestDist) { bestDist = d; bestYaw = yaw; best = p; }
				break;
			}
			if (bestDist >= 560) break;
		}
		probe.Destroy();
		if (bestDist < 0) return;
		mo.A_SetAngle(bestYaw);
		SpawnPitch(best, bestYaw + 180, mo);
		Shout("KICK OFF!", Font.CR_GOLD, 70);
		mo.A_StartSound("sic/whistle", CHAN_AUTO, CHANF_OVERLAP, 1, ATTN_NONE);
	}

	// A normal game: the cat takes the place of the monster farthest from the start that has room for a goal.
	void PlacePitch()
	{
		let mo = players[consoleplayer].mo;
		if (!mo || ThinkerIterator.Create("SICGoal").Next()) return;   // the map has its own pitch
		Array<Actor> cands;
		let it = ThinkerIterator.Create("Actor");
		Actor a;
		while (a = Actor(it.Next())) if (a.bIsMonster && a.health > 0 && !(a is "SICCat")) cands.Push(a);
		let probe = Actor.Spawn("SICProbe", mo.pos);
		Actor bestM;
		Vector3 best;
		double bestYaw, bestDist = -1;
		for (int i = 0; i < cands.Size(); i++)
		{
			let m = cands[i];
			double d = m.Distance2D(mo);
			if (d < 700 || d < bestDist) continue;
			for (int k = 0; k < 8; k++)
			{
				double yaw = k * 45;
				if (Fits(probe, m.pos, yaw)) { bestDist = d; bestM = m; best = m.pos; bestYaw = yaw; break; }
			}
		}
		probe.Destroy();
		if (!bestM) return;
		bestM.ClearCounters();
		bestM.Destroy();
		SpawnPitch(best, bestYaw, null);
		Console.Printf("\cfThe SuperIntelligent Cat has set up its goal somewhere in this level. Go and score!");
	}

	// ---- Events ----

	override void WorldLoaded(WorldEvent e)
	{
		if (!e.IsSaveGame) PlacePitch();
	}

	override void PlayerEntered(PlayerEvent e)
	{
		let mo = players[e.PlayerNumber].mo;
		if (!mo) return;
		mo.GiveInventory("SICBoot", 1);
		mo.player.PendingWeapon = Weapon(mo.FindInventory("SICBoot"));
		mo.A_StartSound("sic/crowd", CHAN_7, CHANF_LOOPING, 0.35, ATTN_NONE);
		Shout("SUPERINTELLIGENT CAT", Font.CR_GOLD, 110);
		sub = "Kick the cube football past Grey Matter FC's genius goalkeeper!";
		subAt = level.maptime;
		subTics = 120;
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		let mo = players[e.Player].mo;
		if (!mo) return;
		if (e.Name ~== "sic_kickoff") KickOff(mo);
		else if (e.Name ~== "sic_demo" && !demoAt) demoAt = max(1, level.maptime);
		else if (e.Name ~== "sic_wave") Wave(mo, max(1, e.Args[0]));
		else if (e.Name ~== "sic_lineup") Lineup(mo);
	}

	// Team photo: the whole Grey Matter FC squad in a row in front of the player (console: netevent sic_lineup).
	void Lineup(PlayerPawn mo)
	{
		static const Name SQUAD[] = { 'SICZombie', 'SICOrc', 'SICRobot', 'SICFireStriker', 'SICPig', 'SICPanda', 'SICMonkey',
			'SICCow', 'SICElephant', 'SICGiraffe', 'SICHog', 'SICCrab', 'SICBee', 'SICParrot', 'SICChick', 'SICLion', 'SICTiger' };
		for (int i = 0; i < SQUAD.Size(); i++)
		{
			double row = i < 9 ? 380 : 620;
			int k = i < 9 ? i : i - 9;
			int n = i < 9 ? 9 : SQUAD.Size() - 9;
			Vector2 xy = mo.pos.xy + Actor.AngleToVector(mo.angle) * row + Actor.AngleToVector(mo.angle + 90) * (k - (n - 1) / 2.) * (i < 9 ? 70 : 120);
			let m = Actor.Spawn(SQUAD[i], (xy, level.PointInSector(xy).floorplane.ZatPoint(xy)));
			if (m) m.angle = mo.angle + 180;
		}
	}

	// A few Grey Matter players run onto the pitch in front of the player.
	void Wave(PlayerPawn mo, int n)
	{
		static const Name TEAM[] = { 'SICZombie', 'SICOrc', 'SICRobot', 'SICFireStriker', 'SICPig', 'SICZombie' };
		int made = 0;
		for (int i = 0; i < n * 12 && made < n; i++)
		{
			// In front of the player first; after a few tries anywhere they can see each other.
			Vector2 xy = mo.Vec2Angle(frandom(300, 560), mo.angle + (i < n * 6 ? frandom(-45, 45) : frandom(0, 360)));
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - mo.pos.z) > 32) continue;
			let m = Actor.Spawn(TEAM[random(0, TEAM.Size() - 1)], (xy, z), ALLOW_REPLACE);
			if (!m) continue;
			if (!m.TestMobjLocation() || !m.CheckSight(mo) || (cat && m.Distance2D(cat) < 120)) { m.Destroy(); continue; }
			Actor.Spawn("SICPoof", m.pos);
			m.target = mo;
			m.SetState(m.SeeState);
			made++;
		}
	}

	int demoAt;   // the stream demo's timeline (netevent sic_demo), in tics since it started; -1 = off

	override void WorldTick()
	{
		if (excite > 0) excite--;
		// A real match in the arena: twelve seconds of celebration, then on to the away games (the Doom levels).
		if (fullTimeAt && !demoAt && level.MapName ~== "MAP01" && level.maptime - fullTimeAt == 35 * 12)
			level.ExitLevel(0, false);
		// Full time: fireworks keep going up in front of the winner for a while.
		if (fullTimeAt && level.maptime - fullTimeAt < 35 * 9 && level.maptime % 12 == 0)
		{
			let w = players[consoleplayer].mo;
			if (w) SICFirework.Launch((w.Vec2Angle(frandom(220, 420), w.angle + frandom(-35, 35)), w.floorz), 0);
		}
		let mo = players[consoleplayer].mo;
		if (!mo) return;
		// The boot is the weapon you start with.
		if (level.maptime == 2 || level.maptime == 8) mo.A_SelectWeapon("SICBoot");
		if (level.maptime == 30)
		{
			let cv = CVar.FindCVar("sic_autorun");
			String run = cv ? cv.GetString() : "";
			if (run ~== "lineup") Lineup(PlayerPawn(mo));
			else if (run ~== "demo" && !demoAt) demoAt = 30;
		}
		// The stream's demo player (the kit pilot) is loaded: run the demo even if the console event got lost.
		if (!demoAt && level.maptime == 40)
		{
			String pilot = "SigfPilot";
			class<StaticEventHandler> pc = pilot;
			if (pc && EventHandler.Find(pc)) demoAt = 40;
		}
		if (demoAt > 0) DemoTick(PlayerPawn(mo), level.maptime - demoAt);
	}

	// The demo shown on stream: the cat alone first (dodges, goals, its lines), then Grey Matter players come on,
	// the TNT launcher has a go at them, and the boot finishes the match against the cat.
	void DemoTick(PlayerPawn mo, int t)
	{
		// Demo only: the demo player is gently pulled back into the attacking zone in front of the cat's goal
		// when it drifts toward the touchline.
		if (goals.Size() && level.MapName ~== "MAP01")
		{
			Vector2 c = (380, 0), d = mo.pos.xy - c;
			double r = d.Length();
			if (r > 420) mo.TryMove(mo.pos.xy - d / r * min(r - 420, 2.0 + (r - 420) * 0.1), 0);
		}
		switch (t)
		{
		case 1:
		{
			// The demo hands the launcher over itself: no detour to the one in the corner.
			let it = ThinkerIterator.Create("SICTNTLauncher");
			Inventory w;
			while (w = Inventory(it.Next())) if (!w.Owner) w.Destroy();
			KickOff(mo);
			break;
		}
		case 560: Wave(mo, 2); break;
		case 860: Wave(mo, 2); break;
		case 1000:
			mo.GiveInventory("SICTNTLauncher", 1);
			mo.GiveInventory("RocketAmmo", 20);
			mo.player.PendingWeapon = Weapon(mo.FindInventory("SICTNTLauncher"));
			Shout("TNT LAUNCHER!", Font.CR_RED, 60);
			break;
		case 1040: Wave(mo, 2); break;
		case 1330:
			mo.player.PendingWeapon = Weapon(mo.FindInventory("SICBoot"));
			mo.TakeInventory("RocketAmmo", 999);
			Wave(mo, 1);
			break;
		case 2150:
		{
			// Demo, final minutes: the referee sends Grey Matter's outfield players off and the genius, alone in goal,
			// is one or two goals from breaking.
			let it = ThinkerIterator.Create("SICFooty");
			Actor m;
			while (m = Actor(it.Next())) if (m.health > 0) { Actor.Spawn("SICPoof", m.pos); m.ClearCounters(); m.Destroy(); }
			if (cat)
			{
				cat.nextSub = int.max;
				if (cat.health > 120) cat.health = 120;
			}
			Shout("SENT OFF! JUST THE CAT LEFT", Font.CR_RED, 70);
			mo.A_StartSound("sic/whistle", CHAN_AUTO, CHANF_OVERLAP, 1, ATTN_NONE);
			break;
		}
		}
	}

	override void WorldThingDied(WorldEvent e)
	{
		let t = e.Thing;
		if (!t || !t.bIsMonster) return;
		int n = clamp(t.SpawnHealth() / 20, 1, 30);
		for (int i = 0; i < n; i++)
		{
			let o = Actor.Spawn("SICXPOrb", t.pos + (0, 0, t.height * 0.5));
			if (o) o.vel = (frandom(-4, 4), frandom(-4, 4), frandom(3, 7));
		}
	}

	// ---- HUD ----

	ui void Text(Font f, int col, double x, double y, String t, double sc, double alpha = 1, bool centre = true)
	{
		if (centre) x -= f.StringWidth(t) * sc / 2;
		Screen.DrawText(f, col, x, y, t, DTA_ScaleX, sc, DTA_ScaleY, sc, DTA_Alpha, alpha);
	}

	override void RenderOverlay(RenderEvent e)
	{
		if (automapactive) return;
		double sw = Screen.GetWidth(), sh = Screen.GetHeight();
		double s = sh / 480.;
		int now = level.maptime;

		// Scoreboard, TV style.
		String score = String.Format("%d - %d", doomScore, catScore);
		int secs = now / 35;
		String clock = String.Format("%02d:%02d", secs / 60, secs % 60);
		double bw = 470 * s, bh = 30 * s, bx = sw / 2 - bw / 2, by = 10 * s;
		Screen.Dim(0x101018, 0.8, int(bx), int(by), int(bw), int(bh));
		Screen.Clear(int(bx), int(by + bh - 3 * s), int(bx + bw / 2), int(by + bh), 0x3a8a3a);
		Screen.Clear(int(bx + bw / 2), int(by + bh - 3 * s), int(bx + bw), int(by + bh), 0x6c3ec4);
		Text(smallfont, Font.CR_GREEN, bx + bw * 0.2, by + 10 * s, "DOOM FC", 1.4 * s);
		Text(smallfont, Font.CR_WHITE, sw / 2, by + 6 * s, score, 2.4 * s);
		Text(smallfont, Font.CR_PURPLE, bx + bw * 0.78, by + 10 * s, "GREY MATTER FC", 1.4 * s);
		Screen.Dim(0x101018, 0.8, int(sw / 2 - 30 * s), int(by + bh), int(60 * s), int(14 * s));
		Text(smallfont, Font.CR_GOLD, sw / 2, by + bh + 3 * s, clock, 1.2 * s);

		// The cat's health bar and its "thinking".
		if (cat && cat.health > 0 && cat.target)
		{
			double hw = 300 * s, hx = sw / 2 - hw / 2, hy = by + bh + 22 * s;
			Text(smallfont, Font.CR_GOLD, sw / 2, hy, "SUPERINTELLIGENT CAT", 1.3 * s);
			hy += 12 * s;
			Screen.Dim(0x000000, 0.7, int(hx - 2 * s), int(hy - 2 * s), int(hw + 4 * s), int(10 * s));
			Screen.Clear(int(hx), int(hy), int(hx + hw * cat.health / double(cat.SpawnHealth())), int(hy + 6 * s), 0xf2c230);
			if (cat.Calculating())
			{
				int pct = clamp((now - cat.calcStart) * 100 / SICCat.CALC_TICS, 0, 99);
				if ((now / 6) % 3) Text(smallfont, Font.CR_GOLD, sw / 2, hy + 12 * s, String.Format("CALCULATING OPTIMAL SAVE... %d%%", pct), 1.4 * s);
			}
		}

		// Big shout: GOAL!, DODGED!, LEVEL UP...
		if (shoutTics && now - shoutAt < shoutTics)
		{
			double t = (now - shoutAt + e.FracTic) / double(shoutTics);
			double pop = t < 0.15 ? 1.0 + (0.15 - t) * 6 : 1.0;
			double a = t > 0.8 ? (1 - t) * 5 : 1;
			double sc = (shoutText == "GOAL!" ? 4.5 : 2.4) * s;
			sc = min(sc, sw * 0.7 / max(1, bigfont.StringWidth(shoutText)));
			Text(bigfont, shoutColor, sw / 2, sh * 0.30, shoutText, sc * pop, a);
		}

		// Full time: the final score, big.
		if (fullTimeAt && now - fullTimeAt > 70 && now - fullTimeAt < 35 * 10)
		{
			String fin = String.Format("DOOM FC %d - %d GREY MATTER FC", doomScore, catScore);
			double fs = min(2.2 * s, sw * 0.8 / max(1, bigfont.StringWidth(fin)));
			Screen.Dim(0x000000, 0.5, 0, int(sh * 0.42), int(sw), int(bigfont.GetHeight() * fs + 16 * s));
			Text(bigfont, Font.CR_GOLD, sw / 2, sh * 0.42 + 8 * s, fin, fs);
		}

		// Subtitles of the cat (or the kick-off hint).
		if (subTics && now - subAt < subTics)
		{
			double a = clamp((subTics - (now - subAt)) / 15., 0, 1);
			double y = sh - 92 * s;
			double tw = smallfont.StringWidth(sub) * 1.45 * s;
			Screen.Dim(0x000000, 0.55 * a, int(sw / 2 - tw / 2 - 8 * s), int(y - 15 * s), int(tw + 16 * s), int(32 * s));
			bool kick = sub.Left(4) == "Kick";
			Text(smallfont, Font.CR_GOLD, sw / 2, y - 12 * s, kick ? "HOW TO PLAY" : "SUPERINTELLIGENT CAT:", 1.2 * s, a);
			Text(smallfont, Font.CR_WHITE, sw / 2, y + 1 * s, sub, 1.45 * s, a);
		}

		// Minecraft XP bar.
		double xw = 280 * s, xh = 6 * s, xx = sw / 2 - xw / 2, xy = sh - 26 * s;
		Screen.Dim(0x000000, 0.75, int(xx - 2 * s), int(xy - 2 * s), int(xw + 4 * s), int(xh + 4 * s));
		Screen.Clear(int(xx), int(xy), int(xx + xw * xp / double(XPNeed())), int(xy + xh), 0x7cf04a);
		Text(smallfont, Font.CR_GREEN, sw / 2, xy - 13 * s, String.Format("%d", xpLevel), 1.3 * s);
	}
}

class SICProbe : Actor
{
	Default { +NOBLOCKMAP +NOGRAVITY +NOINTERACTION Radius 1; Height 1; }
	States { Spawn: TNT1 A -1; Stop; }
}
