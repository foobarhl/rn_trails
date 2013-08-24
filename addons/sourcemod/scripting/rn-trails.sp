/*
 * rn-trails.sp: [foo] bar's Redneck Custom Trails
 * Copyright (c) 2013 [foo] bar <foobarhl@gmail.com> | http://steamcommunity.com/id/foo-bar/
 *
 * With code from:
 *    vog_fireworks.sp by FlyingMongoose http://forums.alliedmods.net/showthread.php?t=71051 
 *    striker_hl2dm_epicexplosions.sp by StrikerMan780
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


#include <sourcemod>
#include <smlib>
#include <sdkhooks>

#include <sdktools_sound.inc>

#define VERSION  "0.23"

public Plugin:myinfo = {
	name = "RN-Trails",
	author = "[foo] bar",
	description = "[foo] bar's redneck custom trails",
	version = VERSION,
	url = "http://www.sixofour.tk/~foobar/"
};


new bool:_debug = false;

#define MAX_TRAIL_ENTITIES	20	// Increase this if you have more than this number of entity defs in your config

#define TRAIL_EFFECT_NONE	Integer:0
#define TRAIL_EFFECT_BEAM 	Integer:1
#define TRAIL_EFFECT_SMOKE 	Integer:2
#define TRAIL_EFFECT_RIBBON 	Integer:3
#define TRAIL_EFFECT_ENERGY 	Integer:4
#define TRAIL_EFFECT_DUST	Integer:5	// Dust can be laggy
#define TRAIL_EFFECT_SPARK	Integer:6
#define TRAIL_EFFECT_TESLA	Integer:7
#define TRAIL_EFFECT_SMOKEPK 	Integer:8

enum EEntityConfig
{
/*	String:trail_effect[21], */

	Integer:owner_offs,
	Integer:trail_effect,
	Integer:trail_effect_activate,	//"trail_effect_playeronly"
	Integer:trail_beam_color_v4[4],
	Float:trail_beam_time,
	Float:trail_beam_iwidth,
	Float:trail_beam_ewidth,
	Float:trail_beam_fadelength,

	Integer:light,
	Float:light_distance,
	String:light_color[16],
	Integer:light_color_v4[4],
	Float:light_time,
	Integer:light_inner_cone,
	Integer:light_cone,
	Integer:light_brightness,
	Float:light_spotlight_radius,
	Integer:light_pitch,

	String:sound_file[255],
	smoke_scale,
	smoke_framerate,

	sparks_scale,
	sparks_framerate,

	dust_scale,
	dust_framerate,

	String:tesla_color[16],
	tesla_radius,
	tesla_beamcount_min,	//int
	tesla_beamcount_max, //int
	tesla_thick_min[10],
	tesla_thick_max[10],
	tesla_lifetime_min[10],
	tesla_lifetime_max[10],
	tesla_interval_min[10],
	tesla_interval_max[10],

	ondeath_effect[20],
	onhurt_effect[20]
};

#define EENTPARAM_TYPE_STRING 1
#define EENTPARAM_TYPE_FLOAT 2
#define EENTPARAM_TYPE_INT 3
#define EENTPARAM_TYPE_VECTOR 4
#define EENTPARAM_TYPE_COLOR 5

enum EEntityConfigParams 
{
	String:name[40],
	dtype,
	dlen,	// For strings
	dfl	// Default value
};


#define ENTITY_STATE_UNKNOWN 	0
#define ENTITY_STATE_CREATED 	1
#define ENTITY_STATE_SPAWNED 	2
#define ENTITY_STATE_GF		3
#define ENTITY_STATE_GF2	4
#define ENTITY_STATE_DEAD	9

new Integer:entity_state[4096];	// bleh

new String:configfile[PLATFORM_MAX_PATH]="";
new Handle:configkv = INVALID_HANDLE;
new smokeModel1;
new smokeModel2;
new firelineModel;

new g_ExplosionSprite;
new g_BlueGlowSprite;
new g_RedGlowSprite;
new g_GreenGlowSprite;
new g_YellowGlowSprite;
new g_PurpleGlowSprite;
new g_OrangeGlowSprite;
new g_WhiteGlowSprite;

new g_BlueLaser;


new g_iLaserSprite;

//new hitGroups[MAXPLAYERS+1];

#define WEPCFG_TRAIL_EFFECT 0
#define WEPCFG_LIGHT_EFFECT 1
#define WEPCFG_ONDEATH_EFFECT 2

#define MAX_GROUPS 3	// 0 = everything, 1 = team 1, 2 = team 2

new entityConfig[MAX_GROUPS][MAX_TRAIL_ENTITIES][EEntityConfig];//  = false;
new String:entityConfigIdx[MAX_GROUPS][MAX_TRAIL_ENTITIES][50];
new Integer:entityConfigIdxc[MAX_GROUPS];





public OnPluginStart()
{
	decho("rn-trails %s starting up in debugging moide", VERSION);

	CreateConVar("rn_trails_version", VERSION, "Version of this mod", FCVAR_DONTRECORD|FCVAR_PLUGIN|FCVAR_NOTIFY);

	LoadConfig();

	HookEvent("player_death",Event_PlayerDeath);
	HookEvent("player_hurt",Event_PlayerHurt);
#if 0
	for(new i=1;i<MaxClients;i++){
		if(IsClientInGame(i))
		{
//			SDKHook(i, SDKHook_TraceAttackPost,Event_TrackAttack);
//			SDKHook(i, SDKHook_OnTakeDamagePost,Event_SdkHookOnTakeDamagePost);
		}
	}
#endif
	AddNormalSoundHook(BlockSound);
	decho("OnPluginStart() finished");

	return;
}

