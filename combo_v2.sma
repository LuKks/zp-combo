#include <amxmodx>
#include <amxmisc>

#include hamsandwich
#include zombieplague

#include fakemeta

new admin, hud, saytext, happyhour, Float:gametime;

new Float:combo_time[33], combo_count[33], combo_hits[33], combo_last_dmg[33], combo_need_dmg[33], combo_total_dmg[33];

new cvar_damage, cvar_admin, cvar_time;
new cvar_happyhour, cvar_hh_start, cvar_hh_end, cvar_hh_user, cvar_hh_admin;
new cvar_red, cvar_green, cvar_blue, cvar_x, cvar_y, cvar_effect;

#define is(%1,%2) %1 & (1 << %2 & 31)

public combo_required_dmg(id, victim) {
	return combo_count[id] * 12 + 515 + get_pcvar_num(cvar_damage)
				- (is(admin, id) ? get_pcvar_num(cvar_admin) : 0)
				- (happyhour ? (is(admin, id) ? get_pcvar_num(cvar_hh_admin) : get_pcvar_num(cvar_hh_user)) : 0)
				- (zp_get_user_zombie(id) && !zp_get_user_nemesis(id) && zp_get_user_survivor(victim) ? 300 : 0);
}

public plugin_init() {
	register_plugin("[ZP] sistema de combos", "2.0.0", "LuKks");

	register_clcmd("say /hh", "clcmd_happyhour");
	register_clcmd("say /hf", "clcmd_happyhour");

	register_event("HLTV", "event_round_start", "a", "1=0", "2=0");
	RegisterHam(Ham_TakeDamage, "player", "take_damage");

	hud = CreateHudSyncObj();
	saytext = get_user_msgid("SayText");
	
	cvar_damage = register_cvar("zp_combo_damage", "0");
	cvar_admin = register_cvar("zp_combo_admin", "100");
	cvar_time = register_cvar("zp_combo_time", "7.0");

	cvar_happyhour = register_cvar("zp_combo_happyhour", "1");
	cvar_hh_start = register_cvar("zp_combo_hh_start", "22");
	cvar_hh_end = register_cvar("zp_combo_hh_end", "10");
	cvar_hh_user = register_cvar("zp_combo_hh_user", "100");
	cvar_hh_admin = register_cvar("zp_combo_hh_admin", "200");
	
	cvar_red = register_cvar("zp_combo_red", "235");
	cvar_green = register_cvar("zp_combo_green", "235");
	cvar_blue = register_cvar("zp_combo_blue", "0");
	
	cvar_x = register_cvar("zp_combo_x", "-1.0");
	cvar_y = register_cvar("zp_combo_y", "0.65");
	
	cvar_effect = register_cvar("zp_combo_effect", "0");
}

public client_putinserver(id) {
	if(is_user_admin(id)) {
		admin |= 1 << id & 31;
	}
}

public client_disconnect(id) {
	remove_task(id);
	combo_end(id);

	admin &= ~(1 << id & 31);
}

public clcmd_happyhour(id) {
	if(!get_pcvar_num(cvar_happyhour)) {
		return PLUGIN_CONTINUE;
	}

	new h[3], m[3];
	get_time("%H", h, 2);
	get_time("%M", m, 2);

	h[0] = get_pcvar_num(happyhour ? cvar_hh_end : cvar_hh_start) - str_to_num(h);
	if(h[0] < 0) {
		h[0] += 24;
	}

	m[0] = 60 - str_to_num(m);

	print(id, id, "^4[ZP]^3 Faltan ^4%d^3 hora%s y ^4%d^3 minuto%s para que ^4%s^3 la hora feliz.", h[0] - 1, h[0] == 2 ? "" : "s", m[0], m[0] == 1 ? "" : "s", happyhour ? "finalice" : "comience");
	return PLUGIN_HANDLED;
}

