#Credit to Rinn, cakyrespa, zarqon, heeheehee, Theraze

record _skills {
	string name;
	int id;
	boolean perm;
	boolean hc_perm;
	boolean usable;
};

_skills [int] skills;

int [int] skill_list(int start, int end) {
	int [int] lst;
	foreach i in skills
		if(i >= start && i <= end)
			lst[count(lst)] = i;
	return lst;
}

void list_append(int[int] dst, int[int] src) {
	foreach i, sk in src {
		dst[count(dst)] = sk;
	}
}

buffer build_line(_skills s) {
	buffer temp;
	temp.append("<tr");
	if (!s.usable)
		temp.append(" style='color: #999; text-decoration: line-through;'");
	temp.append('><td><img style="max-width:20;max-height:20;" src="/images/itemimages/');
	temp.append(to_skill(s.id).image);
	temp.append('" border=0 class=hand onClick=\'javascript:poop("desc_skill.php?whichskill=');
	temp.append(s.id);
	temp.append('&self=true","skill", 350, 300)\'></td>');
	temp.append("<td valign=center><a onClick='javascript:poop(\"desc_skill.php?whichskill=" + s.id + "&self=true\",\"skill\", 350, 300)'>" + s.name + "</a></td>");
	if (s.hc_perm)
		temp.append("<td><b>HP</b></td>");
	else if (s.perm) temp.append("<td>P</td>");
	else temp.append("<td>-</td>");
	temp.append("</tr>");
	remove skills[s.id];  // Only allow each skill to be added once.
	return temp;
}

string build_title_line(string t) {
	return ("<tr><td colspan=3 align='center'><b>" + t + "</b></td></tr>");
}

string build_sub_title_line(string t) {
	return ("<tr><td colspan=3 align='center'><i>" + t + "</i></td></tr>");
}

buffer build_section(int [int] lst, string t, boolean sub, boolean sorted) {

	// First sort lst
	int level(int sk) {
		int lvl = to_skill(sk).level;
		if(lvl < 0) return 99; // Non guild skills go last
		return lvl;
	}
	if(sorted) {
		if(lst[0] < 1000)
			sort lst by skills[value].name;	// sort class independant skill by name
		else
			sort lst by level(value);		// Sort class skills by level
	}
	
	buffer s;
	if(count(lst) > 0) {
		boolean title = (t == "");
		foreach i, sk in lst {
			if (!title) {
				if (!sub) {
					s.append(build_title_line(t));
				}
				else {
					s.append(build_sub_title_line(t));
				}
				title = true;
			}
			s.append(build_line(skills[sk]));
		}
	}
	clear(lst);
	return s;
}

buffer build_section(int [int] lst, string t, boolean sub) {
	return build_section(lst, t, sub, true);
}
string build_section(int [int] lst, string t) {
	return build_section(lst, t, false);
}

void parse_skills(string sub, boolean usable, boolean self) {
	matcher skillmatch = create_matcher(self? "whichskill\\=(\\d+)&[^>]+>(.+?)</a>(.*?)<br>"
		: '<a onclick="javascript:skill\\\(([0-9]+)\\\)">(.+?)</a> \\\((P|<b>HP</b>)\\\)', sub);
	while(skillmatch.find()) {
		int skill_id = skillmatch.group(1).to_int();
		skills[skill_id].name = skillmatch.group(2);
		skills[skill_id].id = skill_id;
		skills[skill_id].hc_perm = skillmatch.group(3).contains_text("<b>HP</b>");
		skills[skill_id].perm = self? skills[skill_id].hc_perm || skillmatch.group(3).contains_text("(P)"): true;
		skills[skill_id].usable = usable;
	}
	
	// Toggle Optimality doesn't appear on the charsheet
	if((self || form_field("who") == my_id()) && have_skill($skill[toggle optimality])) {
		int skill_id = to_int($skill[toggle optimality]);
		skills[skill_id].name = "Toggle Optimality";
		skills[skill_id].id = skill_id;
		skills[skill_id].hc_perm = true;
		skills[skill_id].perm = true;
		skills[skill_id].usable = true;
	}
}