public OnMapStart()
{

	smokeModel1 = PrecacheModel("materials/effects/fire_cloud1.vmt",true);
	smokeModel2 = PrecacheModel("materials/effects/fire_cloud2.vmt",true);
	firelineModel =  PrecacheModel("materials/sprites/fire.vmt",true);

	g_ExplosionSprite = PrecacheModel("materials/sprites/sprite_fire01.vmt",true);

	g_BlueLaser = g_BlueGlowSprite = PrecacheModel("materials/sprites/blueglow1.vmt",true);
	g_RedGlowSprite = PrecacheModel("materials/sprites/redglow1.vmt",true);
	g_GreenGlowSprite = PrecacheModel("materials/sprites/greenglow1.vmt",true);
	g_YellowGlowSprite = PrecacheModel("materials/sprites/yellowglow1.vmt",true);
	g_PurpleGlowSprite = PrecacheModel("materials/sprites/purpleglow1.vmt",true);
	g_OrangeGlowSprite = PrecacheModel("materials/sprites/orangeglow1.vmt",true);
	g_WhiteGlowSprite = PrecacheModel("materials/sprites/glow1.vmt",true);
//	 g_iLaserSprite = PrecacheModel("materials/sprites/crystal_beam1.vmt");
	g_iLaserSprite = PrecacheModel("materials/sprites/laser.vmt");

	decl Integer:grpidx;
	for(grpidx = 0;  grpidx < MAX_GROUPS; grpidx++) {
		for(new i=0; i<entityConfigIdxc[grpidx]; i++){
			new entid=-1;
			if(strlen(entityConfig[grpidx][i][sound_file])>0){
				decl String:buffer2[200];
				decho("Using %s", entityConfig[grpidx][i][sound_file]);
				PrecacheSound(entityConfig[grpidx][i][sound_file],true);
				Format(buffer2,sizeof(buffer2),"sound/%s",entityConfig[grpidx][i][sound_file]);

				decho("rn-trails: AddFileToDownloadsTable %s",buffer2);
				AddFileToDownloadsTable(buffer2);

			}

			while( (entid=FindEntityByClassname(entid, entityConfigIdx[grpidx][i])) != -1 ){
				decho("Hook entity (in map startup) %d", entid);
				SDKHook(entid, SDKHook_SpawnPost, OnEntitySpawned);
				OnEntitySpawned(entid);	// xxx: 
			}
		}
	}
	decho("OnMapStart() finished");
#if defined USETIMER
	if(CreateTimer(0.1, TrailsTimer, _, TIMER_REPEAT)==false){
		SetFailState("Could not create master timer!");
	}
#endif
	return;
}

public OnClientPutInServer(client)
{
#if 0
	SDKHook(client, SDKHook_TraceAttackPost,Event_TrackAttack);
//	SDKHook(client, SDKHook_OnTakeDamagePost,Event_SdkHookOnTakeDamagePost);
#endif
}

public Action:BlockSound(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if(StrEqual(sample,"weapons/grenade/tick1.wav")){
		return(Plugin_Handled);
	}
	return(Plugin_Continue);
}

public Action:Event_TrackAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
	decho("TraceAttack: victim=%d,inflictor=%d,hitgroup=%d",victim,inflictor,hitgroup);
}
public Event_SdkHookOnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype, weapon, const Float:damageForce[3], const Float:damagePosition[3])
{

	new Float:clipos[3];
	GetClientEyePosition(victim,clipos);
	new Float:vecDistance = GetVectorDistance(clipos,damagePosition);
	decho("Victim %d hurt by %d distance=%f",victim,weapon,vecDistance);

//	hitGroups[victim]=hitgroup;
}

public OnEntityCreated(entid, const String:entityname[])
{
	new grpid = 0;

	decl entconfig[EEntityConfig];
	if(!IsValidEntity(entid)){
		decho("rn-trails: OnEntityCreated(%d, %s) is invalid!", entid, entityname);
		return;
	}	

	if(entid < 0 || entid > sizeof(entity_state)){
		PrintToServer("Entity id %d exceeds entity_state size!");
	}

	entity_state[entid] = ENTITY_STATE_CREATED;

//	HookSingleEntityOutput(entid, "OnAwakened", OnEntityOutput_MotionEnabled);

	SDKHook(entid,SDKHook_SpawnPost, OnEntitySpawned);

	return;
}

public OnEntityOutput_MotionEnabled(const String:output[], caller, activator, Float:delay) 
{
	PrintToServer("OnEntityOutput_MotionEnabled output=%s caller=%d activator=%d delay=%f", output, caller, activator, delay);
}