public event_round_start() {
	set_cvar_num("zp_human_damage_reward", 0);
	set_cvar_num("zp_zombie_damage_reward", 0);
	set_cvar_num("zp_nem_ignore_rewards", 1);
	set_cvar_num("zp_surv_ignore_rewards", 1);

	if(!get_pcvar_num(cvar_happyhour)) {
		return;
	}
	
	new h[3];
	get_time("%H", h, 2);

	h[0] = str_to_num(h); //h
	h[1] = get_pcvar_num(cvar_hh_start); //s
	h[2] = get_pcvar_num(cvar_hh_end); //e

	happyhour = h[1] < h[2] ? (h[0] >= h[1] && h[0] < h[2]) : (h[0] >= h[1] || h[0] < h[2]);
	//readability = s < e ? (h >= s && h < e) : (h >= s || h < e);

	print(0, 33, "^4[ZP]^3 Horario de la hora feliz: ^4%dhs^3 a ^4%dhs^3 (/hh o /hf).", get_pcvar_num(cvar_hh_start), get_pcvar_num(cvar_hh_end));

	if(happyhour) {
		print(0, 33, "^4[ZP]^3 Estamos en hora feliz, ^4ganaras mas ammopacks^3 al hacer combos.")
	}
	else {
		clcmd_happyhour(0);
	}
}

public zp_round_ended(winteam) {
	for(new i = get_maxplayers(); i > 0; i--) {
		if(is_user_connected(i)) {
			combo_end(i);
		}
	}
}

public take_damage(victim, inflictor, attacker, Float:damage) {
	if(attacker != victim && is_user_connected(attacker) && is_user_connected(victim)) {
		combo_last_dmg[attacker] = floatround(damage);
		combo_total_dmg[attacker] += combo_last_dmg[attacker];
		combo_need_dmg[attacker] += combo_last_dmg[attacker];
		combo_hits[attacker]++;
		
		while(combo_need_dmg[attacker] >= combo_required_dmg(attacker, victim)) {
			combo_need_dmg[attacker] -= combo_required_dmg(attacker, victim);
			combo_count[attacker]++;
		}

		gametime = get_gametime();
		
		if(combo_time[attacker] < gametime) {
			combo_time[attacker] = gametime + 0.1;
			combo_damaging(attacker, victim);
		}
	}
}

public zp_user_infected_post(id, infector, nemesis) {
	if(infector && !nemesis) {
		take_damage(id, infector, infector, random_float(515.0 + get_pcvar_num(cvar_damage), 1015.0 + get_pcvar_num(cvar_damage))); //always 1 ammopack (and bit more)
		combo_hits[infector]--;

		combo_end(id);
	}
}

public combo_damaging(id, victim) {
	set_hudmessage(
		get_pcvar_num(cvar_red), get_pcvar_num(cvar_green), get_pcvar_num(cvar_blue),
		get_pcvar_float(cvar_x), get_pcvar_float(cvar_y), get_pcvar_num(cvar_effect),
		get_pcvar_float(cvar_time) - 1.0, get_pcvar_float(cvar_time) - 1.0, 0.33, 1.0
	); //Ã±

	ShowSyncHudMsg(id, hud, "+%s Ammopacks - Hits %s^nDaño %s^n%s / %s", addpoints(combo_count[id]), addpoints(combo_hits[id]), addpoints(combo_last_dmg[id]), addpoints(combo_need_dmg[id]), addpoints(combo_required_dmg(id, victim)));

	remove_task(id);
	set_task(get_pcvar_float(cvar_time), "combo_end", id);
}

public combo_end(id) {
	ClearSyncHud(id, hud);

	if(combo_count[id]) {
		print(id, id, "^4[ZP]^3 Ammopacks: ^4+%s^3 ^1|^3 Daño total: ^4%s^3 en ^4%s^3 hits!", addpoints(combo_count[id]), addpoints(combo_total_dmg[id]), addpoints(combo_hits[id]));

		zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) + combo_count[id]);
	}

	combo_count[id] = combo_hits[id] = combo_last_dmg[id] = combo_need_dmg[id] = combo_total_dmg[id] = 0;
}

stock print(id, color, message[], any:...) {
	static msg[256];
	vformat(msg, charsmax(msg), message, 4);
	
	message_begin(id ? MSG_ONE : MSG_ALL, saytext, { 0, 0, 0 }, id);
	write_byte(color ? color : 33);
	write_string(msg);
	message_end();
}

stock addpoints(num) {
	new res[15], i, c;
	static str[15], len;

	for(len = num_to_str(num, str, 14); i < len; i++) {
		i && (len - i) % 3 == 0 && (res[c++] = '.');
		res[c++] = str[i];
	}

	return res;
}