// self is true for charsheet, but false for showplayer relay
buffer skill_list(buffer source, boolean self) {

	// Find skill block
	string skill_block;
	matcher skillMatch = create_matcher(self? '</td></tr><tr><td>(<a.*?)</td>'
		: '(<tr class="pskill">.*?)<tr><td height=1 bgcolor=black>', source);
	if(skillMatch.find())
		skill_block = skillMatch.group(1);
	else return source;
	// If the match fails it means the charsheet didn't load correctly (typically from being in a combat).
	
	// Build the skills for the main block.
	buffer results = source;
	parse_skills(skill_block, true, self);

	// Check for permanent skills you can't use right now, we mark these with a strikethrough and gray to tell you that they are unusable.
	if(self && find(skillMatch = create_matcher("<tr><td height=1 bgcolor=black></td></tr><tr><td><a id='permlink'.+?show permanent skills.*?(<a.+?)</td></tr>", source))) {
		parse_skills(skillMatch.group(1), false, self);
		results.replace_string(skillMatch.group(0), ""); // Remove the block entirely from the output.
	}

	// Rebuild the entire section as a table.
	buffer rep;
	int [int] lst;
	
	void add_class(buffer b, class c) {
		int i = to_int(c) * 1000;
		b.append(build_section(skill_list(i, i + 999), c));
	}
	
	// First Avatar Paths, since their skills are all you have during that path. Other important path skills are pretty important also!
	switch(my_path()) {
	case "Way of the Surprising Fist":
		rep.append(build_section(skill_list(0064, 0074), "Teachings of the Fist"));
		break;
	case "Heavy Rains":
		rep.append(build_section(skill_list(16001, 16027), "Heavy Rains"));
		break;
	case "Avatar of West of Loathing":
		foreach c in $classes[Cow Puncher, Beanslinger, Snake Oiler]
			rep.add_class(c);
		break;
	case "The Source":
		rep.append(build_section(skill_list(21000, 21011), "The Source"));
		break;
	case "Nuclear Autumn":
		rep.append(build_section(skill_list(22000, 22039), "Nuclear Autumn"));
		break;
	case "Gelatinous Noob":
		lst.list_append(skill_list(23000, 23000));
		lst.list_append(skill_list(23201, 23203));
		rep.append(build_section(lst, "Gelatinous Noob"));
		
		// Add value to all remaining Gelatinous Noob skills
		matcher mod;
		foreach id,rec in skills {
			skill sk = to_skill(id);
			if(sk.class == $class[Gelatinous Noob])
				if( find(mod = create_matcher("(Hot|Cold|Spooky|Sleaze|Stench|Muscle|Mysticality|Moxie)?.*?:( [+-]?\\d+)", 
					(sk.passive? sk.string_modifier("Modifiers"): sk.to_effect().string_modifier("Modifiers")))) )
						rec.name += "<span style='float:right;'>( " + mod.group(1) + mod.group(2) + " ) &nbsp;</span>";
		}
		
		rep.append(build_section(skill_list(23301, 23306), "Combat Frequency", true, false));
		rep.append(build_section(skill_list(23026, 23030), "Damage Absorption", true, false));
		rep.append(build_section(skill_list(23031, 23035), "Damage Reduction", true, false));
		rep.append(build_section(skill_list(23036, 23040), "Initiative", true, false));
		rep.append(build_section(skill_list(23041, 23045), "Experience", true, false));
		rep.append(build_section(skill_list(23046, 23050), "Absorb Adventures", true, false));
		rep.append(build_section(skill_list(23051, 23055), "Absorb Stats", true, false));
		rep.append(build_section(skill_list(23056, 23060), "Maximum HP Percent", true, false));
		rep.append(build_section(skill_list(23061, 23065), "Maximum MP Percent", true, false));
		rep.append(build_section(skill_list(23066, 23070), "Item Drop", true, false));
		rep.append(build_section(skill_list(23071, 23075), "Pickpocket Chance", true, false));
		rep.append(build_section(skill_list(23076, 23080), "Meat Drop", true, false));
		rep.append(build_section(skill_list(23081, 23095), "Stat Bonus", true, false));
		rep.append(build_section(skill_list(23096, 23100), "Weapon Damage", true, false));
		rep.append(build_section(skill_list(23001, 23025), "Elemental Resistance", true, false));
		rep.append(build_section(skill_list(23101, 23125), "Elemental Damage", true, false));
		break;
	default:
		if(my_class().to_int() > 6)
			rep.add_class(my_class());
		else
			rep.append(build_section(skill_list(0021,0027), "Bad Moon", true));
	}

	// Now the basic classes
	for c from 1 to 6
		rep.add_class(to_class(c));

	buffer misc_sort;

	lst.list_append(skill_list(74, 74));		// Master of the Surprising Fist
	lst.list_append(skill_list(82, 82));		// Request Sandwich
	lst.list_append(skill_list(117, 117));		// Belch The Rainbow
	lst.list_append(skill_list(17047, 17047));	// Mild Curse
	misc_sort.append(build_section(lst, "Challenge Path Trophies", true));

	// Clan Dungeons
	misc_sort.append(build_section(skill_list(092, 106), "Clan Dungeon: Dreadsylvania", true));
	lst.list_append(skill_list(028, 037));
	lst.list_append(skill_list(042, 043));
	lst.list_append(skill_list(038, 041));
	misc_sort.append(build_section(lst, "Clan Dungeon: Hobopolis", true));
	misc_sort.append(build_section(skill_list(046, 048), "Clan Dungeon: Slime Tube", true));
	
	lst.list_append(skill_list(045, 045));		// Crimbo 2008: Vent Rage Gland
	lst.list_append(skill_list(053, 053));		// Crimbo 2009: Summon Crimbo Candy
	lst.list_append(skill_list(056, 062));		// Crimbo 2010: Wassail, Toynado, Fashionably Late, Executive Narcolepsy, Lunch Break, Offensive Joke, Managerial Manipulation
	lst.list_append(skill_list(110, 111));		// Crimbo 2013: Shrap & Psychokinetic Hug
	lst.list_append(skill_list(125, 127));		// Crimbo 2014: Rapid Prototyping, Mathematical Precision, Ruthless Efficiency
	lst.list_append(skill_list(152, 152));		// Crimbo 2015: Communism!
	lst.list_append(skill_list(166, 167));		// Crimbo 2016: Sweet Synthesis & Stack Lumps
	misc_sort.append(build_section(lst, "Crimbo Skills", true, false));

	misc_sort.append(build_section(skill_list(136, 140), "Deck of Many Things", true));

	# misc_sort.append(build_section(skill_list(141, 143), "Elemental Plane of Hot", true));
	# misc_sort.append(build_section(skill_list(112, 114), "Elemental Plane of Sleaze", true));
	# misc_sort.append(build_section(skill_list(119, 120), "Elemental Plane of Spooky", true));
	# misc_sort.append(build_section(skill_list(130, 133), "Elemental Plane of Stench", true));

	lst.list_append(skill_list(112, 114));		// Sleaze Charter
	lst.list_append(skill_list(119, 120));		// Spooky Charter
	lst.list_append(skill_list(130, 133));		// Stench Charter
	lst.list_append(skill_list(141, 143));		// Hot Charter
	lst.list_append(skill_list(145, 148));		// Cold Charter
	misc_sort.append(build_section(lst, "Elemental Planes", true));

	misc_sort.append(build_section(skill_list(0162,0165), "Gingerbread", true));

	lst.list_append(skill_list(080, 081));
	lst.list_append(skill_list(107, 107));
	lst.list_append(skill_list(118, 118));
	lst.list_append(skill_list(121, 121));
	lst.list_append(skill_list(128, 128));
	lst.list_append(skill_list(134, 135));
	lst.list_append(skill_list(144, 144));
	lst.list_append(skill_list(7254, 7254));
	misc_sort.append(build_section(lst, "Jack's Swagger Shop", true));

	misc_sort.append(build_section(skill_list(0010,0014), "Regnaissance Gnome", true));

	misc_sort.append(build_section(skill_list(0170,0173), "Spacegate", true));

	# lst.list_append(skill_list(44, 44));		// 2008 Traveling Trader: Rainbow Gravitation
	# lst.list_append(skill_list(54, 54));		// 2010 Uncle P's Antiques: Unaccompanied Miner
	# lst.list_append(skill_list(55, 55));		// 2010 Bigg's Dig: Volcanometeor Showeruption
	# lst.list_append(skill_list(63, 63));		// 2011 Valhalla Invasion: Natural Born Skeleton Killer
	# lst.list_append(skill_list(75, 75));		// 2011 Haunted Sorority House: Summon "Boner Battalion"
	# lst.list_append(skill_list(83, 86));		// 2012 Brushfires: Frigidalmatian and 2012 Silent Invasion skills
	# lst.list_append(skill_list(115, 115));		// 2014 Twitch I: Alien Source Code
	# misc_sort.append(build_section(lst, "Various World Events", true));

	// I don't think the following ever appear on the charsheet.
	misc_sort.append(build_section(skill_list(7000, 7999), "Conditional"));
	misc_sort.append(build_section(skill_list(8000, 8999), "Mystical Bookshelf"));
	
	// Finally, the remaining unsorted skills get added to res before adding the rest of the classless skills.
	lst.list_append(skill_list(000, 999));		// Class Independant skills not already added to misc_sort
	lst.list_append(skill_list(17047, 17047));	// Mild Curse
	# lst.list_append(skill_list(23000, 99999));	// Any skills not yet added to KoLmafia (Classes after Nuclear Autumn)
	rep.append(build_section(lst, "Class-Independent"));

	rep.append(misc_sort);

	// Any classes not yet added to KoLmafia (Classes after Nuclear Autumn)
	rep.append(build_section(skill_list(23000, 99999), "Unsorted Skills"));
	
	if(self) {
		results.replace_string("<tr><td>" + skill_block + "</td></tr>", rep);
		results.replace_string(	"<tr><td height=1 bgcolor=black></td></tr>", "<tr><td height=1 bgcolor=black colspan=3></td></tr>");
		results.replace_string(	"<tr><td>(<b>", "<tr><td colspan=3>(<b>");
		
		// add a link to your public charsheet
		results.replace_string("<center><table><tr><td><center><img src", "<center><table><tr><td><center><a href=\"showplayer.php?who="+my_id()+"\" title=\"View public charsheet\"><img src");
		results.replace_string("An Adventurer is You!\">","An Adventurer is You!\"></a>");
	} else {
		rep.replace_string("<tr>", '<tr class="pskill">');
		results.replace_string(skill_block, rep);
		results.replace_string('<tr><td align="center"><a href="#" class="nounder"', '<tr><td align="center" colspan=3><a href="#" class="nounder"');
		results.replace_string('<tr><td height=1 bgcolor=black></td></tr>', '<tr><td height=1 bgcolor=black colspan=3></td></tr>');
	}
	
	// Style links
	results.replace_string("</style>", "a:hover {color:blue;}</style>");

	return results;
}

void main() {
	visit_url().skill_list(true).write();
}