public Integer:MyGetEntityOwner(entid, String:entityname[])
{
	decl String:netClsName[255];
	new Integer:ownerOffs;
	new owner=-1;	

//	decho("Just for shits and giggles: m_iTeamNum for %d/%s is %d", entid, entityname, GetEntPropEnt(entid, Prop_Send, "m_iTeamNum"));
	owner = GetEntPropEnt(entid, Prop_Send, "m_hOwnerEntity");
//	decho("GetEntPropEnt %d/%s m_hOwnerEntity = %d", entid, entityname, owner);
	if(owner>=0){
		return owner;
	}

	if(GetEntityNetClass(entid, netClsName, sizeof(netClsName))==false){
		return 0;	// just default to world
	}

	ownerOffs = FindSendPropInfo(netClsName, "m_hOwnerEntity");
	if(ownerOffs>0){
		owner = GetEntDataEnt2(entid, ownerOffs);

//		decho("GetEntDataEnt2 m_hOwnerEntity = %d", owner);
	}

		if(owner<0)
			return 0;
	return owner;
}

Integer:MyGetClientTeam(client)
{
	if(client==0)
		return(0);
	new Integer:t = GetClientTeam(client);
	if(t<=1)
		return(0);
	return(t-1);
}

public Action:OnEntitySpawned(entid)
{
	entity_state[entid] = ENTITY_STATE_SPAWNED;
	return(Plugin_Continue);
}

#if defined USETIMER
public Action:TrailsTimer(Handle:timer)
#else
public OnGameFrame()
#endif
{
	new entid = -1;
	new Float:position[3];
	decl String:entityname[100];
	
	decl entconfig[EEntityConfig];	

	decl Integer:i2max;

//	i2max = sizeof(entityConfigIdx[grpid]);
//decho("Ping");
	new Integer:owner;
	for(new i = MAX_GROUPS-1; i >=0; i--) {	// run through reverse groups first.  world comes last.
		for(new i2 = 0; i2 < MAX_TRAIL_ENTITIES; i2++){
		
			if(entityConfigIdx[i][i2][0]=='\0'){
				break;
			}

			if(_GetEntityConfig(i,entityConfigIdx[i][i2], entconfig)==false){
				continue;
			}

			if(entconfig[trail_effect] == TRAIL_EFFECT_NONE ) {
				break;
			}

			strcopy(entityname,sizeof(entityname), entityConfigIdx[i][i2]);
			entid = -1;
		
			while((entid = Entity_FindByClassName(entid,entityname))>0)
			{


				owner = MyGetEntityOwner(entid, entityname);
//decho("Team is %d/%d %d", MyGetClientTeam(owner),i, owner);
				if(MyGetClientTeam(owner) != i)
					continue;

				if(entity_state[entid] == ENTITY_STATE_GF)
					entity_state[entid] = ENTITY_STATE_GF2;
				else if(entity_state[entid] < ENTITY_STATE_GF)
					entity_state[entid] = ENTITY_STATE_GF;


				if(entconfig[trail_effect_activate] == 1 && (owner < 0 || owner > MaxClients)){
					PrintToServer("Not applying trail to %s - owner = %d", entityname, owner);
					continue;
				}

				if(entity_state[entid] == ENTITY_STATE_GF){
					// first frame from onspawn 
					if(entconfig[light] != TRAIL_EFFECT_NONE ){
						if(entconfig[light] == Integer:999 ) {
							StrikersCreateLight(entid, "65 105 225 128", 15.0, 5.0, true);
						} else {
							CreateLight(entid, entconfig, true, false);
						}
					}

					if(strlen(entconfig[sound_file]) > 0){
						EmitAmbientSound(entconfig[sound_file],position,entid);
					}

				}

//				decho("  Doing %d to %s",entconfig[trail_effect], entityname);

//				decho("%s owner is %d", entityname,owner);
				
				GetEntPropVector(entid,Prop_Send,"m_vecOrigin",position);
				switch(entconfig[trail_effect]){
					case(TRAIL_EFFECT_BEAM):
					{
		//				decho("CreateBeam(%d,...)", entid);
						if(entity_state[entid] == ENTITY_STATE_GF){	// only initiate once right after spawn.  follows entity
							CreateBeam(entid, entconfig);
						}
					}
					case(TRAIL_EFFECT_SMOKEPK):
					{
						if(entity_state[entid] == ENTITY_STATE_GF){		// only initiate once right after spawn - this one has a movement parent
							PainKiller_CreateCloud(entid, "69 102 237", "69 102 238", 15.0);
						}
					}

					case(TRAIL_EFFECT_SMOKE): {
						smoke(position,entconfig[smoke_scale],entconfig[smoke_framerate]);
					} 
					case(TRAIL_EFFECT_ENERGY): {
						energy(position);
					}
					case(TRAIL_EFFECT_SPARK): {
						spark(position,entconfig[sparks_scale],entconfig[sparks_framerate]);
					}
					case(TRAIL_EFFECT_DUST):{
						dust(position,entconfig[dust_scale],entconfig[dust_framerate]);
					}
					case(TRAIL_EFFECT_RIBBON): {
	//					FireSprites(position);//,scale,framerate);
						ribbon(position);
					}
					case(TRAIL_EFFECT_TESLA): {
						if(entity_state[entid] == ENTITY_STATE_GF){						
							CreateTesla(entid, entconfig);
						}
					}

//					decho("rn-trails: Unknown effect '%d'  configured for %s!", entconfig[trail_effect], entityname);
				}
			}
		}

	}
	return Plugin_Continue;

}

public bool:_GetEntityConfig(Integer:grpid, const String:entname[], entconfig[EEntityConfig])
{
	if(entityConfigIdxc[grpid] == 0 ){
		return(false);
	}
	for(new i = 0; i < entityConfigIdxc[grpid]; i++ ) {
		if(StrEqual(entname, entityConfigIdx[grpid][i])){
			entconfig = entityConfig[grpid][i];
			return(true);
		}
	}
	return(false);
}

public _DumpWeaponConfig(const String:entname[], entconfig[EEntityConfig])
{
	decho("** Dumping config for %s", entname);
	decho("  trail_effect: %d", entconfig[trail_effect]);
	decho("  light=%d", entconfig[light]);
	decho("  light_inner_cone=%s", entconfig[light_inner_cone]);
	decho("  light_distance=%f", entconfig[light_distance]);
	decho("  light_color: %s", entconfig[light_color]);
//	decho("  trail_beam_color: %s", entconfig[trail_beam_color]);
	decho("  trail_beam_color_v4: %d %d %d %d", entconfig[trail_beam_color_v4][0], entconfig[trail_beam_color_v4][1], entconfig[trail_beam_color_v4][2], entconfig[trail_beam_color_v4][3]);
	return;
}

public ColorStringToV4(const String:cstr[], v4arr[])
{
	decl String:buffer[5][5];

	ExplodeString(cstr, " ",buffer, 5, 54, false);

	v4arr[0] = StringToInt(buffer[0]);
	v4arr[1] = StringToInt(buffer[1]);
	v4arr[2] = StringToInt(buffer[2]);
	v4arr[3] = StringToInt(buffer[3]);
}

public _ParseWeaponConfig(kv, Integer:grpid, String:entname[])
{
	decl String:buffer[200];
	new entconfig[EEntityConfig];
	_GetEntityConfig(grpid, entname, entconfig);

#if 0
	KvGetString(kv, "class_name", clsname, sizeof(clsname), "");
	if(clsname[0]!='\0'){
		entconfig[owner_offs] = FindSendPropInfo(clsname,"m_hOwnerEntity");
	}
	decho("Owner offset for %s is %d", entname, entconfig[owner_offs]);
#endif


	KvGetString(kv, "trail_effect", buffer, sizeof(buffer), "");

	if(StrEqual(buffer,"beam")) {
		entconfig[trail_effect] = TRAIL_EFFECT_BEAM;

	} else if(StrEqual(buffer,"smokepk")){
		entconfig[trail_effect] = TRAIL_EFFECT_SMOKEPK;
	} else if(StrEqual(buffer,"smoke")){
		entconfig[trail_effect] = TRAIL_EFFECT_SMOKE;
	} else if(StrEqual(buffer, "ribbon")) {
		entconfig[trail_effect] = TRAIL_EFFECT_RIBBON;
	} else if(StrEqual(buffer,"energy")){
		entconfig[trail_effect] = TRAIL_EFFECT_ENERGY;
	} else if(StrEqual(buffer,"sparks") || StrEqual(buffer,"spark")) {
		entconfig[trail_effect] = TRAIL_EFFECT_SPARK;
	} else if(StrEqual(buffer,"tesla")) {
		entconfig[trail_effect] = TRAIL_EFFECT_TESLA;
	}

	entconfig[trail_effect_activate] = KvGetNum(kv, "trail_effect_activate", 0);

	KvGetString(kv, "trail_beam_color", buffer, sizeof(buffer), "0 0 0 0");
	ColorStringToV4(buffer, entconfig[trail_beam_color_v4]);

	entconfig[trail_beam_time] = KvGetFloat(kv, "trail_beam_time", 2.0);
	entconfig[trail_beam_iwidth] = KvGetFloat(kv, "trail_beam_iwidth", 25.0);
	entconfig[trail_beam_ewidth] = KvGetFloat(kv, "trail_beam_ewidth", 25.0);
	entconfig[trail_beam_fadelength] = KvGetFloat(kv, "trail_beam_fadelength", 10.0);

	KvGetString(kv, "light_color", entconfig[light_color], sizeof(entconfig[light_color]), "");
	if(strlen(entconfig[light_color])>0){
		ColorStringToV4(entconfig[light_color], entconfig[light_color_v4]);
	}

	entconfig[light] = KvGetNum(kv, "light", 0);
	entconfig[light_distance] = KvGetFloat(kv, "light_distance", 0.00 );

	entconfig[light_time]  = KvGetFloat(kv, "light_time", 0.00 );
	entconfig[light_inner_cone] = KvGetNum(kv, "light_inner_cone", 0);
//	KvGetString(kv, "light_inner_cone", entconfig[light_inner_cone], sizeof(entconfig[light_inner_cone]),"");
	entconfig[light_cone] = KvGetNum(kv, "light_cone", 0 );
	entconfig[light_brightness] = KvGetNum(kv, "light_brightness", 0);
	entconfig[light_spotlight_radius] = KvGetFloat(kv, "light_spotlight_radius", 0.00);
	entconfig[light_pitch] = KvGetNum(kv, "light_pitch", 0);

	KvGetString(kv, "tesla_color", buffer, sizeof(buffer), "128 128 128 128");
	entconfig[tesla_radius] = KvGetNum(kv, "tesla_radius", 15);
	entconfig[tesla_beamcount_min] = KvGetNum(kv, "tesla_beamcount_min", 1);
	entconfig[tesla_beamcount_max] = KvGetNum(kv, "tesla_maxeams", 15);
	KvGetString(kv, "tesla_thick_min", entconfig[tesla_thick_min], sizeof(entconfig[tesla_thick_min]), "1");
	KvGetString(kv, "tesla_thick_max", entconfig[tesla_thick_max], sizeof(entconfig[tesla_thick_max]), "1");
	KvGetString(kv, "tesla_lifetime_min", entconfig[tesla_lifetime_min], sizeof(entconfig[tesla_lifetime_min]), "1");
	KvGetString(kv, "tesla_lifetime_max", entconfig[tesla_lifetime_max], sizeof(entconfig[tesla_lifetime_max]), "5");
	KvGetString(kv, "tesla_interval_min", entconfig[tesla_interval_min], sizeof(entconfig[tesla_interval_min]), "1");
	KvGetString(kv, "tesla_interval_max", entconfig[tesla_interval_max], sizeof(entconfig[tesla_interval_max]), "5");
	
	
	KvGetString(kv, "ondeath_effect", entconfig[ondeath_effect], sizeof(entconfig[ondeath_effect]), "");
	KvGetString(kv, "onhurt_effect", entconfig[onhurt_effect], sizeof(entconfig[onhurt_effect]), "");

	KvGetString(kv, "sound_file", entconfig[sound_file], sizeof(entconfig[sound_file]), "");
	
	entconfig[smoke_scale] = KvGetFloat(kv, "smoke_scale", 2.0);
	entconfig[smoke_framerate] = KvGetFloat(kv, "smoke_framerate", 15.0);

	
	entityConfig[grpid][entityConfigIdxc[grpid]] = entconfig;
	strcopy(entityConfigIdx[grpid][entityConfigIdxc[grpid]], 100, entname);
	entityConfigIdxc[grpid]++;
//	_DumpWeaponConfig(entname,entconfig);
	decho("Read config for %d/%s", grpid, entname);
}

public _ParseConfig(kv)
{
	decl String:section[100];
	decl String:buffer2[200];
	do
	{
		KvGetSectionName(kv, section, sizeof(section));

		if(StrEqual(section, "Entities")){
			KvGotoFirstSubKey(kv);
			do {
				KvGetSectionName(kv, buffer2, sizeof(buffer2));
				new grpid = StringToInt(buffer2);
				PrintToServer("parse weapon config grpid=%d / %s", grpid, buffer2);
#if 1
				if(KvGotoFirstSubKey(kv,false)==false){
					continue;
					SetFailState("Section %s had no sub!", buffer2);
				} else {
					do {
						KvGetSectionName(kv, buffer2, sizeof(buffer2));
						PrintToServer("  parse grpid=%d section=%s", grpid, buffer2);
						_ParseWeaponConfig(kv, grpid, buffer2);
					
					} while(KvGotoNextKey(kv,false));
					KvGoBack(kv);
				}
#endif

			} while(KvGotoNextKey(kv));

			KvGoBack(kv);
		} else {
			decho("Ignore top level key %s", section);
		}
	} while(KvGotoNextKey(kv));


}

public LoadConfig()
{
	BuildPath(Path_SM,configfile,sizeof(configfile),"configs/rn-trails2.cfg");

	if(!FileExists(configfile)){
		SetFailState("Unable to load %s",configfile);
		return(-1);
	}
	
	if(configkv != INVALID_HANDLE){
		CloseHandle(configkv);
	}

	configkv = CreateKeyValues("configfile");

	FileToKeyValues(configkv,configfile);
	KvRewind(configkv);
	_ParseConfig(configkv);//,"Weapon Trails","");

	return(Plugin_Handled);

}

public smoke(Float:vec[3],smokescale,smokeframerate)
{
	TE_SetupSmoke(vec, smokeModel1, smokescale, smokeframerate);
	TE_SetupSmoke(vec, smokeModel2, smokescale, smokeframerate);
	TE_SendToAll();
}


public spark(Float:position[3],scale,framerate)
{
	new Float:dir[3]={0.0,0.0,0.0}
	TE_SetupSparks(position,dir,scale,framerate);
	TE_SendToAll();
}

public dust(Float:position[3],scale,framerate)
{
	new Float:dir[3]={0.0,0.0,0.0};
	TE_SetupDust(position,dir,scale,framerate);

	
}

public energy(Float:position[3])
{
	new Float:dir[3]={0.0,0.0,0.0};
	TE_SetupEnergySplash(position,dir,false);
	TE_SendToAll();
}


stock CreateBeam(entid, entconfig[EEntityConfig])
{
	new color[4] = {0,0,0,0};
	color[0] = entconfig[trail_beam_color_v4][0];
	color[1] = entconfig[trail_beam_color_v4][1];
	color[2] = entconfig[trail_beam_color_v4][2];
	color[3] = entconfig[trail_beam_color_v4][3];

	new time = entconfig[trail_beam_time];//2.0;
	new iwidth = entconfig[trail_beam_iwidth];//100.0;
	new ewidth = entconfig[trail_beam_ewidth];//100.0;
	new flength = entconfig[trail_beam_fadelength];//10.0;

	TE_SetupBeamFollow(entid,g_iLaserSprite,0,time,iwidth,ewidth,flength,color);
//	decho("TE_SetupBeamFollow(%d,iLaserSprite,0,%f,%f,%f,%f,%d/%d/%d/%d)", entid, time, iwidth, ewidth, flength, color[0], color[1], color[2], color[3]);
	TE_SendToAll();	
}
public ribbon(Float:startvec[3])
{
	new Float:endvec[3]={0,0,0};
	endvec[0] = startvec[0]+2;
	endvec[1] = startvec[1]+2;
	endvec[2] = startvec[2]+2;


//	fire_line(startvec,endvec);
	new color[4]={255,255,255,200};
#if 1
	color[0] = GetRandomInt(0,255);
	color[1] = GetRandomInt(0,255);
	color[2] = GetRandomInt(0,255);
	color[3] = 255;
#endif
	new r = GetRandomInt(0,3);
	new laser;
	if(r==0){ 
		laser = g_BlueLaser;
	} else if (r==1){
		laser =  g_GreenGlowSprite;
	} else if(r==2){
		laser = g_PurpleGlowSprite;
	} else if(r==3){
		laser = g_WhiteGlowSprite;
	} else if(r==4){

	}

	laser = g_BlueGlowSprite;

	TE_SetupBeamPoints( 
		startvec,
		endvec, 
		laser,//		firelineModel, 	// model index
		0, 	//halo index
		0, 	//initial frame to render
		0, 	//beam frame rate
		0.5, 	//time duration
		2.0, 	//initial width
		5.0, 	//final width
		0, 	//fade time duration
		10.0, 	// beam amplitude
		color, 	// color
		10	// speed
	);
	TE_SendToAll();
}

// from vog_fireworks.sp
public fire_line(Float:startvec[3],Float:endvec[3])
{
	new color[4]={255,255,255,200};
	TE_SetupBeamPoints( startvec,endvec, firelineModel, 0, 0, 0, 0.8, 2.0, 1.0, 1, 0.0, color, 10);
	TE_SendToAll();
}

public FireSprites(Float:vec[3])
{
	new Float:vec2[3];
	vec2 = vec;
	vec2[2] = vec[2] + 300.0;
	fire_line(vec,vec2);
//	sound(vec2);
	//explode(vec2);
	sphere(vec2);
	spark(vec2,1,0.01);
//scale,framerate);
}

public sphere(Float:vec[3])
{
	new Float:rpos[3], Float:radius, Float:phi, Float:theta, Float:live, Float: size, Float:delay;
	new Float:direction[3];
	new Float:spos[3];
	new bright = 255;
	direction[0] = 0.0;
	direction[1] = 0.0;
	direction[2] = 0.0;
	radius = GetRandomFloat(75.0,150.0);

	for (new i=0;i<50;i++)
	{
		new rand = GetRandomInt(0,6);
		delay = GetRandomFloat(0.0,0.5);
		bright = GetRandomInt(128,255);
		live = 2.0 + delay;
		size = GetRandomFloat(0.5,0.7);
		phi = GetRandomFloat(0.0,6.283185);
		theta = GetRandomFloat(0.0,6.283185);
		spos[0] = radius*Sine(phi)*Cosine(theta);
		spos[1] = radius*Sine(phi)*Sine(theta);
		spos[2] = radius*Cosine(phi);
		rpos[0] = vec[0] + spos[0];
		rpos[1] = vec[1] + spos[1];
		rpos[2] = vec[2] + spos[2];

		switch(rand)
		{
			case 0:	TE_SetupGlowSprite(rpos, g_BlueGlowSprite,live, size, bright);
			case 1:	TE_SetupGlowSprite(rpos, g_RedGlowSprite,live, size, bright);
			case 2: TE_SetupGlowSprite(rpos, g_GreenGlowSprite,live, size, bright);
			case 3: TE_SetupGlowSprite(rpos, g_YellowGlowSprite,live, size, bright);
			case 4: TE_SetupGlowSprite(rpos, g_PurpleGlowSprite,live, size, bright);
			case 5: TE_SetupGlowSprite(rpos, g_OrangeGlowSprite,live, size, bright);
			case 6: TE_SetupGlowSprite(rpos, g_WhiteGlowSprite,live, size, bright);
		}
		TE_SendToAll(delay);
	}
}

public explode(Float:vec[3])
{
	TE_SetupExplosion(vec, g_ExplosionSprite, 10.0, 1, 0, 0, 5000); // 600
	TE_SendToAll();
}



public Action:Event_PlayerHurt(Handle:event, const String:entname[], bool:dontBroadcast)
{
//	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
//	new victim   = GetClientOfUserId(GetEventInt(event, "userid"));
//	new headshot   = (GetEventInt(event, "health") == 0 && GetEventInt(event, "hitgroup") == 1);
	decho("Victim health=%d hitgroup=%d",GetEventInt(event, "health") ,GetEventInt(event, "hitgroup"));

	return(Plugin_Handled);
}

public Action:Event_PlayerDeath(Handle:event, const String:entname[], bool:dontBroadcast)
{
	new weapon[40];

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
        new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	new Float:clivec[3] = {0,0,0};

	GetEventString(event,"weapon",weapon,sizeof(weapon));
	
	if( strcmp(weapon,"crossbow_bolt",false)==0) {
		decl entconfig[EEntityConfig];

		if(_GetEntityConfig(MyGetClientTeam(attacker), weapon, entconfig)==false){
			return Plugin_Continue;
		}

		decho("Player killed by crossbow");
		if(StrEqual(entconfig[ondeath_effect],"fireworks")){	// todo: add more. 
			GetClientAbsOrigin(client,clivec);
			explode(clivec);
		//	dust(clivec,1.0,1.0);
			sphere(clivec);	// this is fireworks
		}
	}

	return(Plugin_Continue);
}

stock Gib_Skull(Client)
{
	//Create:
	new Gib_Ent = CreateEntityByName("env_blood");
	if (Gib_Ent == -1)
		return;

	//Set up:
	DispatchSpawn(Gib_Ent);
	DispatchKeyValue(Gib_Ent, "spawnflags", "1");
	DispatchKeyValue(Gib_Ent, "m_iGibs", "1");
	DispatchKeyValue(Gib_Ent, "delay", "0.1");
	DispatchKeyValue(Gib_Ent, "m_flVelocity", "10");
	DispatchKeyValue(Gib_Ent, "m_flVariance", "10");
	DispatchKeyValue(Gib_Ent, "m_flGibLife", "5");
	DispatchKeyValue(Gib_Ent, "renderfx", "0");
	DispatchKeyValue(Gib_Ent, "rendermode", "0");
	DispatchKeyValue(Gib_Ent, "renderamt", "255");
	DispatchKeyValue(Gib_Ent, "shootsounds", "3");
	DispatchKeyValue(Gib_Ent, "simulation", "1");
	DispatchKeyValue(Gib_Ent, "skin", "1");
	DispatchKeyValue(Gib_Ent, "nogibshadows", "true");
	DispatchKeyValue(Gib_Ent, "shootmodel", "models/gibs/hgibs.mdl");

	//Emit:
	AcceptEntityInput(Gib_Ent, "Shoot", Client);
	RemoveEdict(Gib_Ent);

}

public DispatchKeyValueInt(ent, const String:var[], Integer:val)
{
	decl String:buffer[50];
	//IntToString(_:val, buffer, sizeof(buffer));
	Format(buffer, sizeof(buffer), "%d", val);
//	decho("DispatchKeyValue(%d,%s,%s) (was %d)", ent, var, buffer,val);
	return(DispatchKeyValue(ent, var, buffer));
}

// Ported From striker_hl2dm_epicexplosions.sp
stock CreateLight(iEntity, entconfig[EEntityConfig], bool:bAttach = false, bool:bKill = false, String:strAttachmentPoint[]="")
{
	if ( !IsValidEdict(iEntity)) {
		return -1;
	}
	new iLight = CreateEntityByName("light_dynamic");
	
	if (IsValidEntity(iLight)) {
		// Spawn and start
		DispatchKeyValueInt(iLight, "inner_cone", entconfig[light_inner_cone]);
		DispatchKeyValueInt(iLight, "cone", entconfig[light_cone]);
		DispatchKeyValueInt(iLight, "brightness", entconfig[light_brightness]);
		DispatchKeyValueFloat(iLight, "spotlight_radius", entconfig[light_spotlight_radius]);
		DispatchKeyValueFloat(iLight, "distance", entconfig[light_distance]);
		DispatchKeyValue(iLight, "_light", entconfig[light_color]);
//		decho("Light color is %s", entconfig[light_color]);
		DispatchKeyValueInt(iLight, "pitch", entconfig[light_pitch]);
		DispatchKeyValueInt(iLight, "style", entconfig[light]);
		
		// Teleport and attach
		decl Float:fPosition[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fPosition);
		TeleportEntity(iLight, fPosition, NULL_VECTOR, NULL_VECTOR);
		
		if (bAttach == true) {
			SetVariantString("!activator");
			AcceptEntityInput(iLight, "SetParent", iEntity, iLight, 0);            
			decl strParent[5];
			Format(strParent,sizeof(strParent), "%d", iEntity);
			DispatchKeyValue(iLight, "Parent", strParent);
			
			if (StrEqual(strAttachmentPoint, "") == false)
			{
				SetVariantString(strAttachmentPoint);
				AcceptEntityInput(iLight, "SetParentAttachmentMaintainOffset", iLight, iLight, 0);                
			}
		}
		
		DispatchSpawn(iLight);
		
		ActivateEntity(iLight);
		AcceptEntityInput(iLight, "TurnOn");
	} else {
		decho("CreateLight: Invalid entity %d", iEntity);
	}
	
	if(bKill == true)
	{
		CreateTimer(entconfig[light_time], Timer_KillLight, iLight);
	}
	
	return iLight;
}

// From striker_hl2dm_epicexplosions.sp for testing reasons. Set light = 999 to use this instead of the ported version above
stock StrikersCreateLight(iEntity, String:strColor[], Float:distance, Float:time, bool:bAttach = false, bool:bKill = false, String:strAttachmentPoint[]="")
{
	if ( !IsValidEdict(iEntity))
	{
		return -1;
	}
	
	new iLight = CreateEntityByName("light_dynamic");
	
	if (IsValidEntity(iEntity))
	{
		// Spawn and start
		DispatchKeyValue(iLight, "inner_cone", "0");
		DispatchKeyValue(iLight, "cone", "80");
		DispatchKeyValue(iLight, "brightness", "1");
		DispatchKeyValueFloat(iLight, "spotlight_radius", 240.0);
		DispatchKeyValueFloat(iLight, "distance", distance);
		DispatchKeyValue(iLight, "_light", strColor);
		DispatchKeyValue(iLight, "pitch", "-90");
		DispatchKeyValue(iLight, "style", "5");
		
		// Teleport and attach
		decl Float:fPosition[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fPosition);
		TeleportEntity(iLight, fPosition, NULL_VECTOR, NULL_VECTOR);
		
		if (bAttach == true)
		{
			SetVariantString("!activator");
			AcceptEntityInput(iLight, "SetParent", iEntity, iLight, 0);            
			
			if (StrEqual(strAttachmentPoint, "") == false)
			{
				SetVariantString(strAttachmentPoint);
				AcceptEntityInput(iLight, "SetParentAttachmentMaintainOffset", iLight, iLight, 0);                
			}
		}
		
		DispatchSpawn(iLight);
		
		ActivateEntity(iLight);
		AcceptEntityInput(iLight, "TurnOn");
	}
	
	if(bKill == true)
	{
		CreateTimer(time, Timer_KillLight, iLight);
	}
	
	return iLight;
}

// from striker_hl2dm_epicexplosions.sp
public Action:Timer_KillParticle(Handle:timer, any:entity)
{
	if (IsValidEdict(entity))
	{
		decl String:Classname[64];
		GetEdictClassname(entity, Classname, sizeof(Classname));

		//Is a Particle:
		if(StrEqual(Classname, "info_particle_system", false))
		{
			AcceptEntityInput(entity, "Stop");
			AcceptEntityInput(entity, "ClearParent");
			AcceptEntityInput(entity, "Kill");
		}
	}
}

// striker_hl2dm_epicexplosions.sp
public Action:Timer_KillLight(Handle:timer, any:entity)
{
	if (IsValidEdict(entity))
	{
		decl String:Classname[64];
		GetEdictClassname(entity, Classname, sizeof(Classname));

		//Is a Particle:
		if(StrEqual(Classname, "light_dynamic", false))
		{
			AcceptEntityInput(entity, "kill");
		}
	}
}



stock CreateTesla(entid,  entconfig[EEntityConfig], bool:bAttach=true)
{
	new tesla = CreateEntityByName("point_tesla");
	if(IsValidEntity(tesla)){
		DispatchKeyValue(tesla, "m_Color", entconfig[tesla_color]);
		DispatchKeyValueInt(tesla, "m_flRadius", entconfig[tesla_radius]);
		DispatchKeyValueInt(tesla, "beamcount_min", entconfig[tesla_beamcount_min]);
		DispatchKeyValueInt(tesla, "beamcount_max", entconfig[tesla_beamcount_max]);
		DispatchKeyValue(tesla, "thick_min", entconfig[tesla_thick_min]);
		DispatchKeyValue(tesla, "thick_max", entconfig[tesla_thick_max]);
		DispatchKeyValue(tesla, "lifetime_min", entconfig[tesla_lifetime_min]);
		DispatchKeyValue(tesla, "lifetime_max", entconfig[tesla_lifetime_max]);
		DispatchKeyValue(tesla, "interval_min", entconfig[tesla_interval_min]);
		DispatchKeyValue(tesla, "interval_max", entconfig[tesla_interval_max]);



		// Teleport and attach
		decl Float:fPosition[3];
		GetEntPropVector(entid, Prop_Send, "m_vecOrigin", fPosition);
		TeleportEntity(tesla, fPosition, NULL_VECTOR, NULL_VECTOR);
		
		if (bAttach == true)
		{
			SetVariantString("!activator");
			AcceptEntityInput(tesla, "SetParent", entid, tesla, 0);            
			
#if 0
			if (StrEqual(strAttachmentPoint, "") == false)
			{
				SetVariantString(strAttachmentPoint);
				AcceptEntityInput(tesla, "SetParentAttachmentMaintainOffset", tesla, tesla, 0);                
			}
#endif
		}

		DispatchSpawn(tesla);
		ActivateEntity(tesla);
		AcceptEntityInput(tesla, "TurnOn");

	}
}

stock decho(const String:myString[], any:...)
{
	if(_debug == false )
		return;

	decl myFormattedString[1024];
	VFormat(myFormattedString, sizeof(myFormattedString), myString, 2);
 
	PrintToServer("rn-trails: %s",  myFormattedString);
	
}

stock PainKiller_CreateCloud(pent, String:Color1[], String:Color2[],  Float:Time, Float:Scale1 = 15.0, Float:Scale2 = 15.0, Float:vOffset = 0.0)
{
	if (!IsValidEntity(pent))
	{
		return -1;
	}
	
	new Float:vOrigin[3];
	
	new ent = CreateEntityByName("env_smoketrail");
	if (ent)
	{		
		DispatchKeyValue(ent, "startcolor", Color1);
		DispatchKeyValue(ent, "endcolor", Color2);
		DispatchKeyValueFloat(ent, "lifetime", Time);
		DispatchKeyValueFloat(ent, "emittime", 60.0);
		DispatchKeyValueFloat(ent, "startsize", Scale1);
		DispatchKeyValueFloat(ent, "endsize", Scale2);
		DispatchKeyValueFloat(ent, "minspeed", 15.0);
		DispatchKeyValueFloat(ent, "maxspeed", 30.0);
		DispatchKeyValueFloat(ent, "spawnradius", 15.0);
		DispatchKeyValue(ent, "firesprite", "sprites/firetrail.spr");
		DispatchKeyValue(ent, "smokesprite", "sprites/whitepuff.spr");

		GetEntPropVector(pent, Prop_Send, "m_vecOrigin", vOrigin);
		vOrigin[2] += vOffset;
		TeleportEntity(ent, vOrigin, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(ent);

		SetVariantString("!activator");
		AcceptEntityInput(ent, "SetParent", pent, ent, 0);

//		SetEntityMoveType(ent, MOVETYPE_NOCLIP);
		
	}

	return ent;
}